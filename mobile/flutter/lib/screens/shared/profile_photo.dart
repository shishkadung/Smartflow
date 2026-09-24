import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';

Future<void> sfPickAndUploadProfilePhoto(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1200,
    );
    if (picked == null || !context.mounted) return;

    final data = await auth.api.uploadAvatar(picked.path);
    if (!context.mounted) return;
    final raw = data['user'];
    if (raw is Map<String, dynamic>) {
      await auth.refreshUser(AppUser.fromJson(raw));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']?.toString() ?? 'Photo updated')),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update profile photo')),
      );
    }
  }
}

Future<void> sfRemoveProfilePhoto(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  try {
    final data = await auth.api.removeAvatar();
    if (!context.mounted) return;
    final raw = data['user'];
    if (raw is Map<String, dynamic>) {
      await auth.refreshUser(AppUser.fromJson(raw));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']?.toString() ?? 'Photo removed')),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove profile photo')),
      );
    }
  }
}
