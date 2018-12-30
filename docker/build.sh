#!/bin/bash
version=${1:-$(git ls-remote --refs https://github.com/couchbase/couchbase-lite-core.git master | cut -f1)}
tag=${LITECORE_VERSION_STRING:-latest}
echo "Building a docker image for cblite version $version..."
docker build --tag temochka/cblite-test:$tag --build-arg CBLITE_REF=$version --build-arg LITECORE_VERSION_STRING=$tag .
docker push temochka/cblite-test:$tag
