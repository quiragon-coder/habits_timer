import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/activity.dart';
import 'models/session.dart';
import 'services/database_service.dart';

final dbProvider = Provider<DatabaseService>((ref) => DatabaseService());
final activitiesProvider = FutureProvider<List<Activity>>((ref) async => ref.watch(dbProvider).getActivities());

final runningSessionProvider = StreamProvider.family<Session?, int>((ref, activityId) async* {
  final db = ref.watch(dbProvider);
  while (true) {
    yield await db.getRunningSession(activityId);
    await Future.delayed(const Duration(seconds: 1));
  }
});

final liveActiveSecondsProvider = StreamProvider.family<int, int>((ref, activityId) async* {
  final db = ref.watch(dbProvider);
  while (true) {
    final s = await db.getRunningSession(activityId);
    if (s == null) {
      yield 0;
    } else {
      final d = await db.activeDuration(s);
      yield d.inSeconds;
    }
    await Future.delayed(const Duration(seconds: 1));
  }
});
