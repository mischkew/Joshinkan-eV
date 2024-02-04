#! /bin/bash

set -e

# Load the .env file and export its variables
ENV_FILE="${1:-.env}"
if [ ! -f "$ENV_FILE" ]; then
  echo "No .env file found at $ENV_FILE"
  exit 1
fi

while IFS='=' read -r key value
do
    # Only process lines that actually contain an assignment
    if [[ -n "$key" && -n "$value" && ! $key =~ ^\s*# ]]; then
        # Remove leading and trailing spaces from key and value
        key=$(echo $key | xargs)
        value=$(echo $value | xargs)
        # Use eval to handle variables with spaces properly
        eval export $key=\"$value\"
    fi
done < $ENV_FILE
