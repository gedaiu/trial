FROM dlanguage/dmd:2.080.0

MAINTAINER Szabo Bogdan <szabobogdan3@gmail.com>

COPY trial /usr/local/bin

WORKDIR /src

RUN apt-get update \
  && apt-get install -y libevent-dev libssl-dev

# Trial version
RUN trial --version


RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["${COMPILER}"]
