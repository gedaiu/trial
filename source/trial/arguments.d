/++
  Command line arguments that override the `trial.json` settings

  Copyright: © 2026 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.arguments;

/// The command line arguments of a test run
struct RunArguments {
  /// The test name filter, filled by `-t`
  string testName;

  /// The suite name filter, filled by `-s`
  string suiteName;

  /// The full test name filter, filled by `-f`
  string fullName;

  /// The source location filter `file:line`, filled by `--at`
  string at;

  /// The reporters to use, filled by `-r`
  string[] reporters;

  /// The executor to use, filled by `-e`
  string executor;
}
