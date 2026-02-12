import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';

// Base URL configuration
enum Environment { production, localhost, staging }

class ApiConfig {
  static Environment environment = Environment.production;
  static Duration timeout = const Duration(seconds: 15);
  static bool enableLogging = false;
  static int maxRetries = 3;
  static Duration retryDelay = const Duration(seconds: 1);
  
  static String get baseUrl {
    switch (environment) {
      case Environment.localhost:
        return 'http://localhost/demo_api/';
      case Environment.staging:
        return 'https://staging.digiagekenya.com/pay_age/demo_api/';
      case Environment.production:
        return 'https://digiagekenya.com/pay_age/demo_api/';
    }
  }
}

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

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  @override
  String toString() => 'ValidationException: $message';
}

// Logger Utility
class ApiLogger {
  static void logRequest(String method, String endpoint, {dynamic data}) {
    if (ApiConfig.enableLogging) {
      debugPrint('🎯 API Request: $method $endpoint');
      if (data != null) {
        debugPrint('📦 Request Data: ${jsonEncode(data)}');
      }
    }
  }
  
  static void logResponse(String method, String endpoint, int statusCode, dynamic response) {
    if (ApiConfig.enableLogging) {
      debugPrint('📡 API Response: $method $endpoint -> $statusCode');
      if (response != null) {
        debugPrint('📥 Response Data: ${response is String ? response : jsonEncode(response)}');
      }
    }
  }
  
  static void logError(String method, String endpoint, dynamic error) {
    if (ApiConfig.enableLogging) {
      debugPrint('💥 API Error: $method $endpoint -> $error');
    }
  }
}

abstract class BaseApiService {
  final http.Client _client;
  User _user;

  BaseApiService({required http.Client client, required User user})
      : _client = client,
        _user = user;

  String get baseUrl => ApiConfig.baseUrl;

  // URL Builder with enhanced parameters
  String buildQueryUrl(String endpoint, Map<String, dynamic> params) {
    final stringParams = params.map((key, value) => 
      MapEntry(key, value?.toString() ?? ''));
    
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: stringParams);
    return uri.toString();
  }

  // Validation methods
  void validateCompanyId(int companyId) {
    if (_user.role.toLowerCase() == 'admin') return;
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

  void validateRequiredFields(Map<String, dynamic> data, List<String> requiredFields) {
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null || data[field] == '') {
        throw ValidationException('Required field "$field" is missing or empty');
      }
    }
  }

  // Core request method with retry mechanism
  Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? data,
    int retryCount = 0,
  }) async {
    ApiLogger.logRequest(method, endpoint, data: data);
    
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final request = http.Request(method, uri);
      
      // Set headers
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'application/json';
      if (_user.token != null) {
        request.headers['Authorization'] = 'Bearer ${_user.token}';
      }
      
      // Add user agent for analytics
      request.headers['User-Agent'] = 'PayAgeApp/1.0';
      
      // Set body for methods that support it
      if (data != null && (method == 'POST' || method == 'PUT' || method == 'PATCH')) {
        request.body = json.encode(data);
      }

      final streamedResponse = await _client.send(request).timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);
      
      ApiLogger.logResponse(method, endpoint, response.statusCode, response.body);
      
      return _handleResponse(response);
      
    } on SocketException {
      final error = NetworkException('No internet connection');
      ApiLogger.logError(method, endpoint, error);
      
      // Retry on network errors
      if (retryCount < ApiConfig.maxRetries) {
        await Future.delayed(ApiConfig.retryDelay * (retryCount + 1));
        return _makeRequest(method, endpoint, data: data, retryCount: retryCount + 1);
      }
      throw error;
      
    } on TimeoutException {
      final error = NetworkException('Request timed out after ${ApiConfig.timeout}');
      ApiLogger.logError(method, endpoint, error);
      
      // Retry on timeout
      if (retryCount < ApiConfig.maxRetries) {
        await Future.delayed(ApiConfig.retryDelay * (retryCount + 1));
        return _makeRequest(method, endpoint, data: data, retryCount: retryCount + 1);
      }
      throw error;
      
    } catch (e) {
      ApiLogger.logError(method, endpoint, e);
      
      // Don't retry on other types of errors
      if (e is NetworkException || e is ServerException || e is UnauthorizedAccessException) {
        rethrow;
      }
      throw NetworkException('Network error: $e');
    }
  }

  // Response handler
  Map<String, dynamic> _handleResponse(http.Response response) {
    // Handle empty response
    if (response.body.isEmpty) {
      throw ServerException('Empty response from server', response.statusCode);
    }

    // Parse JSON response
    final decoded = json.decode(response.body) as Map<String, dynamic>?;
    if (decoded == null) {
      throw ServerException('Invalid JSON response format', response.statusCode);
    }

    // Handle different status codes
    switch (response.statusCode) {
      case 200:
      case 201:
        return decoded;
      case 400:
        throw ValidationException(
          decoded['message'] ?? decoded['error'] ?? 'Bad request'
        );
      case 401:
        throw UnauthorizedAccessException(
          decoded['message'] ?? 'Invalid or expired token'
        );
      case 403:
        throw UnauthorizedAccessException(
          decoded['message'] ?? 'Access forbidden'
        );
      case 404:
        throw ServerException(
          decoded['message'] ?? 'Resource not found',
          response.statusCode,
        );
      case 422: // Validation errors
        final errors = decoded['errors'] ?? decoded['message'];
        throw ValidationException(
          errors is Map ? errors.entries.map((e) => '${e.key}: ${e.value}').join(', ') 
          : errors?.toString() ?? 'Validation failed'
        );
      case 500:
      case 502:
      case 503:
        throw ServerException(
          decoded['message'] ?? 'Server error occurred',
          response.statusCode,
        );
      default:
        throw ServerException(
          decoded['message'] ?? 'Unexpected error: ${response.statusCode}',
          response.statusCode,
        );
    }
  }

  // HTTP Method wrappers
  Future<Map<String, dynamic>> getRequest(String endpoint) async {
    return _makeRequest('GET', endpoint);
  }

  Future<Map<String, dynamic>> postRequest(
      String endpoint, Map<String, dynamic> data) async {
    return _makeRequest('POST', endpoint, data: data);
  }

  Future<Map<String, dynamic>> putRequest(
      String endpoint, Map<String, dynamic> data) async {
    return _makeRequest('PUT', endpoint, data: data);
  }

  Future<Map<String, dynamic>> patchRequest(
      String endpoint, Map<String, dynamic> data) async {
    return _makeRequest('PATCH', endpoint, data: data);
  }

  Future<Map<String, dynamic>> deleteRequest(String endpoint) async {
    return _makeRequest('DELETE', endpoint);
  }

  // File upload support
  Future<Map<String, dynamic>> uploadFile(
    String endpoint,
    String filePath,
    String fieldName, {
    Map<String, String>? additionalFields,
  }) async {
    try {
      ApiLogger.logRequest('POST', endpoint, data: {'file': filePath, ...?additionalFields});
      
      final uri = Uri.parse('$baseUrl$endpoint');
      final request = http.MultipartRequest('POST', uri);
      
      // Add authorization header
      if (_user.token != null) {
        request.headers['Authorization'] = 'Bearer ${_user.token}';
      }
      
      // Add file
      final file = await http.MultipartFile.fromPath(fieldName, filePath);
      request.files.add(file);
      
      // Add additional fields
      if (additionalFields != null) {
        request.fields.addAll(additionalFields);
      }
      
      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);
      
      ApiLogger.logResponse('POST', endpoint, response.statusCode, response.body);
      
      return _handleResponse(response);
      
    } on SocketException {
      throw NetworkException('No internet connection');
    } on TimeoutException {
      throw NetworkException('File upload timed out');
    } catch (e) {
      throw NetworkException('Upload error: $e');
    }
  }

  // Response parsing helpers
  T parseResponse<T>(Map<String, dynamic> response, String key) {
    if (!response.containsKey(key)) {
      throw ServerException('Missing required field: $key', 200);
    }
    return response[key] as T;
  }

  T? parseOptionalResponse<T>(Map<String, dynamic> response, String key) {
    return response.containsKey(key) ? response[key] as T? : null;
  }

  List<T> parseListResponse<T>(Map<String, dynamic> response, String key) {
    final data = parseResponse<List<dynamic>>(response, key);
    return data.cast<T>();
  }

  List<T> parseOptionalListResponse<T>(Map<String, dynamic> response, String key) {
    final data = parseOptionalResponse<List<dynamic>>(response, key);
    return data?.cast<T>() ?? <T>[];
  }

  // Check if response indicates success
  bool isSuccessResponse(Map<String, dynamic> response) {
    return response['success'] == true || 
           response['status'] == 'success' ||
           (response.containsKey('error') && response['error'] == false);
  }

  // Get message from response
  String getResponseMessage(Map<String, dynamic> response) {
    return response['message']?.toString() ?? 
           response['msg']?.toString() ?? 
           (isSuccessResponse(response) ? 'Operation completed successfully' : 'Operation failed');
  }

  // User management
  void updateUser(User newUser) {
    _user = newUser;
  }

  User get currentUser => _user;

  // Cleanup
  void dispose() {
    _client.close();
  }
}

// Concrete service example
class UserService extends BaseApiService {
  UserService({required super.client, required super.user});

  Future<List<Map<String, dynamic>>> getCompanyUsers(int companyId) async {
    validateCompanyId(companyId);
    
    final response = await getRequest('users?company_id=$companyId');
    
    if (isSuccessResponse(response)) {
      final usersData = parseListResponse<Map<String, dynamic>>(response, 'users');
      return usersData;
    }
    
    throw ServerException(getResponseMessage(response), 200);
  }

  Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> profileData) async {
    validateRequiredFields(profileData, ['employee_id', 'company_id']);
    
    final response = await putRequest('user/profile', profileData);
    
    if (isSuccessResponse(response)) {
      final userData = parseResponse<Map<String, dynamic>>(response, 'user');
      return userData;
    }
    
    throw ServerException(getResponseMessage(response), 200);
  }

  Future<bool> uploadProfilePicture(String filePath) async {
    final response = await uploadFile(
      'user/upload_photo',
      filePath,
      'profile_picture',
      additionalFields: {
        'employee_id': _user.employeeId!,
        'company_id': _user.companyId.toString(),
      },
    );
    
    return isSuccessResponse(response);
  }
}
