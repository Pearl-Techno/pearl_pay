import 'dart:convert';

import 'package:http/http.dart' as http;

/// Base URL for API requests
const String baseUrl = 'https://digiagekenya.com/pay_age/mobile_api/';

/// API Endpoints
class ApiEndpoints {
  static const String getEmployeeList = 'get_employeelist.php';
  static const String addEmployee = 'add_employee.php';
  static const String getPositions = 'get_positions.php';
  static const String getAllEmployees = 'get_all_employees.php';
  static const String getOvertimeList = 'get_all_overtime.php';
  static const String fetchAbsenteeismDeduction =
      'fetch_absenteeism_deduction.php';
  static const String fetchNonCashBenefits = 'fetch_non_cash_benefits.php';
  static const String fetchOvertimeAmount = 'fetch_overtime_amount.php';
  static const String fetchEarnings = 'fetch_earnings.php';
  static const String fetchDeductions = 'fetch_deductions.php';
  static const String fetchPensionContributions =
      'fetch_pension_contributions.php';
  static const String fetchLoanRepayment = 'fetch_loan_repayment.php';
  static const String calculatePAYE = 'calculate_paye.php';
  static const String calculateNSSF = 'calculate_nssf.php';
  static const String calculateNHIF = 'calculate_nhif.php';
  static const String addOvertime = 'add_overtime.php';
  static const String fetchLoans = 'fetch_loans.php';
  static const String fetchLoansForEmployee =
      'fetch_loans_for_employee.php?employee_id=';
  static const String fetchEmployees = 'fetch_employees.php';
  static const String processLoanRepayment = 'process_loan_repayment.php';
  static const String addLoan = 'add_loan.php';
  static const String saveSalary = 'pay_salaries.php';
  static const String getSalaries = 'get_paid_salaries.php';

  // New endpoints for deductions and benefits
  static const String addDeduction = 'add_deduction.php';
  static const String fetchDeductionsList = 'fetch_deductions_list.php';
  static const String addBenefit = 'add_benefit.php';
  static const String fetchBenefits = 'fetch_non_cash_benefits.php';

  static const String addInsuranceRelief = 'add_insurance_relief.php';
  static const String getInsuranceRelief = 'get_insurance_relief.php';

  // New endpoint for adding company
  static const String addCompany = 'add_company.php';
  static const String getCompanies = 'get_companies.php';

    // New leave management endpoints
  static const String getLeaveBalance = 'get_leave_balance.php';
  static const String requestLeave = 'request_leave.php';
  static const String getLeaveRequests = 'get_leave_requests.php';
  static const String updateLeaveStatus = 'update_leave_status.php';

  // New endpoint for fetching P9 data
  static const String getP9Data = 'get_p9_data.php';
}

/// Custom Exceptions
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class ServerException implements Exception {
  final String message;
  final int statusCode;
  ServerException(this.message, this.statusCode);
}

/// Service class for handling backend API interactions
class ApiService {
  final http.Client client;

  ApiService({required this.client});

  /// Helper method for making HTTP GET requests
  Future<Map<String, dynamic>> _getRequest(String endpoint) async {
    try {
      final response = await client.get(Uri.parse('$baseUrl$endpoint'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ServerException(
            'Server error: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      throw NetworkException('Network error: $e');
    }
  }

   /// Helper method for making HTTP POST requests
  Future<Map<String, dynamic>> _postRequest(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ServerException(
            'Server error: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      throw NetworkException('Network error: $e');
    }
  }

  /// Fetches the list of employees from the backend.
  Future<List<Map<String, dynamic>>> getEmployeeList() async {
    final data = await _getRequest(ApiEndpoints.getEmployeeList);
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['employees']);
    } else {
      throw Exception('Failed to load employees: ${data['message']}');
    }
  }

  /// Adds a new employee to the backend.
  Future<bool> addEmployee(Map<String, dynamic> employeeData) async {
    final data = await _postRequest(ApiEndpoints.addEmployee, employeeData);
    if (data['status'] == 'success') {
      return true;
    } else {
      throw Exception('Failed to add employee: ${data['message']}');
    }
  }

  /// Fetches the list of positions from the backend.
  Future<List<Map<String, dynamic>>> getPositions() async {
    final data = await _getRequest(ApiEndpoints.getPositions);
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['positions']);
    } else {
      throw Exception('Failed to load positions: ${data['message']}');
    }
  }

  /// Fetches the list of all employees from the backend.
  Future<List<Map<String, dynamic>>> getAllEmployees() async {
    final data = await _getRequest(ApiEndpoints.getAllEmployees);
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['employees']);
    } else {
      throw Exception('Failed to load all employees: ${data['message']}');
    }
  }

  /// Fetches the list of overtime records from the backend.
  Future<List<Map<String, dynamic>>> getOvertimeList() async {
    final data = await _getRequest(ApiEndpoints.getOvertimeList);
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['overtime_records']);
    } else {
      throw Exception('Failed to fetch overtime records: ${data['message']}');
    }
  }

  /// Fetches absenteeism deduction for an employee for a specific month and year.
  Future<double> fetchAbsenteeismDeduction(
      String employeeId, int month, int year) async {
    final data = await _postRequest(ApiEndpoints.fetchAbsenteeismDeduction, {
      'employee_id': employeeId,
      'month': month,
      'year': year,
    });
    if (data['status'] == 'success') {
      return double.tryParse(data['deduction'].toString()) ?? 0.0;
    } else {
      throw Exception(
          'Failed to fetch absenteeism deduction: ${data['message']}');
    }
  }

  /// Fetches non-cash benefits for an employee for a specific month and year.
  Future<List<Map<String, dynamic>>> fetchNonCashBenefits(
      String employeeId, int month, int year) async {
    final data = await _postRequest(ApiEndpoints.fetchNonCashBenefits, {
      'employee_id': employeeId,
      'month': month,
      'year': year,
    });
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['benefits']);
    } else {
      throw Exception('Failed to fetch non-cash benefits: ${data['message']}');
    }
  }

  /// Fetches overtime amount for an employee for a specific month and year.
  Future<double> fetchOvertimeAmount(
      String employeeId, int month, int year) async {
    final data = await _postRequest(ApiEndpoints.fetchOvertimeAmount, {
      'employee_id': employeeId,
      'month': month,
      'year': year,
    });
    if (data['status'] == 'success') {
      return double.tryParse(data['amount'].toString()) ?? 0.0;
    } else {
      throw Exception('Failed to fetch overtime amount: ${data['message']}');
    }
  }

  /// Fetches earnings for an employee for a specific month and year.
  Future<List<Map<String, dynamic>>> fetchEarnings(
      String employeeId, int month, int year) async {
    final data = await _postRequest(ApiEndpoints.fetchEarnings, {
      'employee_id': employeeId,
      'month': month,
      'year': year,
    });
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['earnings']);
    } else {
      throw Exception('Failed to fetch earnings: ${data['message']}');
    }
  }

  /// Fetches deductions for an employee for a specific month and year.
  Future<List<Map<String, dynamic>>> fetchDeductions(
      String employeeId, int month, int year) async {
    final data = await _postRequest(ApiEndpoints.fetchDeductions, {
      'employee_id': employeeId,
      'month': month,
      'year': year,
    });
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['deductions']);
    } else {
      throw Exception('Failed to fetch deductions: ${data['message']}');
    }
  }

  /// Fetches pension contributions for an employee for a specific month and year.
  Future<double> fetchPensionContributions(
      String employeeId, int month, int year) async {
    final data = await _postRequest(ApiEndpoints.fetchPensionContributions, {
      'employee_id': employeeId,
      'month': month,
      'year': year,
    });
    if (data['status'] == 'success') {
      return double.tryParse(data['total_contribution'].toString()) ?? 0.0;
    } else {
      throw Exception(
          'Failed to fetch pension contributions: ${data['message']}');
    }
  }

  /// Fetches loan repayment amount for an employee for a specific month and year.
  Future<double> fetchLoanRepayment(
      String employeeId, int month, int year) async {
    final data = await _postRequest(ApiEndpoints.fetchLoanRepayment, {
      'employee_id': employeeId,
      'month': month,
      'year': year,
    });
    if (data['status'] == 'success') {
      return double.tryParse(data['total_repayment'].toString()) ?? 0.0;
    } else {
      throw Exception('Failed to fetch loan repayment: ${data['message']}');
    }
  }

  /// Calculates PAYE for a given taxable income and other parameters.
  Future<double> calculatePAYE(double taxableIncome,
      {double personalRelief = 0,
      double nhifRelief = 0,
      double nssfContribution = 0,
      double housingLevy = 0}) async {
    final data = await _postRequest(ApiEndpoints.calculatePAYE, {
      'taxable_income': taxableIncome,
      'personal_relief': personalRelief,
      'nhif_relief': nhifRelief,
      'nssf_contribution': nssfContribution,
      'housing_levy': housingLevy,
    });
    if (data['status'] == 'success') {
      return double.tryParse(data['paye'].toString()) ?? 0.0;
    } else {
      throw Exception('Failed to calculate PAYE: ${data['message']}');
    }
  }

  /// Calculates NSSF for a given gross pay.
  Future<double> calculateNSSF(double grossPay) async {
    final data = await _postRequest(ApiEndpoints.calculateNSSF, {
      'gross_pay': grossPay,
    });
    if (data['status'] == 'success') {
      return double.tryParse(data['nssf'].toString()) ?? 0.0;
    } else {
      throw Exception('Failed to calculate NSSF: ${data['message']}');
    }
  }

  /// Calculates NHIF for a given gross pay.
  Future<double> calculateNHIF(double grossPay) async {
    final data = await _postRequest(ApiEndpoints.calculateNHIF, {
      'gross_pay': grossPay,
    });
    if (data['status'] == 'success') {
      return double.tryParse(data['nhif'].toString()) ?? 0.0;
    } else {
      throw Exception('Failed to calculate NHIF: ${data['message']}');
    }
  }

  /// Adds a new overtime record to the backend.
  Future<bool> addOvertime(Map<String, dynamic> overtimeData) async {
    final data = await _postRequest(ApiEndpoints.addOvertime, overtimeData);
    if (data['status'] == 'success') {
      return true;
    } else {
      throw Exception('Failed to add overtime: ${data['message']}');
    }
  }

  /// Fetches all loan records from the backend.
  Future<List<Map<String, dynamic>>> fetchLoans() async {
    final data = await _getRequest(ApiEndpoints.fetchLoans);
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['loans']);
    } else {
      throw Exception('Failed to fetch loans: ${data['message']}');
    }
  }

  /// Fetches loans for a specific employee from the backend.
  Future<List<Map<String, dynamic>>> fetchLoansForEmployee(
      String employeeId) async {
    final response = await client
        .get(Uri.parse('${ApiEndpoints.fetchLoansForEmployee}$employeeId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(data['loans']);
      } else {
        throw Exception(
            'Failed to fetch loans for employee: ${data['message']}');
      }
    } else {
      throw Exception('Failed to load loans for employee');
    }
  }

  /// Fetches all employees from the backend.
  Future<List<Map<String, dynamic>>> fetchEmployees() async {
    final data = await _getRequest(ApiEndpoints.fetchEmployees);
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['employees']);
    } else {
      throw Exception('Failed to fetch employees: ${data['message']}');
    }
  }

  /// Processes loan repayment for an employee.
  Future<void> processLoanRepayment(Map<String, dynamic> repaymentData) async {
    final data =
        await _postRequest(ApiEndpoints.processLoanRepayment, repaymentData);
    if (data['status'] != 'success') {
      throw Exception('Failed to process loan repayment: ${data['message']}');
    }
  }

  /// Adds a new loan to the backend.
  Future<void> addLoan(Map<String, dynamic> loanData) async {
    final data = await _postRequest(ApiEndpoints.addLoan, loanData);
    if (data['status'] != 'success') {
      throw Exception('Failed to add loan: ${data['message']}');
    }
  }

  /// Saves salary data for an employee or multiple employees.
  Future<void> saveSalary(Map<String, dynamic> salaryData) async {
    try {
      final response = await _postRequest(ApiEndpoints.saveSalary, salaryData);

      if (response['status'] != 'success') {
        throw Exception('Failed to save salary: ${response['message']}');
      }
    } catch (e) {
      throw Exception('Error saving salary data: $e');
    }
  }

  /// Fetches the list of saved salaries.
  Future<List<Map<String, dynamic>>> getSalaries() async {
    final data = await _getRequest(ApiEndpoints.getSalaries);
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['salaries']);
    } else {
      throw Exception('Failed to fetch salaries: ${data['message']}');
    }
  }

  /// Adds a new deduction to the backend.
  Future<void> addDeduction(Map<String, dynamic> deductionData) async {
    final data = await _postRequest(ApiEndpoints.addDeduction, deductionData);
    if (data['status'] != 'success') {
      throw Exception('Failed to add deduction: ${data['message']}');
    }
  }

  /// Fetches the list of deductions from the backend.
  Future<List<Map<String, dynamic>>> fetchDeductionsList() async {
    final data = await _getRequest(ApiEndpoints.fetchDeductionsList);
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['deductions']);
    } else {
      throw Exception('Failed to fetch deductions: ${data['message']}');
    }
  }

  /// Adds a new benefit to the backend.
  Future<void> addBenefit(Map<String, dynamic> benefitData) async {
    final data = await _postRequest(ApiEndpoints.addBenefit, benefitData);
    if (data['status'] != 'success') {
      throw Exception('Failed to add benefit: ${data['message']}');
    }
  }

  /// Fetches non-cash benefits for a specific employee, month, and year from the backend.
  Future<List<Map<String, dynamic>>> fetchBenefits(
      String employeeId, int month, int year) async {
    final data = await _postRequest(ApiEndpoints.fetchBenefits, {
      'employee_id': employeeId,
      'month': month,
      'year': year,
    });
    if (data['status'] == 'success') {
      // Filter to return only non-cash benefits
      final allBenefits = List<Map<String, dynamic>>.from(data['benefits']);
      return allBenefits
          .where((benefit) => benefit['benefit_type'] == 'Non-Cash')
          .toList();
    } else {
      throw Exception('Failed to fetch benefits: ${data['message']}');
    }
  }

  /// Adds a new insurance relief record to the backend
  Future<void> addInsuranceRelief(Map<String, dynamic> reliefData) async {
    final data =
        await _postRequest(ApiEndpoints.addInsuranceRelief, reliefData);
    if (data['status'] != 'success') {
      throw Exception('Failed to add insurance relief: ${data['message']}');
    }
  }

  /// Fetches insurance relief records from the backend
  /// Can filter by employeeId, month, and year if provided
  Future<List<Map<String, dynamic>>> getInsuranceRelief({
    String? employeeId,
    int? month,
    int? year,
  }) async {
    // Build query parameters
    Map<String, dynamic> queryParams = {};
    if (employeeId != null) queryParams['employee_id'] = employeeId;
    if (month != null) queryParams['month'] = month;
    if (year != null) queryParams['year'] = year;

    final data;
    if (queryParams.isEmpty) {
      // Simple GET request if no parameters
      data = await _getRequest(ApiEndpoints.getInsuranceRelief);
    } else {
      // POST request with parameters
      data = await _postRequest(ApiEndpoints.getInsuranceRelief, queryParams);
    }

    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['relief_records']);
    } else {
      throw Exception('Failed to fetch insurance relief: ${data['message']}');
    }
  }

  /// Adds a new company to the backend.
  Future<bool> addCompany(Map<String, dynamic> companyData) async {
    final data = await _postRequest(ApiEndpoints.addCompany, companyData);
    if (data['status'] == 'success') {
      return true;
    } else {
      throw Exception('Failed to add company: ${data['message']}');
    }
  }

  /// Fetches the list of companies from the backend.
  Future<List<Map<String, dynamic>>> getCompanies() async {
    final data = await _getRequest(ApiEndpoints.getCompanies);
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['companies']);
    } else {
      throw Exception('Failed to fetch companies: ${data['message']}');
    }
  }

  // New leave management methods
  /// Fetches the leave balance for the authenticated user
  Future<Map<String, dynamic>> getLeaveBalance() async {
    final data = await _getRequest(ApiEndpoints.getLeaveBalance);
    if (data['status'] == 'success') {
      return data['balance']; // Expecting {'days_remaining': int}
    } else {
      throw Exception('Failed to fetch leave balance: ${data['message']}');
    }
  }

  /// Submits a new leave request
  Future<void> requestLeave(Map<String, dynamic> leaveData) async {
    final data = await _postRequest(ApiEndpoints.requestLeave, leaveData);
    if (data['status'] != 'success') {
      throw Exception('Failed to submit leave request: ${data['message']}');
    }
  }

  /// Fetches all leave requests (for admins) or user-specific requests
  Future<List<Map<String, dynamic>>> getLeaveRequests() async {
    final data = await _getRequest(ApiEndpoints.getLeaveRequests);
    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['requests']);
    } else {
      throw Exception('Failed to fetch leave requests: ${data['message']}');
    }
  }

  /// Updates the status of a leave request (e.g., Approved, Rejected)
  Future<void> updateLeaveStatus(int requestId, String status) async {
    final data = await _postRequest(
      '${ApiEndpoints.updateLeaveStatus}?request_id=$requestId',
      {'status': status},
    );
    if (data['status'] != 'success') {
      throw Exception('Failed to update leave status: ${data['message']}');
    }
  }

   /// Fetches P9 tax deduction data for a specific year.
Future<List<Map<String, dynamic>>> fetchP9Data({
    required String employeeId,
    required int year,
  }) async {
    try {
      final data = await _postRequest(ApiEndpoints.getP9Data, {
        'employee_id': employeeId,
        'year': year,
      });
      if (data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(data['p9_data']);
      } else {
        throw Exception('Failed to fetch P9 data: ${data['message']}');
      }
    } catch (e) {
      throw Exception('Error fetching P9 data: $e');
    }
  }


}
