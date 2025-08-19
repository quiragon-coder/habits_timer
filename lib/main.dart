import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/activities_list_page.dart';
import 'pages/settings_page.dart';
import 'pages/annual_heatmap_page.dart';
import 'pages/day_detail_page.dart';
import 'models/activity.dart';
import 'pages/activity_edit_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: HabitsApp()));
}

class HabitsApp extends StatelessWidget {
  const HabitsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habits Timer',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF6750A4)),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF6750A4), brightness: Brightness.dark),
      routes: {
        '/': (_) => const ActivitiesListPage(),
        '/settings': (_) => const SettingsPage(),
        '/annual-heatmap': (_) => const AnnualHeatmapPage(),
        '/activity-edit': (ctx){
          final arg = ModalRoute.of(ctx)!.settings.arguments as Activity?;
          return ActivityEditPage(activity: arg);
        },
        '/day-detail': (ctx) {
          final arg = ModalRoute.of(ctx)!.settings.arguments as DateTime?;
          return DayDetailPage(date: arg ?? DateTime.now());
        },
      },
    );
  }
}
