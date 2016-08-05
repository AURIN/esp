# ESP Operations Manual

This guide is intended to support operations teams with setting up ad maintaining the ESP
application.


## Build

ESP is a Meteor app, so to deploy it you should use the Meteor toolchain to build a bundled Node.js
app:

    npm run buildMeteor

Even easier to deploy than Node.js is Docker. You can build an ESP Docker image with:

    npm run buildDocker

Note that this will run `meteor build` in an `ONBUILD` step, so it may take a few minutes.

Once built, push the image to a Docker registry with `docker push` to make it available for
deployment.


## Deploy

[Docker][docker] is the recommended tool for simple, declarative, repeatable deployments. Once you
build a Docker image of ESP (as described above), you can choose to deploy the image as a Docker
container in one of the following ways:

* Standalone: SSH into your chosen server, set the required environment variables, and simply
  [`docker run`][drun] the image.
* Compose: run [`docker-compose up`][dc] to start and link multiple Docker containers with
  pre-configured environment variables.
* Docker Cloud: forget about managing servers, simply upload a [Stackfile][stack] (much like a
  `docker-compose.yml` file) and upload it to Docker Cloud. Connect Docker Cloud to one or more
  nodes (EC2, DigitalOcean or bring your own with the Docker Cloud agent) and deploy the stack on
  the node by clicking a few buttons.

Other deployment targets include:

* Local: `grunt deploy:local`
* Meteor: `grunt deploy:meteor`
* Heroku: `grunt deploy:heroku`
* Modulus: `grunt deploy:modulus`

No matter how the app is deployed, it will require configuration provided in the form of environment
variables.


## Configuration

The ESP app is primarily configured through the environment variables described below:

| Environment Variable          | Description                                   |
| ----------------------------- | --------------------------------------------- |
| ROOT_URL                      | Location the Meteor app is served from        |
| MONGO_URL                     | Location of the Meteor app's MongoDB instance |
| NODE_ENV                      | The environment type {dev, production}        |
| METEOR\_ADMIN\_PASSWORD       | The default admin username                    |
| METEOR\_ADMIN\_EMAIL          | The default admin password                    |
| AURIN\_SERVER\_URL            | The location of the AURIN auth server         |
| AURIN\_APP\_NAME              | The name of the ESP application in the AURIN auth server |
| AWS\_ACCESS\_KEY\_ID          | The ID of the AWS key to access S3            |
| AWS\_SECRET\_ACCESS\_KEY      | The secret AWS key to access S3               |
| S3\_BUCKET\_NAME              | The name of the S3 bucket to store files in   |
| S3_REGION                     | The S3 region to store files in               |
| FILES_DIR                     | The directory to store files in (if local, else 0) |
| KADIRA\_APP\_ID               | The app ID for Kadira monitoring              |
| KADIRA\_APP\_SECRET           | The secret key for Kadira monitoring          |
| ACS_URL                       | The Asset Conversion Service URL.             |
| LOG_LEVEL                     | The level of logs to output {INFO, DEBUG}     |

[docker]: https://www.docker.com/
[drun]: https://docs.docker.com/engine/reference/run/
[dc]: https://docs.docker.com/compose/overview/
