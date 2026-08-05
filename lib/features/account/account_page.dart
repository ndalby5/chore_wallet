import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isUploading = false;

  String? _errorMessage;
  String? _name;
  String? _email;
  String? _avatarPath;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'You need to sign in again.';
        _isLoading = false;
      });

      return;
    }

    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('name, avatar_path')
          .eq('id', currentUser.id)
          .limit(1);

      final profiles =
          List<Map<String, dynamic>>.from(rows);

      String? name;
      String? avatarPath;

      if (profiles.isNotEmpty) {
        name = profiles.first['name']?.toString();
        avatarPath =
            profiles.first['avatar_path']?.toString();
      }

      String? avatarUrl;

      if (avatarPath != null && avatarPath.isNotEmpty) {
        avatarUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(avatarPath);

        // This prevents an old cached image from showing
        // after the user replaces their avatar.
        avatarUrl =
            '$avatarUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      }

      if (!mounted) return;

      setState(() {
        _name = name;
        _email = currentUser.email;
        _avatarPath = avatarPath;
        _avatarUrl = avatarUrl;
        _errorMessage = null;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Could not load your account.';
        _isLoading = false;
      });
    }
  }

  Future<void> _chooseProfilePicture() async {
    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedImage == null) {
        return;
      }

      final imageBytes = await pickedImage.readAsBytes();

      if (!mounted) return;

      await _uploadProfilePicture(
        imageBytes: imageBytes,
        originalName: pickedImage.name,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open your photo library.',
          ),
        ),
      );
    }
  }

  Future<void> _uploadProfilePicture({
    required Uint8List imageBytes,
    required String originalName,
  }) async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      return;
    }

    if (imageBytes.length > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please choose an image smaller than 5 MB.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final extension = _fileExtension(originalName);
      final avatarPath =
          '${currentUser.id}/avatar.$extension';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            avatarPath,
            imageBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentType(extension),
            ),
          );

      await Supabase.instance.client
          .from('profiles')
          .update({
            'avatar_path': avatarPath,
          })
          .eq('id', currentUser.id);

      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(avatarPath);

      if (!mounted) return;

      setState(() {
        _avatarPath = avatarPath;
        _avatarUrl =
            '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated.'),
        ),
      );
    } on StorageException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not upload the profile picture.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  String _fileExtension(String fileName) {
    final extension = fileName
        .split('.')
        .last
        .toLowerCase();

    switch (extension) {
      case 'png':
        return 'png';
      case 'webp':
        return 'webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'jpg';
    }
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _initial() {
    final name = _name?.trim() ?? '';

    if (name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    }

    final email = _email?.trim() ?? '';

    if (email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }

    return '?';
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not sign out. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Account',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 52,
                color: AppColors.danger,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });

                  _loadProfile();
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        120,
      ),
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 58,
                backgroundColor:
                    AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: _avatarUrl == null
                    ? null
                    : NetworkImage(_avatarUrl!),
                child: _avatarUrl == null
                    ? Text(
                        _initial(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: -4,
                bottom: -2,
                child: Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isUploading
                        ? null
                        : _chooseProfilePicture,
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: _isUploading
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white,
                              size: 21,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _name?.trim().isNotEmpty == true
              ? _name!
              : 'PocketPot user',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _email ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.subtitle,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFEAE8F2),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.photo_camera_outlined,
                color: AppColors.primary,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Tap the camera button to choose or replace your profile picture.',
                  style: TextStyle(
                    color: AppColors.subtitle,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
          label: const Text(
            'Sign Out',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(
              color: AppColors.danger,
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}