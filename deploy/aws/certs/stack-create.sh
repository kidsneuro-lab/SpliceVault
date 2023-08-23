#!/bin/bash
set -e

aws cloudformation create-stack \
    --stack-name au-dev-splicevault-certificates \
    --capabilities "CAPABILITY_NAMED_IAM" \
    --template-body file://stack.yaml \
    --parameters file://env-dev.json
    
aws cloudformation create-stack \
    --stack-name au-test-splicevault-certificates \
    --capabilities "CAPABILITY_NAMED_IAM" \
    --template-body file://stack.yaml \
    --parameters file://env-test.json
    
aws cloudformation create-stack \
    --stack-name au-prod-splicevault-certificates \
    --capabilities "CAPABILITY_NAMED_IAM" \
    --template-body file://stack.yaml \
    --parameters file://env-prod.json