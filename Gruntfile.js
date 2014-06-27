/*jshint node:true*/
module.exports = function(grunt) {
  require('load-grunt-tasks')(grunt, ['grunt-*']);
  var path = require('path'),
      fs = require('fs'),
      shell = require('shelljs');

  var BOWER_DIR = 'bower_components';
  var PUBLIC_DIR = 'public';

  var ATLAS_PATH = bowerPath('atlas');
  var ATLAS_BUILD_PATH = path.join(ATLAS_PATH, 'dist');
  var ATLAS_BUILD_FILE = path.join(ATLAS_BUILD_PATH, 'atlas.min.js');
  var ATLAS_RESOURCES_PATH = path.join(ATLAS_PATH, 'assets');
  var ATLAS_CESIUM_PATH = bowerPath('atlas-cesium');
  var ATLAS_CESIUM_BUILD_PATH = path.join(ATLAS_CESIUM_PATH, 'dist');
  var ATLAS_CESIUM_BUILD_FILE = path.join(ATLAS_CESIUM_BUILD_PATH, 'atlas-cesium.min.js');
  var ATLAS_CESIUM_RESOURCES_PATH = path.join(ATLAS_CESIUM_PATH, 'dist', 'cesium');

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

  grunt.registerTask('install', 'Installs all dependencies', ['build-atlas', 'copy:resources']);

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

  grunt.registerTask('default', ['install']);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // AUXILIARY
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // PATHS

  function _prefixPath(dir, args) {
    var prefixedArgs = Array.prototype.slice.apply(args);
    prefixedArgs.unshift(dir);
    return path.join.apply(path, prefixedArgs);
  }

  function bowerPath() {
    return _prefixPath(BOWER_DIR, arguments);
  }

  function publicPath() {
    return _prefixPath(PUBLIC_DIR, arguments);
  }

};
