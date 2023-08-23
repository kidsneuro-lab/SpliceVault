#!/bin/bash
set -e

aws cloudformation delete-stack --stack-name au-dev-splicevault-certificates
aws cloudformation delete-stack --stack-name au-test-splicevault-certificates
aws cloudformation delete-stack --stack-name au-prod-splicevault-certificates
