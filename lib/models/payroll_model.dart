class Payroll {
  String employeeId;
  double grossSalary;
  double deductions;
  double netSalary;

  Payroll(
      {required this.employeeId,
      required this.grossSalary,
      required this.deductions,
      required this.netSalary});
}
