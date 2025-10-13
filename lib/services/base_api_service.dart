import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/user.dart';

// Base URL for API requests
const String baseUrl = 'https://digiagekenya.com/pay_age/demo_api/';

// Custom Exceptions
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => 'NetworkException: $message';
}

class ServerException implements Exception {
  final String message;
  final int statusCode;
  ServerException(this.message, this.statusCode);
  @override
  String toString() => 'ServerException: $message (Status: $statusCode)';
}

class UnauthorizedAccessException implements Exception {
  final String message;
  UnauthorizedAccessException(this.message);
  @override
  String toString() => 'UnauthorizedAccessException: $message';
}

abstract class BaseApiService {
  final http.Client _client;
  User _user;

  BaseApiService({required http.Client client, required User user})
      : _client = client,
        _user = user;

  String buildQueryUrl(String endpoint, Map<String, String> params) {
    final uri =
        Uri.https('digiagekenya.com', '/pay_age/demo_api/$endpoint', params);
    return uri.toString();
  }

  void validateCompanyId(int companyId) {
    if (_user.companyId != companyId) {
      throw UnauthorizedAccessException(
          'Access denied: Company ID $companyId does not match user company ID ${_user.companyId}');
    }
  }

  void validateEmployeeId(String employeeId) {
    if (_user.role.toLowerCase() != 'admin' && _user.employeeId != employeeId) {
      throw UnauthorizedAccessException(
          'Access denied: Employee ID $employeeId does not match user employee ID ${_user.employeeId}');
    }
  }

  Future<Map<String, dynamic>> getRequest(String endpoint) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          if (_user.token != null) 'Authorization': 'Bearer ${_user.token}',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>?;
        if (decoded == null) {
          throw ServerException('Invalid response format', response.statusCode);
        }
        return decoded;
      } else if (response.statusCode == 401) {
        throw UnauthorizedAccessException('Invalid or expired token');
      }
      final decoded = json.decode(response.body) as Map<String, dynamic>?;
      throw ServerException(
        decoded?['message'] ?? 'Server error: ${response.statusCode}',
        response.statusCode,
      );
    } on SocketException {
      throw NetworkException('No internet connection');
    } on TimeoutException {
      throw NetworkException('Request timed out');
    } catch (e) {
      throw NetworkException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> postRequest(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              if (_user.token != null) 'Authorization': 'Bearer ${_user.token}',
            },
            body: json.encode(data),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>?;
        if (decoded == null) {
          throw ServerException('Invalid response format', response.statusCode);
        }
        return decoded;
      } else if (response.statusCode == 401) {
        throw UnauthorizedAccessException('Invalid or expired token');
      }
      final decoded = json.decode(response.body) as Map<String, dynamic>?;
      throw ServerException(
        decoded?['message'] ?? 'Server error: ${response.statusCode}',
        response.statusCode,
      );
    } on SocketException {
      throw NetworkException('No internet connection');
    } on TimeoutException {
      throw NetworkException('Request timed out');
    } catch (e) {
      throw NetworkException('Network error: $e');
    }
  }

  void updateUser(User newUser) {
    _user = newUser;
  }

  void dispose() {
    _client.close();
  }
}
