FROM ubuntu:20.04

LABEL maintainer="Szabo Bogdan <szabobogdan3@gmail.com>"

COPY trial /usr/local/bin

WORKDIR /src

RUN apt-get update \
  && apt-get install -y build-essential libssl-dev libevent-dev libcurl4 gcc wget libc6-dev git libmagickwand-dev libsqlite3-dev \
  && cd /tmp/ \
  && wget http://downloads.dlang.org/releases/2.x/2.093.1/dmd_2.093.1-0_amd64.deb \
  && dpkg -i dmd_2.093.1-0_amd64.deb \

# Trial version
RUN trial --version
