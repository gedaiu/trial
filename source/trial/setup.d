module trial.setup;

version(unittest):

import trial.runner;

static if(!__traits(compiles, () {static import dub_test_root;})) {
  static assert(false, "Couldn't find 'dub_test_root'. Make sure you are running tests with `dub test`");
}

// A module constructor here would form a constructor cycle through `dub_test_root`, which imports the modules
// under test. A C constructor is enough, since the setup only registers the unit tester.
pragma(crt_constructor)
extern(C) void setupTrialUnitTester() {
  import dub_test_root;
  unittestRuntimeSetup!(dub_test_root.allModules);
}
