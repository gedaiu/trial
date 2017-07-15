module trial.attributes;

struct TestAttribute {
  string name;
}

TestAttribute Test() {
  return TestAttribute("");
}

TestAttribute Test(string name) {
  return TestAttribute(name);
}