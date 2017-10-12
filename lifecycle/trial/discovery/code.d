/++
  A module containing parsing code utilities

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.discovery.code;

import std.algorithm;
import std.string;
import std.range;
import std.file;
import std.stdio;
import std.conv;

version(Have_libdparse) {
	public import dparse.ast;
	public import dparse.lexer;
	public import dparse.parser;
}

/// Get the module name of a DLang source file
string getModuleName(string fileName) {
	if(!exists(fileName)) {
		return "";
	}

	if(isDir(fileName)) {
		return "";
	}

	auto file = File(fileName);

	auto moduleLine = file.byLine()
		.map!(a => a.to!string)
		.filter!(a => a.startsWith("module"));

	if(moduleLine.empty) {
		return "";
	}

	return moduleLine.front.split(' ')[1].split(";")[0];
}


version(Have_libdparse) {
	///
	struct DLangAttribute {
		const(Token)[] tokens;

		inout {
			string identifier() {
				string result;

				foreach(token; tokens) {
					if(str(token.type) == "(") {
						break;
					}

					result ~= token.text;
				}

				return result;
			}

			string value() {
				bool after;
				string result;

				foreach(token; tokens) {
					if(after) {
						result ~= token.text.strip('"').strip('`').strip('\'');
					}

					if(str(token.type) == "(") {
						after = true;
					}
				}

				return result;
			}
		}
	}

	struct DLangFunction {
		const(DLangAttribute)[] attributes;
		const(Token)[] tokens;

		string name() {
			auto result = TokenIterator(tokens)
				.readUntilType("(")
				.replace("\n", " ")
				.replace("\r", " ")
				.replace("\t", " ")
				.split(" ");

			result.reverse;

			return result[0];
		}

		bool hasAttribute(string name) {
			return !attributes.filter!(a => a.identifier == name).empty;
		}

		string testName() {
			foreach(attribute; attributes) {
				if(attribute.identifier == "") {
					return attribute.value;
				}
			}

			return name.camelToSentence;
		}

		size_t line() {
			return TokenIterator(tokens).skipUntilType("(").currentToken.line;
		}
	}

	struct DLangClass {
		const(Token)[] tokens;

		/// returns the class name
		string name() {
			auto iterator = TokenIterator(tokens);
			auto name = iterator.readUntilType("{");

			import std.stdio;
			if(name.indexOf(":") != -1) {
				name = name.split(":")[0];
			}

			return name.strip;
		}

		DLangFunction[] functions() {
			int paranthesisCount;

			auto iterator = TokenIterator(tokens);
			iterator.skipUntilType("{");

			const(Token)[] currentTokens;
			DLangFunction[] discoveredFunctions;
			DLangAttribute[] attributes;
			bool readingFunction;
			int functionLevel = 1;

			foreach(token; iterator) {
				string type = token.type.str;
				currentTokens ~= token;

				if(type == "@") {
					attributes ~= iterator.readAttribute;
				}

				if(type == "{") {
					paranthesisCount++;
				}

				if(type == "}") {
					paranthesisCount--;

					if(paranthesisCount == functionLevel) {
						discoveredFunctions ~= DLangFunction(attributes, currentTokens);
					}
				}

				readingFunction = paranthesisCount > functionLevel;

				if(type == "}" || (!readingFunction && type == ";")) {
					currentTokens = [];
					attributes = [];
				}
			}

			return discoveredFunctions;
		}
	}

	/// An iterator that helps to deal with DLang tokens
	struct TokenIterator {
		private {
			const(Token)[] tokens;
			size_t index;
		}

		///
		int opApply(int delegate(const(Token)) dg) {
			int result = 0;

			while(index < tokens.length) {
				result = dg(tokens[index]);
				index++;
				if (result) {
					break;
				}
			}

			return result;
		}

		///
		ref auto skipWsAndComments() {
			while(index < tokens.length) {
				auto type = str(tokens[index].type);
				if(type != "comment" && type != "whitespace") {
					break;
				}

				index++;
			}

			return this;
		}

		///
		auto currentToken() {
			return tokens[index];
		}

		/// Skip until a token with a certain text is reached
		ref auto skipUntil(string text) {
			while(index < tokens.length) {
				if(tokens[index].text == text) {
					break;
				}

				index++;
			}

			return this;
		}

		ref auto skipNextBlock() {
			readNextBlock();
			return this;
		}

		auto readNextBlock() {
			const(Token)[] blockTokens = [];

			bool readingBlock;
			int paranthesisCount;

			while(index < tokens.length) {
				auto type = str(tokens[index].type);

				if(type == "{") {
					paranthesisCount++;
					readingBlock = true;
				}

				if(type == "}") {
					paranthesisCount--;
				}

				blockTokens ~= tokens[index];
				index++;
				if(readingBlock && paranthesisCount == 0) {
					break;
				}
			}

			return blockTokens;
		}

		/// Skip until a token with a certain type is reached
		ref auto skipUntilType(string type) {
			while(index < tokens.length) {
				if(str(tokens[index].type) == type) {
					break;
				}

				index++;
			}

			return this;
		}

		/// Skip one token
		ref auto skipOne() {
			index++;

			return this;
		}

		/// Concatenate all the tokens until the first token of a certain type
		/// that will be ignored
		string readUntilType(string type) {
			string result;

			while(index < tokens.length) {
				if(str(tokens[index].type) == type) {
					break;
				}

				result ~= tokens[index].text == "" ? str(tokens[index].type) : tokens[index].text;
				index++;
			}

			return result;
		}

		/// Returns a Dlang class. You must call this method after the
		/// class token was read.
		DLangClass readClass() {
			const(Token)[] classTokens = [];

			bool readingClass;
			int paranthesisCount;

			while(index < tokens.length) {
				auto type = str(tokens[index].type);

				if(type == "{") {
					paranthesisCount++;
					readingClass = true;
				}

				if(type == "}") {
					paranthesisCount--;
				}
				classTokens ~= tokens[index];
				index++;
				if(readingClass && paranthesisCount == 0) {
					break;
				}
			}

			return DLangClass(classTokens);
		}

		/// Returns a Dlang attribute. You must call this method after the
		/// @ token was read.
		DLangAttribute readAttribute() {
			const(Token)[] attributeTokens = [];

			int paranthesisCount;
			bool readingParams;
			bool foundWs;

			while(index < tokens.length) {
				auto type = str(tokens[index].type);

				if(type == "whitespace" && paranthesisCount == 0 && !readingParams) {
					foundWs = true;
				}

				if(foundWs && type == ".") {
					foundWs = false;
				}

				if(foundWs && type != "(") {
					break;
				}

				if(type == "(") {
					paranthesisCount++;
					readingParams = true;
					foundWs = false;
				}

				if(type == ")") {
					paranthesisCount--;
				}

				attributeTokens ~= tokens[index];

				if(readingParams && paranthesisCount == 0) {
					break;
				}

				index++;
			}

			return DLangAttribute(attributeTokens);
		}
	}
}

/// Converts a string from camel notation to a readable sentence
string camelToSentence(const string name) pure {
  string sentence;

  foreach(ch; name) {
    if(ch.toUpper == ch) {
      sentence ~= " " ~ ch.toLower.to!string;
    } else {
      sentence ~= ch;
    }
  }

  return sentence.capitalize;
}
