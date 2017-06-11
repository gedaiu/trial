#!/bin/bash
set -e -x -o pipefail

# run unit tests
dub test :runner --compiler=$DC
dub run :runner --compiler=$DC -- :lifecycle
