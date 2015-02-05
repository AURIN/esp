/*jshint node:true*/
module.exports = function(grunt) {
  require('load-grunt-tasks')(grunt, ['grunt-*']);
  var path = require('path'),
      fs = require('fs'),
      nodeFs = require('node-fs'),
      shell = require('shelljs'),
      child_process = require('child_process'),
      _ = require('underscore');

  var APP_ID = 'aurin-esp';
  var BOWER_DIR = 'bower_components';
  var APP_DIR = 'app';
  var DIST_DIR = 'dist';
  // The directory to build into before merging with the existing distribution.
  var DIST_TEMP_DIR = 'dist_tmp';
  var HEROKU_DIR = 'heroku';
  var HEROKU_CONFIG_DIR = path.join('deploy', 'heroku');
  var PUBLIC_DIR = appPath('public');

  var DEPLOY_CONFIGS = {
    LOCAL: {
      MONGO_USER: null,
      MONGO_PASSWORD: null,
      MONGO_HOST: 'localhost',
      MONGO_PORT: '27017',
      MONGO_DB_NAME: APP_ID,
      DEPLOY_URL: 'http://localhost',
      DEPLOY_PORT: '3000'
    },
    HEROKU: {
      // Environment variables are configured in Heroku app settings.
      APP_NAME: APP_ID
    }
  };

  var ATLAS_PATH = bowerPath('atlas');
  var ATLAS_BUILD_PATH = path.join(ATLAS_PATH, 'dist');
  var ATLAS_BUILD_FILE = path.join(ATLAS_BUILD_PATH, 'atlas.min.js');
  var ATLAS_RESOURCES_PATH = path.join(ATLAS_BUILD_PATH, 'resources');
  var ATLAS_ASSETS_PATH = path.join(ATLAS_PATH, 'assets');
  var ATLAS_CESIUM_PATH = bowerPath('atlas-cesium');
  var ATLAS_CESIUM_BUILD_PATH = path.join(ATLAS_CESIUM_PATH, 'dist');
  var ATLAS_CESIUM_BUILD_FILE = path.join(ATLAS_CESIUM_BUILD_PATH, 'atlas-cesium.min.js');
  var ATLAS_CESIUM_RESOURCES_PATH = path.join(ATLAS_CESIUM_PATH, 'dist', 'cesium');
  var ATLAS_CESIUM_STYLE_FILE = path.join(ATLAS_CESIUM_BUILD_PATH, 'resources',
      'atlas-cesium.min.css');
  var ATLAS_RESOURCES_REPO = 'https://bitbucket.org/mutopia/atlas-resources.git';
  var PUBLIC_PARENT_DIR = 'design';
  var PUBLIC_PARENT_PATH = publicPath(PUBLIC_PARENT_DIR);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CONFIG
  //////////////////////////////////////////////////////////////////////////////////////////////////

  grunt.initConfig({
    copy: {
      atlasResources: {
        files: [
          {
            expand: true,
            cwd: ATLAS_ASSETS_PATH,
            src: '**/*',
            dest: path.join(PUBLIC_PARENT_PATH, 'atlas', 'assets')
          },
          {
            expand: true,
            cwd: ATLAS_CESIUM_RESOURCES_PATH,
            src: '**/*',
            dest: path.join(PUBLIC_PARENT_PATH, 'atlas-cesium', 'cesium')
          },
          {
            expand: true,
            cwd: ATLAS_RESOURCES_PATH,
            src: '**/*',
            dest: path.join(PUBLIC_PARENT_PATH, 'atlas', 'resources')
          }
        ]
      }
    },
    clean: {
      dist: {
        files: [
          {
            expand: true,
            cwd: DIST_DIR,
            src: [
              path.join('**', '*')
            ]
          }
        ]
      },
      atlasResources: {
        files: [
          {
            expand: true,
            cwd: path.join(PUBLIC_PARENT_PATH, 'atlas-cesium', 'cesium', 'Source'),
            src: [
              path.join('**', 'package.json')
            ]
          }
        ]
      }
    }
  });

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INSTALL TASKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  grunt.registerTask('install', 'Installs all dependencies', function() {
    var args = arguments,
        tasks = [],
        addTasks = function() {
          Array.prototype.slice.apply(arguments).forEach(function(task) {
            tasks.push(task);
          });
        },
        hasArgs = function(arg) {
          return Object.keys(args).some(function(argIndex) {
            var value = args[argIndex];
            return value === arg;
          });
        };
      addTasks('install-meteor-packages', 'setup-atlas-resources');
    console.log('Running tasks', tasks);
    tasks.forEach(function(task) {
      grunt.task.run(task);
    })
  });

  grunt.registerTask('install-mrt', 'Installs Meteorite dependencies.', function() {
    // TODO(aramk) Run this as a child process since it causes huge CPU lag otherwise.
    shell.exec('cd ' + APP_DIR + ' && mrt install');
  });

  grunt.registerTask('install-meteor-packages', 'Installs Meteor dependencies manually to avoid \
      Meteorite installing all transient dependencies for packages when we only need to provide a \
      few custom forks.', function() {
    var done = this.async();
    shell.cd(path.join(APP_DIR, 'packages'));
    execAll([
      'git clone https://github.com/aramk/Meteor-cfs-tempstore.git cfs-tempstore',
      'git clone https://github.com/aramk/Meteor-cfs-s3.git cfs-s3',
      'git clone https://github.com/aramk/meteor-collection-hooks.git collection-hooks --branch feature/exceptions --single-branch'
    ], function() {
      done();
    });
  });

  grunt.registerTask('build-atlas', 'Builds Atlas.', function(arg1) {
    var isLazy = arg1 === 'lazy';
    var dirname = __dirname;
    if (!isLazy || !fs.existsSync(ATLAS_BUILD_FILE)) {
      console.log('Atlas needs building...');
      shell.cd(ATLAS_PATH);
      shell.exec('grunt build');
      shell.cd(dirname);
    }
    if (!isLazy || !fs.existsSync(ATLAS_CESIUM_BUILD_FILE)) {
      console.log('Atlas-Cesium needs building...');
      shell.cd(ATLAS_CESIUM_PATH);
      shell.exec('grunt build');
      shell.cd(dirname);
    }
  });

  grunt.registerTask('setup-atlas-resources', 'Sets up the static resources for Atlas.',
    function() {
      var done = this.async();
      if (fs.existsSync(PUBLIC_PARENT_PATH)) {
        // Update the git repo for Atlas resources.
        shell.cd(PUBLIC_PARENT_PATH);
        runProcess('git pull', {
          exit: function() {
            done();
          }
        });
      } else {
        // Clone the git repo for Atlas resources.
        shell.cd(PUBLIC_DIR);
        runProcess('git clone ' + ATLAS_RESOURCES_REPO + ' ' + PUBLIC_PARENT_DIR, {
          exit: function() {
            done();
          }
        });
      }
  });

  grunt.registerTask('build', 'Builds the app.', function(arg1) {
    mkdir(DIST_DIR);
    shell.rm('-rf', path.join(DIST_DIR, '*'));
    var debug = arg1 === 'debug' ? '--debug' : '';
    var cmd = 'meteor build ' + debug + ' --directory ' + path.join('..', DIST_TEMP_DIR);
    shell.cd(APP_DIR);
    shell.exec(cmd);
    shell.cd('..');
    // Remove existing files in app directories to prevent conflicts or old files remaining.
    shell.cp('-Rf', path.join(DIST_TEMP_DIR, 'bundle', '*'), DIST_DIR);
    shell.rm('-rf', DIST_TEMP_DIR);
  });

  grunt.registerTask('deploy', 'Deploys the built app.', function(arg1, arg2) {
    var config;
    var done = this.async();
    if (arg1 === 'modulus') {
      deployModulus(done);
    } else if (arg1 === 'heroku') {
      deployHeroku(done);
    } else if (arg1 === 'meteor') {
      shell.cd(APP_DIR);
      var cmd = 'meteor deploy ' + APP_ID + '.meteor.com';
      if (arg2 === 'debug') {
        cmd += ' --debug';
      }
      runProcess(cmd, {
        exit: function() {
          done();
        }
      });
    } else {
      console.log('Deploying locally...');
      var result = shell.cd(DIST_DIR);
      if (result === null) {
        console.log('Run `grunt build` before deploy.');
        return;
      }
      if (arg2 !== 'lazy') {
        shell.cd(path.join('programs', 'server'));
        // Install all dependencies.
        shell.exec('npm install');
        shell.cd('../..');
      }
      config = DEPLOY_CONFIGS.LOCAL;
      var MONGO_URL = 'mongodb://' + urlAuth(config.MONGO_USER, config.MONGO_PASSWORD) +
          config.MONGO_HOST + ':' + config.MONGO_PORT + '/' +
          config.MONGO_DB_NAME;
      var env = {
        MONGO_URL: MONGO_URL,
        ROOT_URL: config.DEPLOY_URL,
        PORT: config.DEPLOY_PORT
      };
      for (var name in env) {
        shell.env[name] = env[name];
      }
      var runNode = runProcess('node', ['main.js']);
      runNode.on('exit', function() {
        done();
      });
    }
  });

  grunt.registerTask('meteor', function() {
    var done = this.async();
    process.chdir(APP_DIR);
    var proc;
    var env = {
      AURIN_SERVER_URL: 'http://115.146.86.33:8080/envisionauth',
      AURIN_APP_NAME: 'Lens10',
      METEOR_ADMIN_PASSWORD: 'password',
      METEOR_ADMIN_EMAIL: 'admin@test.com'
    };

    var args = _.toArray(arguments);
    var hasArg = _.memoize(function(arg) {
      return args.indexOf(arg) >= 0;
    });
    var processArgs = {options: {env: env}};
    if (hasArg('debug')) {
      _.extend(env, {
        NODE_OPTIONS: '--debug-brk'
      });
    }
    if (hasArg('acs-local')) {
      _.extend(env, {
        ACS_ENV: 'local'
      });
    }
    _.extend(env, process.env);
    proc = runProcess('meteor', processArgs);
    proc.on('exit', function() {
      done();
    });
  });

  grunt.registerTask('laika', function() {
    var done = this.async();
    process.chdir(APP_DIR);
    var args = '';
    for (var i = 0; i < arguments.length; i++) {
      args += ' --' + arguments[i];
    }
    var proc = runProcess('laika --timeout 10000 --debug-brk ' + args);
    proc.on('exit', function() {
      done();
    });
  });

  grunt.registerTask('migrations-lock-reset', 'Resets the lock on the MongoDB database.', function() {
    shell.cd(APP_DIR);
    shell.exec('echo \'db.migrations.update({_id:"control"}, {$set:{"locked":false}});\' | meteor mongo')
  });

  grunt.registerTask('default', ['install']);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // AUXILIARY
  //////////////////////////////////////////////////////////////////////////////////////////////////

  function deployModulus(done) {
    shell.cd(APP_DIR);
    runProcess('modulus deploy --project-name ' + APP_ID, {
      exit: function() {
        done();
      }
    });
  }

  function deployHeroku(done) {
    if (!fs.existsSync('.git')) {
      console.log('Run `grunt build` before deploy.');
      done();
      return;
    }

    var config = DEPLOY_CONFIGS.HEROKU;

    function setUpGit(callback) {
      console.log('Setting up git repo...');
      var herukoGitRepo = 'git@heroku.com:' + config.APP_NAME + '.git';
      var runClone = runProcess('git clone ' + herukoGitRepo + ' ' + HEROKU_DIR);
      runClone.on('exit', function() {
        shell.cd(HEROKU_DIR);
        execAll(['heroku git:remote -a ' + config.APP_NAME, 'git pull heroku master'], function() {
          shell.cd('..');
          callback();
        });
      });
    }

    function copyDist() {
      console.log('Copying build...');
      // Remove existing files to avoid keeping outdated source files.
      shell.rm('-rf', path.join(HEROKU_DIR, '*'));
      shell.cp('-Rf', path.join(DIST_DIR, '*'), HEROKU_DIR);
      // Comment this if we don't want to overwrite config files in heroku git repo.
      shell.cp('-Rf', path.join(HEROKU_CONFIG_DIR, '*'), HEROKU_DIR);
      removeNpmGitIgnores();
    }

    function removeNpmGitIgnores() {
      console.log('Removing git ignores in npm/...');
      shell.echo(shell.pwd());
      var npmPath = path.join(HEROKU_DIR, 'programs', 'server', 'npm');
      shell.exec('find ' + npmPath + ' -type f -name .gitignore | xargs rm');
    }

    function updateHeroku() {
      copyDist();
      console.log('Updating heroku app...');
      shell.cd(HEROKU_DIR);
      execAll(['git pull heroku master', 'git add -A', 'git commit -am "Deployment."',
        'git push heroku master', 'heroku restart'], function() {
        shell.cd('..');
        done();
      });
    }

    console.log('Deploying on Heroku...');
    if (!fs.existsSync(HEROKU_DIR)) {
      setUpGit(updateHeroku);
    } else {
      console.log('Using existing git repo...');
      updateHeroku();
    }
  }

  // PROCESSES

  /**
   * Runs a child process; prints stdout and stderr.
   * @param {String} cmd - A single command name. If it contains spaces, they are treated as
   * arguments.
   * @param {Object|Array} [args] - If given as an array, this becomes args.args.
   * @param {Array} [args.args] - The arguments invoked on the given command.
   * @param {Object} [args.options] - The options passed to child_process.spawn().
   * @param {Function} [args.data] - Invoked with the response data when the command responds with
   * data.
   * @param {Function} [args.error] - Invoked with the response data when the command has
   * completed with an error.
   * @param {Function} [args.exit] - Invoked when the command has completed successfully.
   * @returns {ChildProcess}
   */
  function runProcess(cmd, args) {
    if (args && args.length !== undefined) {
      args = {args: args};
    }
    args = _.extend({
      args: [],
      options: {}
    }, args);
    var matches = cmd.match(/(\w+)(\s+.+)/);
    if (matches) {
      cmd = matches[1];
      var cmdArgs = matches[2];
      cmdArgs = cmdArgs.trim().split(/\s+/);
      args.args = cmdArgs.concat(args.args);
    }
    console.log('Running process: ', cmd, args.args);
    var proc = child_process.spawn(cmd, args.args, args.options);
    proc.stdout.on('data', function(data) {
      process.stdout.write(data.toString('utf8'));
      args.success && args.success(data);
    });
    proc.stderr.on('data', function(data) {
      process.stdout.write(data.toString('utf8'));
      args.error && args.error(data);
    });
    proc.on('exit', function(data) {
      args.exit && args.exit(data);
    });
    return proc;
  }

  /**
   *
   * @param {Array} cmds
   * @param {Object} args
   * @param {Function} [args.beforeCall] - Called before each command is executed.
   * @param {Function} [args.afterCall] - Called after each command is executed.
   * @param {Function} [args.afterAll] - Called after all commands are executed.
   */
  function runProcessSeries(cmds, args) {
    args = _.extend({}, args);
    var processes = [];
    _.each(cmds, function(cmd, i) {
      var callNext = function() {
        console.log('success');
        args.afterCall && args.afterCall(cmd);
        if (i < cmds.length - 1) {
          processes[i]();
        } else {
          args.afterAll && args.afterAll();
        }
      };
      var _run = function() {
        args.beforeCall && args.beforeCall(cmd);
        runProcess(cmd, {
          exit: callNext
        });
      };
      if (i === 0) {
        _run();
      } else {
        processes.push(_run);
      }
    });
  }

  function execAll(cmds, callback) {
    // TODO(aramk) ShellJS.exec() is CPU intensive for long asynchronous tasks, use child process
    // for now.
    // TODO(aramk) Use Futures to make this synchronous without callbacks.
    runProcessSeries(cmds, {
      beforeCall: function(cmd) {
        console.log(cmd);
      },
      afterAll: function() {
        callback && callback();
      }
    });
  }

  // FILES

  function readFile(file) {
    return fs.readFileSync(file, {encoding: 'utf-8'});
  }

  function writeFile(file, data) {
    if (typeof data === 'function') {
      data = data(readFile(file));
    }
    fs.writeFileSync(file, data);
  }

  function mkdir(dir, callback) {
    nodeFs.mkdirSync(dir, 0777, true, callback);
  }

  // PATHS

  function _prefixPath(dir, args) {
    var prefixedArgs = Array.prototype.slice.apply(args);
    prefixedArgs.unshift(dir);
    return path.join.apply(path, prefixedArgs);
  }

  function bowerPath() {
    return _prefixPath(BOWER_DIR, arguments);
  }

  function appPath() {
    return _prefixPath(APP_DIR, arguments);
  }

  function publicPath() {
    return _prefixPath(PUBLIC_DIR, arguments);
  }

  // STRINGS

  function urlAuth(username, password) {
    var auth = '';
    if (username) {
      auth += username;
    }
    if (password) {
      auth += ':' + password;
    }
    if (auth) {
      auth += auth + '@';
    }
    return auth;
  }

};
