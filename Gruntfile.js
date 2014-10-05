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
  var PUBLIC_DIR = appPath('public');

  var DEPLOY_CONFIGS = {
    LOCAL: {
      MONGO_USER: null,
      MONGO_PASSWORD: null,
      MONGO_HOST: 'localhost',
      MONGO_PORT: '27017',
      MONGO_DB_NAME: 'aurin-esp',
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
  var PUBLIC_PARENT_DIR = 'design';
  var PUBLIC_PARENT_PATH = publicPath(PUBLIC_PARENT_DIR);

  var bowerPaths = [ATLAS_PATH, ATLAS_CESIUM_PATH];
  var npmPaths = [ATLAS_PATH, ATLAS_CESIUM_PATH];
  var gruntPaths = [ATLAS_PATH, ATLAS_CESIUM_PATH];

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
    addTasks('install-bower', 'install-npm', 'install-grunt');
    addTasks('build-atlas' + (hasArgs('atlas-lazy') ? ':lazy' : ''));
    addTasks('fix-atlas-build', 'copy:atlasResources', 'install-mrt');
    console.log('Running tasks', tasks);
    tasks.forEach(function(task) {
      grunt.task.run(task);
    })
  });

  grunt.registerTask('install-bower', 'Gets all bower dependencies', function() {
    ['.'].concat(bowerPaths).forEach(function(dir) {
      grunt.log.writeln(dir + ': running bower install');
      shell.exec('cd ' + dir + ' && bower install');
    });
  });

  grunt.registerTask('install-npm', 'Gets all node dependencies', function() {
    npmPaths.forEach(function(dir) {
      grunt.log.writeln(dir + ': running npm install');
      shell.exec('cd ' + dir + '&& npm install --cache-min 999999999');
    });
  });

  grunt.registerTask('install-grunt', 'Runs "grunt install" on all dependencies.', function() {
    gruntPaths.forEach(function(dir) {
      grunt.log.writeln(dir + ': running grunt install');
      shell.exec('cd ' + dir + ' && grunt install');
    });
  });

  grunt.registerTask('install-mrt', 'Installs Meteorite dependencies.', function() {
    // TODO(aramk) Run this as a child process since it causes huge CPU lag otherwise.
    shell.exec('cd ' + APP_DIR + ' && mrt install');
  });

  grunt.registerTask('fix-atlas-build', 'Fixes the Atlas build.', function(arg1) {
    // Replace the path to the cesium style which is now in the app's public folder.
    writeFile(ATLAS_CESIUM_STYLE_FILE, function(data) {
      return data.replace(/(@import\s+["'])[^;]*cesium/,
              '$1' + path.join(PUBLIC_PARENT_DIR, 'atlas-cesium', 'cesium'));
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

  grunt.registerTask('build', 'Builds the app.', function() {
    mkdir(DIST_DIR);
    var cmd = 'meteor build --debug --directory ' + path.join('..', DIST_TEMP_DIR);
    shell.cd(APP_DIR);
    shell.exec(cmd);
    shell.cd('..');
    // Remove existing files in app directories to prevent conflicts or old files remaining.
    shell.rm('-rf', path.join(DIST_DIR, 'programs'));
    shell.cp('-Rf', path.join(DIST_TEMP_DIR, 'bundle', '*'), DIST_DIR);
    shell.rm('-rf', DIST_TEMP_DIR);
  });

  grunt.registerTask('deploy', 'Deploys the built app.', function(arg1, arg2) {
    var config;
    var done = this.async();
    // TODO(aramk) Run this as a child process since it causes huge CPU lag otherwise.
    if (arg1 === 'heroku') {
      buildHeroku(done);
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
      // TODO(aramk) Fix paths for this.
      throw new Error('Not supported yet.');
      var result = shell.cd(DIST_DIR);
      if (result === null) {
        console.log('Run `grunt build` before deploy.');
        return;
      }
      shell.cd(path.join('programs', 'server'));
      shell.rm('-rf', 'node_modules/fibers');
      shell.rm('-rf', 'node_modules/bcrypt');
      shell.exec('npm install fibers@1.0.1');
      shell.exec('npm install bcrypt@0.7.7');
      shell.cd('../..');
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
      var runNode = runProcess('node', {args: ['main.js']});
      runNode.on('exit', function() {
        done();
      });
    }
  });

  grunt.registerTask('meteor', function() {
    var done = this.async();
    process.chdir(APP_DIR);
    var proc = runProcess('meteor');
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

  grunt.registerTask('default', ['install']);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // AUXILIARY
  //////////////////////////////////////////////////////////////////////////////////////////////////

  function buildHeroku(done) {
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
        execAll(['heroku git:remote -a ' + config.APP_NAME, 'git pull heroku master'], function () {
          shell.cd('..');
          callback();
        });
      });
    }

    function copyDist() {
      shell.cp('-Rf', path.join(DIST_DIR, '*'), HEROKU_DIR);
    }

    function updateHeroku() {
      copyDist();
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
   * @param {Object} [args]
   * @param {Array} [args.args] The arguments invoked on the given command.
   * @param {Object} [args.options] The options passed to child_process.spawn().
   * @param {Function} [args.data] Invoked with the response data when the command responds with
   * data.
   * @param {Function} [args.error] Invoked with the response data when the command has
   * completed with an error.
   * @param {Function} [args.exit] Invoked when the command has completed successfully.
   * @returns {ChildProcess}
   */
  function runProcess(cmd, args) {
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
    console.log('Running process: ', cmd, args);
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
    args = _.extend({
    }, args);
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
