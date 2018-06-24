#!/bin/bash
set -e -x -o pipefail

# test for successful 32-bit build
# if [ "$DC" == "dmd" ]; then
#   dub test --arch=x86
#   dub clean --all-packages
# fi

# test for successful release build
dub build :runner -b release --compiler=$DC

# run unit tests
dub clean --all-packages
cat dub.selections.json || true
dub upgrade
dub run :runner --compiler=$DC -- -v --compiler=$DC
