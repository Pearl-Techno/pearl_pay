import 'package:flutter/material.dart';

import '../widgets/custom_app_bar.dart';

class TimeAndAttendanceScreen extends StatelessWidget {
  const TimeAndAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Time & Attendance',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          // Add your notification handling logic here
          print('Notifications tapped');
        },
        onProfileTap: () {
          // Add your profile handling logic here
          print('Profile tapped');
        },
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple[50]!, Colors.purple[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.access_time, color: Colors.purple),
                  title: const Text('Clock In/Out'),
                  subtitle: const Text('Tap to record your attendance'),
                  onTap: () {
                    // Add clock-in/out logic here
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Clock In/Out functionality to be implemented')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading:
                      const Icon(Icons.calendar_today, color: Colors.purple),
                  title: const Text('Select Date'),
                  subtitle: const Text('View attendance for a specific date'),
                  onTap: () {
                    // Add date picker logic here
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Date picker to be implemented')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: const [
                    ListTile(
                      leading: Icon(Icons.person, color: Colors.purple),
                      title: Text('Employee 1'),
                      subtitle: Text('Present - 8 hrs'),
                    ),
                    ListTile(
                      leading: Icon(Icons.person, color: Colors.purple),
                      title: Text('Employee 2'),
                      subtitle: Text('Absent'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
