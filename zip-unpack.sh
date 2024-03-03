#! /bin/bash

# NOTE(sven): Stop on errors and log the shell commands executed to
# stdout. Useful for debugging when running the bootstrap script via the make
# pipeline.
set -ex
USER=ubuntu

FILENAME="${1:-pack.zip}"
DIRECTORY_NAME="${FILENAME%.*}"

if [ ! -f "$FILENAME" ]; then
    echo "$FILENAME does not exist. Make sure it is uploaded correctly before executing this script."
    exit 1
fi

if [ -z "$(command -v unzip)" ]; then
    sudo apt-get update
    sudo apt-get install --yes unzip
fi

rm -rf $DIRECTORY_NAME
# NOTE(sven): -d export directory
unzip $FILENAME -d "$DIRECTORY_NAME"
