# Attachments

[up](../README.md)

Here are informations about how to add attachments to your reports.

## Summary

  - [About](#about)
  - [Adding attachments](#adding-attachments)
  - [Hacking](#hacking)

## About

When you write complex tests, like integration or ui tests, usually is helpful to add more verbosity to your reports.
You can add screenshots, logs, performance data, etc.

## Adding attachments

If you want to add an attachment to the current test or step, you have to call the [Attachment.fromFile](http://trial.szabobogdan.com/api/trial/interfaces/Attachment.html#fromFile) method.

```
import trial.interfaces;

/// A test that will attach a file
unittest {
  Attachment.fromFile("my awesome screenshot", "screenshot.png", "image/png");
}

```

It is also possible to add an attachment using the LifecycleListener:

```
import trial.runner;

/// Alternative attachment
unittest {
    auto a = const Attachment(name, path, name);
    LifeCycleListeners.instance.attach(a);
}
```

## Hacking

If you want to capture the attachments, you need to implement the [IAttachmentListener](http://trial.szabobogdan.com/api/trial/interfaces/IAttachmentListener.html)
and add your custom handler.

Note that if you want to implement a custom [executor](http://trial.szabobogdan.com/doc/executors.html), in order to 
have the attachments linked to the current test or step, you must implement this interface. 

```
  /// Called when an attachment is ready
  void attach(ref const Attachment attachment) {
    if(currentStep is null) {
      suiteResult.attachments ~= Attachment(attachment.name, attachment.file, attachment.mime);
      return;
    }

    currentStep.attachments ~= Attachment(attachment.name, attachment.file, attachment.mime);
  }
```
