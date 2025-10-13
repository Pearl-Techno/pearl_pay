import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class AddCompanyScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const AddCompanyScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

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
  String? _errorMessage;

  List<Map<String, dynamic>> _companies = [];

  @override
  void initState() {
    super.initState();
    if (widget.user['role']?.toLowerCase() != 'admin') {
      _errorMessage = 'Access denied: Admin role required';
      return;
    }
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

  // Fetch companies
  Future<void> _fetchCompanies() async {
    setState(() {
      _isFetching = true;
      _errorMessage = null;
    });
    try {
      final companies = await widget.apiService.getCompanies();
      setState(() {
        _companies = companies;
        _isFetching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load companies: $e';
        _isFetching = false;
      });
    }
  }

  // Add company
  Future<void> _addCompany() async {
    if (widget.user['role']?.toLowerCase() != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Access denied: Admin role required'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

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
        'added_by': widget.user['user_id'].toString(),
      };

      try {
        await widget.apiService.addCompany(companyData);

        // Log audit trail (non-critical, catch errors)
        try {
          await widget.apiService.logCompanyAction({
            'user_id': widget.user['user_id'],
            'company_name': _companyNameController.text,
            'action': 'add',
          });
        } catch (e) {
          print('Failed to log company action: $e');
        }

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
          SnackBar(
            content: Text('Failed to add company: $e'),
            backgroundColor: Colors.red[700],
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _addCompany,
            ),
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Logout function
  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
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
          showModalBottomSheet(
            context: context,
            builder: (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.person, color: Colors.teal[700]),
                    title:
                        Text('Profile: ${widget.user['username'] ?? 'Unknown'}'),
                    subtitle: Text('Role: ${widget.user['role'] ?? 'Unknown'}'),
                  ),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.red[700]),
                    title: const Text('Logout'),
                    onTap: () {
                      Navigator.pop(context);
                      _logout(context);
                    },
                  ),
                ],
              ),
            ),
          );
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
        child: _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.teal[900],
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.user['role']?.toLowerCase() == 'admin') ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchCompanies,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add a New Company',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal[900],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Note: Ensure KRA PIN follows Kenyan format (e.g., P051123456X).',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildAddCompanyForm(),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Company List',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal[900],
                                ),
                              ),
                              if (_isFetching)
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.teal[700],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
      elevation: 6,
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
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
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
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ||
                          widget.user['role']?.toLowerCase() != 'admin'
                      ? null
                      : _addCompany,
                  icon: const Icon(Icons.add, size: 20),
                  label: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'Add Company',
                          style: TextStyle(fontSize: 16),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
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
        elevation: 6,
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
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Text(
              'No companies found.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.teal[900],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 6,
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
              minWidth: MediaQuery.of(context).size.width - 40,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: MaterialStateProperty.all(Colors.teal[100]!),
                dataRowHeight: 64,
                columns: [
                  DataColumn(
                    label: Text(
                      'Company Name',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Physical Address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Postal Address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'KRA PIN',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Email Address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Actions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                  ),
                ],
                rows: _companies.map((company) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            company['company_name'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                            semanticsLabel:
                                'Company name: ${company['company_name'] ?? ''}',
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            company['physical_address'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                            semanticsLabel:
                                'Physical address: ${company['physical_address'] ?? ''}',
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            company['postal_address'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                            semanticsLabel:
                                'Postal address: ${company['postal_address'] ?? ''}',
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            company['kra_pin'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                            semanticsLabel:
                                'KRA PIN: ${company['kra_pin'] ?? ''}',
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            company['phone_number'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                            semanticsLabel:
                                'Phone number: ${company['phone_number'] ?? ''}',
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            company['email_address'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                            semanticsLabel:
                                'Email address: ${company['email_address'] ?? ''}',
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
                            semanticsLabel:
                                'Status: ${company['status'] ?? ''}',
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.teal[700]),
                          onPressed: widget.user['role']?.toLowerCase() == 'admin'
                              ? () {
                                  // Navigate to EditCompanyScreen
                                  print('Edit company: ${company['company_name']}');
                                }
                              : null,
                          tooltip: 'Edit Company',
                        ),
                      ),
                    ],
                  );
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
      width: MediaQuery.of(context).size.width * 0.45 - 32,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14, color: Colors.teal[900]),
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
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          prefixIcon: label == 'KRA PIN'
              ? Icon(Icons.fingerprint, color: Colors.teal[700])
              : label == 'Phone Number'
                  ? Icon(Icons.phone, color: Colors.teal[700])
                  : label == 'Email Address'
                      ? Icon(Icons.email, color: Colors.teal[700])
                      : null,
        ),
        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
        keyboardType: isPhone
            ? TextInputType.phone
            : isEmail
                ? TextInputType.emailAddress
                : TextInputType.text,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter $label';
          }
          if (label == 'KRA PIN' &&
              !RegExp(r'^[A-Z]\d{9}[A-Z]$').hasMatch(value)) {
            return 'Invalid KRA PIN format (e.g., P051123456X)';
          }
          if (isEmail &&
              !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email address';
          }
          if (isPhone && !RegExp(r'^\+?\d{10,15}$').hasMatch(value)) {
            return 'Please enter a valid phone number (e.g., +254712345678)';
          }
          return null;
        },
        enabled: widget.user['role']?.toLowerCase() == 'admin',
      ),
    );
  }

  Widget _buildDropdownField(String label, List<String> items,
      String selectedItem, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45 - 32,
      child: DropdownButtonFormField<String>(
        value: selectedItem,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14, color: Colors.teal[900]),
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
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          prefixIcon: Icon(Icons.list, color: Colors.teal[700]),
        ),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(fontSize: 14, color: Colors.teal[900]),
                  ),
                ))
            .toList(),
        onChanged:
            widget.user['role']?.toLowerCase() == 'admin' ? onChanged : null,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select $label';
          }
          return null;
        },
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
        // Removed invalid parameter 'semanticsLabel'
      ),
    );
  }
}