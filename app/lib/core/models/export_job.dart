import 'package:freezed_annotation/freezed_annotation.dart';

part 'export_job.freezed.dart';
part 'export_job.g.dart';

/// Feature 5 export formats.
enum ExportFormat { png, jpg, webp }

/// Feature 14 resize presets.
enum ResizeMode { original, square1x1, portrait4x5, portrait9x16, custom }

enum ExportStatus { pending, processing, complete, failed }

/// Persisted via sqflite (storage_service.dart, Phase 2) to back the
/// "Recent Exports" grid on home_screen.dart (Phase 5). JSON-serializable
/// because it crosses the storage boundary — unlike EditableImageState,
/// which stays in memory for the current session only.
///
/// freezed ^3.2.5 syntax: `abstract class`, not plain `class` (breaking
/// change from freezed 2.x — see pubspec.yaml comment on the freezed pin).
@freezed
abstract class ExportJob with _$ExportJob {
  const factory ExportJob({
    required String id,
    required ExportFormat format,
    required int quality, // 0-100, relevant for jpg/webp only
    required int width,
    required int height,
    required ResizeMode resizeMode,
    required String filePath,
    required ExportStatus status,
    required DateTime createdAt,
  }) = _ExportJob;

  factory ExportJob.fromJson(Map<String, dynamic> json) =>
      _$ExportJobFromJson(json);
}
