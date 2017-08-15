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
  - [HTML](#html)
  - [Allure](#allure)
  - [Stats](#stats)
  - [Spec Progress](#spec-progress)
  - [Extending](#extending)

## About

The Trial reporters are used to get informations about your tests result. The library comes with a vast
collection of reporters, and if none of these suits your needs you can easily add your own.

A `Reporter` is a class that presents some information to the user about a test run. Most of the time the user is
a person, but it can be an `IDE` or a `CI` too. Because this is an important part of a test run library, you shuld
be able to easily extend or create your custom reporters.

In order to use the embedded reporters, you have to add them to the `reporters` list inside your `trial.json` file.
Here is an example.

```json
...

reporters": [
    "list",
    "result",
    "stats",
    "html"
],

...
```

## Spec

This is the default reporter. The "spec" reporter outputs a hierarchical view nested just as the test cases are.

To use it, add `spec` to the reporters list inisde `trial.json`.

[![asciicast](https://asciinema.org/a/9z1tolgn7x55v41i3mm3wlkum.png)](https://asciinema.org/a/9z1tolgn7x55v41i3mm3wlkum)

## Spec steps

A flavour of the "spec" reporter that show the tests and the steps of your tests.

To use it, add `spec-steps` to the reporters list inisde `trial.json`.

[![asciicast](https://asciinema.org/a/122462.png)](https://asciinema.org/a/122462)

## Dot Matrix

The dot matrix reporter is simply a series of characters which represent test cases. Failures highlight in red exclamation marks (!). Good if you prefer minimal output.

To use it, add `dot-matrix` to the reporters list inisde `trial.json`.

[![asciicast](https://asciinema.org/a/122458.png)](https://asciinema.org/a/122458)

## Landing

The Landing Strip (landing) reporter is a gimmicky test reporter simulating a plane landing unicode ftw

To use it, add `landing` to the reporters list inisde `trial.json`.

[![asciicast](https://asciinema.org/a/122459.png)](https://asciinema.org/a/122459)

## List

The list reporter outputs a simple specifications list as test cases pass or fail.

To use it, add `list` to the reporters list inisde `trial.json`.

[![asciicast](https://asciinema.org/a/b4u0o9vba18dquzdgwif7anl5.png)](https://asciinema.org/a/b4u0o9vba18dquzdgwif7anl5)

## Progress

The progress reporter implements a simple progress-bar

To use it, add `progress` to the reporters list inisde `trial.json`.

[![asciicast](https://asciinema.org/a/122460.png)](https://asciinema.org/a/122460)

## Result

The Result reporter will print an overview of your test run. This is added by default to your reporters list and it's
mandatory to use if you want to see the details of the failed tests.

To use it, add `result` to the reporters list inisde `trial.json`.

[![asciicast](https://asciinema.org/a/12x1mkxfmsj1j0f7qqwarkiyw.png)](https://asciinema.org/a/12x1mkxfmsj1j0f7qqwarkiyw)

## HTML

The HTML reporter outputs a hierarchical HTML body representation of your tests. Just publish it on a webserver
and you will have a nice report for your build.

To use it, add `html` to the reporters list inisde `trial.json`.

[example](http://trial.szabobogdan.com/artifacts/trial-result.html)

## Allure

The Allure reporter outputs the test results in an xml file that can be used to
generate nice [Allure](https://docs.qameta.io/allure/2.0/) reports.

To convert the xml files to html, you can use inside your project, the allure commandline:

```bash
allure generate -o allure-html allure
```

In this case, the xml files are located in `allure` folder

To use it, add `allure` to the reporters list inisde `trial.json`.

[example](http://trial.szabobogdan.com/artifacts/allure/)

## Stats

The stats reporter creates a csv file with the duration and the result of all your steps and tests. It's usefull to use it with other reporters, like spec progress.

To use it, add `stats` to the reporters list inisde `trial.json`.

[example](http://trial.szabobogdan.com/artifacts/trial-stats.csv)

## Spec progress

This is an experimental reporter that extends the Spec reporter. It will display the current running time and the remaining time until the tests are finished. It's recomanded to use it with the parallel executor, when you have tests that take a lot
of time, like ui tests written with `selenium` or `appium`.

To use it, add `spec-progress` to the reporters list inisde `trial.json`.

## Extending

If you want to write a custom reporter, have a look at the Lifecycle interface that trial provides and implement the methods that you need.

[Interfaces list](http://trial.szabobogdan.com/api/trial/interfaces.html)

If you want to use your custom reporter, you can add it to the `LifeCycleListeners`:

```d
static this() {
    LifeCycleListeners.instance.add(new MyCustomReporter);
}
```
