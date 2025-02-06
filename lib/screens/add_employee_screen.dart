import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  _AddEmployeeScreenState createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _kraPinController = TextEditingController();
  final _positionController = TextEditingController();
  final _nssfController = TextEditingController();
  final _nhifController = TextEditingController();
  final _emailController = TextEditingController();
  final _telController = TextEditingController();
  final _basicController = TextEditingController();
  final _houseAllowanceController = TextEditingController(text: '0.00');
  final _grossPayController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankBranchController = TextEditingController();
  final _accountNumberController = TextEditingController();

  String _residentialStatus = 'Resident';
  String _employeeType = 'Primary Employee';
  String _housingType = 'Benefit Not Given';
  bool _noHouseAllowance = false;
  bool _isLoading = false;

  // Create an HTTP client and pass it to ApiService
  final http.Client _httpClient = http.Client();
  final ApiService apiService = ApiService(client: http.Client());

  @override
  void dispose() {
    _employeeIdController.dispose();
    _fullnameController.dispose();
    _nationalIdController.dispose();
    _kraPinController.dispose();
    _positionController.dispose();
    _nssfController.dispose();
    _nhifController.dispose();
    _emailController.dispose();
    _telController.dispose();
    _basicController.dispose();
    _houseAllowanceController.dispose();
    _grossPayController.dispose();
    _bankNameController.dispose();
    _bankBranchController.dispose();
    _accountNumberController.dispose();
    _httpClient.close(); // Close the HTTP client
    super.dispose();
  }

  void _calculateGrossPay(String value) {
    final basicSalary = double.tryParse(_basicController.text) ?? 0.0;
    final houseAllowance = _noHouseAllowance ? 0.0 : basicSalary * 0.15;
    final grossPay = basicSalary + houseAllowance;

    setState(() {
      _houseAllowanceController.text = houseAllowance.toStringAsFixed(2);
      _grossPayController.text = grossPay.toStringAsFixed(2);
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final employeeData = {
        'employee_id': _employeeIdController.text,
        'fullname': _fullnameController.text,
        'national_id': _nationalIdController.text,
        'kra_pin': _kraPinController.text,
        'position': _positionController.text,
        'nssf': _nssfController.text,
        'nhif': _nhifController.text,
        'email': _emailController.text,
        'tel': _telController.text,
        'basic': _basicController.text,
        'house_allowance': _houseAllowanceController.text,
        'gross_pay': _grossPayController.text,
        'residential_status': _residentialStatus,
        'employee_type': _employeeType,
        'housing_type': _housingType,
        'bank_name': _bankNameController.text,
        'bank_branch': _bankBranchController.text,
        'account_number': _accountNumberController.text,
      };

      try {
        await apiService.addEmployee(employeeData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Employee Added: ${employeeData['fullname']}')),
        );
        _formKey.currentState!.reset();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add employee: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Employee'),
        backgroundColor: Colors.teal,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade100, Colors.teal.shade400],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildCard(
                    'Personal Information',
                    [
                      _buildTextField(_employeeIdController, 'Employee ID'),
                      _buildTextField(_fullnameController, 'Full Name'),
                      _buildTextField(_nationalIdController, 'National ID'),
                      _buildTextField(_kraPinController, 'KRA PIN'),
                      _buildTextField(_nssfController, 'NSSF Number'),
                      _buildTextField(_nhifController, 'NHIF Number'),
                      FutureBuilder<List<String>>(
                        future: apiService.getPositions().then((positions) =>
                            positions
                                .map((position) =>
                                    position['description'].toString())
                                .toList()),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          } else if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          } else {
                            final positions = snapshot.data ?? [];
                            if (!_positionController.text.isNotEmpty &&
                                positions.isNotEmpty) {
                              _positionController.text = positions.first;
                            }
                            return _buildDropdownField(
                              'Position',
                              positions,
                              _positionController.text,
                              (value) {
                                setState(
                                    () => _positionController.text = value!);
                              },
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  _buildCard(
                    'Contact Information',
                    [
                      _buildTextField(_emailController, 'Email'),
                      _buildTextField(_telController, 'Tel'),
                    ],
                  ),
                  _buildCard(
                    'Salary Information',
                    [
                      _buildTextField(_basicController, 'Basic Salary',
                          isNumber: true, onChanged: _calculateGrossPay),
                      Row(
                        children: [
                          Checkbox(
                            value: _noHouseAllowance,
                            onChanged: (value) {
                              setState(() {
                                _noHouseAllowance = value!;
                                _calculateGrossPay(_basicController.text);
                              });
                            },
                          ),
                          const Text('No House Allowance'),
                        ],
                      ),
                      _buildTextField(
                          _houseAllowanceController, 'House Allowance',
                          isNumber: true, enabled: false),
                      _buildTextField(_grossPayController, 'Gross Pay',
                          isNumber: true, enabled: false),
                    ],
                  ),
                  _buildCard(
                    'Additional Information',
                    [
                      _buildDropdownField(
                        'Residential Status',
                        ['Resident', 'Non-resident'],
                        _residentialStatus,
                        (value) => setState(() => _residentialStatus = value!),
                      ),
                      _buildDropdownField(
                        'Employee Type',
                        ['Primary Employee', 'Secondary Employee'],
                        _employeeType,
                        (value) => setState(() => _employeeType = value!),
                      ),
                      _buildDropdownField(
                        'Housing Type',
                        ['Benefit Given', 'Benefit Not Given'],
                        _housingType,
                        (value) => setState(() => _housingType = value!),
                      ),
                    ],
                  ),
                  _buildCard(
                    'Bank Information',
                    [
                      _buildTextField(_bankNameController, 'Bank Name'),
                      _buildTextField(_bankBranchController, 'Bank Branch'),
                      _buildTextField(
                          _accountNumberController, 'Account Number'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Add Employee'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 16.0, runSpacing: 16.0, children: children),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false,
      bool enabled = true,
      void Function(String)? onChanged}) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
        enabled: enabled,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDropdownField(String label, List<String> items,
      String selectedItem, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      child: DropdownButtonFormField(
        value: selectedItem.isNotEmpty ? selectedItem : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select $label';
          }
          return null;
        },
      ),
    );
  }
}
