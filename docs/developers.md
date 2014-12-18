# ESP Developer Guide

This guide is intended to walk developers through the process of building and deploying the *ESP*
application.


## Installation

Install [Node.js](http://nodejs.org/) and NPM (Node Package Manager).

Install [Grunt](http://gruntjs.com/):

    $ npm install -g grunt-cli

Install [Meteor](https://www.meteor.com/):

    $ curl https://install.meteor.com/ | sh

Install [Meteorite](https://github.com/oortcloud/meteorite/):

    $ npm install -g meteorite

Run the following:

    $ npm install
    $ grunt install


## Running

Run the app by running `meteor` in the `app/` directory, or using `grunt meteor` from anywhere in
the project directory.


## Building

To build a distributable Meteor app in `dist/`:

    $ grunt build


## Deployment

*ESP* can be deployed on a variety of hosting services that support `Node.js`.

Deployment settings are found in `Gruntfile.js`.

### Local

    $ grunt deploy:local

### Heroku

    $ grunt deploy:heroku

### meteor.com

    $ grunt deploy:meteor

### Modulus

    $ modulus deploy
