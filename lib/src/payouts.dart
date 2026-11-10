part of 'bachs.dart';

/// The kind of payout destination.
extension type const DestinationType(String value) implements String {
  static const bankAccount = DestinationType('bank_account');
  static const mobileMoney = DestinationType('mobile_money');
  static const cryptoWallet = DestinationType('crypto_wallet');
}

/// The review status of a payout destination. Only an approved destination
/// can receive payouts.
extension type const DestinationStatus(String value) implements String {
  static const pendingReview = DestinationStatus('pending_review');
  static const approved = DestinationStatus('approved');
  static const rejected = DestinationStatus('rejected');
}

/// A bank branch address, required for USD bank destinations.
class BankAddress {
  /// Creates an address.
  const BankAddress(
      {this.line1, this.city, this.state, this.postalCode, this.country});

  /// Decodes an address from the API.
  factory BankAddress.fromJson(Map<String, dynamic> json) => BankAddress(
        line1: _strOrNull(json['line1']),
        city: _strOrNull(json['city']),
        state: _strOrNull(json['state']),
        postalCode: _strOrNull(json['postal_code']),
        country: _strOrNull(json['country']),
      );

  final String? line1;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  /// Encodes the address for a request.
  Map<String, dynamic> toJson() => _compact({
        'line1': line1,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'country': country,
      });
}

/// Registers somewhere to pay out to. Which fields are required depends on
/// the currency and type: a bank code and account number for a local bank, a
/// phone number and provider for mobile money, a wallet address for crypto,
/// and routing details for USD, GBP, EUR and CAD bank routes.
class CreatePayoutDestinationParams {
  /// Creates the request body.
  const CreatePayoutDestinationParams({
    required this.currency,
    this.name,
    this.type,
    this.accountNumber,
    this.bankCode,
    this.accountName,
    this.bankName,
    this.phoneNumber,
    this.mobileProvider,
    this.walletAddress,
    this.network,
    this.sortCode,
    this.iban,
    this.swiftBic,
    this.routingNumber,
    this.bankAddress,
    this.institutionNumber,
    this.transitNumber,
    this.interacEmail,
    this.scheme,
    this.metadata,
  });

  /// For example NGN, USD or USDT_TRC20.
  final String currency;
  final String? name;

  /// Inferred from the other fields when null.
  final DestinationType? type;
  final String? accountNumber;
  final String? bankCode;
  final String? accountName;
  final String? bankName;
  final String? phoneNumber;
  final String? mobileProvider;
  final String? walletAddress;
  final String? network;
  final String? sortCode;
  final String? iban;
  final String? swiftBic;
  final String? routingNumber;
  final BankAddress? bankAddress;
  final String? institutionNumber;
  final String? transitNumber;
  final String? interacEmail;

  /// ach, wire or rtp for USD, and eft, interac_account or interac_email for
  /// CAD.
  final String? scheme;
  final Map<String, dynamic>? metadata;

  /// Encodes the request body.
  Map<String, dynamic> toJson() => _compact({
        'currency': currency,
        'name': name,
        'type': type?.value,
        'account_number': accountNumber,
        'bank_code': bankCode,
        'account_name': accountName,
        'bank_name': bankName,
        'phone_number': phoneNumber,
        'mobile_provider': mobileProvider,
        'wallet_address': walletAddress,
        'network': network,
        'sort_code': sortCode,
        'iban': iban,
        'swift_bic': swiftBic,
        'routing_number': routingNumber,
        'bank_address': bankAddress?.toJson(),
        'institution_number': institutionNumber,
        'transit_number': transitNumber,
        'interac_email': interacEmail,
        'scheme': scheme,
        'metadata': metadata,
      });
}

/// A registered place to pay out to. IDs start with `pd_`.
class PayoutDestination {
  /// Decodes a destination from the API.
  PayoutDestination.fromJson(Map<String, dynamic> json)
      : raw = json,
        id = _str(json['id']),
        name = _str(json['name']),
        type = DestinationType(_str(json['type'])),
        currency = _str(json['currency']),
        status = DestinationStatus(_str(json['status'])),
        statusReason = _str(json['status_reason']),
        isUsable = _bool(json['is_usable']),
        isDefault = _bool(json['is_default']),
        accountNumber = _str(json['account_number']),
        accountName = _str(json['account_name']),
        bankCode = _str(json['bank_code']),
        bankName = _str(json['bank_name']),
        phoneNumber = _str(json['phone_number']),
        mobileProvider = _str(json['mobile_provider']),
        walletAddress = _str(json['wallet_address']),
        network = _str(json['network']),
        sortCode = _str(json['sort_code']),
        iban = _str(json['iban']),
        swiftBic = _str(json['swift_bic']),
        routingNumber = _str(json['routing_number']),
        bankAddress = _obj(json['bank_address'], BankAddress.fromJson),
        institutionNumber = _str(json['institution_number']),
        transitNumber = _str(json['transit_number']),
        interacEmail = _str(json['interac_email']),
        scheme = _str(json['scheme']),
        reviewedAt = _time(json['reviewed_at']),
        createdAt = _time(json['created_at']),
        updatedAt = _time(json['updated_at']);

  /// The full JSON object, including fields this SDK does not type yet.
  final Map<String, dynamic> raw;
  final String id;
  final String name;
  final DestinationType type;
  final String currency;
  final DestinationStatus status;

  /// Set when the destination is rejected.
  final String statusReason;

  /// True only when the destination can receive a payout now.
  final bool isUsable;
  final bool isDefault;
  final String accountNumber;
  final String accountName;
  final String bankCode;
  final String bankName;
  final String phoneNumber;
  final String mobileProvider;
  final String walletAddress;
  final String network;
  final String sortCode;
  final String iban;
  final String swiftBic;
  final String routingNumber;
  final BankAddress? bankAddress;
  final String institutionNumber;
  final String transitNumber;
  final String interacEmail;
  final String scheme;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// One page of payout destinations. Unlike other lists, the results are in
/// [destinations] rather than `items`.
class PayoutDestinationList {
  /// Decodes a page from the API.
  PayoutDestinationList.fromJson(Map<String, dynamic> json)
      : raw = json,
        destinations = _list(
            json['destinations'], (v) => PayoutDestination.fromJson(_map(v))),
        total = _int(json['total']),
        limit = _int(json['limit']),
        offset = _int(json['offset']);

  /// The full JSON object.
  final Map<String, dynamic> raw;
  final List<PayoutDestination> destinations;
  final int total;
  final int limit;
  final int offset;
}

/// Filters a destination list. Destinations page by offset.
class ListPayoutDestinationsParams {
  /// Creates the filter.
  const ListPayoutDestinationsParams(
      {this.currency, this.status, this.limit, this.offset});

  final String? currency;
  final DestinationStatus? status;
  final int? limit;
  final int? offset;

  Map<String, List<String>> _query() => _queryOf({
        'currency': currency,
        'status': status?.value,
        'limit': limit,
        'offset': offset,
      });
}

/// Manages payout destinations.
class PayoutDestinationsService with _PayoutDestinationsServiceGen {
  PayoutDestinationsService._(this._c);

  @override
  final BachsClient _c;

  /// Calls `POST /v1/payouts/destinations`. New destinations start in
  /// pending_review.
  Future<PayoutDestination> create(CreatePayoutDestinationParams params,
          {RequestOptions? options}) =>
      _c._request('POST', '/v1/payouts/destinations',
          (j) => PayoutDestination.fromJson(_map(j)),
          body: params, options: options);

  /// Calls `GET /v1/payouts/destinations/{id}`.
  Future<PayoutDestination> get(String id, {RequestOptions? options}) async {
    final esc = _pathId('destination ID', id);
    return _c._request('GET', '/v1/payouts/destinations/$esc',
        (j) => PayoutDestination.fromJson(_map(j)),
        options: options);
  }

  /// Calls `GET /v1/payouts/destinations`. Returns one page.
  Future<PayoutDestinationList> list(
          {ListPayoutDestinationsParams? params, RequestOptions? options}) =>
      _c._request('GET', '/v1/payouts/destinations',
          (j) => PayoutDestinationList.fromJson(_map(j)),
          query: params?._query(), options: options);

  /// Every matching payout destination.
  Stream<PayoutDestination> listAll(
          {ListPayoutDestinationsParams? params, RequestOptions? options}) =>
      _paginateOffset(
        query: params?._query(),
        offset: params?.offset,
        fetch: (q) => _c._request('GET', '/v1/payouts/destinations',
            (j) => PayoutDestinationList.fromJson(_map(j)),
            query: q, options: options),
        items: (page) => page.destinations,
        hasMore: (page, next, got) =>
            _offsetHasMore(null, next, page.total, got, params?.limit),
      );
}

/// Quotes a cross-currency payout.
class PayoutQuoteParams {
  /// Creates the request body.
  const PayoutQuoteParams({
    required this.fromCurrency,
    required this.toCurrency,
    required this.amount,
    this.payoutMethod,
  });

  /// The balance to debit.
  final String fromCurrency;

  /// The destination's currency.
  final String toCurrency;

  /// In [fromCurrency].
  final String amount;
  final String? payoutMethod;

  /// Encodes the request body.
  Map<String, dynamic> toJson() => _compact({
        'from_currency': fromCurrency,
        'to_currency': toCurrency,
        'amount': amount,
        'payout_method': payoutMethod,
      });
}

/// Locks an exchange rate for a cross-currency payout until it expires.
/// Pass [quoteId] to `payouts.create`.
class PayoutQuote {
  /// Decodes a quote from the API.
  PayoutQuote.fromJson(Map<String, dynamic> json)
      : raw = json,
        quoteId = _str(json['quote_id']),
        fromCurrency = _str(json['from_currency']),
        toCurrency = _str(json['to_currency']),
        fromAmount = _str(json['from_amount']),
        toAmount = _str(json['to_amount']),
        exchangeRate = _str(json['exchange_rate']),
        expiresAt = _time(json['expires_at']);

  /// The full JSON object.
  final Map<String, dynamic> raw;
  final String quoteId;
  final String fromCurrency;
  final String toCurrency;

  /// Debited from your balance, before the withdrawal fee.
  final String fromAmount;

  /// What the destination receives, net of the fee.
  final String toAmount;
  final String exchangeRate;
  final DateTime? expiresAt;
}

/// Creates payout quotes.
class PayoutQuotesService {
  PayoutQuotesService._(this._c);

  final BachsClient _c;

  /// Calls `POST /v1/payouts/quotes`. Quotes a cross-currency payout.
  Future<PayoutQuote> create(PayoutQuoteParams params,
          {RequestOptions? options}) =>
      _c._request(
          'POST', '/v1/payouts/quotes', (j) => PayoutQuote.fromJson(_map(j)),
          body: params, options: options);
}

/// The status of a payout. A payout is pending, processing, completed or
/// failed; the list filter also accepts requested, approved and rejected.
extension type const PayoutStatus(String value) implements String {
  static const pending = PayoutStatus('pending');
  static const processing = PayoutStatus('processing');
  static const completed = PayoutStatus('completed');
  static const failed = PayoutStatus('failed');
  static const requested = PayoutStatus('requested');
  static const approved = PayoutStatus('approved');
  static const rejected = PayoutStatus('rejected');
}

/// Sends money to a payout destination.
class CreatePayoutParams {
  /// Creates the request body.
  const CreatePayoutParams({
    required this.destination,
    this.amount,
    this.quoteId,
    this.reference,
    this.narration,
    this.metadata,
  });

  /// A usable payout destination ID (`pd_...`).
  final String destination;

  /// What the destination receives, in its currency. The fee is charged on
  /// top. Leave it null for a cross-currency payout and set [quoteId]
  /// instead.
  final String? amount;
  final String? quoteId;

  /// Your own ID, up to 128 letters, digits, '.', '-' and '_'. It is unique
  /// per account, and `payouts.list` can filter by it.
  final String? reference;

  /// A short note for the recipient's statement. Keep it under 15
  /// characters.
  final String? narration;
  final Map<String, dynamic>? metadata;

  /// Encodes the request body.
  Map<String, dynamic> toJson() => _compact({
        'destination': destination,
        'amount': amount,
        'quote_id': quoteId,
        'reference': reference,
        'narration': narration,
        'metadata': metadata,
      });
}

/// Money sent to a payout destination.
class Payout {
  /// Decodes a payout from the API.
  Payout.fromJson(Map<String, dynamic> json)
      : raw = json,
        id = _str(json['id']),
        status = PayoutStatus(_str(json['status'])),
        amount = _str(json['amount']),
        currency = _str(json['currency']),
        sourceCurrency = _str(json['source_currency']),
        fee = _str(json['fee']),
        totalDebited = _str(json['total_debited']),
        destination = _str(json['destination']),
        reference = _str(json['reference']),
        narration = _str(json['narration']),
        sessionId = _str(json['session_id']),
        failureReason = _str(json['failure_reason']),
        createdAt = _time(json['created_at']),
        completedAt = _time(json['completed_at']);

  /// The full JSON object, including fields this SDK does not type yet.
  final Map<String, dynamic> raw;
  final String id;
  final PayoutStatus status;

  /// What the destination receives, in [currency].
  final String amount;
  final String currency;
  final String sourceCurrency;

  /// In [sourceCurrency].
  final String fee;

  /// In [sourceCurrency].
  final String totalDebited;
  final String destination;
  final String reference;
  final String narration;

  /// The NIP session ID for a payout to a Nigerian bank.
  final String sessionId;
  final String failureReason;
  final DateTime? createdAt;
  final DateTime? completedAt;
}

/// One page of payouts.
class PayoutList {
  /// Decodes a page from the API.
  PayoutList.fromJson(Map<String, dynamic> json)
      : raw = json,
        items = _list(json['items'], (v) => Payout.fromJson(_map(v))),
        total = _int(json['total']);

  /// The full JSON object.
  final Map<String, dynamic> raw;
  final List<Payout> items;
  final int total;
}

/// Filters a payout list. Payouts page by offset.
class ListPayoutsParams {
  /// Creates the filter.
  const ListPayoutsParams(
      {this.limit, this.offset, this.status, this.reference});

  final int? limit;
  final int? offset;
  final PayoutStatus? status;

  /// Returns only the payout created with this reference.
  final String? reference;

  Map<String, List<String>> _query() => _queryOf({
        'limit': limit,
        'offset': offset,
        'status_filter': status?.value,
        'reference': reference,
      });
}

/// Sends and reads payouts.
class PayoutsService {
  PayoutsService._(this._c);

  final BachsClient _c;

  /// Calls `POST /v1/payouts`. Your balance must cover
  /// [Payout.totalDebited].
  ///
  /// Always pass an idempotency key. The SDK never retries a write; if the
  /// result is uncertain ([BachsException.outcomeUnknown]), look the payout
  /// up by reference before retrying, and retry only with the same key and
  /// request.
  Future<Payout> create(CreatePayoutParams params, {RequestOptions? options}) =>
      _c._request('POST', '/v1/payouts', (j) => Payout.fromJson(_map(j)),
          body: params, options: options);

  /// Calls `GET /v1/payouts/{id}`.
  Future<Payout> get(String id, {RequestOptions? options}) async {
    final esc = _pathId('payout ID', id);
    return _c._request(
        'GET', '/v1/payouts/$esc', (j) => Payout.fromJson(_map(j)),
        options: options);
  }

  /// Calls `GET /v1/payouts`. Returns one page of payouts.
  Future<PayoutList> list(
          {ListPayoutsParams? params, RequestOptions? options}) =>
      _c._request('GET', '/v1/payouts', (j) => PayoutList.fromJson(_map(j)),
          query: params?._query(), options: options);

  /// Every matching payout.
  ///
  /// ```dart
  /// await for (final payout in client.payouts.listAll(
  ///     params: ListPayoutsParams(status: PayoutStatus.failed))) {
  ///   print('${payout.id} ${payout.failureReason}');
  /// }
  /// ```
  Stream<Payout> listAll(
          {ListPayoutsParams? params, RequestOptions? options}) =>
      _paginateOffset(
        query: params?._query(),
        offset: params?.offset,
        fetch: (q) => _c._request(
            'GET', '/v1/payouts', (j) => PayoutList.fromJson(_map(j)),
            query: q, options: options),
        items: (page) => page.items,
        hasMore: (page, next, got) =>
            _offsetHasMore(null, next, page.total, got, params?.limit),
      );
}
