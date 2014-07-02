/*jshint node:true*/
module.exports = function(grunt) {
  require('load-grunt-tasks')(grunt, ['grunt-*']);
  var path = require('path'),
      fs = require('fs'),
      nodeFs = require('node-fs'),
      shell = require('shelljs'),
      child_process = require('child_process');

  var BOWER_DIR = 'bower_components';
  var APP_DIR = 'app';
  var DIST_DIR = 'dist';
  // The directory to build into before merging with the existing distribution.
  var DIST_TEMP_DIR = 'dist_tmp';
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
      APP_NAME: 'aurin-esp'
    }
  };

  var ATLAS_PATH = bowerPath('atlas');
  var ATLAS_BUILD_PATH = path.join(ATLAS_PATH, 'dist');
  var ATLAS_BUILD_FILE = path.join(ATLAS_BUILD_PATH, 'atlas.min.js');
  var ATLAS_RESOURCES_PATH = path.join(ATLAS_PATH, 'assets');
  var ATLAS_CESIUM_PATH = bowerPath('atlas-cesium');
  var ATLAS_CESIUM_BUILD_PATH = path.join(ATLAS_CESIUM_PATH, 'dist');
  var ATLAS_CESIUM_BUILD_FILE = path.join(ATLAS_CESIUM_BUILD_PATH, 'atlas-cesium.min.js');
  var ATLAS_CESIUM_RESOURCES_PATH = path.join(ATLAS_CESIUM_PATH, 'dist', 'cesium');
  var ATLAS_CESIUM_STYLE_FILE = path.join(ATLAS_CESIUM_BUILD_PATH, 'atlas-cesium.min.css');

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
            cwd: ATLAS_RESOURCES_PATH,
            src: '**/*',
            dest: publicPath('atlas', 'assets')
          },
          {
            expand: true,
            cwd: ATLAS_CESIUM_RESOURCES_PATH,
            src: '**/*',
            dest: publicPath('atlas-cesium', 'cesium')
          }
        ]
      }
    },
    clean: {
      dist: {
        files: [
          {
            expand: true,
            cwd: DIST_TEMP_DIR,
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
    shell.exec('cd ' + APP_DIR + ' && mrt install');
  });

  grunt.registerTask('fix-atlas-build', 'Fixes the Atlas build.', function(arg1) {
    // Replace the path to the cesium style which is now in the app's public folder.
    writeFile(ATLAS_CESIUM_STYLE_FILE, function(data) {
      return data.replace(/(@import\s+["'])(cesium)/, '$1atlas-cesium/$2');
    });
  });

  grunt.registerTask('build-atlas', 'Builds Atlas.', function(arg1) {
    var isLazy = arg1 === 'lazy';
    if (!isLazy || !fs.existsSync(ATLAS_BUILD_FILE)) {
      console.log('Atlas needs building...');
      shell.cd(ATLAS_PATH);
      shell.exec('grunt build');
    }
    if (!isLazy || !fs.existsSync(ATLAS_CESIUM_BUILD_FILE)) {
      console.log('Atlas-Cesium needs building...');
      shell.cd(ATLAS_CESIUM_PATH);
      shell.exec('grunt build');
    }
  });

  grunt.registerTask('build', 'Builds the app.', function() {
    mkdir(DIST_DIR);
    var cmd = 'meteor bundle --debug --directory ' + path.join('..', DIST_TEMP_DIR);
    shell.cd(APP_DIR);
    shell.exec(cmd);
    shell.cd('..');
    // Remove existing files in app directories to prevent conflicts or old files remaining.
    shell.rm('-rf', path.join(DIST_DIR, 'programs'));
    shell.cp('-Rf', path.join(DIST_TEMP_DIR, '*'), DIST_DIR);
    shell.rm('-rf', DIST_TEMP_DIR);
  });

  grunt.registerTask('deploy', 'Deploys the built app.', function(arg1) {
    var config;
    // All fs, process, shell methods are relative to this directory now.
    var result = shell.cd(DIST_DIR);
    if (result === null) {
      console.log('Run `grunt build` before deploy.');
      return;
    }
    var done = this.async();
    if (arg1 === 'heroku') {
      config = DEPLOY_CONFIGS.HEROKU;
      function updateHeroku() {
        execAll(['git pull heroku master', 'git add -A', 'git commit -am "Deployment."',
          'git push heroku master', 'heroku restart']);
        done();
      }
      console.log('Deploying on Heroku...');
      if (!fs.existsSync('.git')) {
        console.log('Setting up git repo...');
        shell.cd('..');
        shell.rm('-rf', DIST_TEMP_DIR);
        shell.mv(DIST_DIR, DIST_TEMP_DIR);
        var herukoGitRepo = 'git@heroku.com:' + config.APP_NAME + '.git';
        var runClone = runProcess('git', ['clone ' + herukoGitRepo + ' ' + DIST_DIR]);
        runClone.on('exit', function() {
          exec('git clone ' + herukoGitRepo + ' ' + DIST_DIR);
          shell.cd(DIST_DIR);
          execAll(['heroku git:remote -a ' + config.APP_NAME, 'git pull heroku master']);
          var tmpDistDir = path.join('..', DIST_TEMP_DIR);
          shell.cp('-Rf', path.join(tmpDistDir, '*'), '.');
          shell.rm('-rf', tmpDistDir);
          updateHeroku();
        });
      } else {
        console.log('Using existing git repo...');
        updateHeroku();
      }
    } else {
      console.log('Deploying locally...');
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
      var runNode = runProcess('node', ['main.js']);
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

  grunt.registerTask('default', ['install']);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // AUXILIARY
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // PROCESSES

  /**
   * Runs a child process; prints stdout and stderr. Arguments match child_process.spawn().
   * @param cmd
   * @param args
   * @param options
   * @returns {*}
   */
  function runProcess(cmd, args, options) {
    console.log('Running process: ', cmd, args, options);
    var proc = child_process.spawn(cmd, args, options);
    proc.stdout.on('data', function(data) {
      process.stdout.write(data.toString('utf8'));
    });
    proc.stderr.on('data', function(data) {
      process.stdout.write(data.toString('utf8'));
    });
    return proc;
  }

  function execAll(cmds, log) {
    log = log === undefined ? true : log;
    return cmds.forEach(function(cmd) {
      exec(cmd, log);
    });
  }

  function exec(cmd, log) {
    log = log === undefined ? true : log;
    log && console.log(cmd);
    shell.exec(cmd);
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
