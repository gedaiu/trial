module trial.setup;

version(trial_as_dependency):
version(unittest):

import trial.runner;

shared static this() {
  import dub_test_root;

  unittestRuntimeSetup!(dub_test_root.allModules);
}
