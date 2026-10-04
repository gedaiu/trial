[![Build Status](https://gitlab.com/szabobogdan3/trial/badges/master/build.svg)](https://gitlab.com/szabobogdan3/trial)
[![Line Coverage](http://trial.szabobogdan.com/artifacts/coverage/html/coverage-shield.svg)](http://trial.szabobogdan.com/artifacts/coverage/html/index.html)
[![DUB Version](https://img.shields.io/dub/v/trial.svg)](https://code.dlang.org/packages/trial)

[Writing unit tests is easy with Dlang](https://dlang.org/spec/unittest.html). Unfortunately
when you have a big collection of unit tests, it get's hard to maintain and debug them. In order
to avoid these problems, you can use this flexible test runner for D programing language.

## Motivation

There are many test runners for DLang and there are a few of them that have a lot of useful features
that helps you to be more productive. Sometimes you need to use a custom feature that is not embedded
with those libraries. Maybe it's about a custom test report, a new discovery mode or an integration with
a third party app like an IDE or Jenkins. In each of these cases you need to dig in a project that is
not maintained or you need features that does not match the creators view about this subject.

In order to be able to extend your test runs without depending on other people, I propose a simple
idea, inspired from well known projects like [TestNg](http://testng.org/doc/),
[NUnit](https://github.com/nunit/docs/wiki) and [mocha](https://mochajs.org/), that exposes a simple
interface that allows you to add what you want, when you want.

## How it works

Trial is a dub package. Add it to the `unittest` configuration of your project and run `dub test`: it replaces the
default D test runner, discovers your `unittest` blocks and `Spec` suites, runs them and reports the results. There is
no separate executable to install.

```json
"configurations": [
  { "name": "library" },
  { "name": "unittest", "dependencies": { "trial": "~>1.0.1" } }
]
```

Arguments after `--` go to trial. For example `dub test -- -t "=parses an empty list"` runs exactly that test, and
`dub test -- -r spec,xunit` picks the reporters. The [getting started](doc/getting-started.md) guide walks through a
first project, and [Command line](doc/command-line.md) lists every flag.

## Features

This library intends to provide a rich set of features that helps you to customize your test runs:
  - [Getting started](doc/getting-started.md)
  - [Command line](doc/command-line.md)
  - [Test discoveries](doc/test-discovery.md)
  - [Executors](doc/executors.md)
  - [Reporters](doc/reporters.md)
  - [Steps](doc/steps.md)
  - [Attributes](doc/attributes.md)
  - [Attachments](doc/attachments.md)
  - [Extending](doc/plugins.md)

## Configurable

A `trial.json` file in the project folder sets the reporters, the executor, the thread count and where the reports are
written. It is optional, all its keys are optional, and the command line flags override it. See
[Settings precedence](doc/command-line.md#settings-precedence).

## Hacking

Please have a look at [trial.interfaces](http://trial.szabobogdan.com/api/trial/interfaces.html).

To work on trial itself, clone the repository and run `dub test`. The library tests itself with its own runner.

## Fluent Asserts

Since DLang does not have a rich assert library, you can use [Fluent Asserts](http://fluentasserts.szabobogdan.com/), a library
that improves your experience of writing tests.
