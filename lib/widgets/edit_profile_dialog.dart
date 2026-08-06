import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/user_profile.dart';
import '../providers/profile_providers.dart';
import '../repositories/profile_repository.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../utils/error_handler.dart';
import 'avatar_image_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_strings.dart';

class EditProfileDialog extends ConsumerStatefulWidget {
  final UserProfile profile;

  const EditProfileDialog({super.key, required this.profile});

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  late TextEditingController _nameController;
  Uint8List? _avatarBytes;
  String? _avatarVersion;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _avatarBytes = bytes;
        _avatarVersion = null;
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.editProfileEmptyName)),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? uploadedAvatarPath;

      if (_avatarBytes != null) {
        final version = _avatarVersion ??= const Uuid().v4();
        uploadedAvatarPath = await ref
            .read(storageServiceProvider)
            .uploadAvatar(
              bytes: _avatarBytes!,
              uid: widget.profile.uid,
              version: version,
            );
        if (!mounted) return;
      }

      final patch = buildEditProfilePatch(
        displayName: name,
        uploadedAvatarPath: uploadedAvatarPath,
      );
      final repository = ref.read(profileRepositoryProvider);
      await repository.updateProfile(widget.profile.uid, patch);
      if (!mounted) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              AppStrings.editProfileUpdated,
              style: TextStyle(
                color: AppTheme.fondenteExtra,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppTheme.mentaGlaciale,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.editProfileTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Selettore Avatar
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    AuthenticatedAvatar(
                      source: widget.profile.photoUrl,
                      bytes: _avatarBytes,
                      radius: 50,
                      iconSize: 50,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Campo Nome
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: AppStrings.editProfileDisplayName,
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),

              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.icecream_outlined),
                title: Text(AppStrings.editProfileFavoritesTitle),
                subtitle: Text(AppStrings.editProfileFavoritesSubtitle),
              ),
              const SizedBox(height: 16),

              // Pulsanti Azione
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(AppStrings.cancel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                Image.asset(
                                      'assets/images/logo-white.png',
                                      width: 20,
                                      height: 20,
                                      fit: BoxFit.contain,
                                    )
                                    .animate(
                                      onPlay: (controller) =>
                                          controller.repeat(reverse: true),
                                    )
                                    .scaleXY(
                                      begin: 0.75,
                                      end: 1.15,
                                      duration: 600.ms,
                                      curve: Curves.easeInOutCubic,
                                    ),
                          )
                        : const Text(AppStrings.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ProfilePatch buildEditProfilePatch({
  required String displayName,
  String? uploadedAvatarPath,
}) => ProfilePatch(
  displayName: displayName,
  avatarPath: uploadedAvatarPath == null
      ? const Keep<String>()
      : SetValue<String>(uploadedAvatarPath),
);
