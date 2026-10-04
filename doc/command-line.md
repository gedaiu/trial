# Command line

[up](../README.md)

Here is how you can choose which tests run and how they are reported, without editing any file.

## Summary

  - [Passing arguments](#passing-arguments)
  - [Flags](#flags)
  - [Settings precedence](#settings-precedence)
  - [Agent mode](#agent-mode)

## Passing arguments

Arguments after `--` are passed by `dub` to the test runner:

```
dub test -- -s "my.module" -r spec,result
```

You can also call the built test executable directly, for example `./my-project-test-unittest -t "parses an empty list"`.

## Flags

| Flag | Value | What it does |
|------|-------|--------------|
| `-t`, `--testName` | filter | Runs only the tests whose name matches the filter |
| `-s`, `--suiteName` | filter | Runs only the tests whose suite name matches the filter |
| `-f`, `--filter` | filter | Runs only the tests whose `<suite> <test name>` matches the filter, so one value can select both the suite and the test |
| `--at` | `file:line` | Runs the test that contains that line, for example `--at source/my/module.d:42` |
| `-r`, `--reporters` | names | Replaces the reporter list. Separate names with commas: `-r spec,result,xunit` |
| `-e`, `--executor` | name | Replaces the executor: `default`, `parallel` or `process` |

When several filters are given, a test must match all of them.

When the filters match no test, the run fails instead of passing with nothing executed, so a typo can't turn CI green:

```
No tests matched the filters: -s "my.module" -t "retruns 404"
```

A run without filters still passes when the project has no tests.

An unknown reporter or executor name stops the run with an error like ``There is no `nope` reporter``.

### Filter values

| Value | Matches | Example |
|-------|---------|---------|
| plain text | names containing the text | `-t "returns 404"` |
| `=text` | the exact name only | `-t "=returns 404"` |
| `/regex/` | names matching the regular expression | `-t "/^returns (404\|403)$/"` |

A plain filter can select more than you expect: `-t "returns 404"` also runs `returns 404 when the map is private`.
Use the `=` form to run exactly one test.

### Selecting a test by line

`--at file:line` runs the test whose body contains that line, which is handy when a stack trace or your editor points at a
line. The file only needs to end with the given path, so `--at my/module.d:42` is enough. Trial knows only the line
where each test starts, so it picks the test in that file that starts closest before the line.

## Settings precedence

The settings are resolved in this order, the last one wins:

1. the defaults
2. the `trial.json` file from the current directory, when it exists
3. the command line flags

The `trial.json` file can set `reporters`, `executor`, `maxThreads`, `artifactsLocation`, `warningTestDuration` and
`dangerTestDuration`. Missing keys keep their defaults and unknown keys are ignored.

When there is no `reporters` value, these reporters are used: `spec`, `result`, `stats`, `html`, `allure` and `xunit`.

## Agent mode

When the tests are run by an AI coding agent, the `spec` and `result` console reporters are replaced by the
[agent](reporters.md#agent) reporter, which prints only the failed tests and one summary line. The file reporters, like
`xunit` and `html`, keep running.

An agent is detected when one of these environment variables is set: `AI_AGENT`, `CLAUDECODE`, `CURSOR_AGENT`,
`CODEX_SANDBOX`, `GEMINI_CLI`, `OPENCODE` or `CLINE_ACTIVE`.

`TRIAL_AGENT=1` turns agent mode on and `TRIAL_AGENT=0` turns it off, whatever environment variables are set. Passing
`-r` always wins over agent mode, since you chose the reporters yourself.
