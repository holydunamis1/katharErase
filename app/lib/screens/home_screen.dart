import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models/export_job.dart';
import '../core/services/share_service.dart';
import '../core/services/storage_service.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/recent_export_tile.dart';
import '../widgets/toast_notification.dart';

/// Logo, two big buttons (Camera, Gallery), recent exports grid (last 6),
/// settings gear top-right.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ExportJob> _recentExports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    try {
      final jobs = await StorageService.instance.getRecentExportJobs(limit: 6);
      if (mounted) setState(() => _recentExports = jobs);
    } catch (e) {
      // Storage failure shouldn't block the home screen — just show the
      // empty state as if there were no exports yet.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !context.mounted) return;
      context.push('/crop', extra: picked.path);
    } catch (e) {
      if (context.mounted) {
        ToastNotification.show(
          context,
          message: l10n.homeGalleryOpenFailed,
          type: ToastType.error,
        );
      }
    }
  }

  /// File 38's actual purpose: "tap to share again" — re-shares the
  /// already-exported file directly via ShareService, no editing session
  /// or export_bottom_sheet involved (a completed ExportJob has no mask/
  /// EditableImageState attached, just a finished file on disk).
  Future<void> _shareAgain(BuildContext context, ExportJob job) async {
    final l10n = AppLocalizations.of(context);
    try {
      final file = File(job.filePath);
      if (!await file.exists()) {
        if (context.mounted) {
          ToastNotification.show(
            context,
            message: l10n.homeExportUnavailable,
            type: ToastType.error,
          );
        }
        return;
      }
      final bytes = await file.readAsBytes();
      await ShareService.instance.shareImage(
        bytes,
        filename: file.uri.pathSegments.last,
      );
    } catch (e) {
      if (context.mounted) {
        ToastNotification.show(
          context,
          message: l10n.homeShareFailed,
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _BigActionButton(
                      icon: Icons.photo_camera,
                      label: l10n.homeCameraButton,
                      onTap: () => context.push('/camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigActionButton(
                      icon: Icons.photo_library_outlined,
                      label: l10n.homeGalleryButton,
                      onTap: () => _pickFromGallery(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(l10n.homeRecentExports, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_recentExports.isEmpty)
                const EmptyState()
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentExports.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, i) {
                    final job = _recentExports[i];
                    return RecentExportTile(
                      job: job,
                      onTap: () => _shareAgain(context, job),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.2,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
