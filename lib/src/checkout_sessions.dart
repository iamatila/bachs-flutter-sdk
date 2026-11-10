part of 'bachs.dart';

/// The lifecycle status of a checkout session.
extension type const CheckoutSessionStatus(String value) implements String {
  static const open = CheckoutSessionStatus('open');
  static const completed = CheckoutSessionStatus('completed');
  static const expired = CheckoutSessionStatus('expired');
  static const cancelled = CheckoutSessionStatus('cancelled');
}

/// Whether a buyer who identifies themselves on the hosted page becomes a
/// customer record.
extension type const CustomerCreation(String value) implements String {
  static const always = CustomerCreation('always');
  static const ifRequired = CustomerCreation('if_required');
}

/// Creates a checkout session. Set exactly one of [productCart] or
/// [pricing].
///
/// Completing a checkout whose cart holds a recurring product is how a
/// subscription is created; there is no direct create-subscription call.
class CreateCheckoutSessionParams {
  /// Creates the request body.
  const CreateCheckoutSessionParams({
    this.productCart,
    this.pricing,
    this.customer,
    this.successUrl,
    this.cancelUrl,
    this.metadata,
    this.reference,
    this.billingCurrency,
    this.paymentMethodTypes,
    this.platformFee,
    this.transferData,
    this.expiresInMinutes,
    this.customerCreation,
    this.savePaymentMethod,
  });

  /// 1 to 20 catalog products.
  final List<CartItem>? productCart;

  /// A raw amount for a checkout with no catalog product.
  final CheckoutPricing? pricing;

  /// Optional for a one-time checkout and required for a recurring one.
  final CheckoutCustomerParams? customer;

  /// Where the customer lands after paying. Bachs appends
  /// `?checkout_id=<id>`. Don't fulfil orders from this redirect; wait for
  /// the webhook.
  final String? successUrl;

  /// Where the customer goes if they cancel or abandon.
  final String? cancelUrl;

  /// Up to 20 keys and 10KB in total.
  final Map<String, dynamic>? metadata;

  /// Your own ID for the session, up to 128 characters and unique per
  /// account.
  final String? reference;

  /// Defaults to the product's pricing currency.
  final String? billingCurrency;

  /// Restricts the offered methods, such as `USD_CARD` or `MOMO_KES`.
  final List<String>? paymentMethodTypes;

  /// The platform's cut of the sale. It cannot be combined with
  /// [TransferData.amount].
  final String? platformFee;

  /// Makes this a destination charge to a connected account.
  final TransferData? transferData;

  /// 1 to 1440. The API default is 60.
  final int? expiresInMinutes;

  /// Applies only when [customer] is null. The API default is if_required.
  final CustomerCreation? customerCreation;

  /// Saves the card so you can charge it later.
  final bool? savePaymentMethod;

  /// Encodes the request body.
  Map<String, dynamic> toJson() => _compact({
        'product_cart': productCart?.map((i) => i.toJson()).toList(),
        'pricing': pricing?.toJson(),
        'customer': customer?.toJson(),
        'success_url': successUrl,
        'cancel_url': cancelUrl,
        'metadata': metadata,
        'reference': reference,
        'billing_currency': billingCurrency,
        'payment_method_types': paymentMethodTypes,
        'platform_fee': platformFee,
        'transfer_data': transferData?.toJson(),
        'expires_in_minutes': expiresInMinutes,
        'customer_creation': customerCreation?.value,
        'save_payment_method': savePaymentMethod,
      });
}

/// One catalog product in a checkout.
class CartItem {
  /// Creates a cart item.
  const CartItem(
      {required this.productId, this.quantity, this.amount, this.pricing});

  final String productId;

  /// Defaults to 1.
  final int? quantity;

  /// The chosen amount for a pay-what-you-want price.
  final String? amount;

  /// Overrides the price for this item only.
  final AdhocPrice? pricing;

  /// Encodes the item for a request.
  Map<String, dynamic> toJson() => _compact({
        'product_id': productId,
        'quantity': quantity,
        'amount': amount,
        'pricing': pricing?.toJson(),
      });
}

/// A one-off price for a single cart item.
class AdhocPrice {
  /// Creates a price.
  const AdhocPrice({
    this.priceType,
    this.amount,
    this.presetAmount,
    this.minimumAmount,
    this.maximumAmount,
  });

  final PriceType? priceType;
  final String? amount;
  final String? presetAmount;
  final String? minimumAmount;
  final String? maximumAmount;

  /// Encodes the price for a request.
  Map<String, dynamic> toJson() => _compact({
        'price_type': priceType?.value,
        'amount': amount,
        'preset_amount': presetAmount,
        'minimum_amount': minimumAmount,
        'maximum_amount': maximumAmount,
      });
}

/// The price for a checkout with no catalog product.
class CheckoutPricing {
  /// Creates a price.
  const CheckoutPricing({
    required this.currency,
    this.amount,
    this.priceType,
    this.presetAmount,
    this.minimumAmount,
    this.maximumAmount,
    this.currencyOptions,
  });

  /// For example USD or NGN.
  final String currency;

  /// Required for a fixed price.
  final String? amount;
  final PriceType? priceType;
  final String? presetAmount;
  final String? minimumAmount;
  final String? maximumAmount;

  /// Maps extra currency codes to decimal amounts.
  final Map<String, String>? currencyOptions;

  /// Encodes the price for a request.
  Map<String, dynamic> toJson() => _compact({
        'currency': currency,
        'amount': amount,
        'price_type': priceType?.value,
        'preset_amount': presetAmount,
        'minimum_amount': minimumAmount,
        'maximum_amount': maximumAmount,
        'currency_options': currencyOptions,
      });
}

/// Names the customer for a checkout. Set [customerId] for an existing
/// customer, or [email] (with optional [name] and [phoneNumber]) for a new
/// one.
class CheckoutCustomerParams {
  /// Creates the customer details.
  const CheckoutCustomerParams(
      {this.customerId, this.email, this.name, this.phoneNumber});

  final String? customerId;
  final String? email;
  final String? name;
  final String? phoneNumber;

  /// Encodes the customer for a request.
  Map<String, dynamic> toJson() => _compact({
        'customer_id': customerId,
        'email': email,
        'name': name,
        'phone_number': phoneNumber,
      });
}

/// Sends a sale to a connected account.
class TransferData {
  /// Creates transfer data.
  const TransferData({required this.destination, this.amount});

  /// Decodes transfer data from the API.
  factory TransferData.fromJson(Map<String, dynamic> json) => TransferData(
        destination: _str(json['destination']),
        amount: _strOrNull(json['amount']),
      );

  final String destination;

  /// What the destination receives. It cannot be combined with a platform
  /// fee.
  final String? amount;

  /// Encodes the transfer data for a request.
  Map<String, dynamic> toJson() =>
      _compact({'destination': destination, 'amount': amount});
}

/// A hosted checkout.
///
/// `create` returns the subset of fields the API sends on creation,
/// including [checkoutUrl]. `get` returns the full session, including
/// [charge] once payment has been attempted.
class CheckoutSession {
  /// Decodes a session from the API.
  CheckoutSession.fromJson(Map<String, dynamic> json)
      : raw = json,
        checkoutId = _str(json['checkout_id']),
        checkoutUrl = _str(json['checkout_url']),
        status = CheckoutSessionStatus(_str(json['status'])),
        paymentStatus = _str(json['payment_status']),
        recurring = _obj(json['recurring'], CheckoutRecurring.fromJson),
        sourceType = _str(json['source_type']),
        amount = _str(json['amount']),
        currency = _str(json['currency']),
        reference = _str(json['reference']),
        charge = _obj(json['charge'], Payment.fromJson),
        paymentMethod = _str(json['payment_method']),
        customer = _obj(json['customer'], CheckoutCustomer.fromJson),
        customerDetails =
            _obj(json['customer_details'], CheckoutCustomerDetails.fromJson),
        successUrl = _str(json['success_url']),
        cancelUrl = _str(json['cancel_url']),
        products =
            _list(json['products'], (v) => ResolvedProduct.fromJson(_map(v))),
        billingCurrency = _str(json['billing_currency']),
        platformFee = _str(json['platform_fee']),
        destinationAmount = _str(json['destination_amount']),
        sessionMode = _str(json['session_mode']),
        metadata = _mapOrNull(json['metadata']),
        createdAt = _time(json['created_at']),
        updatedAt = _time(json['updated_at']),
        expiresAt = _time(json['expires_at']),
        completedAt = _time(json['completed_at']);

  /// The full JSON object, including fields this SDK does not type yet.
  final Map<String, dynamic> raw;
  final String checkoutId;

  /// Where to send the customer. It is returned by `create`.
  final String checkoutUrl;
  final CheckoutSessionStatus status;
  final String paymentStatus;

  /// Set only for a subscription checkout.
  final CheckoutRecurring? recurring;
  final String sourceType;
  final String amount;
  final String currency;
  final String reference;
  final Payment? charge;
  final String paymentMethod;
  final CheckoutCustomer? customer;
  final CheckoutCustomerDetails? customerDetails;
  final String successUrl;
  final String cancelUrl;
  final List<ResolvedProduct> products;
  final String billingCurrency;
  final String platformFee;
  final String destinationAmount;
  final String sessionMode;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final DateTime? completedAt;
}

/// The billing interval of a subscription checkout.
class CheckoutRecurring {
  /// Decodes the interval from the API.
  CheckoutRecurring.fromJson(Map<String, dynamic> json)
      : interval = Interval(_str(json['interval'])),
        intervalCount = _int(json['interval_count']);

  final Interval interval;
  final int intervalCount;
}

/// The customer a checkout resolved to.
class CheckoutCustomer {
  /// Decodes the customer from the API.
  CheckoutCustomer.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        email = _str(json['email']),
        name = _str(json['name']);

  final String id;
  final String email;
  final String name;
}

/// What the buyer typed on the hosted page.
class CheckoutCustomerDetails {
  /// Decodes the details from the API.
  CheckoutCustomerDetails.fromJson(Map<String, dynamic> json)
      : email = _str(json['email']),
        name = _str(json['name']);

  final String email;
  final String name;
}

/// One product line in a checkout.
class ResolvedProduct {
  /// Decodes the line from the API.
  ResolvedProduct.fromJson(Map<String, dynamic> json)
      : productId = _str(json['product_id']),
        productName = _str(json['product_name']),
        quantity = _int(json['quantity']),
        unitAmount = _str(json['unit_amount']),
        currency = _str(json['currency']),
        priceType = PriceType(_str(json['price_type'])),
        minimumAmount = _str(json['minimum_amount']),
        maximumAmount = _str(json['maximum_amount']),
        lineTotal = _str(json['line_total']);

  final String productId;
  final String productName;
  final int quantity;
  final String unitAmount;
  final String currency;
  final PriceType priceType;
  final String minimumAmount;
  final String maximumAmount;
  final String lineTotal;
}

/// Manages checkout sessions.
class CheckoutSessionsService {
  CheckoutSessionsService._(this._c);

  final BachsClient _c;

  /// Calls `POST /v1/checkout-sessions`. Redirect the customer to
  /// [CheckoutSession.checkoutUrl], and confirm payment from the
  /// `collection.succeeded` webhook, not from the redirect.
  Future<CheckoutSession> create(CreateCheckoutSessionParams params,
      {RequestOptions? options}) async {
    final hasCart = params.productCart?.isNotEmpty ?? false;
    if (hasCart == (params.pricing != null)) {
      throw const BachsConfigException(
          'set exactly one of productCart or pricing');
    }
    return _c._request('POST', '/v1/checkout-sessions',
        (j) => CheckoutSession.fromJson(_map(j)),
        body: params, options: options);
  }

  /// Calls `GET /v1/checkout-sessions/{checkout_id}`. Retrieves a checkout
  /// session by the checkout ID returned from [create].
  Future<CheckoutSession> get(String checkoutId,
      {RequestOptions? options}) async {
    final esc = _pathId('checkout ID', checkoutId);
    return _c._request('GET', '/v1/checkout-sessions/$esc',
        (j) => CheckoutSession.fromJson(_map(j)),
        options: options);
  }
}
