FROM ubuntu:16.04

RUN mkdir /work
WORKDIR /work
ADD Gemfile /work
ADD scraiping.rb /work
ADD lib /work/lib
RUN apt-get -y update && apt-get upgrade
RUN apt-get -y install ruby ruby-dev
RUN gem install bundle
RUN bundle install
