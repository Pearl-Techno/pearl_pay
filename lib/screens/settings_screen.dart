import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? selectedRate;

  void _showRateDetails(String rateType) {
    setState(() {
      selectedRate = rateType;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                children: [
                  _buildSettingsCard(
                    context,
                    icon: Icons.account_circle,
                    title: 'Account',
                    subtitle: 'Manage your account settings',
                    onTap: () {
                      // Navigate to Account settings screen
                    },
                  ),
                  _buildSettingsCard(
                    context,
                    icon: Icons.notifications,
                    title: 'Notifications',
                    subtitle: 'Manage your notification settings',
                    onTap: () {
                      // Navigate to Notifications settings screen
                    },
                  ),
                  _buildSettingsCard(
                    context,
                    icon: Icons.lock,
                    title: 'Privacy',
                    subtitle: 'Manage your privacy settings',
                    onTap: () {
                      // Navigate to Privacy settings screen
                    },
                  ),
                  _buildSettingsCard(
                    context,
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'Manage your language settings',
                    onTap: () {
                      // Navigate to Language settings screen
                    },
                  ),
                  _buildSettingsCard(
                    context,
                    icon: Icons.help,
                    title: 'Help & Support',
                    subtitle: 'Get help and support',
                    onTap: () {
                      // Navigate to Help & Support screen
                    },
                  ),
                  _buildSettingsCard(
                    context,
                    icon: Icons.info,
                    title: 'About',
                    subtitle: 'Learn more about the app',
                    onTap: () {
                      // Navigate to About screen
                    },
                  ),
                  _buildSettingsCard(
                    context,
                    icon: Icons.attach_money,
                    title: 'SHIF Rates',
                    subtitle: 'Set SHIF rates',
                    onTap: () => _showRateDetails('SHIF Rates'),
                  ),
                  _buildSettingsCard(
                    context,
                    icon: Icons.attach_money,
                    title: 'NSSF Rates',
                    subtitle: 'Set NSSF rates',
                    onTap: () => _showRateDetails('NSSF Rates'),
                  ),
                  _buildSettingsCard(
                    context,
                    icon: Icons.attach_money,
                    title: 'Housing Levy Rates',
                    subtitle: 'Set Housing Levy rates',
                    onTap: () => _showRateDetails('Housing Levy Rates'),
                  ),
                  _buildSettingsCard(
                    context,
                    icon: Icons.attach_money,
                    title: 'Loan Rates',
                    subtitle: 'Set Loan rates',
                    onTap: () => _showRateDetails('Loan Rates'),
                  ),
                  _buildSettingsCard(
                    context,
                    icon: Icons.attach_money,
                    title: 'Overtime Rates',
                    subtitle: 'Set Overtime rates',
                    onTap: () => _showRateDetails('Overtime Rates'),
                  ),
                  _buildSettingsCard(
                    context,
                    icon: Icons.attach_money,
                    title: 'PAYE Rates',
                    subtitle: 'Set PAYE rates',
                    onTap: () => _showRateDetails('PAYE Rates'),
                  ),
                ],
              ),
              if (selectedRate != null) ...[
                SizedBox(height: 16),
                Text(
                  '$selectedRate Details',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal),
                ),
                SizedBox(height: 16),
                _buildRateDetailsForm(selectedRate!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 150, // Fixed width for all cards
          height: 150, // Fixed height for all cards
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.teal, size: 40),
              SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRateDetailsForm(String rateType) {
    if (rateType == 'PAYE Rates') {
      return _buildPayeRatesForm();
    } else if (rateType == 'SHIF Rates') {
      return _buildShifRatesForm();
    } else if (rateType == 'Housing Levy Rates') {
      return _buildHousingLevyRatesForm();
    } else if (rateType == 'NSSF Rates') {
      return _buildNssfRatesForm();
    } else if (rateType == 'Loan Rates') {
      return _buildLoanRatesForm();
    } else if (rateType == 'Overtime Rates') {
      return _buildOvertimeRatesForm();
    }
    return Container();
  }

  Widget _buildPayeRatesForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set PAYE Rates',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal),
            ),
            SizedBox(height: 16),
            _buildPayeRateRow('Up to 24,000', 'Up to 288,000', '10.0'),
            _buildPayeRateRow('24,001 - 32,333', '288,001 - 388,000', '25.0'),
            _buildPayeRateRow(
                '32,334 - 500,000', '388,001 - 6,000,000', '30.0'),
            _buildPayeRateRow(
                '500,001 - 800,000', '6,000,001 - 9,600,000', '32.5'),
            _buildPayeRateRow('Above 800,000', 'Above 9,600,000', '35.0'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Save PAYE rates
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayeRateRow(
      String monthlyRange, String annualRange, String rate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: monthlyRange,
              decoration: InputDecoration(
                labelText: 'Monthly Range',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.text,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              initialValue: annualRange,
              decoration: InputDecoration(
                labelText: 'Annual Range',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.text,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              initialValue: rate,
              decoration: InputDecoration(
                labelText: 'Rate (%)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShifRatesForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set SHIF Rates',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal),
            ),
            SizedBox(height: 16),
            TextFormField(
              initialValue: '2.75',
              decoration: InputDecoration(
                labelText: 'SHIF Rate (%)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Save SHIF rate
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHousingLevyRatesForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set Housing Levy Rates',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal),
            ),
            SizedBox(height: 16),
            TextFormField(
              initialValue: '1.5',
              decoration: InputDecoration(
                labelText: 'Housing Levy Rate (%)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Save Housing Levy rate
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNssfRatesForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set NSSF Rates',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal),
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'NSSF Rate (%)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Save NSSF rate
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanRatesForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set Loan Rates',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal),
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Loan Rate (%)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Save Loan rate
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOvertimeRatesForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set Overtime Rates',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal),
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Overtime Rate (%)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Save Overtime rate
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
