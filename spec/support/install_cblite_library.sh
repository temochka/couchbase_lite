#!/bin/bash
set -eax
url=${RELEASE_URL:-"https://github.com/temochka/couchbase-lite-core/releases/download/v2.1.0-bootleg/cblite-b05945c5.tar.gz"}
curl -L $url | tar xz
