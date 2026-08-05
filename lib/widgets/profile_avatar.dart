import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

class ProfileAvatar extends StatelessWidget {
  final String? avatarPath;
  final String? name;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.avatarPath,
    required this.name,
    this.radius = 24,
  });

  String? _avatarUrl() {
    final path = avatarPath?.trim();

    if (path == null || path.isEmpty) {
      return null;
    }

    return Supabase.instance.client.storage
        .from('avatars')
        .getPublicUrl(path);
  }

  String _initial() {
    final trimmedName = name?.trim() ?? '';

    if (trimmedName.isEmpty) {
      return '?';
    }

    return trimmedName.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _avatarUrl();

    return CircleAvatar(
      radius: radius,
      backgroundColor:
          AppColors.primary.withValues(alpha: 0.12),
      backgroundImage:
          avatarUrl == null ? null : NetworkImage(avatarUrl),
      child: avatarUrl == null
          ? Text(
              _initial(),
              style: TextStyle(
                color: AppColors.primary,
                fontSize: radius * 0.75,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}