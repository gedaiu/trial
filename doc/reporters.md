# Reporters

[up](../README.md)


Here are informations about the supported reporters and how you can create your own.

## Summary

  - [About](#about)
  - [Spec](#spec)
  - [Spec steps](#spec-steps)
  - [Dot matrix](#dot-matrix)
  - [Landing](#landing)
  - [List](#list)
  - [Progress](#progress)
  - [Result](#result)
  - [Spec Progress](#spec-progress)

## About

The Trial reporters are used to get informations about your tests result. The library comes with a vast 
collection of reporters, and if none of these suits your needs you can easily add your own.

A `Reporter` is a class that presents some information to the user about a test run. Most of the time the user is
a person, but it can be an `IDE` or a `CI` too. Because this is an important part of a test run library, you shuld
be able to easily extend or create your custom reporters.

## Spec

This is the default reporter. The "spec" reporter outputs a hierarchical view nested just as the test cases are.

[![asciicast](https://asciinema.org/a/9z1tolgn7x55v41i3mm3wlkum.png)](https://asciinema.org/a/9z1tolgn7x55v41i3mm3wlkum)

## Spec steps

A flavour of the "spec" reporter that show the tests and the steps of your tests.

[![asciicast](https://asciinema.org/a/122462.png)](https://asciinema.org/a/122462)

## Dot Matrix

The dot matrix reporter is simply a series of characters which represent test cases. Failures highlight in red exclamation marks (!). Good if you prefer minimal output.

[![asciicast](https://asciinema.org/a/122458.png)](https://asciinema.org/a/122458)

## Landing

The Landing Strip (landing) reporter is a gimmicky test reporter simulating a plane landing unicode ftw

[![asciicast](https://asciinema.org/a/122459.png)](https://asciinema.org/a/122459)

## List

The list reporter outputs a simple specifications list as test cases pass or fail.

[![asciicast](https://asciinema.org/a/b4u0o9vba18dquzdgwif7anl5.png)](https://asciinema.org/a/b4u0o9vba18dquzdgwif7anl5)

## Progress

The progress reporter implements a simple progress-bar

[![asciicast](https://asciinema.org/a/122460.png)](https://asciinema.org/a/122460)

## Result

The Result reporter will print an overview of your test run

[![asciicast](https://asciinema.org/a/12x1mkxfmsj1j0f7qqwarkiyw.png)](https://asciinema.org/a/12x1mkxfmsj1j0f7qqwarkiyw)


## Spec progress

This is an experimental reporter that extends the Spec reporter. It will display the current running time and the remaining time until the tests are finished. It's recomanded to use it with the parallel executor, when you have tests that take a lot
of time, like ui tests written with `selenium` or `appium`.

