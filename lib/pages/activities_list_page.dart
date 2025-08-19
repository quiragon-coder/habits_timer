import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity.dart';
import '../providers.dart';
import 'activity_detail_page.dart';
import 'activity_edit_page.dart';

class ActivitiesListPage extends ConsumerStatefulWidget {
  const ActivitiesListPage({super.key});
  @override
  ConsumerState<ActivitiesListPage> createState() => _ActivitiesListPageState();
}

class _ActivitiesListPageState extends ConsumerState<ActivitiesListPage> {
  @override
  Widget build(BuildContext context) {
    final activities = ref.watch(activitiesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits Timer'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/annual-heatmap'),
            icon: const Icon(Icons.grid_view),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: activities.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erreur: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Aucune activité. Ajoute avec +'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final a = list[i];
                return Column(
                  children: [
                    ListTile(
                      leading: Text(a.emoji, style: const TextStyle(fontSize: 24)),
                      title: Text(a.name),
                      subtitle: Text('Objectifs: ${a.goalHoursPerWeek}h/sem, ${a.goalDaysPerWeek}j/sem'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ActivityDetailPage(activity: a)),
                      ),
                      onLongPress: () => _edit(context, a),
                    ),
                    if (!(a.goalHoursPerWeek<=0 && a.goalDaysPerWeek<=0))
                      FutureBuilder<Map<String, int>>(
                        future: _progressFor(a.id!, a.goalHoursPerWeek, a.goalDaysPerWeek),
                        builder: (ctx, snap) {
                          final m = snap.data ?? const {"m": 0, "d": 0};
                          final hours = m["m"]! / 60.0;
                          final hrGoal = a.goalHoursPerWeek <= 0 ? 1.0 : a.goalHoursPerWeek;
                          final days = m["d"]!;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (a.goalHoursPerWeek > 0) ...[
                                  Row(
                                    children: [
                                      const Icon(Icons.flag, size: 16),
                                      const SizedBox(width: 6),
                                      Text('Semaine: ${hours.toStringAsFixed(1)} / ${a.goalHoursPerWeek.toStringAsFixed(1)}'),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(value: (hours / hrGoal).clamp(0, 1)),
                                  ),
                                ],
                                if (a.goalDaysPerWeek > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.event_available, size: 16),
                                      const SizedBox(width: 6),
                                      Text('Jours actifs: $days / ${a.goalDaysPerWeek}'),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle activité'),
      ),
    );
  }

  Future<void> _edit(BuildContext context, Activity? a) async {
    final res = await Navigator.push<Activity?>(
      context,
      MaterialPageRoute(builder: (_) => ActivityEditPage(activity: a)),
    );
    if (res == null) return;
    final db = ref.read(dbProvider);
    if (res.id == null) {
      await db.insertActivity(res);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activité ajoutée')));
    } else {
      await db.updateActivity(res);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activité modifiée')));
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    // Force refetch and rebuild
    await ref.read(dbProvider).getActivities();
    ref.invalidate(activitiesProvider);
    if (mounted) setState(() {});
  }

  Future<Map<String, int>> _progressFor(int activityId, double goalH, int goalD) async {
    final db = ref.read(dbProvider);
    final now = DateTime.now();
    final m = await db.minutesForWeek(now, activityId);
    final d = await db.activeDaysForWeek(now, activityId);
    return {"m": m, "d": d};
  }
}
