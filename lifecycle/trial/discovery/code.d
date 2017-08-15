module trial.discovery.code;

import std.algorithm;
import std.string;
import std.range;
import std.file;
import std.stdio;
import std.conv;

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