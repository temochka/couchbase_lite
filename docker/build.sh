#!/bin/bash
version=${1:-$(git ls-remote --refs https://github.com/couchbase/couchbase-lite-core.git master | cut -f1)}
echo "Building a docker image for cblite version $version..."
docker build --tag temochka/cblite-test:latest --build-arg CBLITE_REF=$version .
docker push temochka/cblite-test:latest

