part of 'bachs.dart';

/// The status of a subscription. Bachs sets it as payments succeed or fail.
extension type const SubscriptionStatus(String value) implements String {
  static const trialing = SubscriptionStatus('trialing');
  static const active = SubscriptionStatus('active');
  static const pastDue = SubscriptionStatus('past_due');
  static const unpaid = SubscriptionStatus('unpaid');
  static const canceled = SubscriptionStatus('canceled');
  static const paused = SubscriptionStatus('paused');
}

/// A recurring billing agreement. IDs start with `sub_`.
///
/// Subscriptions are created by completing a checkout session for a
/// recurring product. There is no direct create call.
class Subscription {
  /// Decodes a subscription from the API.
  Subscription.fromJson(Map<String, dynamic> json)
      : raw = json,
        id = _str(json['id']),
        customer = _obj(json['customer'], Customer.fromJson),
        paymentMethodId = _str(json['payment_method_id']),
        status = SubscriptionStatus(_str(json['status'])),
        collectionMethod = _str(json['collection_method']),
        currency = _str(json['currency']),
        amount = _str(json['amount']),
        billingCycle = _obj(json['billing_cycle'], Cadence.fromJson),
        quantity = _int(json['quantity']),
        seats = _intOrNull(json['seats']),
        currentPeriodStart = _time(json['current_period_start']),
        currentPeriodEnd = _time(json['current_period_end']),
        previouslyBilledAt = _time(json['previously_billed_at']),
        nextBilledAt = _time(json['next_billed_at']),
        trialEnd = _time(json['trial_end']),
        cancelAtPeriodEnd = _bool(json['cancel_at_period_end']),
        canceledAt = _time(json['canceled_at']),
        createdAt = _time(json['created_at']),
        product = _obj(json['product'], SubscriptionProduct.fromJson),
        items = _list(json['items'], (v) => SubscriptionItem.fromJson(_map(v))),
        metadata = _mapOrNull(json['metadata']);

  /// The full JSON object, including fields this SDK does not type yet.
  final Map<String, dynamic> raw;
  final String id;
  final Customer? customer;
  final String paymentMethodId;
  final SubscriptionStatus status;
  final String collectionMethod;
  final String currency;

  /// The recurring amount as a decimal string.
  final String amount;
  final Cadence? billingCycle;
  final int quantity;
  final int? seats;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? previouslyBilledAt;
  final DateTime? nextBilledAt;
  final DateTime? trialEnd;
  final bool cancelAtPeriodEnd;
  final DateTime? canceledAt;
  final DateTime? createdAt;
  final SubscriptionProduct? product;
  final List<SubscriptionItem> items;
  final Map<String, dynamic>? metadata;
}

/// A customer record. IDs start with `cust_`.
class Customer {
  /// Decodes a customer from the API.
  Customer.fromJson(Map<String, dynamic> json)
      : raw = json,
        customerId = _str(json['customer_id']),
        email = _str(json['email']),
        name = _str(json['name']),
        phoneNumber = _str(json['phone_number']),
        metadata = _mapOrNull(json['metadata']),
        createdAt = _time(json['created_at']),
        updatedAt = _time(json['updated_at']),
        billingAddress = _obj(json['billing_address'], Address.fromJson);

  /// The full JSON object, including fields this SDK does not type yet.
  final Map<String, dynamic> raw;
  final String customerId;
  final String email;
  final String name;
  final String phoneNumber;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Address? billingAddress;
}

/// The catalog product a subscription bills for.
class SubscriptionProduct {
  /// Decodes the product from the API.
  SubscriptionProduct.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        name = _str(json['name']),
        description = _str(json['description']),
        status = _str(json['status']),
        billingCycle = _obj(json['billing_cycle'], Cadence.fromJson),
        trialPeriod = _obj(json['trial_period'], Cadence.fromJson),
        createdAt = _time(json['created_at']),
        updatedAt = _time(json['updated_at']);

  final String id;
  final String name;
  final String description;
  final String status;
  final Cadence? billingCycle;
  final Cadence? trialPeriod;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// One line item of a subscription.
class SubscriptionItem {
  /// Decodes the item from the API.
  SubscriptionItem.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        status = _str(json['status']),
        quantity = _int(json['quantity']),
        seats = _int(json['seats']),
        recurring = _bool(json['recurring']),
        priceType = PriceType(_str(json['price_type'])),
        unitAmount = _str(json['unit_amount']),
        currency = _str(json['currency']),
        previouslyBilledAt = _time(json['previously_billed_at']),
        nextBilledAt = _time(json['next_billed_at']),
        price = _obj(json['price'], SubscriptionPrice.fromJson),
        product = _obj(json['product'], SubscriptionProduct.fromJson),
        createdAt = _time(json['created_at']),
        updatedAt = _time(json['updated_at']);

  final String id;
  final String status;
  final int quantity;
  final int seats;
  final bool recurring;
  final PriceType priceType;
  final String unitAmount;
  final String currency;
  final DateTime? previouslyBilledAt;
  final DateTime? nextBilledAt;
  final SubscriptionPrice? price;
  final SubscriptionProduct? product;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// The price a subscription item bills at.
class SubscriptionPrice {
  /// Decodes the price from the API.
  SubscriptionPrice.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        productId = _str(json['product_id']),
        priceType = PriceType(_str(json['price_type'])),
        currency = _str(json['currency']),
        unitAmount = _str(json['unit_amount']),
        billingCycle = _obj(json['billing_cycle'], Cadence.fromJson),
        trialPeriod = _obj(json['trial_period'], Cadence.fromJson),
        seatTiers = json['seat_tiers'],
        isArchived = _bool(json['is_archived']),
        createdAt = _time(json['created_at']),
        updatedAt = _time(json['updated_at']);

  final String id;
  final String productId;
  final PriceType priceType;
  final String currency;
  final String unitAmount;
  final Cadence? billingCycle;
  final Cadence? trialPeriod;

  /// The decoded JSON value; the API does not document its shape.
  final Object? seatTiers;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// One page of subscriptions, newest first.
class SubscriptionList {
  /// Decodes a page from the API.
  SubscriptionList.fromJson(Map<String, dynamic> json)
      : raw = json,
        items = _list(json['items'], (v) => Subscription.fromJson(_map(v))),
        pagination = Pagination.fromJson(_map(json['pagination']));

  /// The full JSON object.
  final Map<String, dynamic> raw;
  final List<Subscription> items;
  final Pagination pagination;
}

/// Filters a subscription list. Subscriptions page by offset.
class ListSubscriptionsParams {
  /// Creates the filter.
  const ListSubscriptionsParams(
      {this.limit, this.offset, this.customerId, this.status});

  final int? limit;
  final int? offset;
  final String? customerId;
  final SubscriptionStatus? status;

  Map<String, List<String>> _query() => _queryOf({
        'limit': limit,
        'offset': offset,
        'customer_id': customerId,
        'status': status?.value,
      });
}

/// Controls how a subscription ends.
class CancelSubscriptionParams {
  /// Creates the options.
  const CancelSubscriptionParams({this.cancelAtPeriodEnd, this.reason});

  /// Keeps the subscription active until `current_period_end` when true, and
  /// ends it immediately when false. It defaults to true when null.
  final bool? cancelAtPeriodEnd;

  /// An optional note of up to 255 characters.
  final String? reason;

  /// Encodes the request body.
  Map<String, dynamic> toJson() => _compact({
        'cancel_at_period_end': cancelAtPeriodEnd ?? true,
        'reason': reason,
      });
}

/// Reads, updates and cancels subscriptions.
class SubscriptionsService with _SubscriptionsServiceGen {
  SubscriptionsService._(this._c);

  @override
  final BachsClient _c;

  /// Calls `GET /v1/subscriptions/{id}`. Retrieves a subscription.
  Future<Subscription> get(String id, {RequestOptions? options}) async {
    final esc = _pathId('subscription ID', id);
    return _c._request(
        'GET', '/v1/subscriptions/$esc', (j) => Subscription.fromJson(_map(j)),
        options: options);
  }

  /// Calls `GET /v1/subscriptions`. Returns one page of subscriptions.
  Future<SubscriptionList> list(
          {ListSubscriptionsParams? params, RequestOptions? options}) =>
      _c._request(
          'GET', '/v1/subscriptions', (j) => SubscriptionList.fromJson(_map(j)),
          query: params?._query(), options: options);

  /// Every matching subscription, fetching pages as you consume them.
  Stream<Subscription> listAll(
          {ListSubscriptionsParams? params, RequestOptions? options}) =>
      _paginateOffset(
        query: params?._query(),
        offset: params?.offset,
        fetch: (q) => _c._request('GET', '/v1/subscriptions',
            (j) => SubscriptionList.fromJson(_map(j)),
            query: q, options: options),
        items: (page) => page.items,
        hasMore: (page, next, got) =>
            _offsetHasMore(page.pagination, next, 0, got, params?.limit),
      );

  /// Calls `DELETE /v1/subscriptions/{id}`. With no [params] it cancels at
  /// the end of the current period.
  Future<Subscription> cancel(String id,
      {CancelSubscriptionParams? params, RequestOptions? options}) async {
    final esc = _pathId('subscription ID', id);
    return _c._request('DELETE', '/v1/subscriptions/$esc',
        (j) => Subscription.fromJson(_map(j)),
        body: params ?? const CancelSubscriptionParams(), options: options);
  }
}
