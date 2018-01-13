#!/bin/bash
set -e -x -o pipefail

# test for successful 32-bit build
if [ "$DC" == "dmd" ]; then
	dub test :lifecycle --arch=x86
	dub clean --all-packages
fi

# test for successful release build
dub build :runner -b release --compiler=$DC --registry https://code-mirror.dlang.io/
dub clean --all-packages

# run unit tests
dub test :runner --compiler=$DC --registry https://code-mirror.dlang.io/
dub run :runner --compiler=$DC -- :lifecycle --coverage -v --registry https://code-mirror.dlang.io/

# download vibe and run the tests
git clone https://github.com/vibe-d/vibe.d.git
cd vibe.d
../trial :data --coverage --registry https://code-mirror.dlang.io/
cd ..

# Test the examples
cd examples/unittest
../../trial --coverage --registry https://code-mirror.dlang.io/

cd ../spec
../../trial --coverage --registry https://code-mirror.dlang.io/

cd ../test-class
../../trial --coverage --registry https://code-mirror.dlang.io/

cd ../..