import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';
import 'add_loan_screen.dart';

// Constants
class LoansConstants {
  static const Color primaryColor = Color(0xFF0D47A1);
  static const Color secondaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF00B0FF);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF1A237E);
  static const Color subtitleColor = Color(0xFF546E7A);
}

class LoansScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const LoansScreen({
    super.key, 
    required this.user, 
    required this.apiService
  });

  @override
  LoansScreenState createState() => LoansScreenState();
}

class LoansScreenState extends State<LoansScreen> {
  List<Map<String, dynamic>> loans = [];
  List<Map<String, dynamic>> employees = [];
  List<int> companyIds = [];
  Map<int, String> companyIdToName = {};
  bool isLoadingCompanies = false;
  bool isLoadingEmployees = false;
  bool isLoadingLoans = false;
  String? errorMessage;

  String searchKeyword = '';
  Map<String, bool> selectedLoans = {};
  double totalLoanAmount = 0.0;
  double totalInterest = 0.0;
  double totalRemainingAmount = 0.0;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int? _selectedCompanyId;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanies() async {
    setState(() => isLoadingCompanies = true);
    try {
      final userCompanyId = widget.user.companyId;
      final isAdmin = widget.user.role == 'admin';

      if (userCompanyId <= 0) {
        throw Exception('No valid company ID for user');
      }

      setState(() {
        if (isAdmin) {
          companyIds = [userCompanyId];
          companyIdToName = {
            userCompanyId: widget.user.companyName ?? 'Unknown'
          };
          companyIds.insert(0, 0);
          companyIdToName[0] = 'All Companies';
        } else {
          companyIds = [userCompanyId];
          companyIdToName = {
            userCompanyId: widget.user.companyName ?? 'Unknown'
          };
        }
        _selectedCompanyId = companyIds.isNotEmpty ? companyIds[0] : null;
        isLoadingCompanies = false;
      });

      await _fetchEmployeesAndLoans();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load companies: $e';
        isLoadingCompanies = false;
      });
      _showErrorSnackBar('Failed to load companies: $e');
    }
  }

  Future<void> _fetchEmployeesAndLoans() async {
    setState(() {
      isLoadingEmployees = true;
      isLoadingLoans = true;
    });

    try {
      List<Map<String, dynamic>> fetchedEmployees = [];
      List<Map<String, dynamic>> fetchedLoans = [];
      final userCompanyId = widget.user.companyId;
      final isAdmin = widget.user.role == 'admin';

      if (userCompanyId == 0) {
        throw Exception('No valid company ID for user');
      }

      if (isAdmin && _selectedCompanyId == 0) {
        try {
          fetchedEmployees =
              await widget.apiService.getEmployeeList(userCompanyId);
          fetchedLoans = await widget.apiService.fetchLoans(userCompanyId);
        } catch (e) {
          throw Exception('Access denied: $e');
        }
      } else if (_selectedCompanyId != null && _selectedCompanyId != 0) {
        if (_selectedCompanyId == userCompanyId) {
          try {
            fetchedEmployees =
                await widget.apiService.getEmployeeList(_selectedCompanyId!);
            if (isAdmin) {
              fetchedLoans =
                  await widget.apiService.fetchLoans(_selectedCompanyId!);
            } else {
              fetchedLoans = await widget.apiService.fetchLoansForEmployee(
                  widget.user.employeeId.toString(), _selectedCompanyId!);
            }
          } catch (e) {
            throw Exception('Access denied: $e');
          }
        } else {
          throw Exception(
              'Unauthorized access to company ID $_selectedCompanyId');
        }
      } else {
        throw Exception('Invalid company ID selected');
      }

      // Pre-process loans with names and basic numbers
      for (var loan in fetchedLoans) {
        final employee = fetchedEmployees.firstWhere(
          (e) => e['employee_id'].toString() == loan['employee_id'].toString(),
          orElse: () => {'fullname': 'Unknown', 'company_id': null},
        );
        loan['employee_name'] = employee['fullname'] ?? 'Unknown';
        loan['company_name'] =
            companyIdToName[employee['company_id'] ?? userCompanyId] ??
                'Unknown';

        // Ensure numbers are doubles
        loan['amount'] = double.tryParse(loan['amount']?.toString() ?? '0') ?? 0.0;
        loan['interest'] = double.tryParse(loan['interest']?.toString() ?? '0') ?? 0.0;
        loan['interest_rate'] = double.tryParse(loan['interest_rate']?.toString() ?? '0') ?? 0.0;
        loan['total_amount_repaid'] = double.tryParse(loan['total_amount_repaid']?.toString() ?? '0') ?? 0.0;
      }

      // Group by employee to handle repayment distribution
      Map<String, List<Map<String, dynamic>>> loansByEmployee = {};
      for (var loan in fetchedLoans) {
        String empId = loan['employee_id'].toString();
        if (!loansByEmployee.containsKey(empId)) {
          loansByEmployee[empId] = [];
        }
        loansByEmployee[empId]!.add(loan);
      }

      // Fetch repayments in parallel
      List<Future<void>> futures = [];
      for (var entry in loansByEmployee.entries) {
        futures.add(_processEmployeeRepayment(entry.key, entry.value));
      }

      await Future.wait(futures);

      if (!mounted) return;

      setState(() {
        employees = fetchedEmployees;
        loans = fetchedLoans;
        isLoadingEmployees = false;
        isLoadingLoans = false;
      });

      _filterAndCalculateTotals();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error fetching data: $e';
        isLoadingEmployees = false;
        isLoadingLoans = false;
      });
      _showErrorSnackBar('Error fetching data: $e');
    }
  }

  Future<void> _processEmployeeRepayment(String employeeId, List<Map<String, dynamic>> employeeLoans) async {
    if (employeeLoans.isEmpty) return;

    double repaymentAmount = 0.0;
    try {
      // Assuming all loans for an employee are in the same company context for this screen
      int companyId = int.tryParse(employeeLoans.first['company_id'].toString()) ?? 0;
      if (companyId > 0) {
        repaymentAmount = await widget.apiService.fetchLoanRepayment(
            employeeId,
            companyId,
            _selectedMonth,
            _selectedYear
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching repayment for $employeeId: $e');
    }

    double remainingRepaymentToDistribute = repaymentAmount;

    for (var loan in employeeLoans) {
      double amount = loan['amount'];
      double interest = loan['interest'];
      double rate = loan['interest_rate'];
      double staticTotalRepaid = loan['total_amount_repaid'];

      if (interest == 0 && rate > 0) {
        interest = amount * rate;
        loan['interest'] = interest;
      }

      double baseRemaining = (amount + interest) - staticTotalRepaid;
      if (baseRemaining < 0) baseRemaining = 0;

      double currentLoanRepayment = 0.0;
      if (remainingRepaymentToDistribute > 0) {
        if (remainingRepaymentToDistribute >= baseRemaining) {
          currentLoanRepayment = baseRemaining;
          remainingRepaymentToDistribute -= baseRemaining;
        } else {
          currentLoanRepayment = remainingRepaymentToDistribute;
          remainingRepaymentToDistribute = 0;
        }
      }

      double finalRemaining = baseRemaining - currentLoanRepayment;
      double finalTotalRepaid = staticTotalRepaid + currentLoanRepayment;

      loan['remaining_amount'] = finalRemaining;
      loan['total_amount_repaid'] = finalTotalRepaid;
    }
  }

  void _onSearchChanged() {
    _filterAndCalculateTotals();
  }

  void _filterAndCalculateTotals() {
    setState(() {
      final filteredLoans = loans.where((loan) {
        final matchesCompany = _selectedCompanyId == null ||
            _selectedCompanyId == 0 ||
            loan['company_id'] == _selectedCompanyId;
        final matchesKeyword = _searchController.text.isEmpty ||
            (loan['employee_name'] ?? '')
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            (loan['company_name'] ?? '')
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());
        return matchesCompany && matchesKeyword;
      }).toList();

      loans = filteredLoans;

      totalLoanAmount = loans.fold(
          0.0,
          (sum, loan) =>
              sum + (loan['total_amount_repaid']?.toDouble() ?? 0.0));
      totalInterest = loans.fold(
          0.0, (sum, loan) => sum + (loan['interest']?.toDouble() ?? 0.0));
      totalRemainingAmount = loans.fold(0.0,
          (sum, loan) => sum + (loan['remaining_amount']?.toDouble() ?? 0.0));
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
        backgroundColor: LoansConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _repayLoan() async {
    if (selectedLoans.isEmpty) {
      _showErrorSnackBar('Please select at least one loan to repay');
      return;
    }

    if (widget.user.role != 'admin') {
      _showErrorSnackBar('Access denied: Only admins can process repayments');
      return;
    }

    setState(() => isLoadingLoans = true);

    try {
      for (var loan in loans
          .where((loan) => selectedLoans[loan['loan_id'].toString()] == true)) {
        final employee = employees.firstWhere(
          (e) => e['employee_id'].toString() == loan['employee_id'].toString(),
          orElse: () => {'company_id': _selectedCompanyId},
        );
        final companyId = employee['company_id'] ?? _selectedCompanyId;
        if (companyId == 0 || companyId == null) {
          throw Exception('Invalid company ID for loan repayment');
        }

        final repaymentData = {
          'employee_id': loan['employee_id'],
          'repayment_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'amount': loan['remaining_amount']?.toDouble() ?? 0.0,
        };

        await widget.apiService.processLoanRepayment(repaymentData, companyId);
      }

      _showSuccessSnackBar('Bulk repayment processed successfully');
      await _fetchEmployeesAndLoans();
      setState(() => selectedLoans.clear());
    } catch (e) {
      _showErrorSnackBar('Failed to process bulk repayment: $e');
    } finally {
      setState(() => isLoadingLoans = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user.role == 'admin';
    return Scaffold(
      backgroundColor: LoansConstants.backgroundColor,
      appBar: CustomAppBar(
        title: 'Loans Management',
        backgroundColor: LoansConstants.primaryColor,
        onNotificationTap: () {
          if (kDebugMode) print('Notifications tapped');
        },
        onProfileTap: () {
          if (kDebugMode) print('Profile tapped');
        },
      ),
      body: Column(
        children: [
          // Header Section
          _buildHeaderSection(),
          
          // Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildSearchAndFilters(),
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
      floatingActionButton: _buildFloatingActions(isAdmin),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [LoansConstants.primaryColor, LoansConstants.secondaryColor],
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
                    Icons.credit_card,
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
                        'Loans Management',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage employee loans and repayments',
                        style: TextStyle(
                          color: Colors.white.withAlpha(230),
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
            itemBuilder: (month) => DateFormat('MMMM').format(DateTime(_selectedYear, month)),
            onChanged: (value) {
              setState(() {
                _selectedMonth = value!;
                _fetchEmployeesAndLoans();
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
                _selectedYear = value!;
                _fetchEmployeesAndLoans();
              });
            },
            icon: Icons.event,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFilterDropdown(
            value: _selectedCompanyId ?? 0,
            items: companyIds,
            labelText: 'Company',
            itemBuilder: (id) => companyIdToName[id] ?? 'Unknown',
            onChanged: (value) {
              setState(() {
                _selectedCompanyId = value;
                _fetchEmployeesAndLoans();
              });
            },
            icon: Icons.business,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: _fetchEmployeesAndLoans,
            icon: Icon(Icons.refresh, color: LoansConstants.primaryColor),
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

  Widget _buildSearchAndFilters() {
    return Container(
      decoration: BoxDecoration(
        color: LoansConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintText: 'Search by employee name or company...',
          hintStyle: TextStyle(color: LoansConstants.subtitleColor),
          prefixIcon: Icon(Icons.search, color: LoansConstants.subtitleColor),
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
        ),
        style: TextStyle(
          color: LoansConstants.textColor,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Repaid',
            value: 'KES ${totalLoanAmount.toStringAsFixed(2)}',
            icon: Icons.payments,
            color: LoansConstants.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Total Interest',
            value: 'KES ${totalInterest.toStringAsFixed(2)}',
            icon: Icons.trending_up,
            color: LoansConstants.warningColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Remaining',
            value: 'KES ${totalRemainingAmount.toStringAsFixed(2)}',
            icon: Icons.pending_actions,
            color: LoansConstants.accentColor,
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
        color: LoansConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 26 / 255),
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
                    color: LoansConstants.subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: LoansConstants.textColor,
                    fontSize: 16,
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

  Widget _buildContentSection() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: LoansConstants.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 16,
              offset: const Offset(0, 4),
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
    if (isLoadingCompanies || isLoadingEmployees || isLoadingLoans) {
      return _buildLoadingState();
    }
    
    if (errorMessage != null) {
      return _buildErrorState();
    }
    
    if (loans.isEmpty) {
      return _buildEmptyState();
    }
    
    return Column(
      children: [
        _buildTableHeader(),
        Expanded(child: _buildLoansTable()),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: LoansConstants.primaryColor,
            strokeWidth: 2,
          ),
          SizedBox(height: 20),
          Text(
            'Loading Loans...',
            style: TextStyle(
              color: LoansConstants.subtitleColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: LoansConstants.subtitleColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Data',
              style: TextStyle(
                color: LoansConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: TextStyle(
                color: LoansConstants.subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchCompanies,
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LoansConstants.primaryColor,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_off,
              size: 80,
              color: LoansConstants.subtitleColor.withAlpha(128),
            ),
            const SizedBox(height: 24),
            Text(
              'No Loans Found',
              style: TextStyle(
                color: LoansConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No loans available for the selected filters',
              style: TextStyle(
                color: LoansConstants.subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing the filters or add new loans',
              style: TextStyle(
                color: LoansConstants.subtitleColor,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (widget.user.role == 'admin')
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddLoanScreen(
                        user: widget.user.toMap(),
                        apiService: widget.apiService,
                      ),
                    ),
                  ).then((_) => _fetchEmployeesAndLoans());
                },
                icon: Icon(Icons.add, size: 18),
                label: Text('Add Loan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LoansConstants.primaryColor,
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

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: LoansConstants.backgroundColor,
        border: Border(
          bottom: BorderSide(color: LoansConstants.backgroundColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.list_alt, color: LoansConstants.primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(
            'Loans Records',
            style: TextStyle(
              color: LoansConstants.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${loans.length} records',
            style: TextStyle(
              color: LoansConstants.subtitleColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansTable() {
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
              color: LoansConstants.textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
            dataTextStyle: TextStyle(
              color: LoansConstants.textColor,
              fontSize: 12,
            ),
            headingRowColor: WidgetStateProperty.all(LoansConstants.backgroundColor),
            columns: _buildTableColumns(),
            rows: _buildTableRows(),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    return [
      if (widget.user.role == 'admin')
        DataColumn(label: _buildTableHeaderCell('Select')),
      DataColumn(label: _buildTableHeaderCell('Employee Name')),
      DataColumn(label: _buildTableHeaderCell('Amount')),
      DataColumn(label: _buildTableHeaderCell('Total Repaid')),
      DataColumn(label: _buildTableHeaderCell('Interest')),
      DataColumn(label: _buildTableHeaderCell('Remaining')),
      DataColumn(label: _buildTableHeaderCell('Interest Rate')),
      DataColumn(label: _buildTableHeaderCell('Loan Period')),
      DataColumn(label: _buildTableHeaderCell('Created At')),
    ];
  }

  Widget _buildTableHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: LoansConstants.textColor,
          fontSize: 12,
        ),
      ),
    );
  }

  List<DataRow> _buildTableRows() {
    return loans.map((loan) {
      return DataRow(
        cells: [
          if (widget.user.role == 'admin')
            DataCell(
              Checkbox(
                value: selectedLoans[loan['loan_id'].toString()] ?? false,
                onChanged: (value) {
                  setState(() {
                    selectedLoans[loan['loan_id'].toString()] = value!;
                  });
                },
                activeColor: LoansConstants.primaryColor,
              ),
            ),
          _buildDataCell(loan['employee_name']?.toString() ?? 'Unknown'),
          _buildCurrencyCell(loan['amount']),
          _buildCurrencyCell(loan['total_amount_repaid']),
          _buildCurrencyCell(loan['interest']),
          _buildCurrencyCell(loan['remaining_amount'], isHighlighted: true),
          _buildDataCell('${(loan['interest_rate']?.toDouble() ?? 0).toStringAsFixed(2)}%'),
          _buildDataCell('${loan['loan_period'] ?? 0} months'),
          _buildDataCell(_formatDate(loan['created_at'])),
        ],
      );
    }).toList();
  }

  DataCell _buildDataCell(String text) {
    return DataCell(
      Tooltip(
        message: text,
        child: Text(
          text,
          style: TextStyle(
            color: LoansConstants.textColor,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  DataCell _buildCurrencyCell(dynamic amount, {bool isHighlighted = false}) {
    final value = double.tryParse(amount?.toString() ?? '0.0') ?? 0.0;
    final formattedValue = 'KES ${value.toStringAsFixed(2)}';
    
    return DataCell(
      Tooltip(
        message: formattedValue,
        child: Text(
          formattedValue,
          style: TextStyle(
            color: isHighlighted ? LoansConstants.primaryColor : LoansConstants.textColor,
            fontSize: 12,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.tryParse(dateString);
      return date != null ? DateFormat('MMM dd, yyyy').format(date) : 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildFilterDropdown<T>({
    required T value,
    required List<T> items,
    required String labelText,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: LoansConstants.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        key: ValueKey(value),
        initialValue: value,
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    itemBuilder(item),
                    style: TextStyle(
                      color: LoansConstants.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelText: labelText,
          labelStyle: TextStyle(color: LoansConstants.subtitleColor, fontSize: 14),
          prefixIcon: Icon(icon, color: LoansConstants.primaryColor, size: 20),
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
            borderSide: BorderSide(color: LoansConstants.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        dropdownColor: LoansConstants.cardColor,
        icon: Icon(Icons.arrow_drop_down, color: LoansConstants.primaryColor),
        style: TextStyle(color: LoansConstants.textColor, fontSize: 14),
      ),
    );
  }

  Widget _buildFloatingActions(bool isAdmin) {
    if (!isAdmin) return const SizedBox.shrink();
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selectedLoans.isNotEmpty)
          FloatingActionButton(
            onPressed: _repayLoan,
            backgroundColor: LoansConstants.successColor,
            heroTag: 'bulk_repayment',
            tooltip: 'Bulk Repayment',
            child: const Icon(Icons.payment, color: Colors.white),
          ),
        if (selectedLoans.isNotEmpty) const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddLoanScreen(
                  user: widget.user.toMap(),
                  apiService: widget.apiService,
                ),
              ),
            ).then((_) => _fetchEmployeesAndLoans());
          },
          backgroundColor: LoansConstants.primaryColor,
          heroTag: 'add_loan',
          tooltip: 'Add Loan',
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ],
    );
  }
}