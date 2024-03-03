#! /bin/bash

# Create zip for upload using git ls-files. Also copies enviroment variables
# into zip

FILENAME="${1:-pack.zip}"
ENVIRONMENT="${2:-testing}"

function usage() {
  echo "Usage: $(basename $0) <filename> <environment>"
  echo "  filename:    Name of the zip file to create"
  echo "  environment: testing|production|local"
  exit 1
}

if [ "$ENVIRONMENT" != "testing" -a "$ENVIRONMENT" != "production" -a "$ENVIRONMENT" != "local" ]; then
  echo "Invalid environment: $ENVIRONMENT"
  usage
fi

UNTRACKED_FILES=$(git ls-files --exclude-standard --others)
TRACKED_FILES=$(git ls-files --exclude-standard)

rm -f "$FILENAME"

if [ -n "$UNTRACKED_FILES" ]; then zip "$FILENAME" $UNTRACKED_FILES; fi
zip "$FILENAME" $TRACKED_FILES
cp ".env.$ENVIRONMENT" .env.current-deployment
zip "$FILENAME" .env.current-deployment
rm -f .env.current-deployment

chmod a+w "$FILENAME"
echo "zip created at $FILENAME for environment $ENVIRONMENT"
