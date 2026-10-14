import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

bool get isHasNetwork => globalInternetNotifier.value;

/// Biến global ValueNotifier báo trạng thái kết nối Internet, mặc định là true.
/// Các widget có thể lắng nghe biến này để thay đổi giao diện tương ứng.
final ValueNotifier<bool> globalInternetNotifier = ValueNotifier<bool>(true);

/// Hàm khởi tạo lắng nghe stream kiểm tra kết nối mạng thực tế.
/// Khi trạng thái thay đổi, cập nhật trực tiếp vào globalInternetNotifier.bn
void initInternetListener() {
  // Lấy trạng thái mạng lúc mới khởi động
  Connectivity().checkConnectivity().then((List<ConnectivityResult> results) {
    _updateNetworkState(results);
  });

  // Lắng nghe thay đổi kết nối
  Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    _updateNetworkState(results);
  });
}

void _updateNetworkState(List<ConnectivityResult> results) {
  bool isConnected = results.isNotEmpty && !results.contains(ConnectivityResult.none);
  if (globalInternetNotifier.value != isConnected) {
    globalInternetNotifier.value = isConnected;
  }
}
