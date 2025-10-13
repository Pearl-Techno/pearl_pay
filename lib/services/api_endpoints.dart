class ApiEndpoints {
  // Authentication
  static const String login = 'login_api.php';

  // Employee Management
  static const String getEmployeeList = 'get_employeelist.php';
  static const String addEmployee = 'add_employee.php';
  static const String updateEmployee = 'update_employee.php';
  static const String activateEmployee = 'activate_employee.php';
  static const String deactivateEmployee = 'deactivate_employee.php';
  static const String getPositions = 'get_positions.php';

  // Payroll
  static const String saveSalary = 'pay_salaries.php';
  static const String getSalaries = 'get_paid_salaries.php';
  static const String calculatePAYE = 'calculate_paye.php';
  static const String calculateNSSF = 'calculate_nssf.php';
  static const String calculateNHIF = 'calculate_nhif.php';

  // Overtime
  static const String getOvertimeList = 'get_all_overtime.php';
  static const String addOvertime = 'add_overtime.php';
  static const String fetchOvertimeAmount = 'fetch_overtime_amount.php';

  // Deductions and Benefits
  static const String fetchAbsenteeismDeduction =
      'fetch_absenteeism_deduction.php';
  static const String fetchBenefits = 'fetch_non_cash_benefits.php';
  static const String fetchEarnings = 'fetch_earnings.php';
  static const String fetchDeductions = 'fetch_deductions.php';
  static const String addDeduction = 'add_deduction.php';
  static const String fetchDeductionsList = 'fetch_deductions_list.php';
  static const String addBenefit = 'add_benefit.php';
  static const String addInsuranceRelief = 'add_insurance_relief.php';
  static const String getInsuranceRelief = 'get_insurance_relief.php';

  // Pension
  static const String fetchPensionContributions =
      'fetch_pension_contributions.php';
  static const String fetchAllPensionContributions =
      'pension_contributions.php';
  static const String savePensionContribution = 'save_pension_contribution.php';

  // Loans
  static const String fetchLoanRepayment = 'fetch_loan_repayment.php';
  static const String fetchLoans = 'fetch_loans.php';
  static const String fetchLoansForEmployee = 'fetch_loans_for_employee.php';
  static const String addLoan = 'add_loan.php';
  static const String processLoanRepayment = 'process_loan_repayment.php';

  // Company Management
  static const String addCompany = 'add_company.php';
  static const String getCompanies = 'get_companies.php';

  // Leave Management
  static const String getLeaveBalance = 'get_leave_balance.php';
  static const String requestLeave = 'request_leave.php';
  static const String getLeaveRequests = 'get_leave_requests.php';
  static const String updateLeaveStatus = 'update_leave_status.php';

  // Reports
  static const String getP9Data = 'get_p9_data.php';

  // Attendance
  static const String getAttendanceRecords = 'get_attendance_records.php';
  static const String recordAttendance = 'record_attendance.php';

  // Logging
  static const String logCompanyAction = 'log_company_action.php';
  static const String logEmployeeAction = 'log_employee_action.php';

  // Preferences
  static const String getNotificationPrefs = 'get_notification_prefs.php';
  static const String updateNotificationPrefs = 'update_notification_prefs.php';
  static const String getPrivacyPrefs = 'get_privacy_prefs.php';
  static const String updatePrivacyPrefs = 'update_privacy_prefs.php';
  static const String getLanguagePref = 'get_language_prefs.php';
  static const String updateLanguagePref = 'update_language_prefs.php';

  // Rates
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
}
