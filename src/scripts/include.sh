#! /bin/bash

# This script reads the input file, and applies all {{ }} substitutions by
# executing the shell command between the braces.
#
# It adds the src/scripts directory to the PATH and sets the working directory
# to the directory of the input file so that relative paths can be used. It
# sources the src/variables.ini file and exposes all variables as shell
# variables.

set -e

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 HTML-FILE"
  exit 1
fi

if [ ! -f $1 ]; then
   echo "Input file '$1' not found."
   exit 1
fi

if [ -z "$(which realpath)" ]; then
  echo "realpath not found"
  exit 1
fi

export PATH="$(realpath $(dirname $0)):$PATH"
source $(dirname $0)/../variables.ini

cd $(dirname $1)

SED=sed
if [ "$(uname -s)" = "Darwin" ]; then
  SED=gsed
fi

if [ -z "$(which $SED)" ]; then
  echo "$SED not found"
  exit 1
fi

# Find all substitution commands and split them on a new line
# and then execute the shell command within
$SED -Ee 's:\{\{([^\{\}]*)\}\}:\n&\n:g' $(basename $1) \
      | $SED -Ee 's:\{\{([^\{\}]*)\}\}:\1:e' \
               2>"/tmp/build-err_$(basename $1).log"

if [ -s "/tmp/build-err_$(basename $1).log" ]; then
  echo "Include errors for $1:";
  cat "/tmp/build-err_$(basename $1).log" >& 2;
  rm "/tmp/build-err_$(basename $1).log";
  exit 1;
fi
