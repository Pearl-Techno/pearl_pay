import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class AddCompanyScreen extends StatefulWidget {
  const AddCompanyScreen({super.key});

  @override
  _AddCompanyScreenState createState() => _AddCompanyScreenState();
}

class _AddCompanyScreenState extends State<AddCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _physicalAddressController = TextEditingController();
  final _postalAddressController = TextEditingController();
  final _kraPinController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailAddressController = TextEditingController();
  String _status = 'Active';
  bool _isLoading = false;
  bool _isFetching = false;

  List<Map<String, dynamic>> _companies = [];
  final ApiService _apiService = ApiService(client: http.Client());

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _physicalAddressController.dispose();
    _postalAddressController.dispose();
    _kraPinController.dispose();
    _phoneNumberController.dispose();
    _emailAddressController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanies() async {
    setState(() => _isFetching = true);
    try {
      final companies = await _apiService.getCompanies();
      setState(() {
        _companies = companies;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load companies: $e')),
      );
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _addCompany() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final companyData = {
        'company_name': _companyNameController.text,
        'physical_address': _physicalAddressController.text,
        'postal_address': _postalAddressController.text,
        'kra_pin': _kraPinController.text,
        'phone_number': _phoneNumberController.text,
        'email_address': _emailAddressController.text,
        'status': _status,
      };

      try {
        await _apiService.addCompany(companyData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Company Added: ${_companyNameController.text}'),
            backgroundColor: Colors.teal[700],
          ),
        );

        _formKey.currentState!.reset();
        _companyNameController.clear();
        _physicalAddressController.clear();
        _postalAddressController.clear();
        _kraPinController.clear();
        _phoneNumberController.clear();
        _emailAddressController.clear();
        setState(() => _status = 'Active');

        await _fetchCompanies();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add company: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Company Management',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          print('Notifications tapped');
        },
        onProfileTap: () {
          print('Profile tapped');
        },
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.teal[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a New Company',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAddCompanyForm(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Company List',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[900],
                          ),
                        ),
                        if (_isFetching)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.teal[700],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildCompanyTable(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCompanyForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.teal[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12.0,
                runSpacing: 12.0,
                children: [
                  _buildTextField(_companyNameController, 'Company Name'),
                  _buildTextField(
                      _physicalAddressController, 'Physical Address'),
                  _buildTextField(_postalAddressController, 'Postal Address'),
                  _buildTextField(_kraPinController, 'KRA PIN'),
                  _buildTextField(_phoneNumberController, 'Phone Number',
                      isPhone: true),
                  _buildTextField(_emailAddressController, 'Email Address',
                      isEmail: true),
                  _buildDropdownField(
                    'Status',
                    ['Active', 'Inactive', 'Closed'],
                    _status,
                    (value) => setState(() => _status = value!),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _addCompany,
                  icon: const Icon(Icons.add, size: 18),
                  label: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Add Company',
                          style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyTable() {
    if (_companies.isEmpty && !_isFetching) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.teal[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No companies found.',
              style: TextStyle(fontSize: 16, color: Colors.teal[900]),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.teal[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 32,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowColor: MaterialStateProperty.all(Colors.teal[100]!),
                dataRowHeight: 60,
                columns: [
                  DataColumn(
                    label: Text(
                      'Company Name',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[900]),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Physical Address',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[900]),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Postal Address',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[900]),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'KRA PIN',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[900]),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Phone Number',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[900]),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Email Address',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[900]),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[900]),
                    ),
                  ),
                ],
                rows: _companies.map((company) {
                  return DataRow(cells: [
                    DataCell(
                      Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          company['company_name'] ?? '',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[800]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          company['physical_address'] ?? '',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[800]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          company['postal_address'] ?? '',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[800]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          company['kra_pin'] ?? '',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[800]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          company['phone_number'] ?? '',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[800]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          company['email_address'] ?? '',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[800]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: company['status'] == 'Active'
                              ? Colors.green[100]
                              : company['status'] == 'Inactive'
                                  ? Colors.orange[100]
                                  : Colors.red[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          company['status'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: company['status'] == 'Active'
                                ? Colors.green[800]
                                : company['status'] == 'Inactive'
                                    ? Colors.orange[800]
                                    : Colors.red[800],
                          ),
                        ),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isPhone = false, bool isEmail = false}) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45 - 28,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: Colors.teal[900]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[200]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[700]!),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        style: TextStyle(fontSize: 12, color: Colors.grey[800]),
        keyboardType: isPhone
            ? TextInputType.phone
            : isEmail
                ? TextInputType.emailAddress
                : TextInputType.text,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          if (label == 'KRA PIN' && value.length < 10) {
            return 'KRA PIN must be at least 10 characters';
          }
          if (isEmail &&
              !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email address';
          }
          if (isPhone && !RegExp(r'^\+?\d{10,15}$').hasMatch(value)) {
            return 'Please enter a valid phone number';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField(String label, List<String> items,
      String selectedItem, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45 - 28,
      child: DropdownButtonFormField<String>(
        value: selectedItem,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: Colors.teal[900]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[200]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[700]!),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item,
                      style: TextStyle(fontSize: 12, color: Colors.teal[900])),
                ))
            .toList(),
        onChanged: onChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select $label';
          }
          return null;
        },
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
      ),
    );
  }
}
