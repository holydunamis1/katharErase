import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/resize_screen.dart';
import 'screens/passport_screen.dart';
import 'screens/watermark_screen.dart';
import 'screens/exif_screen.dart';
import 'screens/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/resize', builder: (context, state) => const ResizeScreen()),
    GoRoute(path: '/passport', builder: (context, state) => const PassportScreen()),
    GoRoute(path: '/watermark', builder: (context, state) => const WatermarkScreen()),
    GoRoute(path: '/exif', builder: (context, state) => const ExifScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
  ],
);
