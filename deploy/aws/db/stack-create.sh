#!/bin/bash
set -e
    
aws cloudformation create-stack \
    --stack-name au-prod-splicevault-db \
    --capabilities "CAPABILITY_NAMED_IAM" \
    --template-body file://stack.yaml \
    --parameters file://env-prod.json