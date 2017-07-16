module trial.attributes;

struct TestAttribute {
  string name;
}

struct TestSetupAttribute {
  bool beforeAll;
  bool afterAll;
  bool beforeEach;
  bool afterEach;
}

TestAttribute Test() {
  return TestAttribute("");
}

TestAttribute Test(string name) {
  return TestAttribute(name);
}

TestSetupAttribute BeforeEach() {
  return TestSetupAttribute(false, false, true, false);
}

TestSetupAttribute AfterEach() {
  return TestSetupAttribute(false, false, false, true);
}

TestSetupAttribute BeforeAll() {
  return TestSetupAttribute(true, false, false, false);
}

TestSetupAttribute AfterAll() {
  return TestSetupAttribute(false, true, false, false);
}