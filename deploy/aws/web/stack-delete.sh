#!/bin/bash
set -e

aws cloudformation delete-stack --stack-name au-dev-splicevault
aws cloudformation delete-stack --stack-name au-test-splicevault
aws cloudformation delete-stack --stack-name au-prod-splicevault
