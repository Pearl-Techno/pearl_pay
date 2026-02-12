import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

// Constants
class OvertimeConstants {
  static const double defaultMonthlyHours = 208.0;
  static const int itemsPerPage = 10;
  static const List<double> rateMultipliers = [1.5, 2.0, 3.0];
  static const Color primaryColor = Color(0xFF0D47A1);
  static const Color secondaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF00B0FF);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF1A237E);
  static const Color subtitleColor = Color(0xFF546E7A);
}

// Validators
class OvertimeValidators {
  static String? validateHours(String? value) {
    if (value == null || value.isEmpty) return 'Please enter overtime hours';
    final hours = double.tryParse(value);
    if (hours == null || hours < 0) return 'Please enter valid hours';
    return null;
  }
  
  static String? validateMinutes(String? value) {
    if (value == null || value.isEmpty) return 'Please enter overtime minutes';
    final minutes = double.tryParse(value);
    if (minutes == null || minutes < 0) return 'Please enter valid minutes';
    if (minutes >= 60) return 'Minutes must be less than 60';
    return null;
  }
  
  static String? validateMonthlyHours(String? value) {
    if (value == null || value.isEmpty) return 'Please enter monthly hours';
    final hours = double.tryParse(value);
    if (hours == null || hours <= 0) return 'Please enter valid monthly hours';
    return null;
  }
}

// Calculator
class OvertimeCalculator {
  static double calculateAmount({
    required double basicPay,
    required double monthlyHours,
    required double hours,
    required double minutes,
    required double rateMultiplier,
  }) {
    final hourlyRate = basicPay / monthlyHours;
    final totalHours = hours + (minutes / 60);
    return hourlyRate * rateMultiplier * totalHours;
  }
}

class OvertimeScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;
  
  const OvertimeScreen({
    super.key,
    required this.apiService,
    required this.user,
  });

  @override
  OvertimeScreenState createState() => OvertimeScreenState();
}

class OvertimeScreenState extends State<OvertimeScreen> {
  String? selectedEmployee;
  String? selectedCompany;
  DateTime? selectedDate;
  final TextEditingController hoursController = TextEditingController();
  final TextEditingController minutesController = TextEditingController();
  final TextEditingController monthlyHoursController = TextEditingController(text: '208');
  final TextEditingController filterController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  int? _selectedMonth;
  int? _selectedYear;
  List<Map<String, dynamic>> employees = [];
  List<String> companyNames = [];
  List<Map<String, dynamic>> overtimeRecords = [];
  List<Map<String, dynamic>> filteredRecords = [];
  bool isLoading = false;
  int currentPage = 0;
  final int itemsPerPage = 10;
  final ScrollController _scrollController = ScrollController();

  // Statistics
  double _totalOvertimeAmount = 0.0;
  int _totalOvertimeRecords = 0;

  @override
  void initState() {
    super.initState();
    selectedCompany = widget.user.companyName;
    companyNames = [widget.user.companyName ?? 'Unknown'];
    _selectedMonth = null;
    _selectedYear = null;
    _fetchEmployees();
    _fetchOvertimeRecords();
    filterController.addListener(_updateFilteredRecords);
  }

  @override
  void dispose() {
    filterController.removeListener(_updateFilteredRecords);
    filterController.dispose();
    hoursController.dispose();
    minutesController.dispose();
    monthlyHoursController.dispose();
    _dateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    setState(() => isLoading = true);
    try {
      employees = await widget.apiService.getEmployeeList(widget.user.companyId);
      setState(() {
        companyNames = [widget.user.companyName ?? 'Unknown'];
      });
    } catch (e) {
      _showErrorSnackBar('Error fetching employees: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchOvertimeRecords() async {
    setState(() => isLoading = true);
    try {
      overtimeRecords = await widget.apiService.getOvertimeList(
        widget.user.companyId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      
      // Process records
      for (var record in overtimeRecords) {
        final employee = employees.firstWhere(
          (e) => e['employee_id'].toString() == record['employee_id'].toString(),
          orElse: () => {'company_name': widget.user.companyName, 'fullname': 'Unknown'},
        );
        record['company_name'] = employee['company_name'] ?? widget.user.companyName;
        record['fullname'] = employee['fullname'] ?? record['fullname'] ?? 'Unknown';
        if (record['date_overtime'] != null && DateTime.tryParse(record['date_overtime']) == null) {
          record['date_overtime'] = null;
        }
      }
      
      _calculateStatistics();
      _updateFilteredRecords();
      
    } catch (e) {
      _showErrorSnackBar('Error fetching overtime records: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _calculateStatistics() {
    _totalOvertimeAmount = overtimeRecords.fold(0.0, (sum, record) {
      final amount = double.tryParse(record['amount']?.toString() ?? '0') ?? 0.0;
      return sum + amount;
    });
    _totalOvertimeRecords = overtimeRecords.length;
  }

  void _updateFilteredRecords() {
    final filter = filterController.text.toLowerCase();
    setState(() {
      filteredRecords = overtimeRecords.where((record) {
        final dateOvertime = record['date_overtime'] != null ? DateTime.tryParse(record['date_overtime']) : null;
        final employeeId = record['employee_id']?.toString().toLowerCase() ?? '';
        final fullname = record['fullname']?.toString().toLowerCase() ?? '';
        final companyName = record['company_name']?.toString().toLowerCase() ?? '';
        final matchesMonth = _selectedMonth == null || (dateOvertime != null && dateOvertime.month == _selectedMonth);
        final matchesYear = _selectedYear == null || (dateOvertime != null && dateOvertime.year == _selectedYear);
        final matchesKeyword = employeeId.contains(filter) ||
            fullname.contains(filter) ||
            (record['date_overtime']?.toLowerCase() ?? '').contains(filter) ||
            companyName.contains(filter);
        return matchesMonth && matchesYear && matchesKeyword;
      }).toList();
      currentPage = 0;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: OvertimeConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: OvertimeConstants.primaryColor),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: OvertimeConstants.primaryColor),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showAddOvertimeDialog() {
    final formKey = GlobalKey<FormState>();
    double? calculatedAmount;
    double? selectedRateMultiplier;
    String? employeeId;

    showDialog(
      context: context,
      builder: (context) {
        String? dialogSelectedCompany = selectedCompany;
        String? dialogSelectedEmployee = selectedEmployee;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredEmployees = employees
                .where((e) => e['company_name'] == dialogSelectedCompany)
                .toList();

            void calculateOvertime() {
              if (formKey.currentState == null || !formKey.currentState!.validate()) {
                setDialogState(() => calculatedAmount = null);
                return;
              }

              final hoursText = hoursController.text;
              final minutesText = minutesController.text;
              final monthlyHoursText = monthlyHoursController.text;

              final hours = double.tryParse(hoursText) ?? 0.0;
              final minutes = double.tryParse(minutesText) ?? 0.0;
              final monthlyHours = double.tryParse(monthlyHoursText) ?? 208.0;

              if (hours <= 0 || minutes < 0 || minutes >= 60 || monthlyHours <= 0) {
                setDialogState(() => calculatedAmount = null);
                return;
              }

              final empId = dialogSelectedEmployee;
              if (empId == null) {
                setDialogState(() => calculatedAmount = null);
                return;
              }

              final employee = employees.firstWhere(
                (e) => e['id'].toString() == empId,
                orElse: () => {'basic': 0},
              );

              double basicPay = 0.0;
              if (employee['basic'] is num) {
                basicPay = (employee['basic'] as num).toDouble();
              } else if (employee['basic'] is String) {
                basicPay = double.tryParse(employee['basic']) ?? 0.0;
              }

              if (basicPay <= 0 || selectedRateMultiplier == null) {
                setDialogState(() => calculatedAmount = null);
                return;
              }

              final amount = OvertimeCalculator.calculateAmount(
                basicPay: basicPay,
                monthlyHours: monthlyHours,
                hours: hours,
                minutes: minutes,
                rateMultiplier: selectedRateMultiplier!,
              );

              setDialogState(() {
                calculatedAmount = amount;
              });
            }

            hoursController.addListener(calculateOvertime);
            minutesController.addListener(calculateOvertime);
            monthlyHoursController.addListener(calculateOvertime);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: OvertimeConstants.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: OvertimeConstants.primaryColor.withAlpha(26),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.access_time, color: OvertimeConstants.primaryColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Add New Overtime',
                                style: TextStyle(
                                  color: OvertimeConstants.textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                hoursController.removeListener(calculateOvertime);
                                minutesController.removeListener(calculateOvertime);
                                monthlyHoursController.removeListener(calculateOvertime);
                                if (context.mounted) Navigator.pop(context);
                              },
                              icon: Icon(Icons.close, color: OvertimeConstants.subtitleColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildDialogField(
                                readOnly: true,
                                initialValue: widget.user.companyName ?? 'Unknown',
                                label: 'Company',
                                icon: Icons.business,
                              ),
                              const SizedBox(height: 16),
                              _buildEmployeeDropdown(
                                value: dialogSelectedEmployee,
                                filteredEmployees: filteredEmployees,
                                onChanged: (value) {
                                  setDialogState(() {
                                    dialogSelectedEmployee = value;
                                    employeeId = employees
                                        .firstWhere(
                                            (e) => e['id'].toString() == value,
                                            orElse: () => {'employee_id': null})['employee_id']
                                        ?.toString();
                                  });
                                  setState(() {
                                    selectedEmployee = value;
                                  });
                                  calculateOvertime();
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildDateField(),
                              const SizedBox(height: 16),
                              _buildDialogField(
                                controller: monthlyHoursController,
                                label: 'Total Monthly Hours',
                                icon: Icons.schedule,
                                keyboardType: TextInputType.number,
                                validator: (value) => OvertimeValidators.validateMonthlyHours(value),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDialogField(
                                      controller: hoursController,
                                      label: 'Hours',
                                      icon: Icons.timer,
                                      keyboardType: TextInputType.number,
                                      validator: (value) => OvertimeValidators.validateHours(value),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDialogField(
                                      controller: minutesController,
                                      label: 'Minutes',
                                      icon: Icons.timer_outlined,
                                      keyboardType: TextInputType.number,
                                      validator: (value) => OvertimeValidators.validateMinutes(value),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildRateDropdown(
                                value: selectedRateMultiplier,
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedRateMultiplier = value;
                                  });
                                  calculateOvertime();
                                },
                              ),
                              const SizedBox(height: 20),
                              if (calculatedAmount != null)
                                _buildAmountPreview(calculatedAmount!),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        hoursController.removeListener(calculateOvertime);
                                        minutesController.removeListener(calculateOvertime);
                                        monthlyHoursController.removeListener(calculateOvertime);
                                        Navigator.pop(context);
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        side: BorderSide(color: OvertimeConstants.primaryColor),
                                      ),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(color: OvertimeConstants.primaryColor),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        if (formKey.currentState!.validate() &&
                                            calculatedAmount != null &&
                                            selectedRateMultiplier != null) {
                                          await _addOvertimeRecord(
                                            employeeId!,
                                            (double.parse(hoursController.text) + 
                                             double.parse(minutesController.text) / 60).toStringAsFixed(2),
                                            selectedRateMultiplier!,
                                            calculatedAmount!,
                                          );
                                          hoursController.removeListener(calculateOvertime);
                                          minutesController.removeListener(calculateOvertime);
                                          monthlyHoursController.removeListener(calculateOvertime);
                                          if (context.mounted) Navigator.pop(context);
                                        } else {
                                          _showErrorSnackBar('Please ensure all fields are valid and amount is calculated.');
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: OvertimeConstants.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 2,
                                      ),
                                      child: Text('Add Overtime'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: OvertimeConstants.subtitleColor),
        prefixIcon: Icon(icon, color: OvertimeConstants.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OvertimeConstants.subtitleColor.withAlpha(77)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OvertimeConstants.subtitleColor.withAlpha(77)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OvertimeConstants.primaryColor),
        ),
        filled: true,
        fillColor: OvertimeConstants.backgroundColor,
      ),
    );
  }

  Widget _buildEmployeeDropdown({
    required String? value,
    required List<Map<String, dynamic>> filteredEmployees,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      items: filteredEmployees.isEmpty
          ? [
              DropdownMenuItem<String>(
                value: null,
                enabled: false,
                child: Text(
                  'No employees available',
                  style: TextStyle(color: OvertimeConstants.subtitleColor, fontStyle: FontStyle.italic),
                ),
              )
            ]
          : filteredEmployees
              .map((e) => DropdownMenuItem<String>(
                    value: e['id'].toString(),
                    child: Text(
                      '${e['employee_id']} - ${e['fullname']}',
                      style: TextStyle(color: OvertimeConstants.textColor),
                    ),
                  ))
              .toList(),
      decoration: InputDecoration(
        labelText: 'Select Employee',
        labelStyle: TextStyle(color: OvertimeConstants.subtitleColor),
        prefixIcon: Icon(Icons.person, color: OvertimeConstants.primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OvertimeConstants.subtitleColor.withAlpha(77)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OvertimeConstants.primaryColor),
        ),
        filled: true,
        fillColor: OvertimeConstants.backgroundColor,
      ),
      validator: (value) => value == null ? 'Please select an employee' : null,
      dropdownColor: OvertimeConstants.cardColor,
      icon: Icon(Icons.arrow_drop_down, color: OvertimeConstants.primaryColor),
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Select Date',
        labelStyle: TextStyle(color: OvertimeConstants.subtitleColor),
        prefixIcon: Icon(Icons.calendar_today, color: OvertimeConstants.primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OvertimeConstants.subtitleColor.withAlpha(77)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OvertimeConstants.primaryColor),
        ),
        filled: true,
        fillColor: OvertimeConstants.backgroundColor,
        suffixIcon: IconButton(
          icon: Icon(Icons.calendar_month, color: OvertimeConstants.primaryColor),
          onPressed: () => _selectDate(context),
        ),
      ),
      validator: (value) => selectedDate == null ? 'Please select a date' : null,
    );
  }

  Widget _buildRateDropdown({
    required double? value,
    required ValueChanged<double?> onChanged,
  }) {
    return DropdownButtonFormField<double>(
      initialValue: value,
      onChanged: onChanged,
      items: OvertimeConstants.rateMultipliers
          .map((rate) => DropdownMenuItem(
                value: rate,
                child: Text(
                  '${rate}x Rate',
                  style: TextStyle(color: OvertimeConstants.textColor),
                ),
              ))
          .toList(),
      decoration: InputDecoration(
        labelText: 'Overtime Rate',
        labelStyle: TextStyle(color: OvertimeConstants.subtitleColor),
        prefixIcon: Icon(Icons.attach_money, color: OvertimeConstants.primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OvertimeConstants.subtitleColor.withAlpha(77)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OvertimeConstants.primaryColor),
        ),
        filled: true,
        fillColor: OvertimeConstants.backgroundColor,
      ),
      validator: (value) => value == null ? 'Please select a rate' : null,
      dropdownColor: OvertimeConstants.cardColor,
      icon: Icon(Icons.arrow_drop_down, color: OvertimeConstants.primaryColor),
    );
  }

  Widget _buildAmountPreview(double amount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OvertimeConstants.successColor.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OvertimeConstants.successColor.withAlpha(77)),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate, color: OvertimeConstants.successColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calculated Amount',
                  style: TextStyle(
                    color: OvertimeConstants.successColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'KES ${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: OvertimeConstants.successColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addOvertimeRecord(
    String employeeId,
    String totalHours,
    double rateMultiplier,
    double calculatedAmount,
  ) async {
    try {
      Map<String, dynamic> newRecord = {
        'employee_id': employeeId,
        'company_name': selectedCompany,
        'hours': totalHours,
        'rate': rateMultiplier.toString(),
        'date_overtime': selectedDate!.toIso8601String(),
        'amount': calculatedAmount.toStringAsFixed(2),
      };

      await widget.apiService.addOvertime(newRecord, widget.user.companyId);
      if (!mounted) return;
      _showSuccessSnackBar('Overtime added successfully');
      _fetchOvertimeRecords();

      setState(() {
        selectedEmployee = null;
        selectedCompany = widget.user.companyName;
        selectedDate = null;
        hoursController.clear();
        minutesController.clear();
        monthlyHoursController.text = '208';
        _dateController.clear();
      });
    } catch (e) {
      _showErrorSnackBar('Failed to add overtime: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout', style: TextStyle(color: OvertimeConstants.textColor)),
        content: Text('Are you sure you want to log out?', style: TextStyle(color: OvertimeConstants.subtitleColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: OvertimeConstants.primaryColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Widget _buildOvertimeTable() {
    if (filteredRecords.isEmpty) {
      return _buildEmptyState();
    }

    int start = currentPage * itemsPerPage;
    int end = (currentPage + 1) * itemsPerPage;
    end = end > filteredRecords.length ? filteredRecords.length : end;
    final currentRecords = filteredRecords.sublist(start, end);

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 60,
            headingRowHeight: 56,
            horizontalMargin: 24,
            headingTextStyle: TextStyle(
              color: OvertimeConstants.textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
            dataTextStyle: TextStyle(
              color: OvertimeConstants.textColor,
              fontSize: 12,
            ),
            headingRowColor: WidgetStateProperty.all(OvertimeConstants.backgroundColor),
            columns: _buildTableColumns(),
            rows: currentRecords.asMap().entries.map((entry) {
              final index = entry.key;
              final record = entry.value;
              return DataRow(
                color: WidgetStateProperty.all(
                  index % 2 == 0 ? OvertimeConstants.cardColor : OvertimeConstants.backgroundColor,
                ),
                cells: [
                  _buildDataCell(record['id']?.toString() ?? ''),
                  _buildDataCell(record['employee_id']?.toString() ?? ''),
                  _buildDataCell(record['fullname'] ?? 'Unknown'),
                  _buildDataCell(record['company_name'] ?? 'N/A'),
                  _buildDataCell(
                    '${record['hours'] != null ? (record['hours'] is num ? (record['hours'] as num).toStringAsFixed(2) : record['hours'].toString()) : '0'}h'
                  ),
                  _buildDataCell(
                    '${record['rate'] != null ? (record['rate'] is num ? (record['rate'] as num).toStringAsFixed(1) : record['rate'].toString()) : '0'}x'
                  ),
                  _buildDataCell(
                    record['date_overtime'] != null
                        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(record['date_overtime']))
                        : 'N/A'
                  ),
                  _buildAmountCell(record['amount']),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    return [
      _buildDataColumn('ID'),
      _buildDataColumn('Employee ID'),
      _buildDataColumn('Full Name'),
      _buildDataColumn('Company'),
      _buildDataColumn('Hours'),
      _buildDataColumn('Rate'),
      _buildDataColumn('Date'),
      _buildDataColumn('Amount (KES)'),
    ];
  }

  DataColumn _buildDataColumn(String label) {
    return DataColumn(
      label: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: OvertimeConstants.textColor,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  DataCell _buildDataCell(String text) {
    return DataCell(
      Tooltip(
        message: text,
        child: Text(
          text,
          style: TextStyle(
            color: OvertimeConstants.textColor,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  DataCell _buildAmountCell(dynamic amount) {
    final value = double.tryParse(amount?.toString() ?? '0.0') ?? 0.0;
    final formattedValue = 'KES ${value.toStringAsFixed(2)}';
    
    return DataCell(
      Tooltip(
        message: formattedValue,
        child: Text(
          formattedValue,
          style: TextStyle(
            color: OvertimeConstants.successColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time_filled,
              size: 80,
              color: OvertimeConstants.subtitleColor.withAlpha(128),
            ),
            const SizedBox(height: 24),
            Text(
              'No Overtime Records',
              style: TextStyle(
                color: OvertimeConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No overtime records found for the selected filters',
              style: TextStyle(
                color: OvertimeConstants.subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing the month/year filters or add new overtime records',
              style: TextStyle(
                color: OvertimeConstants.subtitleColor,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddOvertimeDialog,
              icon: Icon(Icons.add, size: 18),
              label: Text('Add Overtime'),
              style: ElevatedButton.styleFrom(
                backgroundColor: OvertimeConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required T? value,
    required List<T> items,
    required String labelText,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: OvertimeConstants.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: [
          DropdownMenuItem<T>(
            value: null,
            child: Text('All $labelText', style: TextStyle(color: OvertimeConstants.subtitleColor)),
          ),
          ...items.map((item) => DropdownMenuItem(
                value: item,
                child: Text(itemBuilder(item), style: TextStyle(color: OvertimeConstants.textColor)),
              )),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelText: labelText,
          labelStyle: TextStyle(color: OvertimeConstants.subtitleColor, fontSize: 14),
          prefixIcon: Icon(icon, color: OvertimeConstants.primaryColor, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: OvertimeConstants.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        dropdownColor: OvertimeConstants.cardColor,
        icon: Icon(Icons.arrow_drop_down, color: OvertimeConstants.primaryColor),
        style: TextStyle(color: OvertimeConstants.textColor, fontSize: 14),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Overtime',
            value: 'KES ${_totalOvertimeAmount.toStringAsFixed(2)}',
            icon: Icons.attach_money,
            color: OvertimeConstants.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Total Records',
            value: _totalOvertimeRecords.toString(),
            icon: Icons.list_alt,
            color: OvertimeConstants.accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OvertimeConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: OvertimeConstants.subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: OvertimeConstants.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OvertimeConstants.backgroundColor,
      appBar: CustomAppBar(
        title: 'Overtime Management',
        backgroundColor: OvertimeConstants.primaryColor,
        onNotificationTap: () {
          if (kDebugMode) print('Notifications tapped');
        },
        onProfileTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              decoration: BoxDecoration(
                color: OvertimeConstants.cardColor,
                  borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: OvertimeConstants.subtitleColor.withAlpha(77),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: OvertimeConstants.primaryColor.withAlpha(26),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person, color: OvertimeConstants.primaryColor),
                      ),
                      title: Text('Profile: ${widget.user.username ?? 'User'}', style: TextStyle(color: OvertimeConstants.textColor)),
                      subtitle: Text('Role: ${widget.user.role} | Company: ${widget.user.companyName ?? 'Company'}', 
                          style: TextStyle(color: OvertimeConstants.subtitleColor)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(26),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.logout, color: Colors.red),
                      ),
                      title: Text('Logout', style: TextStyle(color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                        _logout(context);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [OvertimeConstants.primaryColor, OvertimeConstants.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.access_time,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Overtime Management',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage employee overtime records and calculations',
                              style: const TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildDateFilters(),
                ],
              ),
            ),
          ),
          
          // Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildSearchSection(),
                  const SizedBox(height: 16),
                  _buildStatisticsCards(),
                  const SizedBox(height: 16),
                  _buildContentSection(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOvertimeDialog,
        backgroundColor: OvertimeConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: Icon(Icons.add),
        label: Text('Add Overtime'),
      ),
    );
  }

  Widget _buildDateFilters() {
    return Row(
      children: [
        Expanded(
          child: _buildFilterDropdown(
            value: _selectedMonth,
            items: List.generate(12, (index) => index + 1),
            labelText: 'Month',
            itemBuilder: (month) => DateFormat('MMMM').format(DateTime(_selectedYear ?? DateTime.now().year, month)),
            onChanged: (value) {
              setState(() {
                _selectedMonth = value;
                _fetchOvertimeRecords();
              });
            },
            icon: Icons.calendar_month,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFilterDropdown(
            value: _selectedYear,
            items: List.generate(5, (index) => DateTime.now().year - index),
            labelText: 'Year',
            itemBuilder: (year) => year.toString(),
            onChanged: (value) {
              setState(() {
                _selectedYear = value;
                _fetchOvertimeRecords();
              });
            },
            icon: Icons.event,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: _fetchOvertimeRecords,
            icon: Icon(Icons.refresh, color: OvertimeConstants.primaryColor),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchSection() {
    return Container(
      decoration: BoxDecoration(
        color: OvertimeConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: filterController,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintText: 'Search by employee name, ID, or date...',
          hintStyle: TextStyle(color: OvertimeConstants.subtitleColor),
          prefixIcon: Icon(Icons.search, color: OvertimeConstants.subtitleColor),
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
        ),
        style: TextStyle(
          color: OvertimeConstants.textColor,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: OvertimeConstants.cardColor,
          borderRadius: BorderRadius.circular(20),
        boxShadow: const [
            BoxShadow(
                      color: Color(0x33000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return _buildLoadingState();
    }
    
    return Column(
      children: [
        _buildTableHeader(),
        Expanded(child: _buildOvertimeTable()),
        if (filteredRecords.isNotEmpty) _buildPagination(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: OvertimeConstants.primaryColor,
            strokeWidth: 2,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Overtime Records...',
            style: TextStyle(
              color: OvertimeConstants.subtitleColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: OvertimeConstants.backgroundColor,
        border: Border(
          bottom: BorderSide(color: OvertimeConstants.backgroundColor.withAlpha(128)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.list_alt, color: OvertimeConstants.primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(
            'Overtime Records',
            style: TextStyle(
              color: OvertimeConstants.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (filteredRecords.isNotEmpty)
            Text(
              '${filteredRecords.length} records',
              style: TextStyle(
                color: OvertimeConstants.subtitleColor,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (filteredRecords.length / itemsPerPage).ceil();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: OvertimeConstants.backgroundColor,
        border: Border(
          top: BorderSide(color: OvertimeConstants.backgroundColor.withAlpha(128)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: currentPage > 0 ? () => setState(() => currentPage--) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: OvertimeConstants.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Previous'),
          ),
          Text(
            'Page ${currentPage + 1} of $totalPages',
            style: TextStyle(
              color: OvertimeConstants.textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          ElevatedButton(
            onPressed: (currentPage + 1) < totalPages ? () => setState(() => currentPage++) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: OvertimeConstants.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Next'),
          ),
        ],
      ),
    );
  }
}