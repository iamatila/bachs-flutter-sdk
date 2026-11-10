part of 'bachs.dart';

/// The lifecycle status of a product.
extension type const ProductStatus(String value) implements String {
  static const active = ProductStatus('active');
  static const archived = ProductStatus('archived');
}

/// A product's price when creating it.
///
/// For a fixed price set [amount]. For a free price set [priceType] to
/// [PriceType.free] and leave the amounts empty. For a custom price set
/// [priceType] to [PriceType.custom] and use the preset, minimum and maximum
/// amounts.
class PriceInput {
  /// Creates a price.
  const PriceInput({
    required this.currency,
    this.priceType,
    this.amount,
    this.presetAmount,
    this.minimumAmount,
    this.maximumAmount,
    this.currencyOptions,
  });

  /// USD, NGN, GHS, KES, MWK, RWF, TZS, UGX, XAF, XOF or ZMW.
  final String currency;
  final PriceType? priceType;
  final String? amount;
  final String? presetAmount;
  final String? minimumAmount;
  final String? maximumAmount;
  final List<CurrencyOptionInput>? currencyOptions;

  /// Encodes the price for a request.
  Map<String, dynamic> toJson() => _compact({
        'currency': currency,
        'price_type': priceType?.value,
        'amount': amount,
        'preset_amount': presetAmount,
        'minimum_amount': minimumAmount,
        'maximum_amount': maximumAmount,
        'currency_options': currencyOptions?.map((o) => o.toJson()).toList(),
      });
}

/// Prices a product in an additional currency. It cannot repeat the primary
/// currency.
class CurrencyOptionInput {
  /// Creates a currency option.
  const CurrencyOptionInput({
    required this.currency,
    this.amount,
    this.presetAmount,
    this.minimumAmount,
    this.maximumAmount,
  });

  final String currency;
  final String? amount;
  final String? presetAmount;
  final String? minimumAmount;
  final String? maximumAmount;

  /// Encodes the option for a request.
  Map<String, dynamic> toJson() => _compact({
        'currency': currency,
        'amount': amount,
        'preset_amount': presetAmount,
        'minimum_amount': minimumAmount,
        'maximum_amount': maximumAmount,
      });
}

/// Creates a product. Set [billingCycle] to make it recurring; leave it null
/// for a one-time product.
class CreateProductParams {
  /// Creates the request body.
  const CreateProductParams({
    required this.name,
    this.description,
    required this.price,
    this.metadata,
    this.billingCycle,
    this.trialPeriod,
  });

  final String name;
  final String? description;
  final PriceInput price;
  final Map<String, dynamic>? metadata;
  final Cadence? billingCycle;
  final Cadence? trialPeriod;

  /// Encodes the request body.
  Map<String, dynamic> toJson() => _compact({
        'name': name,
        'description': description,
        'price': price.toJson(),
        'metadata': metadata,
        'billing_cycle': billingCycle?.toJson(),
        'trial_period': trialPeriod?.toJson(),
      });
}

/// A product's price in one currency.
class Price {
  /// Decodes a price from the API.
  Price.fromJson(Map<String, dynamic> json)
      : currency = _str(json['currency']),
        priceType = PriceType(_str(json['price_type'])),
        amount = _str(json['amount']),
        presetAmount = _str(json['preset_amount']),
        minimumAmount = _str(json['minimum_amount']),
        maximumAmount = _str(json['maximum_amount']),
        currencyOptions = _list(
            json['currency_options'], (v) => CurrencyOption.fromJson(_map(v)));

  final String currency;
  final PriceType priceType;
  final String amount;
  final String presetAmount;
  final String minimumAmount;
  final String maximumAmount;
  final List<CurrencyOption> currencyOptions;
}

/// A product's price in an additional currency.
class CurrencyOption {
  /// Decodes a currency option from the API.
  CurrencyOption.fromJson(Map<String, dynamic> json)
      : currency = _str(json['currency']),
        amount = _str(json['amount']),
        minimumAmount = _str(json['minimum_amount']),
        maximumAmount = _str(json['maximum_amount']);

  final String currency;
  final String amount;
  final String minimumAmount;
  final String maximumAmount;
}

/// An image attached to a product.
class Media {
  /// Decodes media from the API.
  Media.fromJson(Map<String, dynamic> json)
      : id = _str(json['id']),
        url = _str(json['url']),
        fileName = _str(json['file_name']),
        mimeType = _str(json['mime_type']),
        fileSizeBytes = _int(json['file_size_bytes']),
        createdAt = _time(json['created_at']);

  final String id;
  final String url;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final DateTime? createdAt;
}

/// An item in your billing catalog. IDs start with `prod_`.
class Product {
  /// Decodes a product from the API.
  Product.fromJson(Map<String, dynamic> json)
      : raw = json,
        id = _str(json['id']),
        organizationId = _str(json['organization_id']),
        name = _str(json['name']),
        description = _str(json['description']),
        price = Price.fromJson(_map(json['price'])),
        status = ProductStatus(_str(json['status'])),
        metadata = _mapOrNull(json['metadata']),
        media = _list(json['media'], (v) => Media.fromJson(_map(v))),
        actorId = _str(json['actor_id']),
        createdAt = _time(json['created_at']),
        updatedAt = _time(json['updated_at']),
        archivedAt = _time(json['archived_at']),
        billingCycle = _obj(json['billing_cycle'], Cadence.fromJson),
        trialPeriod = _obj(json['trial_period'], Cadence.fromJson),
        prices = _list(json['prices'], (v) => Price.fromJson(_map(v))),
        totalPayments = _int(json['total_payments']),
        totalAmount = _str(json['total_amount']);

  /// The full JSON object, including fields this SDK does not type yet.
  final Map<String, dynamic> raw;
  final String id;
  final String organizationId;
  final String name;
  final String description;
  final Price price;
  final ProductStatus status;
  final Map<String, dynamic>? metadata;
  final List<Media> media;
  final String actorId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? archivedAt;
  final Cadence? billingCycle;
  final Cadence? trialPeriod;
  final List<Price> prices;
  final int totalPayments;
  final String totalAmount;
}

/// One page of products.
class ProductList {
  /// Decodes a page from the API.
  ProductList.fromJson(Map<String, dynamic> json)
      : raw = json,
        items = _list(json['items'], (v) => Product.fromJson(_map(v))),
        pagination = Pagination.fromJson(_map(json['pagination']));

  /// The full JSON object.
  final Map<String, dynamic> raw;
  final List<Product> items;
  final Pagination pagination;
}

/// Filters a product list. Products page by cursor.
class ListProductsParams {
  /// Creates the filter.
  const ListProductsParams({this.limit, this.cursor, this.includeArchived});

  /// The page size, 1 to 100. The API default is 20.
  final int? limit;

  /// [Pagination.nextCursor] from the previous page.
  final String? cursor;
  final bool? includeArchived;

  Map<String, List<String>> _query() => _queryOf({
        'limit': limit,
        'cursor': cursor,
        'include_archived': includeArchived,
      });
}

/// Manages products.
class ProductsService with _ProductsServiceGen {
  ProductsService._(this._c);

  @override
  final BachsClient _c;

  /// Calls `POST /v1/products`. Creates a product.
  Future<Product> create(CreateProductParams params,
          {RequestOptions? options}) =>
      _c._request('POST', '/v1/products', (j) => Product.fromJson(_map(j)),
          body: params, options: options);

  /// Calls `GET /v1/products/{id}`. Retrieves a product.
  Future<Product> get(String id, {RequestOptions? options}) async {
    final esc = _pathId('product ID', id);
    return _c._request(
        'GET', '/v1/products/$esc', (j) => Product.fromJson(_map(j)),
        options: options);
  }

  /// Calls `GET /v1/products`. Returns one page of products.
  Future<ProductList> list(
          {ListProductsParams? params, RequestOptions? options}) =>
      _c._request('GET', '/v1/products', (j) => ProductList.fromJson(_map(j)),
          query: params?._query(), options: options);

  /// Every product, fetching pages as you consume them. [ListProductsParams.limit]
  /// sets the page size, and [ListProductsParams.cursor], when set, is where
  /// it starts.
  ///
  /// ```dart
  /// await for (final product in client.products.listAll()) {
  ///   print(product.name);
  /// }
  /// ```
  Stream<Product> listAll(
          {ListProductsParams? params, RequestOptions? options}) =>
      _paginateCursor(
        query: params?._query(),
        fetch: (q) => _c._request(
            'GET', '/v1/products', (j) => ProductList.fromJson(_map(j)),
            query: q, options: options),
        items: (page) => page.items,
        pagination: (page) => page.pagination,
      );
}
