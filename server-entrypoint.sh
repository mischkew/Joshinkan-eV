#! /bin/bash

set -ex

# This script launches the backend as a production configuration.
export ENVIRONMENT=current-deployment
source ./load-env.sh
source ../venv/bin/activate # we have created a venv in the parent directory as part of boostrap.sh

joshinkand --log-dir $LOGS_DIR --host $BACKEND_HOST --port $BACKEND_PORT
