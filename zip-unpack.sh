#! /bin/bash

# NOTE(sven): Stop on errors and log the shell commands executed to
# stdout. Useful for debugging when running the bootstrap script via the make
# pipeline.
set -ex

if [ ! -f "/opt/joshinkan.zip" ]; then
    echo "/opt/joshinkan.zip does not exist. Make sure it is uploaded correctly before executing this script."
    exit 1
fi

# NOTE(sven): -o overwrite files, -d export directory
sudo rm -rf /opt/joshinkan
sudo unzip -o /opt/joshinkan.zip -d /opt/joshinkan/
