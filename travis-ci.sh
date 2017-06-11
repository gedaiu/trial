#!/bin/bash

set -e -x -o pipefail

# run unit tests
dub run :runner --compiler=$DC -- :lifecycle
dub run :runner --compiler=$DC -- :runner
