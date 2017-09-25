#!/bin/bash
set -e -x -o pipefail

# test for successful 32-bit build
if [ "$DC" == "dmd" ]; then
	dub test :lifecycle --arch=x86
	dub test :runner --arch=x86
	dub clean --all-packages
fi

# test for successful release build
dub build :runner -b release --compiler=$DC
dub clean --all-packages

# run unit tests
dub test :runner --compiler=$DC
dub run :runner --compiler=$DC -- :lifecycle

# download vibe and run the tests
git clone https://github.com/vibe-d/vibe.d.git
cd vibe.d
../trial :data
cd ..

# download a simple app and run the tests
git clone https://github.com/gedaiu/Game-Of-Life-D.git
cd Game-Of-Life-D
../trial
cd ..