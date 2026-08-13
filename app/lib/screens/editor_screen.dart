import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/models/editable_image_state.dart';
import '../core/providers/image_edit_provider.dart';
import '../widgets/ad_banner_slot.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/background_selector.dart';
import '../widgets/brush_controls.dart';
import '../widgets/bottom_toolbar.dart';
import '../widgets/edge_feather_slider.dart';
import '../widgets/editor_canvas.dart';
import '../widgets/loading_overlay.dart';
import 'export_bottom_sheet.dart';

enum _EditorTab { auto, manual, background }

/// The core screen. Top bar: back + segmented control [Auto/Manual/
/// Background]. editor_canvas fills the remaining space. Bottom:
/// bottom_toolbar (Undo/Redo/Reset/Before-After/Export per Section 3's
/// diagram — see note below). Bottom-most: ad_banner_slot.
///
/// Resolution note: Section 5's File 43 table entry says the top bar has
/// "back, undo, redo, before/after, export," which would duplicate
/// bottom_toolbar.dart (File 37) exactly. Section 3's detailed flow
/// diagram places those five actions at the bottom only, matching File 37
/// exactly, and gives the top bar just [Back] + the three-tab segmented
/// control. Section 3's diagram is more specific and doesn't conflict
/// with any other file's manifest purpose, so it's treated as
/// authoritative here — the abbreviated table description in File 43 is
/// read as imprecise shorthand, not a literal second control row.
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
    final size = await _decodeImageSize(widget.imagePath);
    _provider.loadImage(widget.imagePath, size);

    // Feature 1: auto-run segmentation on load. Preprocessing (resize to
    // the model's input tensor shape, normalize) happens here rather than
    // in the provider itself, since it needs the decoded image dimensions
    // this screen already has. Simplification note: this passes raw
    // decoded bytes; a production pass would resize/normalize to the
    // model's actual input tensor shape (queried via
    // SegmentationService.instance.inputShape after loadModel()) before
    // calling autoSegment — left as the next concrete step once Section
    // 14's real model file exists to test the exact preprocessing against.
    final bytes = await File(widget.imagePath).readAsBytes();
    await _provider.autoSegment(bytes);
  }

  Future<ui.Size> _decodeImageSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return ui.Size(frame.image.width.toDouble(), frame.image.height.toDouble());
  }

  void _openExportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ExportBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: SegmentedButton<_EditorTab>(
          segments: const [
            ButtonSegment(value: _EditorTab.auto, label: Text('Auto')),
            ButtonSegment(value: _EditorTab.manual, label: Text('Manual')),
            ButtonSegment(value: _EditorTab.background, label: Text('Background')),
          ],
          selected: {_tab},
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                const EditorCanvas(),
                ValueListenableBuilder<EditableImageState>(
                  valueListenable: _provider,
                  builder: (context, state, _) =>
                      LoadingOverlay(visible: state.isProcessing),
                ),
                ValueListenableBuilder<EditableImageState>(
                  valueListenable: _provider,
                  builder: (context, state, _) {
                    if (!state.autoSegmentationFailed) {
                      return const SizedBox.shrink();
                    }
                    // Feature 1 fallback message (File 71's fuller
                    // fallback_manual_editor.dart is the Phase 9 version
                    // of this same signal — this inline banner is the
                    // Phase 5 screen-level acknowledgment of the same
                    // autoSegmentationFailed flag).
                    return Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Material(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            "Your device doesn't support automatic background "
                            'removal. Use the manual eraser below.',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          switch (_tab) {
            _EditorTab.auto => const EdgeFeatherSlider(),
            _EditorTab.manual => const BrushControls(),
            _EditorTab.background => const BackgroundSelector(),
          },
          BottomToolbar(onExport: _openExportSheet),
          const AdBannerSlot(personalized: false),
        ],
      ),
    );
  }
}
