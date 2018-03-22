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
dub test :runner --compiler=$DC
dub run :runner --compiler=$DC -- :lifecycle --coverage -v

# download vibe and run the tests
git clone https://github.com/vibe-d/vibe.d.git
cp tests/relative.dub.selections.json vibe.d/data/dub.selections.json
cd vibe.d
dub clean --all-packages
../trial :data --coverage -v
cd ..

# Test the examples
cp tests/relative.dub.selections.json examples/unittest/dub.selections.json
cp tests/relative.dub.selections.json examples/spec/dub.selections.json
cp tests/relative.dub.selections.json examples/test-class/dub.selections.json

cd examples/unittest
../../trial --coverage -v

cd ../spec
../../trial --coverage -v

cd ../test-class
../../trial --coverage -v

cd ../optional-fluent-asserts
../../trial -v

cd ../..