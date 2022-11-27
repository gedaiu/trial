module trial;


public import trial.attributes;
public import trial.runner;
public import trial.discovery.code;
public import trial.discovery.spec;
public import trial.discovery.unit;
public import trial.executor.parallel;
public import trial.executor.process;
public import trial.executor.single;
public import trial.interfaces;
public import trial.reporters.allure;
public import trial.reporters.dotmatrix;
public import trial.reporters.html;
public import trial.reporters.landing;
public import trial.reporters.list;
public import trial.reporters.progress;
public import trial.reporters.result;
public import trial.reporters.spec;
public import trial.reporters.specprogress;
public import trial.reporters.specsteps;
public import trial.reporters.stats;
public import trial.reporters.tap;
public import trial.reporters.visualtrial;
public import trial.reporters.writer;
public import trial.reporters.xunit;
public import trial.runner;
public import trial.settings;
public import trial.stackresult;
public import trial.step;
public import trial.terminal;

version(trial_as_dependency) {} else :
version(unittest):

shared static this() {
  import dub_test_root;

  unittestRuntimeSetup!(dub_test_root.allModules);
}
