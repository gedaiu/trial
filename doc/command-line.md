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
| `-t`, `--testName` | text | Runs only the tests whose name contains the text |
| `-s`, `--suiteName` | text | Runs only the tests whose suite name contains the text |
| `-f`, `--filter` | text | Runs only the tests whose `<suite> <test name>` contains the text, so one value can select both the suite and the test |
| `-r`, `--reporters` | names | Replaces the reporter list. Separate names with commas: `-r spec,result,xunit` |
| `-e`, `--executor` | name | Replaces the executor: `default`, `parallel` or `process` |

When several filters are given, a test must match all of them.

An unknown reporter or executor name stops the run with an error like ``There is no `nope` reporter``.

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
