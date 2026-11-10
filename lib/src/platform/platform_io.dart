import 'dart:io' show Platform;

/// Whether the code runs in a browser.
const bool isWeb = false;

/// Reads a process environment variable.
String? environmentVariable(String name) => Platform.environment[name];

/// Describes the runtime for the User-Agent header.
String get runtimeDescription =>
    'dart/${Platform.version.split(' ').first} (${Platform.operatingSystem})';
