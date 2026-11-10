part of 'bachs.dart';

/// The version of this SDK. It is sent in the User-Agent header.
const String bachsSdkVersion = '0.1.0';

/// The Bachs deployment a client talks to.
enum BachsEnvironment {
  /// `https://sandbox-api.bachs.io`, used with `sk_sandbox_` keys.
  sandbox('https://sandbox-api.bachs.io'),

  /// `https://api.bachs.io`, used with `sk_live_` keys.
  production('https://api.bachs.io');

  const BachsEnvironment(this.baseUrl);

  /// The API host for this environment.
  final String baseUrl;
}

/// How much the SDK logs.
enum BachsLogLevel {
  /// Method, path, status, duration, attempt and request ID of each request.
  debug,

  /// The active environment, once per client.
  info,

  /// Unrecognised key prefixes and reads that ran out of retries.
  warn,

  /// Nothing.
  off,
}

/// One log entry from the SDK. It never contains keys, request or response
/// bodies, portal URLs or webhook secrets.
class BachsLogRecord {
  /// Creates a log record.
  const BachsLogRecord(this.level, this.message, [this.fields = const {}]);

  /// The level the entry was logged at.
  final BachsLogLevel level;

  /// What happened, such as `bachs: request`.
  final String message;

  /// Structured details, such as the method, path and status.
  final Map<String, Object?> fields;

  @override
  String toString() {
    final details = fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
    return '[${level.name}] $message${details.isEmpty ? '' : ' $details'}';
  }
}

/// Receives the SDK's log entries.
typedef BachsLogger = void Function(BachsLogRecord record);

/// The default logger. It prints each entry.
void printBachsLog(BachsLogRecord record) {
  // ignore: avoid_print
  print(record);
}

/// Calls the Bachs API. Create one and reuse it.
///
/// Creating a client sends no request, so an invalid key shows up on the
/// first call. Call [close] when you are done if the client created its own
/// HTTP client.
class BachsClient {
  /// Creates a client.
  ///
  /// Keys starting with `sk_sandbox_` use the sandbox and keys starting with
  /// `sk_live_` use production. Keys with any other prefix need
  /// [environment], and an [environment] that contradicts the key is an
  /// error.
  ///
  /// * [baseUrl] overrides the API host, for a proxy or a test server.
  /// * [timeout] is the total time for one operation, including retries.
  /// * [maxRetries] is how many extra attempts a read gets after a network
  ///   failure or a 429, 500, 502, 503 or 504. Writes are never retried.
  /// * [httpClient] is your own `package:http` client. The SDK does not close
  ///   it.
  /// * [logger] receives log entries. Pass `null` to turn logging off.
  /// * [logLevel] defaults to the `BACHS_LOG` environment variable (or
  ///   `--dart-define=BACHS_LOG=...`): `debug`, `info`, `warn` or `off`. It
  ///   is [BachsLogLevel.warn] when that is unset.
  ///
  /// Throws a [BachsConfigException] for invalid settings.
  factory BachsClient(
    String apiKey, {
    BachsEnvironment? environment,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 2,
    http.Client? httpClient,
    BachsLogger? logger = printBachsLog,
    BachsLogLevel? logLevel,
  }) {
    apiKey = apiKey.trim();
    if (apiKey.isEmpty) {
      throw const BachsConfigException('an API key is required');
    }
    if (timeout <= Duration.zero) {
      throw const BachsConfigException('timeout must be positive');
    }
    if (maxRetries < 0) {
      throw const BachsConfigException('max retries cannot be negative');
    }

    final level = logLevel ?? _levelFromEnvironment();
    final inferred = _environmentFromKey(apiKey);
    BachsEnvironment resolved;
    var unknownPrefix = false;
    if (inferred != null && environment != null && environment != inferred) {
      throw BachsConfigException(
          'the API key is a ${inferred.name} key but the environment is set '
          'to ${environment.name}');
    } else if (inferred != null) {
      resolved = inferred;
    } else if (environment == null) {
      throw const BachsConfigException(
          'the API key prefix is not sk_sandbox_ or sk_live_, so set the '
          'environment');
    } else {
      resolved = environment;
      unknownPrefix = true;
    }

    var url = baseUrl ?? resolved.baseUrl;
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      throw BachsConfigException('invalid base URL "$baseUrl"');
    }

    final client = BachsClient._(
      apiKey: apiKey,
      environment: resolved,
      baseUrl: url,
      timeout: timeout,
      maxRetries: maxRetries,
      http: httpClient ?? http.Client(),
      ownsHttpClient: httpClient == null,
      logger: logger,
      logLevel: level,
    );
    if (unknownPrefix) {
      client._log(
          BachsLogLevel.warn,
          'bachs: unrecognised API key prefix; using the configured '
          'environment',
          {'environment': resolved.name});
    }
    return client;
  }

  BachsClient._({
    required String apiKey,
    required this.environment,
    required String baseUrl,
    required Duration timeout,
    required int maxRetries,
    required http.Client http,
    required bool ownsHttpClient,
    required BachsLogger? logger,
    required BachsLogLevel logLevel,
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl,
        _timeout = timeout,
        _maxRetries = maxRetries,
        _http = http,
        _ownsHttpClient = ownsHttpClient,
        _logger = logger,
        _logLevel = logLevel;

  final String _apiKey;
  final String _baseUrl;
  final Duration _timeout;
  final int _maxRetries;
  final http.Client _http;
  final bool _ownsHttpClient;
  final BachsLogger? _logger;
  final BachsLogLevel _logLevel;
  bool _environmentLogged = false;

  /// The environment this client talks to.
  final BachsEnvironment environment;

  /// The first delay between read retries; later ones double. Tests may
  /// shorten it.
  static Duration retryBaseDelay = const Duration(milliseconds: 500);

  /// Products: `create`, `get`, `list`, `listAll`, `update`, `archive`,
  /// `unarchive`.
  late final ProductsService products = ProductsService._(this);

  /// Product groups.
  late final ProductGroupsService productGroups = ProductGroupsService._(this);

  /// Hosted checkout sessions.
  late final CheckoutSessionsService checkoutSessions =
      CheckoutSessionsService._(this);

  /// Payments (charges).
  late final PaymentsService payments = PaymentsService._(this);

  /// Customers.
  late final CustomersService customers = CustomersService._(this);

  /// Customer portal sessions.
  late final CustomerPortalService customerPortal =
      CustomerPortalService._(this);

  /// Subscriptions.
  late final SubscriptionsService subscriptions = SubscriptionsService._(this);

  /// Refunds.
  late final RefundsService refunds = RefundsService._(this);

  /// Disputes.
  late final DisputesService disputes = DisputesService._(this);

  /// Balances and the payout schedule.
  late final BalancesService balances = BalancesService._(this);

  /// Currency conversions.
  late final ConversionsService conversions = ConversionsService._(this);

  /// Payout destinations.
  late final PayoutDestinationsService payoutDestinations =
      PayoutDestinationsService._(this);

  /// Cross-currency payout quotes.
  late final PayoutQuotesService payoutQuotes = PayoutQuotesService._(this);

  /// Payouts.
  late final PayoutsService payouts = PayoutsService._(this);

  /// Virtual accounts.
  late final VirtualAccountsService virtualAccounts =
      VirtualAccountsService._(this);

  /// File uploads.
  late final UploadsService uploads = UploadsService._(this);

  /// Webhook endpoints and their deliveries.
  late final WebhookEndpointsService webhookEndpoints =
      WebhookEndpointsService._(this);

  /// Webhook events.
  late final WebhookEventsService webhookEvents = WebhookEventsService._(this);

  /// Banks and bank account lookups.
  late final BanksService banks = BanksService._(this);

  /// Reference data: payment methods, rails, currencies and more.
  late final ReferenceService reference = ReferenceService._(this);

  /// Connect: the accounts your platform onboards.
  late final AccountsService accounts = AccountsService._(this);

  /// Connect: people on connected accounts.
  late final PersonsService persons = PersonsService._(this);

  /// Connect: money moved to connected accounts.
  late final TransfersService transfers = TransfersService._(this);

  /// Connect: fees your platform collected.
  late final PlatformFeesService platformFees = PlatformFeesService._(this);

  /// Closes the HTTP client if this client created it. A client you passed
  /// in is left open.
  void close() {
    if (_ownsHttpClient) _http.close();
  }

  String get _userAgent =>
      'bachs-flutter-sdk/$bachsSdkVersion ${platform.runtimeDescription}';

  void _log(BachsLogLevel level, String message,
      [Map<String, Object?> fields = const {}]) {
    final logger = _logger;
    if (logger == null ||
        level == BachsLogLevel.off ||
        level.index < _logLevel.index) {
      return;
    }
    logger(BachsLogRecord(level, message, fields));
  }

  static BachsEnvironment? _environmentFromKey(String key) {
    if (key.startsWith('sk_sandbox_')) return BachsEnvironment.sandbox;
    if (key.startsWith('sk_live_')) return BachsEnvironment.production;
    return null;
  }

  static BachsLogLevel _levelFromEnvironment() {
    const defined = String.fromEnvironment('BACHS_LOG');
    final value = (platform.environmentVariable('BACHS_LOG') ?? defined).trim();
    switch (value.toLowerCase()) {
      case 'debug':
        return BachsLogLevel.debug;
      case 'info':
        return BachsLogLevel.info;
      case 'off':
        return BachsLogLevel.off;
    }
    return BachsLogLevel.warn;
  }
}
