part of 'bachs.dart';

/// The status of a payment.
extension type const PaymentStatus(String value) implements String {
  static const created = PaymentStatus('created');
  static const processing = PaymentStatus('processing');
  static const succeeded = PaymentStatus('succeeded');
  static const accepted = PaymentStatus('accepted');
  static const failed = PaymentStatus('failed');
  static const expired = PaymentStatus('expired');
  static const cancelled = PaymentStatus('cancelled');
  static const refunded = PaymentStatus('refunded');
  static const partiallyRefunded = PaymentStatus('partially_refunded');
  static const autoRefunded = PaymentStatus('auto_refunded');
  static const underpaid = PaymentStatus('underpaid');
  static const overpaid = PaymentStatus('overpaid');
}

/// A single payment (a charge), as returned by `get` and embedded in a
/// checkout session.
class Payment {
  /// Decodes a payment from the API.
  Payment.fromJson(Map<String, dynamic> json)
      : raw = json,
        paymentId = _str(json['payment_id']),
        reference = _str(json['reference']),
        billingReason = _str(json['billing_reason']),
        checkoutId = _str(json['checkout_id']),
        status = PaymentStatus(_str(json['status'])),
        isRefundable = _boolOrNull(json['is_refundable']),
        amount = _str(json['amount']),
        amountPaid = _str(json['amount_paid']),
        amountRemaining = _str(json['amount_remaining']),
        currency = _str(json['currency']),
        feeUsd = _str(json['fee_usd']),
        fees = json['fees'] == null ? null : Fee.fromJson(json['fees']),
        merchantBearsCost = _boolOrNull(json['merchant_bears_cost']),
        platformFee = _str(json['platform_fee']),
        destinationAmount = _str(json['destination_amount']),
        feePaidBy = _str(json['fee_paid_by']),
        paymentMethod = _str(json['payment_method']),
        channel = _str(json['channel']),
        narration = _str(json['narration']),
        meta = _mapOrNull(json['meta']),
        message = _str(json['message']),
        customer = _obj(json['customer'], PaymentCustomer.fromJson),
        lineItems =
            _list(json['line_items'], (v) => LineItem.fromJson(_map(v))),
        subscriptionId = _str(json['subscription_id']),
        invoice = _obj(json['invoice'], PaymentInvoice.fromJson),
        refunds = _list(json['refunds'], _str),
        statusHistory = _list(json['status_history'],
            (v) => PaymentStatusEntry.fromJson(_map(v))),
        paymentMethodDetails = _mapOrNull(json['payment_method_details']),
        createdAt = _time(json['created_at']),
        updatedAt = _time(json['updated_at']),
        completedAt = _time(json['completed_at']);

  /// The full JSON object, including fields this SDK does not type yet.
  final Map<String, dynamic> raw;
  final String paymentId;
  final String reference;

  /// purchase, subscription_create, subscription_cycle or
  /// subscription_update.
  final String billingReason;
  final String checkoutId;
  final PaymentStatus status;
  final bool? isRefundable;

  /// What the payment was created for.
  final String amount;

  /// What actually arrived. Compare it with [amount] before fulfilling a
  /// bank-transfer payment.
  final String amountPaid;
  final String amountRemaining;
  final String currency;
  final String feeUsd;
  final Fee? fees;
  final bool? merchantBearsCost;
  final String platformFee;
  final String destinationAmount;
  final String feePaidBy;
  final String paymentMethod;
  final String channel;
  final String narration;
  final Map<String, dynamic>? meta;
  final String message;
  final PaymentCustomer? customer;
  final List<LineItem> lineItems;
  final String subscriptionId;
  final PaymentInvoice? invoice;
  final List<String> refunds;
  final List<PaymentStatusEntry> statusHistory;
  final Map<String, dynamic>? paymentMethodDetails;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
}

/// The customer captured on a payment.
class PaymentCustomer {
  /// Decodes the customer from the API.
  PaymentCustomer.fromJson(Map<String, dynamic> json)
      : name = _str(json['name']),
        email = _str(json['email']);

  final String name;
  final String email;
}

/// One product a payment covers.
class LineItem {
  /// Decodes a line item from the API.
  LineItem.fromJson(Map<String, dynamic> json)
      : productId = _str(json['product_id']),
        productName = _str(json['product_name']),
        quantity = _int(json['quantity']),
        unitAmount = _str(json['unit_amount']),
        currency = _str(json['currency']),
        lineTotal = _str(json['line_total']);

  final String productId;
  final String productName;
  final int quantity;
  final String unitAmount;
  final String currency;
  final String lineTotal;
}

/// The invoice a subscription payment collected.
class PaymentInvoice {
  /// Decodes the invoice from the API.
  PaymentInvoice.fromJson(Map<String, dynamic> json)
      : invoiceId = _str(json['invoice_id']),
        number = _str(json['number']),
        subscriptionId = _str(json['subscription_id']),
        periodStart = _time(json['period_start']),
        periodEnd = _time(json['period_end']),
        kind = _str(json['kind']);

  final String invoiceId;
  final String number;
  final String subscriptionId;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  /// cycle or proration.
  final String kind;
}

/// One change in a payment's status history.
class PaymentStatusEntry {
  /// Decodes the entry from the API.
  PaymentStatusEntry.fromJson(Map<String, dynamic> json)
      : status = _str(json['status']),
        occurredAt = _time(json['occurred_at']),
        reason = _str(json['reason']);

  final String status;
  final DateTime? occurredAt;
  final String reason;
}

/// A payment as it appears in a list. The list shape differs from the
/// single-payment shape returned by `get`.
class PaymentSummary {
  /// Decodes the summary from the API.
  PaymentSummary.fromJson(Map<String, dynamic> json)
      : raw = json,
        id = _str(json['id']),
        reference = _str(json['reference']),
        status = PaymentStatus(_str(json['status'])),
        isRefundable = _boolOrNull(json['is_refundable']),
        amount = _str(json['amount']),
        amountPaid = _str(json['amount_paid']),
        amountRemaining = _str(json['amount_remaining']),
        currency = _str(json['currency']),
        customerName = _str(json['customer_name']),
        customerEmail = _str(json['customer_email']),
        settlementAmount = _str(json['settlement_amount']),
        settlementCurrency = _str(json['settlement_currency']),
        fee = _str(json['fee']),
        vat = _str(json['vat']),
        meta = _mapOrNull(json['meta']),
        transactionDate = _time(json['transaction_date']),
        completedAt = _time(json['completed_at']),
        platformFee = _str(json['platform_fee']),
        destinationAmount = _str(json['destination_amount']),
        paymentMethod =
            _obj(json['payment_method'], PaymentMethodSummary.fromJson),
        source = _obj(json['source'], PaymentSource.fromJson),
        description = _str(json['description']),
        feePaidBy = _str(json['fee_paid_by']);

  /// The full JSON object.
  final Map<String, dynamic> raw;
  final String id;
  final String reference;
  final PaymentStatus status;
  final bool? isRefundable;
  final String amount;
  final String amountPaid;
  final String amountRemaining;
  final String currency;
  final String customerName;
  final String customerEmail;
  final String settlementAmount;
  final String settlementCurrency;
  final String fee;
  final String vat;
  final Map<String, dynamic>? meta;
  final DateTime? transactionDate;
  final DateTime? completedAt;
  final String platformFee;
  final String destinationAmount;
  final PaymentMethodSummary? paymentMethod;
  final PaymentSource? source;
  final String description;
  final String feePaidBy;
}

/// How a listed payment was made.
class PaymentMethodSummary {
  /// Decodes the method from the API.
  PaymentMethodSummary.fromJson(Map<String, dynamic> json)
      : type = _str(json['type']),
        brand = _str(json['brand']),
        last4 = _str(json['last4']);

  final String type;
  final String brand;
  final String last4;
}

/// Where a listed payment came from.
class PaymentSource {
  /// Decodes the source from the API.
  PaymentSource.fromJson(Map<String, dynamic> json)
      : type = _str(json['type']),
        checkoutId = _str(json['checkout_id']),
        reference = _str(json['reference']);

  final String type;
  final String checkoutId;
  final String reference;
}

/// One page of payments.
class PaymentList {
  /// Decodes a page from the API.
  PaymentList.fromJson(Map<String, dynamic> json)
      : raw = json,
        items = _list(json['items'], (v) => PaymentSummary.fromJson(_map(v))),
        pagination = Pagination.fromJson(_map(json['pagination']));

  /// The full JSON object.
  final Map<String, dynamic> raw;
  final List<PaymentSummary> items;
  final Pagination pagination;
}

/// Filters a payment list. Payments page by offset.
class ListPaymentsParams {
  /// Creates the filter.
  const ListPaymentsParams({this.limit, this.offset, this.status});

  /// The page size. The API default is 50 and the maximum 100.
  final int? limit;
  final int? offset;
  final PaymentStatus? status;

  Map<String, List<String>> _query() => _queryOf({
        'limit': limit,
        'offset': offset,
        'status_filter': status?.value,
      });
}

/// Reads payments.
class PaymentsService with _PaymentsServiceGen {
  PaymentsService._(this._c);

  @override
  final BachsClient _c;

  /// Calls `GET /v1/payments/{payment_id}`. Retrieves a payment by its
  /// charge ID.
  Future<Payment> get(String paymentId, {RequestOptions? options}) async {
    final esc = _pathId('payment ID', paymentId);
    return _c._request(
        'GET', '/v1/payments/$esc', (j) => Payment.fromJson(_map(j)),
        options: options);
  }

  /// Calls `GET /v1/payments`. Returns one page of payments.
  Future<PaymentList> list(
          {ListPaymentsParams? params, RequestOptions? options}) =>
      _c._request('GET', '/v1/payments', (j) => PaymentList.fromJson(_map(j)),
          query: params?._query(), options: options);

  /// Every matching payment, fetching pages as you consume them.
  /// [ListPaymentsParams.limit] sets the page size, and
  /// [ListPaymentsParams.offset] is where it starts.
  Stream<PaymentSummary> listAll(
          {ListPaymentsParams? params, RequestOptions? options}) =>
      _paginateOffset(
        query: params?._query(),
        offset: params?.offset,
        fetch: (q) => _c._request(
            'GET', '/v1/payments', (j) => PaymentList.fromJson(_map(j)),
            query: q, options: options),
        items: (page) => page.items,
        hasMore: (page, next, got) =>
            _offsetHasMore(page.pagination, next, 0, got, params?.limit),
      );
}
