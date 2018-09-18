FROM ubuntu:18.04

RUN apt-get update
RUN apt-get install -y build-essential libicu-dev ruby2.5-dev ruby2.5 git curl

RUN gem install bundler --no-ri --no-rdoc

RUN mkdir -p /source

WORKDIR /source

ADD . /source

RUN bin/setup
