FROM ubuntu:14.04

RUN apt-get update
RUN apt-get install -y build-essential libicu-dev ruby2.0-dev ruby2.0 git

RUN gem install bundler --no-ri --no-rdoc

RUN mkdir -p /source

WORKDIR /source

ADD . /source

RUN bin/setup
