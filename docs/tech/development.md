# ESP Developer Guide

This guide is intended to walk developers through the process of building and deploying the *ESP*
application.


## Local Installation

Install [Node.js](http://nodejs.org/) and NPM (Node Package Manager).

Install [Grunt](http://gruntjs.com/):

    $ npm install -g grunt-cli

Install [Meteor](https://www.meteor.com/):

    $ curl https://install.meteor.com/ | sh

Install [Meteorite](https://github.com/oortcloud/meteorite/):

    $ npm install -g meteorite

Check out the `aurin-esp` code into a project directory:

    $ git clone https://github.com/urbanetic/aurin-esp.git && cd aurin-esp

Run the following in the `aurin-esp` directory to install dependencies:

    $ npm install
    $ grunt install


## Running

Run the app by running `meteor` in the `app/` directory, or using `grunt meteor` from anywhere in
the project directory.


## Building

To build a distributable Meteor app in `dist/`:

    $ grunt build

This generates a standard Node.js app, which can be deployed in a variety of ways.


## Deployment

*ESP* can be deployed on a variety of hosting services that support `Node.js`.

Deployment settings are found in `Gruntfile.js`.

### Local

This method will build the Node.js app and run it locally, expecting a MongoDB instance to be
running on `localhost:27017`.

    $ grunt deploy:local

### meteor.com

This method will deploy the application to Meteor's free hosting service.

    $ grunt deploy:meteor

### Heroku

This method will build the Node.js app and deploy it to [Heroku][heroku]. This requires
that you have the [Heroku Toolbelt][toolbelt] installed.

    $ grunt deploy:heroku

### Modulus

This method will deploy the application to [Modulus.io](https://modulus.io/), a Node.js app hosting
platform-as-a-service. This requires the [Modulus CLI tool][modulus-cli] to be installed.

    $ grunt deploy:modulus


[heroku]: https://heroku.com/
[toolbelt]: https://toolbelt.heroku.com/
[modulus-cli]: https://github.com/onmodulus/modulus-cli
