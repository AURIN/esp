/*jshint node:true*/
module.exports = function(grunt) {
  require('load-grunt-tasks')(grunt, ['grunt-*']);
  var path = require('path'),
      fs = require('fs'),
      shell = require('shelljs');

  var BOWER_DIR = 'bower_components';
  var APP_DIR = 'app';
  var PUBLIC_DIR = appPath('public');

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

    }
  });

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INSTALL TASKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  grunt.registerTask('install', 'Installs all dependencies', function () {
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
    writeFile(ATLAS_CESIUM_STYLE_FILE, function (data) {
      return data.replace(/(@import\s+["'])(cesium)/, '$1atlas-cesium/$2');
    });
  });

  grunt.registerTask('build-atlas', 'Builds Atlas.', function(arg1) {
    var isLazy = arg1 === 'lazy';
    if (!isLazy || !fs.existsSync(ATLAS_BUILD_FILE)) {
      console.log('Atlas needs building...');
      shell.exec('cd ' + ATLAS_PATH + ' && grunt build');
    }
    if (!isLazy || !fs.existsSync(ATLAS_CESIUM_BUILD_FILE)) {
      console.log('Atlas-Cesium needs building...');
      shell.exec('cd ' + ATLAS_CESIUM_PATH + ' && grunt build');
    }
  });

  grunt.registerTask('meteor', 'Runs Meteor.', function() {
    shell.exec('cd ' + APP_DIR + ' && meteor');
  });

  grunt.registerTask('default', ['install']);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // AUXILIARY
  //////////////////////////////////////////////////////////////////////////////////////////////////

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

};
