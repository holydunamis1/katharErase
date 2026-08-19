import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/utils/theme.dart';
import '../widgets/ad_banner_slot.dart';
import '../widgets/app_scaffold.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = [
      _ToolConfig(title: 'Batch Resizer', description: 'Compress & scale image dimensions locally.', icon: Icons.unfold_less_rounded, accentColor: AppTheme.resizeTint, route: '/resize', badge: 'BATCH'),
      _ToolConfig(title: 'Passport Maker', description: 'Crop exact ID and passport dimensions.', icon: Icons.person_outline_rounded, accentColor: AppTheme.passportTint, route: '/passport', badge: 'ID SPEC'),
      _ToolConfig(title: 'Watermark Studio', description: 'Apply custom text or visual overlays.', icon: Icons.layers_outlined, accentColor: AppTheme.watermarkTint, route: '/watermark', badge: 'CUSTOM'),
      _ToolConfig(title: 'EXIF Wiped', description: 'Strip location and device metadata securely.', icon: Icons.admin_panel_settings_outlined, accentColor: AppTheme.exifTint, route: '/exif', badge: 'SECURE'),
    ];

    return AppScaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.resizeTint.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.hub_rounded, color: AppTheme.resizeTint, size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Image Desk Pro'),
                Text('Professional Image Toolkit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16.0, mainAxisSpacing: 16.0, childAspectRatio: 0.85),
                itemCount: tools.length,
                itemBuilder: (context, index) {
                  final tool = tools[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.withOpacity(0.08), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => context.push(tool.route),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: tool.accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                                    child: Icon(tool.icon, size: 26, color: tool.accentColor),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: tool.accentColor.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                                    child: Text(tool.badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: tool.accentColor, letterSpacing: 0.5)),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tool.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryDark, letterSpacing: -0.3)),
                                  const SizedBox(height: 4),
                                  Text(tool.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400, color: Colors.grey[600], height: 1.3)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const AdBannerSlot(personalized: false),
        ],
      ),
    );
  }
}

class _ToolConfig {
  const _ToolConfig({required this.title, required this.description, required this.icon, required this.accentColor, required this.route, required this.badge});
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String route;
  final String badge;
}
