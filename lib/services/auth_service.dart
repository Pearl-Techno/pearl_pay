import '../models/user.dart';
import 'api_endpoints.dart';
import 'base_api_service.dart';

class AuthService extends BaseApiService {
  AuthService({required super.client, required super.user});

  Future<User> login(String username, String password) async {
    final data = await postRequest(ApiEndpoints.login, {
      'username': username,
      'password': password,
    });

    if (data['status'] == 'success') {
      return User.fromMap({
        ...data['user'] as Map<String, dynamic>,
        'token': data['token'] as String?,
      });
    }
    throw Exception('Login failed: ${data['message'] ?? 'Unknown error'}');
  }
}
