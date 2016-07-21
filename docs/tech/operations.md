# ESP Operations Manual

This guide is intended to support operations teams with setting up ad maintaining the ESP
application.


## Build

    docker build -t esp .

## Configuration

The ESP app is primarily configured through the environment variables described below:

| Environment Variable          | Description                                   |
| ----------------------------- | --------------------------------------------- |
| ROOT_URL                      | Location the Meteor app is served from        |
| MONGO_URL                     | Location of the Meteor app's MongoDB instance |
| NODE_ENV                      | The environment type {dev, production}        |
| METEOR_ADMIN_PASSWORD         | The default admin username                    |
| METEOR_ADMIN_EMAIL            | The default admin password                    |
| AURIN_SERVER_URL              | The location of the AURIN auth server         |
| AURIN_APP_NAME                | The name of the ESP application in the AURIN auth server |
| AWS_ACCESS_KEY_ID             | The ID of the AWS key to access S3            |
| AWS_SECRET_ACCESS_KEY         | The secret AWS key to access S3               |
| S3_BUCKET_NAME                | The name of the S3 bucket to store files in   |
| S3_REGION                     | The S3 region to store files in               |
| FILES_DIR                     | The directory to store files in (if local, else 0) |
| KADIRA_APP_ID                 | The app ID for Kadira monitoring              |
| KADIRA_APP_SECRET             | The secret key for Kadira monitoring          |
| LOG_LEVEL                     | The level of logs to output {INFO, DEBUG}     |
| CATALYST_SERVER_AUTH_HEADER   | The authentication header to send to Catalyst |
| CATALYST_USERNAME             | The username with which to access Catalyst    |
| CATALYST_PASSWORD             | The password with which to access Catalyst    |

## Deploy



Other deployment targets include:

* Local: `grunt deploy:local`
* Meteor: `grunt deploy:meteor`
* Heroku: `grunt deploy:heroku`
* Modulus: `grunt deploy:modulus`
