AURIN ESP
============

Installation
------------
Install Grunt and Bower globally:

	$ npm install -g grunt-cli
	$ npm install -g bower

Run the following:

	$ npm install
	$ grunt install
	
Install [Meteor](https://www.meteor.com/):

	$ curl https://install.meteor.com/ | sh

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

	$ grunt deploy

### Heroku

	$ grunt deploy:heroku

Structure
------------
The Meteor app resides in `app/` to allow using Grunt and Bower, which have dependencies stored at the project root directory.
