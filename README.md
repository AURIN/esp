AURIN ESP
============

[![Build Status](https://travis-ci.org/urbanetic/aurin-esp.svg)](https://travis-ci.org/urbanetic/aurin-esp)
[![Documentation Status](https://readthedocs.org/projects/aurin-esp/badge/?version=latest)](https://readthedocs.org/projects/aurin-esp/?badge=latest)

Installation
------------
Install Grunt and Bower globally:

	$ npm install -g grunt-cli
	$ npm install -g bower

Install [Meteor](https://www.meteor.com/):

	$ curl https://install.meteor.com/ | sh

Install [Meteorite](https://github.com/oortcloud/meteorite/):

  $ npm install -g meteorite

Run the following:

	$ npm install
	$ grunt install

Running
-------
Run the app by running `meteor` in the `app/` directory, or using `grunt meteor` from the project root directory.

Building
--------
To build a distributable Meteor app in `dist/`:

	$ grunt build

Deployment
----------
Deployment settings are found in `Gruntfile.js`.

### Local

	$ grunt deploy:local

### Heroku

	$ grunt deploy:heroku

### meteor.com

	$ grunt deploy:meteor

Structure
------------
The Meteor app resides in `app/` to allow using Grunt and Bower, which have dependencies stored at the project root directory.
