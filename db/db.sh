#!/bin/bash
set -e

########################################
# ./db.sh localhost postgres postgres password
########################################

## To test this use a postgres instance running in a local docker container
## for example:
## docker run --name postgres --network host -e POSTGRES_PASSWORD=password -d postgres:15-alpine

# Check if a parameter was passed
if [ $# -ne 4 ]
then
  echo "Please check the parameters."
  exit 1
fi

DB_HOST="$1"
DB_DATABASE="$2"
DB_USERNAME="$3"
DB_PASSWORD="$4"

FILES=( "ref_exons" ) 

echo "Configured with host $DB_HOST database $DB_DATABASE and user $DB_USERNAME"

echo "Recreating database schema"
cat ./db-down.sql | docker run --rm --network host -i -e PGPASSWORD=$DB_PASSWORD postgres:15-alpine psql -h $DB_HOST -d $DB_DATABASE -U $DB_USERNAME
cat ./db-up.sql   | docker run --rm --network host -i -e PGPASSWORD=$DB_PASSWORD postgres:15-alpine psql -h $DB_HOST -d $DB_DATABASE -U $DB_USERNAME

for index in ${!FILES[*]}; do
  FILE=${FILES[$index]}
  echo "Processing file: $FILE"
  
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
done

for index in ${!FILES[*]}; do
  FILE=${FILES[$index]}

  echo "Importing file $FILE"
  
  docker run --rm --network host -v /$(pwd)/:/data -e PGPASSWORD=$DB_PASSWORD postgres:15-alpine psql -h $DB_HOST -d $DB_DATABASE -U $DB_USERNAME \
      -c "\copy $FILE FROM '/data/$FILE.csv' CSV HEADER;"

  echo "Imported $FILE.csv"
done