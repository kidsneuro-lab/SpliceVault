#!/bin/bash
sudo apt-get install -y sqlite3
DB_NAME="splicevault.db"

# Delete the database only if it exists
if [ -f "$DB_NAME" ]; then
  rm $DB_NAME
  echo "Existing database $DB_NAME deleted."
fi

echo "Unzipping files"
ls -la *.csv.gz
gunzip *.csv.gz -r files
ls -la files/*.csv

echo "Creating database $DB_NAME"
sqlite3 $DB_NAME < db-up.sql

echo "Importing CSV files into database $DB_NAME"
for file in files/*.csv; do

  # Extract just the filename (without folder path)
  filename=$(basename -- "$file")

  # Extract the table name (filename without the extension)
  tablename="${filename%.*}"
  
  echo "Importing $file into $tablename"
  
  # Import CSV file into a table with the same name as the filename (without extension)
  sqlite3 -separator "," $DB_NAME ".import $file $tablename"

done

echo "Done!"