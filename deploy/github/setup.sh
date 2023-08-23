#!/bin/bash
########################################
# Usage 
# ./setup.sh dev
# ./setup.sh test
# ./setup.sh prod
########################################

# exit when any command fails
set -e

# Check if a parameter was passed
if [ $# -ne 1 ]
then
  echo "Please provide the environment parameter."
  exit 1
fi

ENV="$1"
REPO='kidsneuro-lab/splicevault'
APP="splicevault"
STACK_NAME="au-${ENV}-${APP}"

ENV_AWS_REGION="$(aws configure get region --output text)"
ENV_AWS_DEPLOYMENT_KEY=$(aws cloudformation describe-stacks             --stack-name $STACK_NAME --query 'Stacks[0].Outputs[?OutputKey==`AwsDeploymentKey`].OutputValue' --output text)
ENV_AWS_DEPLOYMENT_SECRET=$(aws cloudformation describe-stacks          --stack-name $STACK_NAME --query 'Stacks[0].Outputs[?OutputKey==`AwsDeploymentSecret`].OutputValue' --output text)
ENV_AWS_RUNTIME_KEY=$(aws cloudformation describe-stacks                --stack-name $STACK_NAME --query 'Stacks[0].Outputs[?OutputKey==`AwsRuntimeKey`].OutputValue' --output text)
ENV_AWS_RUNTIME_SECRET=$(aws cloudformation describe-stacks             --stack-name $STACK_NAME --query 'Stacks[0].Outputs[?OutputKey==`AwsRuntimeSecret`].OutputValue' --output text)
ENV_AWS_CONTAINER_SERVICE_NAME=$(aws cloudformation describe-stacks     --stack-name $STACK_NAME --query 'Stacks[0].Outputs[?OutputKey==`ContainerServiceName`].OutputValue' --output text)

echo "Values..."
echo "AWS_REGION = $ENV_AWS_REGION"
echo "AWS_DEPLOYMENT_KEY = $ENV_AWS_DEPLOYMENT_KEY"
echo "AWS_DEPLOYMENT_SECRET = $ENV_AWS_DEPLOYMENT_SECRET"
echo "AWS_RUNTIME_KEY = $ENV_AWS_RUNTIME_KEY"
echo "AWS_RUNTIME_SECRET = $ENV_AWS_RUNTIME_SECRET"
echo "AWS_CONTAINER_SERVICE_NAME = $ENV_AWS_CONTAINER_SERVICE_NAME"
echo "DB_HOST = $ENV_DB_HOST"
echo "DB_DATABASE = $ENV_DB_DATABASE"
echo "DB_USERNAME = $ENV_DB_USERNAME"
echo "DB_PASSWORD = $ENV_DB_PASSWORD"

echo "Applying variables..."
gh variable set AWS_REGION                  --repo $REPO --env $ENV --body $ENV_AWS_REGION
gh variable set AWS_DEPLOYMENT_KEY          --repo $REPO --env $ENV --body $ENV_AWS_DEPLOYMENT_KEY
gh variable set AWS_RUNTIME_KEY             --repo $REPO --env $ENV --body $ENV_AWS_RUNTIME_KEY
gh variable set AWS_CONTAINER_SERVICE_NAME  --repo $REPO --env $ENV --body $ENV_AWS_CONTAINER_SERVICE_NAME
gh variable set DB_HOST                     --repo $REPO --env $ENV --body $ENV_DB_HOST
gh variable set DB_DATABASE                 --repo $REPO --env $ENV --body $ENV_DB_DATABASE
gh variable set DB_USERNAME                 --repo $REPO --env $ENV --body $ENV_DB_USERNAME

echo "Applying secrets..."
gh secret set AWS_DEPLOYMENT_SECRET         --repo $REPO --env $ENV --body $ENV_AWS_DEPLOYMENT_SECRET
gh secret set AWS_RUNTIME_SECRET            --repo $REPO --env $ENV --body $ENV_AWS_RUNTIME_SECRET
gh secret set DB_PASSWORD                   --repo $REPO --env $ENV --body $ENV_DB_PASSWORD