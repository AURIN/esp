#!/usr/bin/env bash

set -e

export REPO=urbanetic/aurin-esp
export VERSION=$(node -p -e "require('./package.json').version")
if [ "$TRAVIS_BRANCH" != "" ]; then
    export BRANCH=$TRAVIS_BRANCH
else
    export BRANCH=$(git rev-parse --abbrev-ref HEAD | sed 's#/#_#g' | tr '[:upper:]' '[:lower:]')
fi

cd app
echo "Building Docker image $REPO:$BRANCH from $(pwd)"
docker build -t $REPO:$BRANCH .
cd -

if [ "$BRANCH" == "master" ]; then
    docker tag $REPO:$TAG $REPO:$VERSION
    docker tag $REPO:$TAG $REPO:latest
    echo "Also tagged image as $REPO:$VERSION and $REPO:latest"
fi
