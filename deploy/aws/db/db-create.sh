#!/bin/bash
########################################
# Usage
# ./db-create.sh prod
########################################

# exit when any command fails
set -e

# Check if a parameter was passed
if [ $# -ne 1 ]; then
  echo "Please provide the parameters."
  exit 1
fi

ENV="$1"
APP="splicevault"

CF_STACK_NAME="au-${ENV}-${APP}-db"
CF_INSTANCE_NAME="au_${ENV}_${APP}_database"
DB_NAME="au_${ENV}_${APP}"
DB_USERNAME="au_${ENV}_${APP}"
DB_PASSWORD="au_${ENV}_${APP}"

DB_HOST=$(aws lightsail get-relational-database --relational-database-name $CF_INSTANCE_NAME --query 'relationalDatabase.masterEndpoint.address' --output text)
DB_MASTER_DATABASE=$(aws lightsail get-relational-database --relational-database-name $CF_INSTANCE_NAME --query 'relationalDatabase.masterDatabaseName' --output text)
DB_MASTER_USERNAME=$(aws lightsail get-relational-database --relational-database-name $CF_INSTANCE_NAME --query 'relationalDatabase.masterUsername' --output text)
DB_MASTER_PASSWORD=$(aws cloudformation describe-stacks --stack-name $CF_STACK_NAME --query 'Stacks[0].Outputs[?OutputKey==`MasterUserPassword`].OutputValue' --output text)

echo "DB_HOST = $DB_HOST"
echo "DB_MASTER_DATABASE = $DB_MASTER_DATABASE"
echo "DB_MASTER_USERNAME = $DB_MASTER_USERNAME"
echo "DB_MASTER_PASSWORD = $DB_MASTER_PASSWORD"
echo "DB_NAME = $DB_NAME"
echo "DB_USERNAME = $DB_USERNAME"
echo "DB_PASSWORD = $DB_PASSWORD"

echo "Creating database ${DB_NAME} and user ${DB_USERNAME}..."
echo "CREATE DATABASE ${DB_NAME};CREATE USER ${DB_USERNAME} WITH PASSWORD '${DB_PASSWORD}';" | docker run -i --rm \
  -e PGHOST=$DB_HOST \
  -e PGDATABASE=$DB_MASTER_DATABASE \
  -e PGUSER=$DB_MASTER_USERNAME \
  -e PGPASSWORD=$DB_MASTER_PASSWORD \
  postgres psql

echo "Granting privileges on database ${DB_NAME} to user ${DB_USERNAME}..."
echo "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} to ${DB_USERNAME};" | docker run -i --rm \
  -e PGHOST=$DB_HOST \
  -e PGDATABASE=$DB_NAME \
  -e PGUSER=$DB_MASTER_USERNAME \
  -e PGPASSWORD=$DB_MASTER_PASSWORD \
  postgres psql
