#!/usr/bin/env bash

set -e

export REPO=urbanetic/aurin-esp
export VERSION=$(node -p -e "require('./package.json').version")
export BRANCH=$(git rev-parse --abbrev-ref HEAD | sed 's#/#_#g' | tr '[:upper:]' '[:lower:]')
export TAG=$(if [ "$BRANCH" == "master" ]; then echo "latest"; else echo "$BRANCH" ; fi)

cd app
echo "Building Docker image $REPO:$TAG from $(pwd)"
docker build -t $REPO:$TAG .
cd -

if [ "$BRANCH" == "master" ]; then docker tag $REPO:$TAG $REPO:$VERSION ; fi

