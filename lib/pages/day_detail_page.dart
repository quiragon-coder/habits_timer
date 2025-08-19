import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../providers.dart';
import '../models/activity.dart';

class DayDetailPage extends ConsumerWidget {
  final DateTime date; const DayDetailPage({super.key, required this.date});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider); final start = DateTime(date.year,date.month,date.day); final end = start.add(const Duration(days:1));
    return Scaffold(appBar: AppBar(title: Text('Détail ${date.day}/${date.month}/${date.year}')),
      body: FutureBuilder<List<Session>>(
        future: db.getSessionsBetween(start, end),
        builder: (context, snap){
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final sessions = snap.data!;
          if (sessions.isEmpty) return const Center(child: Text('Aucune session.'));
          return FutureBuilder<List<Activity>>(
            future: db.getActivities(),
            builder: (context, aa){
              final acts = {for (final a in (aa.data ?? const <Activity>[])) a.id!: a};
              final byAct = <int, List<Session>>{};
              for (final s in sessions) { byAct.putIfAbsent(s.activityId, () => []).add(s); }
              final actIds = byAct.keys.toList()..sort();
              return ListView.builder(
                itemCount: actIds.length,
                itemBuilder: (ctx, idx){
                  final id = actIds[idx];
                  final list = byAct[id]!;
                  final a = acts[id];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Row(children: [
                          if (a!=null) Text(a.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(a?.name ?? 'Activité $id', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const Divider(height: 1),
                      ...list.map((s) => FutureBuilder<Duration>(
                        future: db.activeDuration(s),
                        builder: (context, ds) {
                          final d = ds.data ?? Duration.zero;
                          return ListTile(
                            leading: const Icon(Icons.timer),
                            title: Text('${_fmtRange(s.startAt, s.endAt)}'),
                            subtitle: Text('Actif: ${_fmtDur(d)}'),
                          );
                        },
                      )).toList(),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
  String _fmtDur(Duration d){ final h=d.inHours; final m=d.inMinutes.remainder(60); final s=d.inSeconds.remainder(60); return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}'; }
  String _fmtRange(DateTime a, DateTime? b){ final end=b??DateTime.now(); String hhmm(DateTime t)=>'${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}'; return '${hhmm(a)} → ${hhmm(end)}'; }
}
