/// Whether the code runs in a browser.
const bool isWeb = true;

/// Browsers have no process environment.
String? environmentVariable(String name) => null;

/// Describes the runtime for the User-Agent header.
String get runtimeDescription => 'dart/web';
