#!/bin/bash
set -eax
url=${RELEASE_URL:-"https://github.com/temochka/couchbase-lite-core/releases/download/v2.1.0-bootleg-058d121/cblite-cf1e4c29.tar.gz"}
curl -L $url | tar xz
