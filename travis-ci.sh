#!/bin/bash
set -e -x -o pipefail

# test for successful 32-bit build
if [ "$DC" == "dmd" ]; then
	dub build --combined --arch=x86
	dub clean --all-packages
fi

# test for successful release build
dub build --combined -b release --compiler=$DC
dub clean --all-packages

# run unit tests
dub test :runner --compiler=$DC
dub run :runner --compiler=$DC -- :lifecycle
