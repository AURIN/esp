FROM node
MAINTAINER Oliver Lade <piemaster21@gmail.com>

RUN npm cache clean -f && npm install -g n && n 0.10.42
RUN curl https://install.meteor.com/ | sh

ENV PORT=3000 APP_DIR=/var/www/app
EXPOSE 3000

COPY ./app /tmp/app

# Remove the .meteor/local directory to prevent file write/rename issues.
RUN rm -rf /tmp/app/.meteor/local \
    # Docker-copied Meteor files can have weird issues, so make a new copy.
    && cp -R /tmp/app /tmp/build \
    && rm -rf /tmp/app \
    && cd /tmp/build \
    && meteor build --directory $APP_DIR --server=$ROOT_URL \
    && rm -rf /tmp/build

WORKDIR $APP_DIR/bundle

# Install all the NPM dependencies so Node is ready to run.
RUN cd programs/server && npm i

CMD ["node", "main.js"]
