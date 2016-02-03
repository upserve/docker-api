# Uses GoPex ubuntu_rails stock image
FROM gopex/ubuntu_ruby:2.3.0
MAINTAINER Albin Gilles "albin.gilles@gmail.com"
ENV REFRESHED_AT 2016-01-31

RUN apt-get update -yqq && apt-get install git -yqq --no-install-recommends

RUN mkdir -p /docker-api
WORKDIR /docker-api
COPY . .
RUN bundle install
