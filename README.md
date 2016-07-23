# AURIN ESP

[![Build Status](https://travis-ci.org/urbanetic/aurin-esp.svg)](https://travis-ci.org/urbanetic/aurin-esp)
[![Documentation Status](https://readthedocs.org/projects/aurin-esp/badge/?version=latest)](https://readthedocs.org/projects/aurin-esp/?badge=latest)

## Installation

Install Grunt and Bower globally:

	$ npm install -g grunt-cli
	$ npm install -g bower

Install [Meteor](https://www.meteor.com/):

	$ curl https://install.meteor.com/ | sh

Run the following:

	$ npm install

## Running

Run the app with `grunt meteor`.

## Building

To build a distributable Meteor app in `dist/`:

	$ npm run build

## Deployment

Deployment settings are found in `Gruntfile.js`.

### Local

	$ grunt deploy:local

### Heroku

	$ grunt deploy:heroku

### meteor.com

	$ grunt deploy:meteor

### Docker Cloud

1. Provision a node
2. Create a new Stack
3. Copy `docker-compose.yml` into the Stackfile
4. Run the Stack

## Structure

The Meteor app resides in `app/` to allow using Grunt and Bower, which have dependencies stored at the project root directory.


[container]: https://hub.docker.com/r/golden/meteor-dev/
