class OfferModel {
  final int id;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? createdBy;
  final bool isDeleted;
  final bool isBundle;
  final List<OfferItemModel> items;

  OfferModel({
    required this.id,
    required this.name,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    required this.isDeleted,
    this.isBundle = false,
    this.items = const [],
  });

  bool get isActive {
    final now = DateTime.now();
    return status == 'Active' &&
        now.isAfter(startDate) &&
        now.isBefore(endDate);
  }

  bool get isExpired {
    return DateTime.now().isAfter(endDate);
  }

  OfferModel copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? createdBy,
    bool? isDeleted,
    bool? isBundle,
    List<OfferItemModel>? items,
  }) {
    return OfferModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      isBundle: isBundle ?? this.isBundle,
      items: items ?? this.items,
    );
  }
}

class OfferItemModel {
  final int id;
  final int offerId;
  final int productId;
  final double? discountPercent;
  final double discountedPrice;
  final int? quantity;
  final DateTime createdAt;

  // Additional fields from join (not from database)
  final String? productName;
  final double? originalPrice;

  OfferItemModel({
    required this.id,
    required this.offerId,
    required this.productId,
    this.discountPercent,
    required this.discountedPrice,
    this.quantity,
    required this.createdAt,
    this.productName,
    this.originalPrice,
  });

  OfferItemModel copyWith({
    int? id,
    int? offerId,
    int? productId,
    double? discountPercent,
    double? discountedPrice,
    int? quantity,
    DateTime? createdAt,
    String? productName,
    double? originalPrice,
  }) {
    return OfferItemModel(
      id: id ?? this.id,
      offerId: offerId ?? this.offerId,
      productId: productId ?? this.productId,
      discountPercent: discountPercent ?? this.discountPercent,
      discountedPrice: discountedPrice ?? this.discountedPrice,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      originalPrice: originalPrice ?? this.originalPrice,
    );
  }
}
