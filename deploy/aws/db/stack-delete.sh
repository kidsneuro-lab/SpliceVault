#!/bin/bash
set -e

aws cloudformation delete-stack --stack-name au-prod-splicevault-db
