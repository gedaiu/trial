# Attributes

[up](../README.md)

Here are informations about the built in attributes

## Summary

  - [About](#about)
  - [Flaky](#flaky)
  - [Issue](#issue)
  - [Behaviours Mapping](#behaviours-mapping)
  - [Hacking](#hacking)

## About
You can use [User Defined Attributes](http://dlang.org/spec/attribute.html#uda) to add more
informations to your test result. Right now you can only modify the test labels but in the
future, more functionality will be added. Besides the provided attributes, any string attribute, will be used as test name.

## Flaky
In a real life not all of your tests are stable and always green or always red. A test might start to "blink" i.e. it fails
from time-to-time without any obvious reason. You could disable such a test, that is a trivial solution. However what if
you do not want to do that? Say you would like to get more details on possible reasons or the test is so critical that
even being flaky it provides helpful information? You have an option to mark such tests in a special way, so resulting
report will clearly show them as unstable:

```d
@Flaky
unittest {
    ...
}
```

## Issue
To link a test to an issue, you can use @Issue annotation. Simply specify the issue key as shown below:

```d
@Issue("https://github.com/gedaiu/trial/issues/2")
unittest {
    ...
}
```

## Behaviours Mapping
In some development approaches tests are classified by stories and features. If you’re using this then you can annotate
your test with @Story and @Feature annotations:

```d
@Feature("My awesome feature")
@Story("The story name")
unittest {
    ...
}
```

## Hacking
The attributes add custom [Label](http://trial.szabobogdan.com/api/trial/interfaces/Label.html) structs to the `Label[] labels;` property inside test result. If you want to implement a custom
attribute, you have to create a `struct` with the `Label[] labels()` method. You can make it `static Label[] labels()` if you don't want to declare the attribute using paranthesis.
