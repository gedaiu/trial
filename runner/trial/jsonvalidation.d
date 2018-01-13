module trial.jsonvalidation;

import std.traits;
import std.algorithm;
import dub.internal.vibecompat.data.json;

class JsonValidationException : JSONException {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
    super(msg, file, line);
  }
}

private string toStringType(const Json.Type jsonType) pure {
  string type;

  switch (jsonType) {
  case Json.Type.string:
    type = "string";
    break;

  case Json.Type.int_:
    type = "number";
    break;

  case Json.Type.bool_:
    type = "boolean";
    break;

  case Json.Type.object:
    type = "object";
    break;

  case Json.Type.array:
    type = "array";
    break;

  default:
    type = "unknown";
  }

  return type;
}

private string getStringType(T)() pure {
  static if (is(bool == T)) {
    return "boolean";
  } else static if (isNumeric!T) {
    return "number";
  } else static if (isSomeString!T) {
    return "string";
  } else static if (isAggregateType!T) {
    return "object";
  } else static if (isArray!T) {
    return "array";
  } else static if (isAssociativeArray!T) {
    return "object";
  } else {
    return "";
  }
}

void validateJson(T)(const Json data, const string prefix = "", const string postfix = "") {
  immutable expectedType = getStringType!T;
  immutable currentType = data.type.toStringType;
  immutable glue = prefix == "" ? "" : ".";

  if (currentType != expectedType) {
    throw new JsonValidationException(
        "Expected `" ~ prefix ~ "` to be `" ~ expectedType ~ "` instead of `"
        ~ currentType ~ "`" ~ postfix ~ ".");
  }

  static if (isAssociativeArray!T) {
    foreach (string key, value; data) {
      validateJson!(ValueType!(T))(value, prefix ~ glue ~ key, postfix);
    }
  }

  static if (isAggregateType!T) {
    string[] members;

    foreach (memberName; __traits(allMembers, T)) {
        members ~= memberName;

        static if (!isCallable!(__traits(getMember, T, memberName)) && memberName != "Monitor") {
          {
            enum isOptional = hasUDA!(__traits(getMember, T, memberName),
                  OptionalAttribute);

            static if (!isOptional) {
              if (memberName !in data) {
                throw new JsonValidationException(
                    "Missing non-optional field `" ~ prefix ~ glue ~ memberName ~ "` of type `" ~ getStringType!(
                    typeof(__traits(getMember, T, memberName))) ~ "`" ~ postfix ~ ".");
              }
            }

            if (memberName in data) {
              validateJson!(typeof(__traits(getMember, T, memberName)))(data[memberName],
                  prefix ~ glue ~ memberName, postfix);
            }
          }
        }
      }

    foreach (string key, value; data) {
      if (!members.canFind(key)) {
        throw new JsonValidationException(
            "Found an extra field `" ~ prefix ~ glue ~ key ~ "` of type `"
            ~ value.type.toStringType ~ "`" ~ postfix ~ ".");
      }
    }
  }
}

version(unittest) {
  import fluent.asserts;
}

/// validateJson should find a missing field
unittest {
  struct Test {
    string someField;
  }

  ({ validateJson!Test(Json.emptyObject); }).should.throwException!JsonValidationException
    .withMessage.equal("Missing non-optional field `someField` of type `string`.");
}

/// validateJson should find a missing nested field
unittest {
  struct Child {
    bool value;
  }

  struct Test {
    Child child;
  }

  Json value = Json.emptyObject;
  value["child"] = Json.emptyObject;
  ({ validateJson!Test(value); }).should.throwException!JsonValidationException.withMessage.equal(
      "Missing non-optional field `child.value` of type `boolean`.");
}

/// validateJson should find an extra nested field
unittest {
  struct Child {
    bool value;
  }

  struct Test {
    Child child;
  }

  Json value = Json.emptyObject;
  value["child"] = Json.emptyObject;
  value["child"]["value"] = true;
  value["child"]["other"] = true;

  ({ validateJson!Test(value); }).should.throwException!JsonValidationException
    .withMessage.equal("Found an extra field `child.other` of type `boolean`.");
}

/// validateJson should not throw exceptions for an optional field
unittest {
  struct Test {
    @optional string someField;
  }

  ({ validateJson!Test(Json.emptyObject); }).should.not.throwAnyException;
}

/// validateJson should throw exceptions when a string is found instead of int
unittest {
  struct Test {
    int someNumber;
  }

  Json obj = Json.emptyObject;
  obj["someNumber"] = "12";

  ({ validateJson!Test(obj); }).should.throwException!JsonValidationException
    .withMessage.equal("Expected `someNumber` to be `number` instead of `string`.");
}

/// validateJson should throw exceptions when a string is found instead of float
unittest {
  struct Test {
    float someNumber;
  }

  Json obj = Json.emptyObject;
  obj["someNumber"] = "12";

  ({ validateJson!Test(obj); }).should.throwException!JsonValidationException
    .withMessage.equal("Expected `someNumber` to be `number` instead of `string`.");
}

/// validateJson should throw exceptions when a string is found instead of bool
unittest {
  struct Test {
    bool someBool;
  }

  Json obj = Json.emptyObject;
  obj["someBool"] = "12";

  ({ validateJson!Test(obj); }).should.throwException!JsonValidationException
    .withMessage.equal("Expected `someBool` to be `boolean` instead of `string`.");
}

/// validateJson should throw exceptions when a string is found instead of object
unittest {
  struct Test {
    Object someObj;
  }

  Json obj = Json.emptyObject;
  obj["someObj"] = "12";

  ({ validateJson!Test(obj); }).should.throwException!JsonValidationException
    .withMessage.equal("Expected `someObj` to be `object` instead of `string`.");
}

/// validateJson should throw exceptions when a string is found instead of array
unittest {
  struct Test {
    Object[] someObjList;
  }

  Json obj = Json.emptyObject;
  obj["someObjList"] = "12";

  ({ validateJson!Test(obj); }).should.throwException!JsonValidationException
    .withMessage.equal("Expected `someObjList` to be `array` instead of `string`.");
}

/// validateJson should throw exceptions when an int is found instead of string
unittest {
  struct Test {
    string someString;
  }

  Json obj = Json.emptyObject;
  obj["someString"] = 12;

  ({ validateJson!Test(obj); }).should.throwException!JsonValidationException
    .withMessage.equal("Expected `someString` to be `string` instead of `number`.");
}

/// validateJson should throw exceptions when an int is found instead of boolean
unittest {
  struct Test {
    string someString;
  }

  Json obj = Json.emptyObject;
  obj["someString"] = true;

  ({ validateJson!Test(obj); }).should.throwException!JsonValidationException.withMessage.equal(
      "Expected `someString` to be `string` instead of `boolean`.");
}

/// validateJson should throw exceptions when an array is found instead of string
unittest {
  struct Test {
    string someString;
  }

  Json obj = Json.emptyObject;
  obj["someString"] = Json.emptyArray;

  ({ validateJson!Test(obj); }).should.throwException!JsonValidationException
    .withMessage.equal("Expected `someString` to be `string` instead of `array`.");
}

/// validateJson should throw exceptions when an nested struct int is found instead of string
unittest {
  struct Child {
    string someString;
  }

  struct Test {
    Child child;
  }

  Json obj = Json.emptyObject;
  obj["child"] = Json.emptyObject;
  obj["child"]["someString"] = 12;

  ({ validateJson!Test(obj); }).should.throwException!JsonValidationException.withMessage.equal(
      "Expected `child.someString` to be `string` instead of `number`.");
}

/// validateJson should throw exceptions when an assoc array is found instead of string
unittest {
  struct Test {
    string[string] someString;
  }

  Json obj = Json.emptyObject;
  obj["someString"] = Json.emptyObject;
  obj["someString"]["key"] = 12;

  ({ validateJson!Test(obj); }).should.throwException!JsonValidationException.withMessage.equal(
      "Expected `someString.key` to be `string` instead of `number`.");
}
