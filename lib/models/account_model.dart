import 'interfaces/account_model_interface.dart';

/// Hồ sơ người dùng mà UI dùng, dựng từ [AccountModelInterface].
class AccountModel {
  final int id;
  final String name;
  final String? email;
  final String? avatar;

  AccountModel({required AccountModelInterface data})
    : id = data.id ?? 0,
      name = data.name?.trim() ?? '',
      email = data.email,
      avatar = data.avatar;

  @override
  String toString() => 'AccountModel(id: $id)';
}
