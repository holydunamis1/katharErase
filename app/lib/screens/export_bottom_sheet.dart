import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../core/models/export_job.dart';
import '../core/providers/ad_provider.dart';
import '../core/providers/image_edit_provider.dart';
import '../core/providers/subscription_provider.dart';
import '../core/services/export_service.dart';
import '../core/services/share_service.dart';
import '../core/services/storage_service.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/primary_button.dart';
import '../widgets/toast_notification.dart';

/// Modal bottom sheet: format toggle, quality slider, resize toggle
/// (Original / 1:1 / 4:5 / 9:16 / Custom width/height), Save to Gallery,
/// Share. Dismisses to home. Interstitial may show after success (Free
/// user only, capped at 120s per Section 9 — enforced by ad_service.dart,
/// this sheet just triggers the attempt).
class ExportBottomSheet extends StatefulWidget {
  const ExportBottomSheet({super.key});

  @override
  State<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<ExportBottomSheet> {
  ExportFormat _format = ExportFormat.png;
  int _quality = 90;
  ResizeMode _resizeMode = ResizeMode.original;
  bool _isExporting = false;
  final TextEditingController _customWidthController = TextEditingController();
  final TextEditingController _customHeightController = TextEditingController();

  @override
  void dispose() {
    _customWidthController.dispose();
    _customHeightController.dispose();
    super.dispose();
  }

  bool get _showQualitySlider =>
      _format == ExportFormat.jpg || _format == ExportFormat.webp;

  /// Simple, dependency-free unique ID — avoids adding a `uuid` package
  /// for something this trivial. Timestamp + a small random suffix is
  /// sufficient uniqueness for locally-generated export job IDs/filenames
  /// (no cross-device or multi-user collision risk per Section 1's
  /// zero-backend, single-device architecture).
  String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = (now * 2654435761) % 0xFFFFFFFF; // cheap deterministic mix
    return '$now-${rand.toRadixString(16)}';
  }

  Future<void> _export(BuildContext context, {required bool alsoShare}) async {
    final l10n = AppLocalizations.of(context);
    final imageProvider = Provider.of<ImageEditProvider>(context, listen: false);
    final state = imageProvider.value;
    if (state.originalPath == null || state.imageSize == null) return;

    setState(() => _isExporting = true);
    try {
      final originalBytes = await File(state.originalPath!).readAsBytes();

      final maskLength =
          state.imageSize!.width.round() * state.imageSize!.height.round();
      final maskBytes = state.maskBytes ??
          (Uint8List(maskLength)..fillRange(0, maskLength, 255));

      final exportBytes = await ExportService.instance.compositeAndExport(
        originalBytes: originalBytes,
        maskBytes: maskBytes,
        backgroundType: state.backgroundType,
        bgColor: state.bgColor,
        blurRadius: state.blurRadius,
        edgeFeather: state.edgeFeather,
        format: _format,
        quality: _quality,
        resizeMode: _resizeMode,
        customWidth: _resizeMode == ResizeMode.custom
            ? int.tryParse(_customWidthController.text)
            : null,
        customHeight: _resizeMode == ResizeMode.custom
            ? int.tryParse(_customHeightController.text)
            : null,
      );

      final exportsDir = await StorageService.instance.getExportsDirectoryPath();
      final ext = switch (_format) {
        ExportFormat.png => 'png',
        ExportFormat.jpg => 'jpg',
        ExportFormat.webp => 'webp',
      };
      final filename = '${_generateId()}.$ext';
      final filePath = p.join(exportsDir, filename);
      await File(filePath).writeAsBytes(exportBytes);

      final job = ExportJob(
        id: _generateId(),
        format: _format,
        quality: _quality,
        width: state.imageSize!.width.round(),
        height: state.imageSize!.height.round(),
        resizeMode: _resizeMode,
        filePath: filePath,
        status: ExportStatus.complete,
        createdAt: DateTime.now(),
      );
      await StorageService.instance.saveExportJob(job);

      final saved = await ShareService.instance.saveToGallery(exportBytes);
      if (!saved && context.mounted) {
        await ShareService.instance.shareImage(exportBytes, filename: filename);
      } else if (alsoShare) {
        await ShareService.instance.shareImage(exportBytes, filename: filename);
      }

      if (context.mounted) {
        ToastNotification.show(context, message: l10n.exportSuccess, type: ToastType.success);
      }

      if (context.mounted) {
        final subscriptionProvider =
            Provider.of<SubscriptionProvider>(context, listen: false);
        if (!subscriptionProvider.value) {
          final adProvider = Provider.of<AdProvider>(context, listen: false);
          await adProvider.maybeShowPostExportInterstitial(personalized: false);
        }
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        context.go('/');
      }
    } catch (e) {
      if (context.mounted) {
        ToastNotification.show(context, message: l10n.exportFailed, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.exportTitle, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                SegmentedButton<ExportFormat>(
                  segments: [
                    ButtonSegment(value: ExportFormat.png, label: Text(l10n.exportFormatPng)),
                    ButtonSegment(value: ExportFormat.jpg, label: Text(l10n.exportFormatJpg)),
                    ButtonSegment(value: ExportFormat.webp, label: Text(l10n.exportFormatWebp)),
                  ],
                  selected: {_format},
                  onSelectionChanged: (s) => setState(() => _format = s.first),
                ),
                if (_showQualitySlider) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.exportQualityLabel(_quality),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Slider(
                    value: _quality.toDouble(),
                    min: 1,
                    max: 100,
                    onChanged: (v) => setState(() => _quality = v.round()),
                  ),
                ],
                const SizedBox(height: 12),
                Text(l10n.exportResizeLabel, style: Theme.of(context).textTheme.labelMedium),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.exportResizeOriginal),
                      selected: _resizeMode == ResizeMode.original,
                      onSelected: (_) => setState(() => _resizeMode = ResizeMode.original),
                    ),
                    ChoiceChip(
                      label: Text(l10n.cropAspect1x1),
                      selected: _resizeMode == ResizeMode.square1x1,
                      onSelected: (_) => setState(() => _resizeMode = ResizeMode.square1x1),
                    ),
                    ChoiceChip(
                      label: Text(l10n.cropAspect4x5),
                      selected: _resizeMode == ResizeMode.portrait4x5,
                      onSelected: (_) => setState(() => _resizeMode = ResizeMode.portrait4x5),
                    ),
                    ChoiceChip(
                      label: Text(l10n.cropAspect9x16),
                      selected: _resizeMode == ResizeMode.portrait9x16,
                      onSelected: (_) => setState(() => _resizeMode = ResizeMode.portrait9x16),
                    ),
                    ChoiceChip(
                      label: Text(l10n.exportResizeCustom),
                      selected: _resizeMode == ResizeMode.custom,
                      onSelected: (_) => setState(() => _resizeMode = ResizeMode.custom),
                    ),
                  ],
                ),
                if (_resizeMode == ResizeMode.custom) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customWidthController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: l10n.exportWidthLabel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _customHeightController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: l10n.exportHeightLabel),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: l10n.exportSaveToGallery,
                  icon: Icons.download,
                  isLoading: _isExporting,
                  onPressed: () => _export(context, alsoShare: false),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isExporting ? null : () => _export(context, alsoShare: true),
                  icon: const Icon(Icons.ios_share),
                  label: Text(l10n.exportShare),
                ),
              ],
            ),
            LoadingOverlay(visible: _isExporting, message: l10n.exportInProgress),
          ],
        ),
      ),
    );
  }
}
