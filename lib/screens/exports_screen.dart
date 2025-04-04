import 'package:flutter/material.dart';

import '../exports/housing_levy_export.dart';
import '../exports/nssf_export.dart';
import '../exports/paye_export.dart';
import '../exports/shif_export.dart';
import '../widgets/custom_app_bar.dart';

class ExportsScreen extends StatelessWidget {
  const ExportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nssfExport = NSSFExport();
    final shifExport = SHIFExport();
    final housingLevyExport = HousingLevyExport();
    final payeExport = PAYEExport();

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Exports',
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
                      'Export Options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // First row with 2 tiles
                    SizedBox(
                      height: 110,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildExportTile(
                            context,
                            icon: Icons.file_download,
                            title: 'NSSF Export',
                            subtitle: 'Export NSSF data',
                            exportWidget: nssfExport.buildCard(context),
                            backgroundColor: Colors.blue[50]!,
                            iconColor: Colors.blue[500]!,
                            tileCount: 2,
                          ),
                          _buildExportTile(
                            context,
                            icon: Icons.file_download,
                            title: 'SHIF Export',
                            subtitle: 'Export SHIF data',
                            exportWidget: shifExport.buildCard(context),
                            backgroundColor: Colors.green[50]!,
                            iconColor: Colors.green[500]!,
                            tileCount: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Second row with 2 tiles
                    SizedBox(
                      height: 110,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildExportTile(
                            context,
                            icon: Icons.file_download,
                            title: 'Housing Levy',
                            subtitle: 'Export levy data',
                            exportWidget: housingLevyExport.buildCard(context),
                            backgroundColor: Colors.yellow[50]!,
                            iconColor: Colors.yellow[700]!,
                            tileCount: 2,
                          ),
                          _buildExportTile(
                            context,
                            icon: Icons.file_download,
                            title: 'PAYE Export',
                            subtitle: 'Export PAYE data',
                            exportWidget: payeExport.buildCard(context),
                            backgroundColor: Colors.orange[50]!,
                            iconColor: Colors.orange[500]!,
                            tileCount: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget exportWidget, // Widget from buildCard
    required Color backgroundColor,
    required Color iconColor,
    required int tileCount,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 32.0; // 16 on each side
    final spacingBetweenTiles = 16.0 * (tileCount - 1);
    final tileWidth =
        (screenWidth - horizontalPadding - spacingBetweenTiles) / tileCount;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.grey.withOpacity(0.3),
      child: InkWell(
        onTap: () {
          // Optionally navigate to a detailed view or trigger export action
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              content: exportWidget,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: tileWidth,
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, backgroundColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.teal[900],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
