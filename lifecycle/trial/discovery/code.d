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

				if(readingParams && paranthesisCount == 0) {
					break;
				}

				attributeTokens ~= tokens[index];

				index++;
			}

			return DLangAttribute(attributeTokens);
		}
	}
}