# Getting started

[up](../README.md)

This tutorial adds trial to an existing dub project, writes a few tests and runs them.

## Summary

  - [Add the dependency](#add-the-dependency)
  - [Write a test](#write-a-test)
  - [Run the tests](#run-the-tests)
  - [Run only some tests](#run-only-some-tests)
  - [Write spec suites](#write-spec-suites)
  - [Choose the reporters](#choose-the-reporters)
  - [Use the reports in CI](#use-the-reports-in-ci)

## Add the dependency

Trial is a dub package. There is nothing to install: add it to the `unittest` configuration of your `dub.json`, so it is
only built when you run the tests:

```json
"configurations": [
  {
    "name": "library"
  },
  {
    "name": "unittest",
    "dependencies": {
      "trial": "~>1.0.1"
    }
  }
]
```

Trial replaces the default D test runner as soon as it is part of the test build. You don't need to import it or write
a `main` function.

## Write a test

Every `unittest` block is a test. The `///` comment above it, or a string attribute, becomes the test name:

```d
module calculator;

int add(int a, int b) {
  return a + b;
}

/// add returns 5 for 2 and 3
unittest {
  assert(add(2, 3) == 5);
}

@("add returns -1 for 2 and -3")
unittest {
  assert(add(2, -3) == -1);
}
```

Name the tests after the behaviour they check. The names are what you read when a test fails, and what you use to run
a single test.

## Run the tests

```
dub test
```

Trial prints each test grouped by its module, then the failures with their source location and a summary. The run
fails when a test fails, so `dub test` works as a CI step without any extra setup.

## Run only some tests

Arguments after `--` go to trial:

```
dub test -- -t "add returns 5"           # tests whose name contains the text
dub test -- -t "=add returns 5 for 2 and 3"   # exactly one test
dub test -- -s calculator                # one module
dub test -- --at source/calculator.d:12  # the test around a line
```

When the filters match no test the run fails, so a typo can't make a run green. All the flags are listed in
[Command line](command-line.md).

## Write spec suites

If you prefer `describe` and `it`, write the suites with `Spec`:

```d
version (unittest) {
  import trial.discovery.spec;

  private alias suite = Spec!({
    describe("add", {
      it("returns 5 for 2 and 3", {
        assert(add(2, 3) == 5);
      });

      it("returns -1 for 2 and -3", {
        assert(add(2, -3) == -1);
      });
    });
  });
}
```

Spec suites and `unittest` blocks can live in the same project. [Test Discovery](test-discovery.md) covers the setup and
teardown hooks.

## Choose the reporters

Create a `trial.json` next to your `dub.json` to change the defaults:

```json
{
  "reporters": ["spec", "result", "stats", "xunit"],
  "artifactsLocation": ".trial",
  "maxThreads": 4
}
```

You can also pick reporters for one run with `dub test -- -r dot-matrix,result`. [Reporters](reporters.md) describes
each one.

## Use the reports in CI

The file reporters write to `.trial`. Keep that folder as a job artifact; in GitLab the `xunit` files also show up as
test results in merge requests:

```yaml
test:
  script:
    - dub test
  artifacts:
    when: always
    paths:
      - .trial
    reports:
      junit: .trial/xunit/*.xml
```

Add `.trial` to your `.gitignore`.
