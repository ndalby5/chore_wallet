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

  Color _fallbackColour() {
    final value = name?.trim().toLowerCase() ?? '';

    if (value.isEmpty) {
      return AppColors.primary;
    }

    final colours = <Color>[
      const Color(0xFF7C4DFF),
      const Color(0xFF3F51B5),
      const Color(0xFF2196F3),
      const Color(0xFF009688),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
    ];

    var total = 0;

    for (final character in value.codeUnits) {
      total += character;
    }

    return colours[total % colours.length];
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _avatarUrl();
    final fallbackColour = _fallbackColour();

    return CircleAvatar(
      radius: radius,
      backgroundColor: fallbackColour.withValues(
        alpha: 0.15,
      ),
      backgroundImage: avatarUrl == null
          ? null
          : NetworkImage(avatarUrl),
      child: avatarUrl == null
          ? Text(
              _initial(),
              style: TextStyle(
                color: fallbackColour,
                fontSize: radius * 0.75,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}
