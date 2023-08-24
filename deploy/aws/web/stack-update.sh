#!/bin/bash
set -e

aws cloudformation update-stack \
    --stack-name au-dev-splicevault \
    --capabilities "CAPABILITY_NAMED_IAM" \
    --template-body file://stack.yaml \
    --parameters file://env-dev.json
    
aws cloudformation update-stack \
    --stack-name au-test-splicevault \
    --capabilities "CAPABILITY_NAMED_IAM" \
    --template-body file://stack.yaml \
    --parameters file://env-test.json
    
aws cloudformation update-stack \
    --stack-name au-prod-splicevault \
    --capabilities "CAPABILITY_NAMED_IAM" \
    --template-body file://stack.yaml \
    --parameters file://env-prod.json