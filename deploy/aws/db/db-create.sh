#!/bin/bash
########################################
# Usage
# ./db-create.sh prod
########################################
# This will need to be executed on a remote server, ideally close to the database

# first, sync the splicevault files from s3 to the server
# aws s3 sync s3://au-prod-splicevault-storage ./files

# install the postgres client
# sudo amazon-linux-extras install postgresql14

# then execute the process using nohup
# nohup ./db-create.sh prod > db-create.log 2>&1 &

# exit when any command fails
set -e

# Check if a parameter was passed
if [ $# -ne 1 ]; then
  echo "Please provide the parameters."
  exit 1
fi

ENV="$1"
APP="splicevault"

POSTGRES_IMAGE="postgres:15-alpine"

CF_STACK_NAME="au-${ENV}-${APP}-db"
CF_INSTANCE_NAME="au_${ENV}_${APP}_database"
DB_DATABASE="au_${ENV}_${APP}"
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
echo "DB_DATABASE = $DB_DATABASE"
echo "DB_USERNAME = $DB_USERNAME"
echo "DB_PASSWORD = $DB_PASSWORD"

echo "Configured with host $DB_HOST database $DB_MASTER_USERNAME and user $DB_MASTER_PASSWORD"
export PGPASSWORD=$DB_MASTER_PASSWORD

echo "Dropping database ${DB_DATABASE}..."
psql -h $DB_HOST -U $DB_MASTER_USERNAME -d $DB_MASTER_DATABASE -c "DROP DATABASE IF EXISTS ${DB_DATABASE} WITH (FORCE);"

echo "Dropping user ${DB_USERNAME}..."
psql -h $DB_HOST -U $DB_MASTER_USERNAME -d $DB_MASTER_DATABASE -c "DROP ROLE IF EXISTS ${DB_USERNAME};"

echo "Creating database ${DB_DATABASE}..."
psql -h $DB_HOST -U $DB_MASTER_USERNAME -d $DB_MASTER_DATABASE -c "CREATE DATABASE ${DB_DATABASE};"

echo "Creating user ${DB_USERNAME}..."
psql -h $DB_HOST -U $DB_MASTER_USERNAME -d $DB_MASTER_DATABASE -c "CREATE USER ${DB_USERNAME} WITH PASSWORD '${DB_PASSWORD}';"

echo "Granting privileges on database ${DB_DATABASE} to user ${DB_USERNAME}..."
psql -h $DB_HOST -U $DB_MASTER_USERNAME -d $DB_DATABASE -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_DATABASE} TO ${DB_USERNAME};"

FILES=( "ref_tx" "ref_exons" "ref_tissues" "ref_splice_sites" "ref_missplicing_event" "misspl_events_300k_hg38_tx" "misspl_events_40k_hg19_tx" "misspl_events_40k_hg19_events" "misspl_events_300k_hg38_events" "missplicing_stats" "tissue_missplicing_stats" ) 

echo "Dropping database schema"
psql -h $DB_HOST -d $DB_DATABASE -U $DB_MASTER_USERNAME < ./db-down.sql

echo "Creating database schema"
psql -h $DB_HOST -d $DB_DATABASE -U $DB_MASTER_USERNAME < ./db-up.sql

echo "Granting select on all tables in database ${DB_DATABASE} to user ${DB_USERNAME}..."
psql -h $DB_HOST -U $DB_MASTER_USERNAME -d $DB_DATABASE -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO ${DB_USERNAME};"

mkdir -p decompressed
for index in ${!FILES[*]}; do
  COMPRESSED="files/${FILES[$index]}.csv.gz"
  DECOMPRESSED="decompressed/${FILES[$index]}.csv"
  echo "Decompressing: $COMPRESSED"
  
  if [ ! -f $DECOMPRESSED ]; then
    echo "Decompressing $COMPRESSED -> $DECOMPRESSED"
    if [[ ! -f $COMPRESSED ]]; then
      echo "File $COMPRESSED does not exist."
      exit 1
    fi
    gunzip -v -c $COMPRESSED > $DECOMPRESSED
  else
    echo "File $DECOMPRESSED already decompressed"
  fi

done

# Split files into chunks of 1M row csv files
mkdir -p chunks
LINES_PER_FILE="1000000"
for index in ${!FILES[*]}; do
  FILE="${FILES[$index]}"
  DECOMPRESSED="decompressed/$FILE"
  CHUNKS="chunks/$FILE-chunk-"
  
  echo "Splitting $FILE into chunks of $LINES_PER_FILE lines"
  
  split -l $LINES_PER_FILE $DECOMPRESSED.csv $CHUNKS --numeric-suffixes=1 --suffix-length=6 --additional-suffix=.csv
  
  echo "Finished splitting $FILE"
done

# Upload the chunks to the database
for index in ${!FILES[*]}; do
  FILE="${FILES[$index]}"
  DECOMPRESSED="decompressed/$FILE"
  CHUNKS="chunks/$FILE-chunk-"
  
  # Loop through the small files and execute the command
  QUERY="$CHUNKS*"
  echo "Starting import of $FILE using query $QUERY"
  for CHUNK in $QUERY; do

    echo "Importing $CHUNK of file $FILE"
        
    psql -h $DB_HOST -U $DB_MASTER_USERNAME -d $DB_DATABASE -c "\copy $FILE FROM '$(pwd)/$CHUNK' CSV;"
  done
  
  echo "Finished importing $FILE"
done

echo "Creating database indexes"
psql -h $DB_HOST -d $DB_DATABASE -U $DB_MASTER_USERNAME < ./db-up-indexes.sql