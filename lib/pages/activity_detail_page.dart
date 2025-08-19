import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity.dart';
import '../models/session.dart';
import '../providers.dart';
import '../services/database_service.dart';
import '../widgets/daily_bars.dart';
import '../widgets/hourly_bars.dart';

class ActivityDetailPage extends ConsumerStatefulWidget {
  final Activity activity;
  const ActivityDetailPage({super.key, required this.activity});
  @override
  ConsumerState<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends ConsumerState<ActivityDetailPage> {
  int rangeDays = 7;

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final db = ref.watch(dbProvider);
    final running = ref.watch(runningSessionProvider(a.id!));
    final liveSeconds = ref.watch(liveActiveSecondsProvider(a.id!));
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(a.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text(a.name, overflow: TextOverflow.ellipsis)),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Daily & Weekly goals summary
          if (a.goalHoursPerDay>0) ...[
          Card(child: Padding(padding: const EdgeInsets.all(16), child: FutureBuilder<int>(
            future: db.minutesForDay(DateTime.now(), a.id!),
            builder: (ctx, snap){ final dayH=(snap.data??0)/60.0; final dayGoal=a.goalHoursPerDay<=0?1.0:a.goalHoursPerDay; return Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Text('Objectifs du jour', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8),
              Row(children:[const Icon(Icons.today, size:16), const SizedBox(width:6), Text('Heures: \${dayH.toStringAsFixed(1)} / \${a.goalHoursPerDay.toStringAsFixed(1)}')]), const SizedBox(height:6),
              ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (dayH/dayGoal).clamp(0,1))),
            ]); },
          ))), const SizedBox(height: 12),],
          if (a.goalHoursPerWeek>0 || a.goalDaysPerWeek>0)
          FutureBuilder<Map<String,int>>(
            future: () async {
              final m = await db.minutesForWeek(DateTime.now(), a.id!);
              final d = await db.activeDaysForWeek(DateTime.now(), a.id!);
              return {"m": m, "d": d};
            }(),
            builder: (ctx, snap) {
              final map = snap.data ?? const {"m":0,"d":0};
              final hours = map["m"]!/60.0;
              final days = map["d"]!;
              final hrGoal = a.goalHoursPerWeek <= 0 ? 1.0 : a.goalHoursPerWeek;
              return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text('Objectifs de la semaine', style: Theme.of(context).textTheme.titleMedium), TextButton(onPressed: () async { final res = await Navigator.pushNamed(context, '/activity-edit', arguments: a); }, child: const Text('Modifier objectifs'))]),
                Text('Objectifs de la semaine', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(children: [const Icon(Icons.flag, size:16), const SizedBox(width:6), Text('Heures: ${hours.toStringAsFixed(1)} / ${a.goalHoursPerWeek.toStringAsFixed(1)}')]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (hours / hrGoal).clamp(0,1))),
                const SizedBox(height: 8),
                Row(children: [const Icon(Icons.event_available, size:16), const SizedBox(width:6), Text('Jours actifs: $days / ${a.goalDaysPerWeek}')]),
              ])));
            },
          ),
          const SizedBox(height: 12),
          _timerCard(running, liveSeconds, db),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1j')),
                ButtonSegment(value: 7, label: Text('7j')),
                ButtonSegment(value: 30, label: Text('30j')),
                ButtonSegment(value: 365, label: Text('365j')),
              ],
              selected: {rangeDays},
              onSelectionChanged: (s) { setState(() { rangeDays = s.first; }); },
            ),
          ),
          const SizedBox(height: 8),
          Text('Unités: axe vertical en heures, barres = minutes actives', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              if (rangeDays == 1) {
                return FutureBuilder<List<int>>(
                  future: db.hourlyActiveMinutes(DateTime.now(), activityId: a.id!),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                    return HourlyBars(minutes: snap.data!);
                  },
                );
              } else {
                return FutureBuilder<Map<DateTime,int>>(
                  future: _loadDaily(db, a.id!, rangeDays),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                    final map = snap.data!; final days = map.keys.toList()..sort(); final minutes = [for (final d in days) map[d] ?? 0];
                    return DailyBars(days: days, minutes: minutes, onTap: (day)=>Navigator.pushNamed(context, '/day-detail', arguments: DateTime(day.year,day.month,day.day)));
                  },
                );
              }
            },
          ),
          const SizedBox(height: 16),
          Text("Aujourd'hui", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<int>(
            stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
            builder: (context, _) {
              final start = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
              final end = start.add(const Duration(days: 1));
              return FutureBuilder<List<Session>>(
                future: db.getSessionsBetween(start, end, activityId: a.id!),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
                  final sessions = snap.data!;
                  if (sessions.isEmpty) return const Text('Aucune session aujourd\'hui.');
                  return Column(
                    children: [
                      for (final s in sessions) FutureBuilder<Duration>(
                        future: db.activeDuration(s),
                        builder: (context, dSnap) {
                          final d = dSnap.data ?? Duration.zero;
                          final range = _fmtRange(s.startAt, s.endAt);
                          final dur = _fmtDuration(d.inSeconds);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.history),
                            title: Text(range),
                            subtitle: Text(dur),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<Map<DateTime,int>> _loadDaily(DatabaseService db, int activityId, int days) async {
    final end = DateTime.now(); final start = end.subtract(Duration(days: days-1));
    return db.dailyActiveMinutes(DateTime(start.year,start.month,start.day), end, activityId: activityId);
  }

  Widget _timerCard(AsyncValue<Session?> running, AsyncValue<int> liveSeconds, DatabaseService db) {
    final a = widget.activity; final theme = Theme.of(context); final color = Color(a.colorValue);
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Timer', style: theme.textTheme.titleMedium), const SizedBox(height: 8),
      running.when(
        loading: ()=>const Text('Chargement…'),
        error: (e, st)=>Text('Erreur: $e'),
        data: (s){
          final isRunning = s!=null; final durSec = liveSeconds.asData?.value ?? 0;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isRunning ? _fmtDuration(durSec) : '00:00:00', style: theme.textTheme.displaySmall?.copyWith(color: color)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (!isRunning) FilledButton.icon(onPressed: () async { await db.startSession(a.id!); setState((){}); }, icon: const Icon(Icons.play_arrow), label: const Text('Démarrer')),
              if (isRunning) ...[
                FilledButton.icon(onPressed: () async { if (s==null || s.id==null) return; final sid = s.id!; await db.togglePause(sid); setState((){}); }, icon: const Icon(Icons.pause), label: const Text('Pause / Reprendre')),
                OutlinedButton.icon(onPressed: () async { if (s==null || s.id==null) return; final sid=s.id!; await db.stopSession(sid); setState((){}); }, icon: const Icon(Icons.stop), label: const Text('Arrêter')),
              ],
            ]),
          ]);
        },
      ),
    ])));
  }

  String _fmtRange(DateTime a, DateTime? b){
    final end = b ?? DateTime.now();
    String hhmm(DateTime t)=>'${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
    return '${hhmm(a)} → ${hhmm(end)}';
  }

  String _fmtDuration(int seconds){
    final d=Duration(seconds: seconds);
    final h=d.inHours.toString().padLeft(2,'0');
    final m=d.inMinutes.remainder(60).toString().padLeft(2,'0');
    final s=d.inSeconds.remainder(60).toString().padLeft(2,'0');
    return '$h:$m:$s';
  }
}
