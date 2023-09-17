#! /bin/bash

# This script reads a variable from the `src/variables.ini` file and echoes the
# value to stdout.

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 variable-name"
  exit 1
fi

VARIABLES_FILE="$(dirname $0)/../variables.ini"

if [ ! -f $VARIABLES_FILE ]; then
   echo "Variables file '$VARIABLES_FILE' not found."
   exit 1
fi

SED=sed
if [ "$(uname -s)" = "Darwin" ]; then
  SED=gsed
fi

$SED --silent -e "/$1=/ s/$1=// p" $VARIABLES_FILE | $SED 's/"//g'
