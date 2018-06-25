FROM fedora:28

MAINTAINER Szabo Bogdan <contact@szabobogdan.com>

# Copy dlang files
ADD tmp /usr/local

COPY docker/entrypoint.sh /
COPY examples/unittest /tmp/unittest

WORKDIR /src

RUN dnf -y update \
  && dnf -y install ca-certificates dirmngr g++ gcc-multilib xdg-utils \
    libevent-dev libssl-dev wget tar xz-utils curl zlib1g-dev build-essential

# Test example
RUN openssl version \
  && cd /tmp/unittest \
  && dub test \
  && trial \
  && cd .. \
  && rm -rf unittest


RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["${COMPILER}"]
