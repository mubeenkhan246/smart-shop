import 'package:csv/csv.dart';

import '../models/app_models.dart';

class CsvService {
  String exportProducts(List<Product> products) {
    final rows = [
      [
        'Name',
        'SKU',
        'Category',
        'Buying Price',
        'Selling Price',
        'Stock',
        'Unit',
        'Discount',
        'Tax',
        'Expiry',
      ],
      ...products.map(
        (product) => [
          product.name,
          product.sku,
          product.category,
          product.buyingPrice,
          product.sellingPrice,
          product.stockQuantity,
          product.unit,
          product.discountPercent,
          product.taxPercent,
          product.expiryDate?.toIso8601String() ?? '',
        ],
      ),
    ];
    return const ListToCsvConverter().convert(rows);
  }
}
