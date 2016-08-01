#!/usr/bin/env bash

set -e

export REPO=urbanetic/aurin-esp
export VERSION=$(node -p -e "require('./package.json').version")
if [ "$TRAVIS_BRANCH" != "" ]; then
    BRANCH=$TRAVIS_BRANCH
else
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
fi
BRANCH=$(echo $BRANCH | sed 's#/#_#g' | tr '[:upper:]' '[:lower:]')

cd app
echo "Building Docker image $REPO:$BRANCH from $(pwd)"
docker build -t $REPO:$BRANCH .
cd -

if [ "$BRANCH" == "master" ]; then
    docker tag $REPO:$TAG $REPO:$VERSION
    docker tag $REPO:$TAG $REPO:latest
    echo "Also tagged image as $REPO:$VERSION and $REPO:latest"
fi
