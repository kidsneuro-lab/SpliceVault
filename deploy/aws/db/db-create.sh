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

echo "Creating database ${DB_DATABASE} and user ${DB_USERNAME}..."
echo "CREATE DATABASE ${DB_DATABASE};CREATE USER ${DB_USERNAME} WITH PASSWORD '${DB_PASSWORD}';" | docker run -i --rm \
  -e PGHOST=$DB_HOST \
  -e PGDATABASE=$DB_MASTER_DATABASE \
  -e PGUSER=$DB_MASTER_USERNAME \
  -e PGPASSWORD=$DB_MASTER_PASSWORD \
  postgres psql

echo "Granting privileges on database ${DB_DATABASE} to user ${DB_USERNAME}..."
echo "GRANT ALL PRIVILEGES ON DATABASE ${DB_DATABASE} to ${DB_USERNAME};" | docker run -i --rm \
  -e PGHOST=$DB_HOST \
  -e PGDATABASE=$DB_DATABASE \
  -e PGUSER=$DB_MASTER_USERNAME \
  -e PGPASSWORD=$DB_MASTER_PASSWORD \
  postgres psql

FILES=( "ref_tx" "ref_exons" "ref_tissues" "ref_splice_sites" "ref_missplicing_event" "misspl_events_300k_hg38_tx" "misspl_events_40k_hg19_tx" "misspl_events_40k_hg19_events" "misspl_events_300k_hg38_events" "missplicing_stats" "tissue_missplicing_stats" ) 

echo "Configured with host $DB_HOST database $DB_MASTER_USERNAME and user $DB_MASTER_PASSWORD"

echo "Dropping database schema"
cat ./db-down.sql | docker run --rm --network host -i -e PGPASSWORD=$DB_MASTER_PASSWORD postgres:15-alpine psql -h $DB_HOST -d $DB_DATABASE -U $DB_MASTER_USERNAME

echo "Creating database schema"
cat ./db-up.sql   | docker run --rm --network host -i -e PGPASSWORD=$DB_MASTER_PASSWORD postgres:15-alpine psql -h $DB_HOST -d $DB_DATABASE -U $DB_MASTER_USERNAME

echo "Granting select on all tables in database ${DB_DATABASE} to user ${DB_USERNAME}..."
echo "GRANT SELECT ON ALL TABLES IN SCHEMA public TO ${DB_USERNAME};" | docker run -i --rm \
  -e PGHOST=$DB_HOST \
  -e PGDATABASE=$DB_DATABASE \
  -e PGUSER=$DB_MASTER_USERNAME \
  -e PGPASSWORD=$DB_MASTER_PASSWORD \
  postgres psql

for index in ${!FILES[*]}; do
  FILE=${FILES[$index]}
  echo "Processing: $FILE"
  
  if [ ! -f "$FILE.csv" ]; then
    echo "Decompressing $FILE.csv.gz"
    if [[ ! -f $FILE.csv.gz ]]; then
      echo "File $FILE.csv.gz does not exist."
      exit 1
    fi
    gunzip -v -c $FILE.csv.gz > $FILE.csv
  else
    echo "File $FILE.csv already decompressed"
  fi

  echo "Processed: $FILE"
  
done

for index in ${!FILES[*]}; do
  FILE=${FILES[$index]}

  echo "Importing $FILE"
  
  docker run --rm --network host -v /$(pwd)/:/data -e PGPASSWORD=$DB_MASTER_PASSWORD postgres:15-alpine psql -h $DB_HOST -d $DB_DATABASE -U $DB_MASTER_USERNAME \
      -c "\copy $FILE FROM '/data/$FILE.csv' CSV;"

  echo "Imported $FILE"
done
