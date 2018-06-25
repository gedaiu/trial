#!/bin/bash

sudo docker build --rm --no-cache=true -t registry.gitlab.com/szabobogdan3/ogm-server .
sudo docker push registry.gitlab.com/szabobogdan3/ogm-server
