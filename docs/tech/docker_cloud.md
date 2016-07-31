# Docker Cloud Development and Deployment Guide

This guide is a walkthrough of how to develop and deploy ESP, specifically using Docker and Docker
Cloud.

## Setup

To do any local development or builds, you'll need to start by cloning the Git repository:

    git clone git@github.com:AURIN/esp.git --recurse-submodules

Building the source code locally requires a few Node.js-based tools. Assuming you have Node.js and
npm installed, run:

    npm install -g grunt-cli bower

To build, run and push Docker images, you'll need to install Docker. Docker is native to Linux, but
Docker for Mac and Docker for Windows exist for other platforms.

## Develop

Let's say you want to develop a new feature or fix a bug in the code.

Open the project in your preferred IDE (e.g. WebStorm, Atom or Sublime Text). Make sure everything
is where you expect it to be.

We'll start by running the Meteor app locally in development mode to make sure it's working before
changing the code. From the root of the repository directory, run:

    grunt meteor

This will set a few environment variables and run `meteor` in the `/app` directory. Once it's
finished open [`http://localhost:3000`](http://localhost:3000) in your browser and check that the
app is working.

Once you're satisfied, return to your IDE, make some changes to the code and save them to disk. If
the local Meteor server is still running, your browser should refresh automatically to reflect the
new changes (unless new errors were introduced).

Once the changes are made and you've tested that they work, commit them to the repository.

## Build

To build the docker image locally, simply run from the root of the repository:

    npm run buildDocker

Once it has finished, you can see that it has been created by running:

    docker images

## Deploy

Log into [Docker Cloud][dcloud]

[dcloud]: https://cloud.docker.com
