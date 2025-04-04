// lib/widgets/custom_app_bar.dart
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color? backgroundColor;
  final double? elevation;
  final List<Widget>? actions;
  final TextStyle? titleStyle;
  final bool showNotifications;
  final bool showProfile;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;

  const CustomAppBar({
    super.key,
    required this.title,
    this.backgroundColor = Colors.teal,
    this.elevation = 2.0,
    this.actions,
    this.titleStyle,
    this.showNotifications = true,
    this.showProfile = true,
    this.onNotificationTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: titleStyle ??
            const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
            ),
      ),
      elevation: elevation,
      backgroundColor: backgroundColor,
      actions: [
        if (showNotifications)
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: onNotificationTap ?? () {},
            tooltip: 'Notifications',
          ),
        if (showProfile)
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: onProfileTap ?? () {},
            tooltip: 'Profile',
          ),
        if (actions != null)
          ...actions!, // Spread additional actions if provided
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
