FROM ubuntu:18.04 as build

ARG CBLITE_REF=master

RUN apt-get update && apt-get install -y build-essential cmake libc++-dev libc++abi-dev libicu-dev zlib1g-dev clang git libsqlite3-dev

RUN git clone --recursive https://github.com/couchbase/couchbase-lite-core.git /build
WORKDIR /build

RUN git checkout $CBLITE_REF
RUN git submodule update --recursive

RUN build_cmake/scripts/build_unix.sh

FROM ubuntu:18.04

RUN apt-get update && apt-get install -y build-essential libc++1 libc++abi1 libicu60 libsqlite3-0 ruby ruby-dev ruby-bundler git

COPY --from=build /build/build_cmake/unix/libLiteCore.so /usr/local/lib/libLiteCore.so

WORKDIR /checkout