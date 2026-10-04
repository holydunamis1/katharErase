import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/models/editable_image_state.dart';
import '../core/providers/image_edit_provider.dart';
import '../generated/l10n/app_localizations.dart';
import '../platform/image_prep_service.dart';
import '../widgets/ad_banner_slot.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/background_selector.dart';
import '../widgets/bottom_toolbar.dart';
import '../widgets/brush_controls.dart';
import '../widgets/edge_feather_slider.dart';
import '../widgets/editor_canvas.dart';
import '../widgets/fallback_manual_editor.dart';
import '../widgets/loading_overlay.dart';
import 'export_bottom_sheet.dart';

enum _EditorTab { auto, manual, background }

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  _EditorTab _tab = _EditorTab.auto;
  late final ImageEditProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<ImageEditProvider>(context, listen: false);
    _loadAndSegment();
  }

  Future<void> _loadAndSegment() async {
    // Show the spinner immediately; decoding, EXIF rotation, resizing and
    // model preprocessing all run in a background isolate.
    _provider.value = const EditableImageState(isProcessing: true);
    try {
      final tempDir = await getTemporaryDirectory();
      final prepared = await prepareImage(widget.imagePath, tempDir.path);
      if (!mounted) return;
      _provider.loadImage(
        prepared.path,
        ui.Size(prepared.width.toDouble(), prepared.height.toDouble()),
      );
      await _provider.autoSegment(
        prepared.modelInput,
        prepared.width,
        prepared.height,
      );
    } catch (_) {
      if (!mounted) return;
      _provider.value = _provider.value.copyWith(
        isProcessing: false,
        autoSegmentationFailed: true,
      );
    }
  }

  void _openExportSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ExportBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: ValueListenableBuilder<EditableImageState>(
          valueListenable: _provider,
          builder: (context, state, _) {
            if (state.autoSegmentationFailed) {
              return Text(l10n.editorTabManual);
            }
            return SegmentedButton<_EditorTab>(
              segments: [
                ButtonSegment(value: _EditorTab.auto, label: Text(l10n.editorTabAuto)),
                ButtonSegment(value: _EditorTab.manual, label: Text(l10n.editorTabManual)),
                ButtonSegment(
                  value: _EditorTab.background,
                  label: Text(l10n.editorTabBackground),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            );
          },
        ),
      ),
      body: ValueListenableBuilder<EditableImageState>(
        valueListenable: _provider,
        builder: (context, state, _) {
          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    if (state.autoSegmentationFailed)
                      const FallbackManualEditor()
                    else
                      const EditorCanvas(),
                    LoadingOverlay(visible: state.isProcessing),
                  ],
                ),
              ),
              if (!state.autoSegmentationFailed)
                switch (_tab) {
                  _EditorTab.auto => const EdgeFeatherSlider(),
                  _EditorTab.manual => const BrushControls(),
                  _EditorTab.background => const BackgroundSelector(),
                },
              BottomToolbar(onExport: _openExportSheet),
              const AdBannerSlot(personalized: false),
            ],
          );
        },
      ),
    );
  }
}
