import 'dart:developer' as developer;

class FormsGenerator {
  void generatePayslip(String employeeId) {
    developer.log('Payslip generated for Employee ID: $employeeId', name: 'FormsGenerator');
  }

  void generateP9Form(String employeeId) {
    developer.log('P9 Form generated for Employee ID: $employeeId', name: 'FormsGenerator');
  }

  void generateP10Form(String employeeId) {
    developer.log('P10 Form generated for Employee ID: $employeeId', name: 'FormsGenerator');
  }
}
