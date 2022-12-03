/++
  A module containing the attributes used to add metadata to your tests

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.attributes;

/// This struct is used to mark some test functions
struct TestAttribute {
  ///
  string file;

  ///
  size_t line;
}

/// This specifies when a setup method must be called
struct TestSetupAttribute {
  /// Run before the suite starts
  bool beforeAll;

  /// Run after the suite ends
  bool afterAll;

  /// Run before each test
  bool beforeEach;

  /// Run after each test
  bool afterEach;
}

/// Mark a test
TestAttribute Test(string file = __FILE__, size_t line = __LINE__) {
  return TestAttribute(file, line);
}

/// Mark a function to be executed before each test
TestSetupAttribute BeforeEach() {
  return TestSetupAttribute(false, false, true, false);
}

/// Mark a function to be executed after each test
TestSetupAttribute AfterEach() {
  return TestSetupAttribute(false, false, false, true);
}

/// Mark a function to be executed before the suite starts
TestSetupAttribute BeforeAll() {
  return TestSetupAttribute(true, false, false, false);
}

/// Mark a function to be executed after the suite ends
TestSetupAttribute AfterAll() {
  return TestSetupAttribute(false, true, false, false);
}