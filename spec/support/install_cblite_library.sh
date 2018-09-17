#!/bin/bash
set -eax
url=${RELEASE_URL:-"https://github.com/temochka/couchbase-lite-core/releases/download/v2.1.0-bootleg-82fa0f5/cblite-d7d5a0cc.tar.gz"}
curl -L $url | tar xz
