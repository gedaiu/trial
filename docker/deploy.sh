#!/bin/bash

sudo docker stop ogm-staging || true
sudo docker rm ogm-staging || true

sudo docker run -p 9091:9091 -v /srv/ogm/db:/app/db:Z -v /srv/ogm/files:/app/files:Z -v /srv/ogm/config:/app/config:Z -d --restart=always --name=ogm-staging registry.gitlab.com/szabobogdan3/ogm-server
