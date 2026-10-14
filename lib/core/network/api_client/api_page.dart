part of '../api_client.dart';

/// Trang dữ liệu phân trang kiểu Laravel: `{data: [...], current_page, last_page, per_page, total}`.
class ApiPage<T> {
  const ApiPage({required this.items, required this.currentPage, required this.lastPage, this.perPage, this.total});

  factory ApiPage.fromJson(Object? json, T Function(Map<String, dynamic> item) itemParser) {
    final Map<String, dynamic> map = json as Map<String, dynamic>;
    final List<dynamic> list = map['data'] as List<dynamic>? ?? const [];
    return ApiPage(
      items: [for (final dynamic item in list) itemParser(item as Map<String, dynamic>)],
      currentPage: _int(map['current_page']) ?? 1,
      lastPage: _int(map['last_page']) ?? 1,
      perPage: _int(map['per_page']),
      total: _int(map['total']),
    );
  }

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int? perPage;
  final int? total;

  bool get hasMore => currentPage < lastPage;

  // Laravel có lúc trả số dạng chuỗi
  static int? _int(Object? v) => v is int ? v : int.tryParse('$v');
}
