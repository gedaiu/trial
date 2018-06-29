FROM dlanguage/dmd:2.080.0

MAINTAINER Szabo Bogdan <szabobogdan3@gmail.com>

COPY trial /usr/local/bin

WORKDIR /src

RUN apt-get update \
  && apt-get install -y libevent-dev libssl-dev

# Trial version
RUN trial --version
