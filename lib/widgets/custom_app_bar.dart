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
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final bool centerTitle;

  const CustomAppBar({
    super.key,
    required this.title,
    this.backgroundColor = const Color(0xFF0D47A1),
    this.elevation = 2.0,
    this.actions,
    this.titleStyle,
    this.showNotifications = true,
    this.showProfile = true,
    this.onNotificationTap,
    this.onProfileTap,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: titleStyle ??
            const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      elevation: elevation,
      backgroundColor: backgroundColor,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      centerTitle: centerTitle,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: _buildActions(context),
    );
  }

  List<Widget>? _buildActions(BuildContext context) {
    final List<Widget> actionWidgets = [];

    // Add custom actions first
    if (actions != null) {
      actionWidgets.addAll(actions!);
    }

    // Add notification icon if enabled
    if (showNotifications) {
      actionWidgets.add(
        _buildSimpleIconButton(
          icon: Icons.notifications_outlined,
          onPressed: onNotificationTap ?? () => _showSnackbar(context, 'Notifications feature coming soon!'),
        ),
      );
    }

    // Add profile icon if enabled
    if (showProfile) {
      actionWidgets.add(
        _buildSimpleIconButton(
          icon: Icons.person_outlined,
          onPressed: onProfileTap ?? () => _showSnackbar(context, 'Profile feature coming soon!'),
        ),
      );
    }

    return actionWidgets.isNotEmpty ? actionWidgets : null;
  }

  Widget _buildSimpleIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
      splashRadius: 20,
    );
  }

  void _showSnackbar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor?.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}