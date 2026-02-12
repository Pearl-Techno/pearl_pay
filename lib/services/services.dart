import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import 'base_api_service.dart';

// API Endpoints: Defines all API endpoint paths as constants
class ApiEndpoints {
  // Authentication Endpoints
  static const String login = 'auth/login_api.php';

  // Employee Management Endpoints
  static const String getEmployeeList = 'employee/get_employeelist.php';
  static const String addEmployee = 'employee/add_employee.php';
  static const String updateEmployee = 'employee/update_employee.php';
  static const String activateEmployee = 'employee/activate_employee.php';
  static const String deactivateEmployee = 'employee/deactivate_employee.php';
  static const String getPositions = 'employee/get_positions.php';

  // Overtime Management Endpoints
  static const String getOvertimeList = 'overtime/get_all_overtime.php';
  static const String addOvertime = 'overtime/add_overtime.php';
  static const String fetchOvertimeAmount = 'overtime/fetch_overtime_amount.php';

  // Benefits Management Endpoints
  static const String fetchBenefits = 'benefits/fetch_benefits.php';
  static const String addBenefit = 'benefits/add_benefit.php';

  // Earnings Management Endpoints
  static const String fetchEarnings = 'salary_processing/fetch_earnings.php';

  // Deductions Management Endpoints
  static const String fetchAbsenteeismDeduction =
      'deductions/fetch_absenteeism_deduction.php';
  static const String fetchDeductions = 'deductions/fetch_deductions.php';
  static const String addDeduction = 'deductions/add_deduction.php';
  static const String fetchDeductionsList =
      'deductions/fetch_deductions_list.php';
  static const String updateDeduction = 'deductions/update_deduction.php';
  static const String deleteDeduction = 'deductions/delete_deduction.php';

  // Pension Management Endpoints
  static const String fetchPensionContributions =
      'pension/fetch_pension_contributions.php';
  static const String fetchAllPensionContributions =
      'pension/pension_contributions.php';
  static const String savePensionContribution = 'pension/save_pension_contribution.php';

  // Loan Management Endpoints
  static const String fetchLoanRepayment = 'loan/fetch_loan_repayment.php';
  static const String fetchLoans = 'loan/fetch_loans.php';
  static const String fetchLoansForEmployee =
      'loan/fetch_loans_for_employee.php';
  static const String addLoan = 'loan/add_loan.php';
  static const String processLoanRepayment = 'loan/process_loan_repayment.php';

  // Salary Processing Endpoints
  static const String saveSalary = 'salary_processing/pay_salaries.php';
  static const String checkPaidStatus =
      'salary_processing/check_paid_status.php';
  static const String getSalaries = 'salary_processing/get_paid_salaries.php';
  static const String calculatePAYE = 'salary_processing/calculate_paye.php';
  static const String calculateNSSF = 'salary_processing/calculate_nssf.php';
  static const String calculateNHIF = 'salary_processing/calculate_nhif.php';
  static const String getP9Data = 'salary_processing/get_p9_data.php';

  // Insurance Relief Endpoints
  static const String addInsuranceRelief = 'insurance/add_insurance_relief.php';
  static const String getInsuranceRelief = 'insurance/get_insurance_relief.php';

  // Company Management Endpoints
  static const String addCompany = 'companies/add_company.php';
  static const String getCompanies = 'companies/get_companies.php';

  // Leave Management Endpoints
  static const String getLeaveBalance = 'get_leave_balance.php';
  static const String requestLeave = 'request_leave.php';
  static const String getLeaveRequests = 'get_leave_requests.php';
  static const String updateLeaveStatus = 'update_leave_status.php';

  // Attendance Management Endpoints
  static const String getAttendanceRecords = 'get_attendance_records.php';
  static const String recordAttendance = 'record_attendance.php';

  // Logging Endpoints
  static const String logCompanyAction = 'log_company_action.php';
  static const String logEmployeeAction = 'log_employee_action.php';

  // Preferences Management Endpoints
  static const String getNotificationPrefs = 'get_notification_prefs.php';
  static const String updateNotificationPrefs = 'update_notification_prefs.php';
  static const String getPrivacyPrefs = 'get_privacy_prefs.php';
  static const String updatePrivacyPrefs = 'update_privacy_prefs.php';
  static const String getLanguagePref = 'get_language_prefs.php';
  static const String updateLanguagePref = 'update_language_prefs.php';

  // Rate Management Endpoints
  static const String getSHIFRate = 'get_shif_rate.php';
  static const String updateSHIFRate = 'update_shif_rate.php';
  static const String getHousingLevyRate = 'get_housing_levy_rate.php';
  static const String updateHousingLevyRate = 'update_housing_levy_rate.php';
  static const String getLoanRate = 'get_loan_rate.php';
  static const String updateLoanRate = 'update_loan_rate.php';
  static const String getPAYERates = 'get_paye_rates.php';
  static const String updatePAYERates = 'update_paye_rates.php';
  static const String getOvertimeRate = 'get_overtime_rate.php';
  static const String updateOvertimeRate = 'update_overtime_rate.php';

  // Appraisal Management Endpoints
  static const String getAppraisals = 'appraisal/get_appraisals_api.php';
  static const String updateAppraisalStatus =
      'appraisal/update_appraisal_status_api.php';
  static const String submitSelfAppraisal =
      'appraisal/submit_self_appraisal_api.php';
  static const String submitEmployeeAppraisal =
      'appraisal/submit_employee_appraisal.php';
}

// Custom Exceptions: Define specific exceptions for different error scenarios
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

// Custom exception for salary already processed
class SalaryAlreadyProcessedException implements Exception {
  final String message;
  SalaryAlreadyProcessedException(this.message);
}

// ApiService: Main class for handling backend API interactions
class ApiService {
  final http.Client _client;
  final User _user;

  // Constructor: Initialize with HTTP client and user context
  ApiService({required http.Client client, required User user})
      : _client = client,
        _user = user;

  // Get current base URL from ApiConfig
  String get _baseUrl => ApiConfig.baseUrl;

  // Helper: Builds a URL with query parameters
  String _buildQueryUrl(String endpoint, Map<String, String> params) {
    final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: params);
    return uri.toString();
  }

  // Validation: Ensures the provided companyId matches the user's company_id
  void _validateCompanyId(int companyId) {
    if (_user.role.toLowerCase() == 'admin') return;
    if (_user.companyId != companyId) {
      throw UnauthorizedAccessException(
          'Access denied: Company ID $companyId does not match user company ID ${_user.companyId}');
    }
  }

  // Validation: Ensures the provided employeeId matches the user's employee_id for non-admins
  void _validateEmployeeId(String employeeId) {
    if (_user.role.toLowerCase() != 'admin' && _user.employeeId != employeeId) {
      throw UnauthorizedAccessException(
          'Access denied: Employee ID $employeeId does not match user employee ID ${_user.employeeId}');
    }
  }

  // HTTP GET Request: Makes a GET request to the specified endpoint
  Future<Map<String, dynamic>> _getRequest(String endpoint) async {
    try {
      final response = await _client.get(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          if (_user.token != null) 'Authorization': 'Bearer ${_user.token}',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      throw ServerException(
          'Server error: ${response.statusCode}', response.statusCode);
    } catch (e) {
      throw NetworkException('Network error: $e');
    }
  }

  // HTTP POST Request: Makes a POST request with JSON data
  Future<Map<String, dynamic>> _postRequest(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              if (_user.token != null) 'Authorization': 'Bearer ${_user.token}',
            },
            body: json.encode(data),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      throw ServerException(
          'Server error: ${response.statusCode}', response.statusCode);
    } catch (e) {
      throw NetworkException('Network error: $e');
    }
  }

  // Login: Authenticates a user with username and password
 Future<User> login(String username, String password) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl${ApiEndpoints.login}'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              'Origin': 'https://digiagekenya.com',
              'Accept': 'application/json',
              if (_user.token != null) 'Authorization': 'Bearer ${_user.token}',
            },
            body: json.encode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      // Log response for debugging
      if (kDebugMode) {
        print('Login Response Status: ${response.statusCode}');
        print('Login Response Headers: ${response.headers}');
        print('Login Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          return User.fromMap({
            ...data['user'] as Map<String, dynamic>,
            'token': data['token'] as String?,
          });
        }
        throw UnauthorizedAccessException(data['message'] ?? 'Invalid username or password');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied: reCAPTCHA verification required');
      } else {
        throw ServerException(
            'Server error: ${response.body}', response.statusCode);
      }
    } catch (e) {
      if (e is FormatException) {
        // Likely received HTML (reCAPTCHA page) instead of JSON
        throw Exception('Access denied: reCAPTCHA verification required');
      }
      throw NetworkException('Network error: $e');
    }
  }

  // Employee Management: Fetches the list of employees for a company (admin-only or user-specific)
  Future<List<Map<String, dynamic>>> getEmployeeList(int companyId,
      {int page = 1, int limit = 20}) async {
    _validateCompanyId(companyId);
    if (_user.userId == null) {
      throw UnauthorizedAccessException('Access denied: User ID is missing');
    }

    final queryParams = {
      'company_id': companyId.toString(),
      'user_id': _user.userId!,
      'page': page.toString(),
      'limit': limit.toString(),
    };
    final url = _buildQueryUrl(ApiEndpoints.getEmployeeList, queryParams);
    final response = await _getRequest(url);

    if (response['status'] == 'success') {
      return List<Map<String, dynamic>>.from(response['employees'] ?? []);
    }
    throw Exception('Failed to fetch employees: ${response['message']}');
  }

  // Employee Management: Adds a new employee to a company (admin-only)
  Future<void> addEmployee(
      Map<String, dynamic> employeeData, int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can add employees');
    }
    _validateCompanyId(companyId);

    final requestData = {...employeeData, 'company_id': companyId};
    final data = await _postRequest(ApiEndpoints.addEmployee, requestData);

    if (data['status'] != 'success') {
      throw Exception('Failed to add employee: ${data['message']}');
    }
  }

  // Employee Management: Updates an employee's field (admin-only)
  Future<void> updateEmployee({
    required int companyId,
    required String employeeId,
    required String field,
    required String value,
  }) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can update employees');
    }
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.updateEmployee, {
      'company_id': companyId,
      'employee_id': employeeId,
      'field': field,
      'value': value,
    });

    if (data['status'] != 'success') {
      throw Exception('Failed to update employee: ${data['message']}');
    }
  }

  // Employee Management: Activates an employee (admin-only)
  Future<void> activateEmployee(int companyId, String employeeId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can activate employees');
    }
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.activateEmployee, {
      'company_id': companyId,
      'employee_id': employeeId,
    });

    if (data['status'] != 'success') {
      throw Exception('Failed to activate employee: ${data['message']}');
    }
  }

  // Employee Management: Deactivates an employee (admin-only)
  Future<void> deactivateEmployee(int companyId, String employeeId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can deactivate employees');
    }
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.deactivateEmployee, {
      'company_id': companyId,
      'employee_id': employeeId,
    });

    if (data['status'] != 'success') {
      throw Exception('Failed to deactivate employee: ${data['message']}');
    }
  }

  // Logging: Logs an employee action for audit purposes
  Future<void> logEmployeeAction(Map<String, dynamic> data) async {
    final response = await _postRequest(ApiEndpoints.logEmployeeAction, data);
    if (response['status'] != 'success') {
      throw Exception('Failed to log employee action: ${response['message']}');
    }
  }

  // Positions: Fetches the list of available positions (company-agnostic)
  Future<List<Map<String, dynamic>>> getPositions() async {
    final data = await _getRequest('$_baseUrl${ApiEndpoints.getPositions}');
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['positions'] ?? []);
    }
    throw Exception('Failed to load positions: ${data['message']}');
  }

  // Overtime: Fetches overtime records for a company (admin-only or user-specific)
  Future<List<Map<String, dynamic>>> getOvertimeList(
    int companyId, {
    int? month,
    int? year,
  }) async {
    _validateCompanyId(companyId);
    final queryParams = {
      'company_id': companyId.toString(),
      if (month != null) 'month': month.toString(),
      if (year != null) 'year': year.toString(),
    };
    final url = _buildQueryUrl(ApiEndpoints.getOvertimeList, queryParams);
    final data = await _getRequest(url);

    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['overtime_records'] ?? []);
    }
    throw Exception('Failed to fetch overtime records: ${data['message']}');
  }

  // Overtime: Adds a new overtime record (admin-only)
  Future<void> addOvertime(
      Map<String, dynamic> overtimeData, int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can add overtime');
    }
    _validateCompanyId(companyId);

    final requestData = {...overtimeData, 'company_id': companyId};
    final data = await _postRequest(ApiEndpoints.addOvertime, requestData);

    if (data['status'] != 'success') {
      throw Exception('Failed to add overtime: ${data['message']}');
    }
  }

  // Deductions: Fetches absenteeism deduction for an employee
  Future<double> fetchAbsenteeismDeduction(
      String employeeId, int companyId, int month, int year) async {
    _validateCompanyId(companyId);
    _validateEmployeeId(employeeId);

    final data = await _postRequest(ApiEndpoints.fetchAbsenteeismDeduction, {
      'employee_id': employeeId,
      'company_id': companyId,
      'month': month,
      'year': year,
    });

    if (data['status'] == 'success') {
      return double.tryParse(data['deduction'].toString()) ?? 0.0;
    }
    throw Exception(
        'Failed to fetch absenteeism deduction: ${data['message']}');
  }

  // Benefits: Fetches benefits for an employee
  Future<List<Map<String, dynamic>>> fetchBenefits(
      int companyId, int month, int year, String employeeId) async {
    if (kDebugMode) {
      print(
          'Received: companyId=$companyId, month=$month, year=$year, employeeId=$employeeId');
    }
    _validateCompanyId(companyId);
    _validateEmployeeId(employeeId);
    final data = await _postRequest(ApiEndpoints.fetchBenefits, {
      'employee_id': employeeId,
      'company_id': companyId,
      'month': month,
      'year': year,
    });
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['benefits'] ?? []);
    }
    throw Exception('Failed to fetch benefits: ${data['message']}');
  }

  // Overtime: Fetches overtime amount for an employee
  Future<double> fetchOvertimeAmount(
      String employeeId, int companyId, int month, int year) async {
    _validateCompanyId(companyId);
    _validateEmployeeId(employeeId);

    final data = await _postRequest(ApiEndpoints.fetchOvertimeAmount, {
      'employee_id': employeeId,
      'company_id': companyId,
      'month': month,
      'year': year,
    });

    if (data['status'] == 'success') {
      return double.tryParse(data['amount'].toString()) ?? 0.0;
    }
    throw Exception('Failed to fetch overtime amount: ${data['message']}');
  }

  // Earnings: Fetches earnings for an employee
  Future<List<Map<String, dynamic>>> fetchEarnings(
      String employeeId, int companyId, int month, int year) async {
    _validateCompanyId(companyId);
    _validateEmployeeId(employeeId);

    final data = await _postRequest(ApiEndpoints.fetchEarnings, {
      'employee_id': employeeId,
      'company_id': companyId,
      'month': month,
      'year': year,
    });

    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['earnings'] ?? []);
    }
    throw Exception('Failed to fetch earnings: ${data['message']}');
  }

  // Deductions: Fetches deductions for an employee
  Future<List<Map<String, dynamic>>> fetchDeductions(
      int companyId, int month, int year, String employeeId) async {
    _validateCompanyId(companyId);
    _validateEmployeeId(employeeId);

    final requestData = {
      'employee_id': employeeId,
      'company_id': companyId.toString(),
      'month': month,
      'year': year,
      'user_id': _user.userId ?? '', // Add user_id to match PHP validation
    };
    if (kDebugMode) {
      print('Sending fetchDeductions request: $requestData');
    } // Debug log

    final data = await _postRequest(ApiEndpoints.fetchDeductions, requestData);

    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['deductions'] ?? []);
    }
    throw Exception('Failed to fetch deductions: ${data['message']}');
  }

  // Pension: Fetches pension contributions for an employee
  Future<double> fetchPensionContributions(
      String employeeId, int companyId, int month, int year) async {
    _validateCompanyId(companyId);
    _validateEmployeeId(employeeId);

    final data = await _postRequest(ApiEndpoints.fetchPensionContributions, {
      'employee_id': employeeId,
      'company_id': companyId,
      'month': month,
      'year': year,
    });

    if (data['status'] == 'success') {
      return double.tryParse(data['amount'].toString()) ?? 0.0;
    }
    throw Exception(
        'Failed to fetch pension contributions: ${data['message']}');
  }

  // Pension: Fetches all pension contributions for a company (admin-only)
  Future<List<Map<String, dynamic>>> fetchAllPensionContributions(
      int companyId, int month, int year) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can view all pension contributions');
    }
    _validateCompanyId(companyId);

    final queryParams = {
      'company_id': companyId.toString(),
      'month': month.toString(),
      'year': year.toString(),
    };
    final url =
        _buildQueryUrl(ApiEndpoints.fetchAllPensionContributions, queryParams);
    final data = await _getRequest(url);

    if (data['status'] == 'success') {
      // Use 'data' instead of 'contributions' based on the sample response
      final contributions = data['data'] ?? [];
      if (contributions is! List) {
        throw Exception(
            'Invalid response format: Expected a list of contributions');
      }

      // Validate and transform the data to ensure required fields are present
      return contributions.map<Map<String, dynamic>>((item) {
        return {
          'employee_id': item['employee_id'] ?? 'Unknown',
          'company_id': item['company_id'] ?? companyId,
          'amount': item['amount'] ?? '0.00',
          'contribution_date':
              item['contribution_date'] ?? DateTime.now().toIso8601String(),
          'month': item['month'] ?? month,
          'year': item['year'] ?? year,
          'fullname': item['fullname'] ?? 'Unknown Employee',
        };
      }).toList();
    }
    throw Exception(
        'Failed to fetch pension contributions: ${data['message'] ?? 'Unknown error'}');
  }


  // Pension: Saves a pension contribution for an employee (admin-only)
  Future<void> savePensionContribution(
      Map<String, dynamic> pensionData, int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can save pension contributions');
    }
    _validateCompanyId(companyId);

    final requestData = {...pensionData, 'company_id': companyId};
    final data =
        await _postRequest(ApiEndpoints.savePensionContribution, requestData);

    if (data['status'] != 'success') {
      throw Exception(
          'Failed to save pension contribution: ${data['message']}');
    }
  }

  // Loans: Fetches loan repayment amount for an employee
  Future<double> fetchLoanRepayment(
      String employeeId, int companyId, int month, int year) async {
    _validateCompanyId(companyId);
    _validateEmployeeId(employeeId);

    final data = await _postRequest(ApiEndpoints.fetchLoanRepayment, {
      'employee_id': employeeId,
      'company_id': companyId,
      'month': month,
      'year': year,
    });

    if (data['status'] == 'success') {
      return double.tryParse(data['total_repayment'].toString()) ?? 0.0;
    }
    throw Exception('Failed to fetch loan repayment: ${data['message']}');
  }

  // Loans: Fetches loans for a specific employee
  Future<List<Map<String, dynamic>>> fetchLoansForEmployee(
      String employeeId, int companyId) async {
    _validateCompanyId(companyId);
    _validateEmployeeId(employeeId);

    final queryParams = {
      'employee_id': employeeId,
      'company_id': companyId.toString(),
    };
    final url = _buildQueryUrl(ApiEndpoints.fetchLoansForEmployee, queryParams);
    final data = await _getRequest(url);

    if (data['status'] == 'success') {
      final loansData = data['loans'];
      if (loansData is Map) {
        return List<Map<String, dynamic>>.from(loansData.values.whereType<Map>());
      }
      if (loansData is List) {
        return List<Map<String, dynamic>>.from(loansData.whereType<Map>());
      }
      return [];
    }
    throw Exception('Failed to fetch loans for employee: ${data['message']}');
  }

  // Loans: Fetches all loans for a company (admin-only)
  Future<List<Map<String, dynamic>>> fetchLoans(int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can view loans');
    }
    _validateCompanyId(companyId);

    final now = DateTime.now();
    final queryParams = {
      'company_id': companyId.toString(),
      'month': '${now.month}',
      'year': '${now.year}',
    };

    final url = _buildQueryUrl(ApiEndpoints.fetchLoans, queryParams);
    final data = await _getRequest(url);

    if (data['status'] == 'success') {
      final loansData = data['loans'];
      if (loansData is Map) {
        return List<Map<String, dynamic>>.from(loansData.values.whereType<Map>());
      }
      if (loansData is List) {
        return List<Map<String, dynamic>>.from(loansData.whereType<Map>());
      }
      return [];
    }

    throw Exception('Failed to fetch loans: ${data['message']}');
  }

  // Loans: Adds a new loan for an employee (admin-only)
  Future<void> addLoan(Map<String, dynamic> loanData, int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can add loans');
    }
    _validateCompanyId(companyId);

    final requestData = {...loanData, 'company_id': companyId};
    final data = await _postRequest(ApiEndpoints.addLoan, requestData);

    if (data['status'] != 'success') {
      throw Exception('Failed to add loan: ${data['message']}');
    }
  }

  // Loans: Processes a loan repayment (admin-only)
  Future<void> processLoanRepayment(
      Map<String, dynamic> repaymentData, int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can process loan repayments');
    }
    _validateCompanyId(companyId);

    final requestData = {...repaymentData, 'company_id': companyId};
    final data =
        await _postRequest(ApiEndpoints.processLoanRepayment, requestData);

    if (data['status'] != 'success') {
      throw Exception('Failed to process loan repayment: ${data['message']}');
    }
  }

  //check paid status
Future<bool> checkPaidStatus(
      int companyId, String employeeId, int month, int year) async {
    _validateEmployeeId(employeeId);
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.checkPaidStatus, {
      'company_id': companyId,
      'employee_id': employeeId,
      'month': month,
      'year': year,
    });

    if (data['status'] == 'success') {
      return data['paid'] ?? false;
    } else if (data['status'] == 'error' && data['errors'] is List) {
      final errors = data['errors'] as List;
      if (errors.any((error) => error
          .toString()
          .contains('Salary already paid for employee ID $employeeId'))) {
        return true; // Salary is already paid
      }
    }
    throw Exception('Failed to check paid status: ${data['message']}');
  }
 

 // Salaries: Saves salary data for an employee (admin-only)
  Future<void> saveSalary(
      Map<String, dynamic> salaryData, int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can save salaries');
    }
    _validateCompanyId(companyId);

    final payload = {'company_id': companyId, 'salary_data': salaryData};
    final data = await _postRequest(ApiEndpoints.saveSalary, payload);

    if (data['status'] == 'success') {
      return; // Successful save
    } else if (data['status'] == 'error' && data['errors'] is List) {
      final errors = data['errors'] as List;
      final employeeId = salaryData['employee_id']?.toString() ?? '';
      if (errors.any((error) => error
          .toString()
          .contains('Salary already paid for employee ID $employeeId'))) {
        throw SalaryAlreadyProcessedException(
            'Salary already processed for employee ID $employeeId');
      }
    }
    throw Exception('Failed to save salary: ${data['message']}');
  }



// Salaries: Fetches saved salaries for a company (admin-only or user-specific)
Future<List<Map<String, dynamic>>> getSalaries(
  int companyId, {
  int? month,
  int? year,
}) async {
  _validateCompanyId(companyId);

  final now = DateTime.now();
  // Use provided month/year or default to current month/year
  final effectiveMonth = month ?? now.month;
  final effectiveYear = year ?? now.year;

  final url = _buildQueryUrl(ApiEndpoints.getSalaries, {
    'company_id': '$companyId',
    'month': '$effectiveMonth',
    'year': '$effectiveYear',
  });

  if (kDebugMode) {
    print('API URL with month/year: $url');
  }

  final data = await _getRequest(url);

  if (data['status'] == 'success') {
    return List<Map<String, dynamic>>.from(data['salaries'] ?? []);
  }
  throw Exception('Failed to fetch salaries: ${data['message']}');
}

  // Deductions: Adds a new deduction for an employee (admin-only)
  Future<void> addDeduction(
      Map<String, dynamic> deductionData, int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can add deductions');
    }
    _validateCompanyId(companyId);

    final requestData = {
      'company_id': companyId,
      ...deductionData,
      'user_id': _user.userId ?? ''
    };
    final data = await _postRequest(ApiEndpoints.addDeduction, requestData);

    if (data['status'] != 'success') {
      throw Exception('Failed to add deduction: ${data['message']}');
    }
  }

  // Deductions: Updates a deduction (admin-only)
  Future<void> updateDeduction(
      int deductionId, Map<String, dynamic> deductionData) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can update deductions');
    }

    // Validate company ID if present in data, otherwise default to user's company
    int companyId = _user.companyId;
    if (deductionData.containsKey('company_id')) {
      companyId = int.parse(deductionData['company_id'].toString());
    }
    _validateCompanyId(companyId);

    final requestData = {
      'id': deductionId,
      ...deductionData,
      'user_id': _user.userId ?? ''
    };
    final data = await _postRequest(ApiEndpoints.updateDeduction, requestData);

    if (data['status'] != 'success') {
      throw Exception('Failed to update deduction: ${data['message']}');
    }
  }

  // Deductions: Deletes a deduction (admin-only)
  Future<void> deleteDeduction(int deductionId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can delete deductions');
    }
    _validateCompanyId(_user.companyId);

    final requestData = {
      'id': deductionId,
      'company_id': _user.companyId,
      'user_id': _user.userId ?? ''
    };
    final data = await _postRequest(ApiEndpoints.deleteDeduction, requestData);

    if (data['status'] != 'success') {
      throw Exception('Failed to delete deduction: ${data['message']}');
    }
  }

  // Deductions: Fetches deductions for a company (admin-only or user-specific)
  Future<List<Map<String, dynamic>>> fetchDeductionsList(int companyId, {int? month, int? year}) async {
    _validateCompanyId(companyId);
    final queryParams = {
      'company_id': companyId.toString(),
      'user_id': _user.userId ?? ''
    };
    if (_user.role.toLowerCase() != 'admin') {
      queryParams['employee_id'] = _user.employeeId!;
    }
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final url = _buildQueryUrl(ApiEndpoints.fetchDeductionsList, queryParams);
    final data = await _getRequest(url);

    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['deductions'] ?? []);
    }
    throw Exception('Failed to fetch deductions: ${data['message']}');
  }

  // Benefits: Adds a new benefit for an employee (admin-only)
  Future<void> addBenefit(
      Map<String, dynamic> benefitData, int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can add benefits');
    }
    _validateCompanyId(companyId);

    final requestData = {...benefitData, 'company_id': companyId};
    final data = await _postRequest(ApiEndpoints.addBenefit, requestData);

    if (data['status'] != 'success') {
      throw Exception('Failed to add benefit: ${data['message']}');
    }
  }

  // Insurance: Adds an insurance relief record (admin-only)
  Future<void> addInsuranceRelief(
      Map<String, dynamic> reliefData, int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can add insurance relief');
    }
    _validateCompanyId(companyId);

    final requestData = {...reliefData, 'company_id': companyId};
    final data =
        await _postRequest(ApiEndpoints.addInsuranceRelief, requestData);

    if (data['status'] != 'success') {
      throw Exception('Failed to add insurance relief: ${data['message']}');
    }
  }

  // Insurance: Fetches insurance relief records
  Future<List<Map<String, dynamic>>> getInsuranceRelief({
    String? employeeId,
    int? companyId,
    int? month,
    int? year,
  }) async {
    final queryParams = <String, String>{};
    if (employeeId != null) {
      _validateEmployeeId(employeeId);
      queryParams['employee_id'] = employeeId;
    } else if (_user.role.toLowerCase() != 'admin') {
      queryParams['employee_id'] = _user.employeeId!;
    }
    if (companyId != null) {
      _validateCompanyId(companyId);
      queryParams['company_id'] = companyId.toString();
    } else {
      queryParams['company_id'] = _user.companyId.toString();
    }
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final data = queryParams.isEmpty
        ? await _getRequest('$_baseUrl${ApiEndpoints.getInsuranceRelief}')
        : await _postRequest(ApiEndpoints.getInsuranceRelief, queryParams);

    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['relief_records'] ?? []);
    }
    throw Exception('Failed to fetch insurance relief: ${data['message']}');
  }

  // Tax: Fetches P9 tax deduction data for an employee
  Future<List<Map<String, dynamic>>> fetchP9Data({
    required String employeeId,
    required int companyId,
    required int year,
  }) async {
    _validateCompanyId(companyId);
    _validateEmployeeId(employeeId);

    final data = await _postRequest(ApiEndpoints.getP9Data, {
      'employee_id': employeeId,
      'company_id': companyId,
      'year': year,
    });

    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['p9_data'] ?? []);
    }
    throw Exception('Failed to fetch P9 data: ${data['message']}');
  }

  // Statutory Calculations: Calculates PAYE for taxable income
  Future<double> calculatePAYE(
    double taxableIncome, {
    double personalRelief = 0,
    double nhifRelief = 0,
    double nssfContribution = 0,
    double housingLevy = 0,
  }) async {
    final data = await _postRequest(ApiEndpoints.calculatePAYE, {
      'taxable_income': taxableIncome,
      'personal_relief': personalRelief,
      'nhif_relief': nhifRelief,
      'nssf_contribution': nssfContribution,
      'housing_levy': housingLevy,
    });

    if (data['status'] == 'success') {
      return double.tryParse(data['paye'].toString()) ?? 0.0;
    }
    throw Exception('Failed to calculate PAYE: ${data['message']}');
  }

  // Statutory Calculations: Calculates NSSF for gross pay
  Future<double> calculateNSSF(double grossPay) async {
    final data = await _postRequest(ApiEndpoints.calculateNSSF, {
      'gross_pay': grossPay,
    });

    if (data['status'] == 'success') {
      return double.tryParse(data['nssf'].toString()) ?? 0.0;
    }
    throw Exception('Failed to calculate NSSF: ${data['message']}');
  }

  // Statutory Calculations: Calculates NHIF for gross pay
  Future<double> calculateNHIF(double grossPay) async {
    final data = await _postRequest(ApiEndpoints.calculateNHIF, {
      'gross_pay': grossPay,
    });

    if (data['status'] == 'success') {
      return double.tryParse(data['nhif'].toString()) ?? 0.0;
    }
    throw Exception('Failed to calculate NHIF: ${data['message']}');
  }

  // Company Management: Adds a new company (admin-only)
  Future<void> addCompany(Map<String, dynamic> companyData) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can add companies');
    }

    final data = await _postRequest(ApiEndpoints.addCompany, companyData);

    if (data['status'] != 'success') {
      throw Exception('Failed to add company: ${data['message']}');
    }
  }

  // Company Management: Fetches all companies (admin-only)
  Future<List<Map<String, dynamic>>> getCompanies() async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can view companies');
    }

    final data = await _getRequest('$_baseUrl${ApiEndpoints.getCompanies}');
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['companies'] ?? []);
    }
    throw Exception('Failed to fetch companies: ${data['message']}');
  }

  // Leave Management: Fetches leave balance for an employee
  Future<Map<String, dynamic>> getLeaveBalance({
    required int companyId,
    required String employeeId,
  }) async {
    _validateCompanyId(companyId);
    _validateEmployeeId(employeeId);

    final queryParams = {
      'company_id': companyId.toString(),
      'employee_id': employeeId,
    };
    final url = _buildQueryUrl(ApiEndpoints.getLeaveBalance, queryParams);
    final data = await _getRequest(url);

    if (data['status'] == 'success' && data['balance'] is Map) {
      return Map<String, dynamic>.from(data['balance']);
    }
    throw Exception('Failed to fetch leave balance: ${data['message']}');
  }

  // Leave Management: Submits a leave request
  Future<void> requestLeave(
      Map<String, dynamic> leaveData, int companyId) async {
    _validateCompanyId(companyId);

    final payload = {
      'company_id': companyId,
      'leave_data': {
        ...leaveData,
        'employee_id': _user.employeeId,
      },
    };
    final data = await _postRequest(ApiEndpoints.requestLeave, payload);

    if (data['status'] != 'success') {
      throw Exception('Failed to submit leave request: ${data['message']}');
    }
  }

  // Leave Management: Fetches leave requests for a company (admin-only)
  Future<List<Map<String, dynamic>>> getLeaveRequests(int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can view leave requests');
    }
    _validateCompanyId(companyId);

    final queryParams = {'company_id': companyId.toString()};
    final url = _buildQueryUrl(ApiEndpoints.getLeaveRequests, queryParams);
    final data = await _getRequest(url);

    if (data['status'] == 'success' && data['requests'] is List) {
      return List<Map<String, dynamic>>.from(data['requests']);
    }
    throw Exception('Failed to fetch leave requests: ${data['message']}');
  }

  // Leave Management: Updates the status of a leave request (admin-only)
  Future<void> updateLeaveStatus({
    required int requestId,
    required String status,
    required int companyId,
  }) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can update leave status');
    }
    _validateCompanyId(companyId);

    final payload = {
      'company_id': companyId,
      'request_id': requestId,
      'status': status,
    };
    final data = await _postRequest(ApiEndpoints.updateLeaveStatus, payload);

    if (data['status'] != 'success') {
      throw Exception('Failed to update leave status: ${data['message']}');
    }
  }

  // Reports: Fetches payroll summary for a company
  Future<List<Map<String, dynamic>>> getPayrollSummary(
      int companyId, int month, int year) async {
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.getSalaries, {
      'company_id': companyId,
      'month': month,
      'year': year,
    });

    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['salaries'] ?? []);
    }
    throw Exception('Failed to fetch payroll summary: ${data['message']}');
  }

  // Reports: Fetches leave report for a company
  Future<List<Map<String, dynamic>>> getLeaveReport(
      int companyId, int month, int year) async {
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.getLeaveRequests, {
      'company_id': companyId,
      'month': month,
      'year': year,
    });

    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['leave_requests'] ?? []);
    }
    throw Exception('Failed to fetch leave report: ${data['message']}');
  }

  // Reports: Fetches employee report for a company
  Future<List<Map<String, dynamic>>> getEmployeeReport(
      int companyId, int month, int year) async {
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.getEmployeeList, {
      'company_id': companyId,
      'month': month,
      'year': year,
    });

    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['employees'] ?? []);
    }
    throw Exception('Failed to fetch employee report: ${data['message']}');
  }

  // Attendance: Fetches attendance records for a company
  Future<List<Map<String, dynamic>>> getAttendanceRecords({
    required int companyId,
    required String date,
    String? employeeId,
  }) async {
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.getAttendanceRecords, {
      'company_id': companyId,
      'date': date,
      if (employeeId != null) 'employee_id': employeeId,
    });

    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['attendance_records'] ?? []);
    }
    throw Exception('Failed to fetch attendance records: ${data['message']}');
  }

  // Attendance: Records attendance for an employee
  Future<Map<String, dynamic>> recordAttendance({
    required int companyId,
    required String employeeId,
    required bool isClockIn,
  }) async {
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.recordAttendance, {
      'company_id': companyId,
      'employee_id': employeeId,
      'is_clock_in': isClockIn,
    });

    if (data['status'] == 'success') {
      return data;
    }
    throw Exception('Failed to record attendance: ${data['message']}');
  }

  // Support: Sends a support message (token-based)
  Future<void> sendSupportMessage(Map<String, dynamic> messageData) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/support/messages'),
      headers: {
        'Content-Type': 'application/json',
        if (_user.token != null) 'Authorization': 'Bearer ${_user.token}',
      },
      body: jsonEncode(messageData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }
    throw Exception('Failed to send support message: ${response.body}');
  }

  // Feedback: Sends feedback (token-based)
  Future<void> sendFeedback(Map<String, dynamic> feedbackData) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/feedback'),
      headers: {
        'Content-Type': 'application/json',
        if (_user.token != null) 'Authorization': 'Bearer ${_user.token}',
      },
      body: jsonEncode(feedbackData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }
    throw Exception('Failed to send feedback: ${response.body}');
  }

  // Preferences: Fetches notification preferences for a user
  Future<Map<String, dynamic>> getNotificationPreferences(String userId) async {
    final data = await _postRequest(ApiEndpoints.getNotificationPrefs, {
      'user_id': userId,
    });

    if (data['status'] == 'success') {
      return Map<String, dynamic>.from(data['preferences'] ?? {});
    }
    throw Exception(
        'Failed to fetch notification preferences: ${data['message']}');
  }

  // Preferences: Updates notification preferences for a user
  Future<void> updateNotificationPreferences(Map<String, dynamic> data) async {
    final response =
        await _postRequest(ApiEndpoints.updateNotificationPrefs, data);
    if (response['status'] != 'success') {
      throw Exception(
          'Failed to update notification preferences: ${response['message']}');
    }
  }

  // Preferences: Fetches privacy preferences for a user
  Future<Map<String, dynamic>> getPrivacyPreferences(String userId) async {
    final data = await _postRequest(ApiEndpoints.getPrivacyPrefs, {
      'user_id': userId,
    });

    if (data['status'] == 'success') {
      return Map<String, dynamic>.from(data['preferences'] ?? {});
    }
    throw Exception('Failed to fetch privacy preferences: ${data['message']}');
  }

  // Preferences: Updates privacy preferences for a user
  Future<void> updatePrivacyPreferences(Map<String, dynamic> data) async {
    final response = await _postRequest(ApiEndpoints.updatePrivacyPrefs, data);
    if (response['status'] != 'success') {
      throw Exception(
          'Failed to update privacy preferences: ${response['message']}');
    }
  }

  // Preferences: Fetches language preference for a user
  Future<Map<String, dynamic>> getLanguagePreference(String userId) async {
    final data = await _postRequest(ApiEndpoints.getLanguagePref, {
      'user_id': userId,
    });

    if (data['status'] == 'success') {
      return Map<String, dynamic>.from(data['preference'] ?? {});
    }
    throw Exception('Failed to fetch language preference: ${data['message']}');
  }

  // Preferences: Updates language preference for a user
  Future<void> updateLanguagePreference(Map<String, dynamic> data) async {
    final response = await _postRequest(ApiEndpoints.updateLanguagePref, data);
    if (response['status'] != 'success') {
      throw Exception(
          'Failed to update language preference: ${response['message']}');
    }
  }

  // Rates: Fetches SHIF rate for a company (admin-only)
  Future<Map<String, dynamic>> getSHIFRate(int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can view SHIF rate');
    }
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.getSHIFRate, {
      'company_id': companyId,
    });

    if (data['status'] == 'success') {
      return Map<String, dynamic>.from(data['rate'] ?? {});
    }
    throw Exception('Failed to fetch SHIF rate: ${data['message']}');
  }

  // Rates: Updates SHIF rate for a company (admin-only)
  Future<void> updateSHIFRate(Map<String, dynamic> data) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can update SHIF rate');
    }
    _validateCompanyId(int.parse(data['company_id'].toString()));

    final response = await _postRequest(ApiEndpoints.updateSHIFRate, data);
    if (response['status'] != 'success') {
      throw Exception('Failed to update SHIF rate: ${data['message']}');
    }
  }

  // Rates: Fetches Housing Levy rate for a company (admin-only)
  Future<Map<String, dynamic>> getHousingLevyRate(int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can view Housing Levy rate');
    }
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.getHousingLevyRate, {
      'company_id': companyId,
    });

    if (data['status'] == 'success') {
      return Map<String, dynamic>.from(data['rate'] ?? {});
    }
    throw Exception('Failed to fetch Housing Levy rate: ${data['message']}');
  }

  // Rates: Updates Housing Levy rate for a company (admin-only)
  Future<void> updateHousingLevyRate(Map<String, dynamic> data) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can update Housing Levy rate');
    }
    _validateCompanyId(int.parse(data['company_id'].toString()));

    final response =
        await _postRequest(ApiEndpoints.updateHousingLevyRate, data);
    if (response['status'] != 'success') {
      throw Exception(
          'Failed to update Housing Levy rate: ${response['message']}');
    }
  }

  // Rates: Fetches Loan rate for a company (admin-only)
  Future<Map<String, dynamic>> getLoanRate(int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can view Loan rate');
    }
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.getLoanRate, {
      'company_id': companyId,
    });

    if (data['status'] == 'success') {
      return Map<String, dynamic>.from(data['rate'] ?? {});
    }
    throw Exception('Failed to fetch Loan rate: ${data['message']}');
  }

  // Rates: Updates Loan rate for a company (admin-only)
  Future<void> updateLoanRate(Map<String, dynamic> data) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can update Loan rate');
    }
    _validateCompanyId(int.parse(data['company_id'].toString()));

    final response = await _postRequest(ApiEndpoints.updateLoanRate, data);
    if (response['status'] != 'success') {
      throw Exception('Failed to update Loan rate: ${response['message']}');
    }
  }

  // Rates: Fetches PAYE rates for a company (admin-only)
  Future<List<Map<String, dynamic>>> getPAYERates(int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can view PAYE rates');
    }
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.getPAYERates, {
      'company_id': companyId,
    });

    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['rates'] ?? []);
    }
    throw Exception('Failed to fetch PAYE rates: ${data['message']}');
  }

  // Rates: Updates PAYE rates for a company (admin-only)
  Future<void> updatePAYERates(Map<String, dynamic> data) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can update PAYE rates');
    }
    _validateCompanyId(int.parse(data['company_id'].toString()));

    final response = await _postRequest(ApiEndpoints.updatePAYERates, data);
    if (response['status'] != 'success') {
      throw Exception('Failed to update PAYE rates: ${response['message']}');
    }
  }

  // Rates: Fetches Overtime rate for a company (admin-only)
  Future<Map<String, dynamic>> getOvertimeRate(int companyId) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can view Overtime rate');
    }
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.getOvertimeRate, {
      'company_id': companyId,
    });

    if (data['status'] == 'success') {
      return Map<String, dynamic>.from(data['rate'] ?? {});
    }
    throw Exception('Failed to fetch Overtime rate: ${data['message']}');
  }

  // Rates: Updates Overtime rate for a company (admin-only)
  Future<void> updateOvertimeRate(Map<String, dynamic> data) async {
    if (_user.role.toLowerCase() != 'admin') {
      throw UnauthorizedAccessException(
          'Access denied: Only admins can update Overtime rate');
    }
    _validateCompanyId(int.parse(data['company_id'].toString()));

    final response = await _postRequest(ApiEndpoints.updateOvertimeRate, data);
    if (response['status'] != 'success') {
      throw Exception('Failed to update Overtime rate: ${response['message']}');
    }
  }

  // Logging: Logs a company action for audit purposes
  Future<void> logCompanyAction(Map<String, dynamic> data) async {
    final response = await _postRequest(ApiEndpoints.logCompanyAction, data);
    if (response['status'] != 'success') {
      throw Exception('Failed to log company action: ${response['message']}');
    }
  }

  // New Appraisal Methods

  // Fetches appraisals based on role (employee, manager, operator, director)
  Future<List<Map<String, dynamic>>> getAppraisals({
    required int companyId,
    required String role,
    String? employeeId,
    String? filter, // e.g., 'All', 'Pending', 'Approved', 'Rejected'
  }) async {
    _validateCompanyId(companyId);

    final now = DateTime.now(); // Current date: June 06, 2025, 02:49 PM EAT
    final queryParams = {
      'company_id': companyId.toString(),
      'role': role,
      'user_id': _user.userId ?? '',
      'month': now.month.toString(), // Default to current month (June)
      'year': now.year.toString(), // Default to current year (2025)
    };
    if (employeeId != null) {
      _validateEmployeeId(employeeId);
      queryParams['employee_id'] = employeeId;
    }
    if (filter != null) {
      queryParams['filter'] = filter;
    }

    final url = _buildQueryUrl(ApiEndpoints.getAppraisals, queryParams);
    final data = await _getRequest(url);

    if (data['status'] == 'success') {
      final appraisalsData =
          data['data']; // Changed from 'appraisals' to 'data'
      if (appraisalsData is List) {
        return appraisalsData
            .cast<Map<String, dynamic>>(); // Direct cast for better type safety
      } else {
        // Log unexpected type for debugging
        if (kDebugMode) {
          print(
            'Unexpected appraisals data type: ${appraisalsData.runtimeType}. Response: $data');
        }
        return []; // Return empty list for any unexpected type (including null or Map)
      }
    }
    throw Exception(
        'Failed to fetch appraisals: ${data['message'] ?? 'No message provided'}');
  }
  // Updates the status of an appraisal (manager/operator/director only)
  Future<void> updateAppraisalStatus({
    required String appraisalId,
    required String status, // e.g., 'approved', 'rejected'
    required int companyId,
  }) async {
    final allowedRoles = ['manager', 'operator', 'director'];
    if (!allowedRoles.contains(_user.role.toLowerCase())) {
      throw UnauthorizedAccessException(
          'Access denied: Only managers, operators, or directors can update appraisal status');
    }
    _validateCompanyId(companyId);

    final data = await _postRequest(ApiEndpoints.updateAppraisalStatus, {
      'appraisal_id': appraisalId,
      'status': status,
      'company_id': companyId,
      'user_id': _user.userId ?? '',
    });

    if (data['status'] != 'success') {
      throw Exception('Failed to update appraisal status: ${data['message']}');
    }
  }

  // Submits a self-appraisal (employee only)
  Future<void> submitSelfAppraisal({
    required String employeeId,
    required int companyId,
    required Map<String, dynamic>
        data, // Appraisal data (e.g., ratings, comments)
  }) async {
    if (_user.role.toLowerCase() != 'employee') {
      throw UnauthorizedAccessException(
          'Access denied: Only employees can submit self-appraisals');
    }
    _validateCompanyId(companyId);
    _validateEmployeeId(employeeId);

    final requestData = {
      'employee_id': employeeId,
      'company_id': companyId,
      'submitted_by': _user.employeeId, // Set submitted_by to logged-in user
      ...data,
    };
    final response =
        await _postRequest(ApiEndpoints.submitSelfAppraisal, requestData);

    if (response['status'] != 'success') {
      throw Exception(
          'Failed to submit self-appraisal: ${response['message']}');
    }
  }

  // Submits an employee appraisal (admin, manager, or supervisor only)
  Future<void> submitEmployeeAppraisal({
    required String employeeId,
    required int companyId,
    required Map<String, dynamic>
        data, // Appraisal data (e.g., ratings, comments)
  }) async {
    final allowedRoles = ['admin', 'manager', 'supervisor'];
    if (!allowedRoles.contains(_user.role.toLowerCase())) {
      throw UnauthorizedAccessException(
          'Access denied: Only admins, managers, or supervisors can submit employee appraisals');
    }
    _validateCompanyId(companyId);

    final requestData = {
      'employee_id': employeeId,
      'company_id': companyId,
      'role': _user.role
          .toLowerCase(), // Send the user's role for server validation
      'submitted_by': _user.employeeId, // Set submitted_by to logged-in user
      ...data,
    };
    final response =
        await _postRequest(ApiEndpoints.submitEmployeeAppraisal, requestData);

    if (response['status'] != 'success') {
      throw Exception(
          'Failed to submit employee appraisal: ${response['message']}');
    }
  }

  void dispose() {
    _client.close(); // Close HTTP client to prevent memory leaks
  }
}