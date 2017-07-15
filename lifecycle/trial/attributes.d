module trial.attributes;

struct TestAttribute {
  string name;
}


@property TestAttribute Test() {
  return TestAttribute("");
}