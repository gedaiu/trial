# Steps

[up](../README.md)

Here are informations about how you can improve long tests using steps.

## Summary

  - [About](#about)
  - [Nested Steps](#nested-steps)

## About

Most of the time, the unit tests are short and simple. But when you have some complicated scenarios, like
integration or UI tests, you might want to add more verbosity to your test. An example of such report is
this: (allure report)[https://ci.qameta.io/job/allure1/job/master/Allure_Report/index.html#xUnit/c199038c65862cf5/430383b527351443]

The [Step](http://trial.szabobogdan.com/api/trial/step/Step.html) structure helps you to add more information
to your reports. 

```
import trial.step;

unittest {
    Step("first step");
    // do something

    Step("the second step");
    // do something else
}
```

The previous example adds two steps to a test, which will be displayed by your reporter if it suports this feature.

## Nested Steps

You can add nested steps if you store the step in a local variable:
```
import trial.step;

void someStep() {
    auto step2 = Step("the second step");
    // do something else
}

unittest {
    auto step1 = Step("first step");
    // do something

    someStep();
}
```

In this case, the `step2` will have `step1` as a parent.


