# Trial

[Writing unit tests is easy with Dlang](https://dlang.org/spec/unittest.html). Unfortunately
when you have a big collection of unit tests, it get's hard to maintain and debug them. In order
to avoid these problems you can use this flexible test runner for D programing language.

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

## Features

This library intends to provide a rich set of features that helps you to customize your test runs:
  - Executors
  - Reporters
  - Test discoveries
  - Steps and attachments

## Structure

## Fluent Asserts

Since DLang does not have a rich assert library, you can use [Fluent Asserts](http://fluentasserts.szabobogdan.com/), a library
that improves your experience of writing tests.

## Alternatives

  - [Dub](https://code.dlang.org/docs/commandline)
  - [Unit Threaded](https://code.dlang.org/packages/unit-threaded)
  - [DUnit](https://code.dlang.org/packages/dunit)
  - [d-unit](https://code.dlang.org/packages/d-unit)
  - [Feature Test D](https://code.dlang.org/packages/feature-test-d)
