import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';

Future<void> sfPickAndUploadProfilePhoto(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final token = auth.token;
  final userId = auth.user?.id;
  if (token == null || userId == null || auth.loggingOut) return;
  final api = auth.api;
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1200,
    );
    if (picked == null ||
        !context.mounted ||
        auth.loggingOut ||
        !auth.isCurrentSession(token, userId)) {
      return;
    }

    final data = await api.uploadAvatar(picked.path);
    final raw = data['user'];
    if (raw is Map<String, dynamic>) {
      final applied = await auth.refreshUser(
        AppUser.fromJson(raw),
        expectedToken: token,
      );
      if (!applied ||
          !context.mounted ||
          !auth.isCurrentSession(token, userId)) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']?.toString() ?? 'Photo updated')),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted && auth.isCurrentSession(token, userId)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (_) {
    if (context.mounted && auth.isCurrentSession(token, userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update profile photo')),
      );
    }
  }
}

Future<void> sfRemoveProfilePhoto(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final token = auth.token;
  final userId = auth.user?.id;
  if (token == null || userId == null || auth.loggingOut) return;
  final api = auth.api;
  try {
    final data = await api.removeAvatar();
    final raw = data['user'];
    if (raw is Map<String, dynamic>) {
      final applied = await auth.refreshUser(
        AppUser.fromJson(raw),
        expectedToken: token,
      );
      if (!applied ||
          !context.mounted ||
          !auth.isCurrentSession(token, userId)) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']?.toString() ?? 'Photo removed')),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted && auth.isCurrentSession(token, userId)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (_) {
    if (context.mounted && auth.isCurrentSession(token, userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove profile photo')),
      );
    }
  }
}
