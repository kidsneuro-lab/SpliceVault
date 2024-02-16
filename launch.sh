#!/bin/sh

# Step 1: Generate config.yml and google analytics (Note: this is a dummy file)
cp config-template.yml config.yml
cp google-analytics-template.html google-analytics.html

# Step 2: Load the .env file variables
export $(cat .env | xargs)

# Step 3: Substitute the placeholders in config.yml, ensuring compatibility with macOS and Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS's sed requires an empty string argument with -i
  sed -i '' "s/DB_HOST/$DB_HOST/g" config.yml
  sed -i '' "s/DB_NAME/$DB_NAME/g" config.yml
  sed -i '' "s/DB_USER/$DB_USER/g" config.yml
  sed -i '' "s/DB_PASSWORD/$DB_PASSWORD/g" config.yml
else
  # Assuming GNU sed for Linux
  sed -i "s/DB_HOST/$DB_HOST/g" config.yml
  sed -i "s/DB_NAME/$DB_NAME/g" config.yml
  sed -i "s/DB_USER/$DB_USER/g" config.yml
  sed -i "s/DB_PASSWORD/$DB_PASSWORD/g" config.yml
fi

# Step 4: Launch the Shiny app
Rscript -e "shiny::runApp('.', launch.browser=TRUE)"