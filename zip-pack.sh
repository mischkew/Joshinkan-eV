#! /bin/bash

# Create zip for upload using git ls-files. Also copies enviroment variables
# into zip


UNTRACKED_FILES=$(git ls-files --exclude-standard --others)
TRACKED_FILES=$(git ls-files --exclude-standard)

rm -f joshinkan.zip

if [ -n "$UNTRACKED_FILES" ]; then zip joshinkan.zip $UNTRACKED_FILES; fi
zip joshinkan.zip $TRACKED_FILES
zip joshinkan.zip .env
chmod a+w joshinkan.zip

echo "zip created"
