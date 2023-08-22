#!/bin/bash

docker build . -t splicevault
docker run --rm --name splicevault -p 3838:3838 splicevault
