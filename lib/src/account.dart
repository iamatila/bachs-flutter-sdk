part of 'bachs.dart';

/// Opens the hosted customer portal.
class PortalSession {
  /// Decodes a session from the API.
  PortalSession.fromJson(Map<String, dynamic> json)
      : raw = json,
        id = _str(json['id']),
        url = _str(json['url']);

  /// The full JSON object.
  final Map<String, dynamic> raw;

  /// Starts with `psn_`.
  final String id;

  /// Opens the portal as the customer. It carries the session credential, so
  /// don't log it or share it with anyone else.
  final String url;
}

/// Opens customer portal sessions.
class CustomerPortalService {
  CustomerPortalService._(this._c);

  final BachsClient _c;

  /// Calls `POST /v1/customers/{customer_id}/portal-sessions`. Opens a portal
  /// session where the customer can manage their subscriptions, invoices and
  /// cards. Redirect them to the returned URL.
  Future<PortalSession> createSession(String customerId,
      {RequestOptions? options}) async {
    final esc = _pathId('customer ID', customerId);
    return _c._request('POST', '/v1/customers/$esc/portal-sessions',
        (j) => PortalSession.fromJson(_map(j)),
        options: options);
  }
}

/// Your account's balance in every currency.
class Balance {
  /// Decodes a balance from the API.
  Balance.fromJson(Map<String, dynamic> json)
      : raw = json,
        accountId = _str(json['account_id']),
        balances =
            _list(json['balances'], (v) => CurrencyBalance.fromJson(_map(v))),
        totalBalanceUsd = _str(json['total_balance_usd']),
        pendingSettlementsByDay =
            _list(json['pending_settlements_by_day'], _map);

  /// The full JSON object.
  final Map<String, dynamic> raw;
  final String accountId;
  final List<CurrencyBalance> balances;
  final String totalBalanceUsd;
  final List<Map<String, dynamic>> pendingSettlementsByDay;
}

/// The balance held in one currency.
class CurrencyBalance {
  /// Decodes a balance from the API.
  CurrencyBalance.fromJson(Map<String, dynamic> json)
      : currency = _str(json['currency']),
        availableBalance = _str(json['available_balance']),
        pendingBalance = _str(json['pending_balance']);

  final String currency;
  final String availableBalance;
  final String pendingBalance;
}

/// Reads balances and the payout schedule.
class BalancesService with _BalancesServiceGen {
  BalancesService._(this._c);

  @override
  final BachsClient _c;

  /// Calls `GET /v1/balances`. Retrieves your balances.
  Future<Balance> get({RequestOptions? options}) =>
      _c._request('GET', '/v1/balances', (j) => Balance.fromJson(_map(j)),
          options: options);
}

/// A bank you can pay out to.
class Bank {
  /// Decodes a bank from the API.
  Bank.fromJson(Map<String, dynamic> json)
      : name = _str(json['name']),
        code = _str(json['code']);

  final String name;

  /// What to send as `bank_code`.
  final String code;
}

/// The banks available in one country.
class BankList {
  /// Decodes the list from the API.
  BankList.fromJson(Map<String, dynamic> json)
      : raw = json,
        country = _str(json['country']),
        banks = _list(json['banks'], (v) => Bank.fromJson(_map(v)));

  /// The full JSON object.
  final Map<String, dynamic> raw;
  final String country;
  final List<Bank> banks;
}

/// Picks the country. With no country, the API uses your own platform's
/// country.
class ListBanksParams {
  /// Creates the filter.
  const ListBanksParams({this.country});

  /// A two-letter ISO 3166-1 code.
  final String? country;

  Map<String, List<String>> _query() => _queryOf({'country': country});
}

/// Looks up the name on a bank account.
class ResolveBankAccountParams {
  /// Creates the request body.
  const ResolveBankAccountParams(
      {required this.accountNumber, required this.bankCode, this.country});

  /// Digits only, exactly as the account holder typed it.
  final String accountNumber;

  /// [Bank.code] from `banks.list`.
  final String bankCode;

  /// Optional and two letters.
  final String? country;

  /// Encodes the request body.
  Map<String, dynamic> toJson() => _compact({
        'account_number': accountNumber,
        'bank_code': bankCode,
        'country': country,
      });
}

/// The result of a bank account lookup.
class BankAccountResolution {
  /// Decodes the result from the API.
  BankAccountResolution.fromJson(Map<String, dynamic> json)
      : raw = json,
        resolved = _bool(json['resolved']),
        accountName = _str(json['account_name']),
        accountNumber = _str(json['account_number']),
        message = _str(json['message']);

  /// The full JSON object.
  final Map<String, dynamic> raw;

  /// False for a wrong number, an unsupported country or bank, or a lookup
  /// failure. [message] says why.
  final bool resolved;

  /// The registered name. Show it to the account holder to confirm before
  /// you create a payout destination.
  final String accountName;
  final String accountNumber;
  final String message;
}

/// Lists banks and resolves bank accounts.
class BanksService {
  BanksService._(this._c);

  final BachsClient _c;

  /// Calls `GET /v1/reference/banks`. Returns the banks you can pay out to in
  /// a country.
  Future<BankList> list({ListBanksParams? params, RequestOptions? options}) =>
      _c._request(
          'GET', '/v1/reference/banks', (j) => BankList.fromJson(_map(j)),
          query: params?._query(), options: options);

  /// Calls `POST /v1/misc/bank-accounts/resolve`. Looks up the account name
  /// for an account number.
  Future<BankAccountResolution> resolveAccount(ResolveBankAccountParams params,
          {RequestOptions? options}) =>
      _c._request('POST', '/v1/misc/bank-accounts/resolve',
          (j) => BankAccountResolution.fromJson(_map(j)),
          body: params, options: options);
}
