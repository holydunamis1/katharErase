import 'dart:io';

import 'package:flutter/material.dart';

import '../core/models/export_job.dart';
import '../core/utils/date_formatter.dart';
import '../core/utils/extensions.dart';
import '../generated/l10n/app_localizations.dart';

/// Thumbnail, format badge, date, tap to share again. Used in home_
/// screen.dart's recent exports grid (Phase 5).
class RecentExportTile extends StatelessWidget {
  const RecentExportTile({
    super.key,
    required this.job,
    required this.onTap,
  });

  final ExportJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _thumbnail(context),
            PositionedDirectional(
              top: 6,
              start: 6,
              child: _FormatBadge(format: job.format),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: Text(
                  DateFormatter.relative(
                    job.createdAt,
                    locale: Localizations.localeOf(context).toString(),
                    todayLabel: AppLocalizations.of(context).dateToday,
                    yesterdayLabel: AppLocalizations.of(context).dateYesterday,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail(BuildContext context) {
    final file = File(job.filePath);
    if (!file.existsSync()) {
      return Container(
        color: context.colors.surfaceContainerHighest,
        child: Icon(Icons.broken_image_outlined, color: context.colors.onSurfaceVariant),
      );
    }
    return Image.file(file, fit: BoxFit.cover);
  }
}

class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.format});

  final ExportFormat format;

  @override
  Widget build(BuildContext context) {
    final label = switch (format) {
      ExportFormat.png => 'PNG',
      ExportFormat.jpg => 'JPG',
      ExportFormat.webp => 'WEBP',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
