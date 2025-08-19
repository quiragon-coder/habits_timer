import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pause.dart';
import '../providers.dart';

class AnnualHeatmapPage extends ConsumerStatefulWidget { const AnnualHeatmapPage({super.key}); @override ConsumerState<AnnualHeatmapPage> createState()=>_AnnualHeatmapPageState(); }
class _AnnualHeatmapPageState extends ConsumerState<AnnualHeatmapPage> {
  int _year = DateTime.now().year;
  @override Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.primary;
    return Scaffold(appBar: AppBar(title: const Text('Heatmap annuelle'), actions: [
      IconButton(icon: const Icon(Icons.chevron_left), onPressed: ()=>setState(()=>_year--)),
      Center(child: Text('$_year', style: const TextStyle(fontWeight: FontWeight.w600))),
      IconButton(icon: const Icon(Icons.chevron_right), onPressed: ()=>setState(()=>_year++)),
      const SizedBox(width: 8)]),
      body: FutureBuilder<Map<DateTime,int>>(
        future: _buildYear(ref, _year),
        builder: (context, snap){
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final totals = snap.data!; if (totals.isEmpty) return const Center(child: Text('Aucune donnée.'));
          final days = totals.keys.toList()..sort();
          final values = totals.values.where((m)=>m>0).toList()..sort();
          List<int> qs(){ if(values.isEmpty) return [0,0,0,0]; int q(double p)=> values[(p*(values.length-1)).round()]; return [q(0.25),q(0.50),q(0.75),values.last]; }
          Color colorFor(int m){ if (m<=0) return Colors.grey.withValues(alpha: 0.2); final h=HSLColor.fromColor(base);
            Color tone(double s,double l)=>h.withSaturation(s).withLightness(l).toColor();
            final q=qs(); if(m<=q[0]) return tone((h.saturation+0.05).clamp(0,1), math.max(0.75,h.lightness));
            if(m<=q[1]) return tone((h.saturation+0.15).clamp(0,1), (h.lightness-0.05).clamp(0,1));
            if(m<=q[2]) return tone((h.saturation+0.25).clamp(0,1), (h.lightness-0.10).clamp(0,1));
            return tone((h.saturation+0.35).clamp(0,1), (h.lightness-0.15).clamp(0,1)); }
          DateTime dateOnly(DateTime d)=>DateTime(d.year,d.month,d.day);
          DateTime mondayOnOrBefore(DateTime d){ final sub=(d.weekday+6)%7; return dateOnly(d.subtract(Duration(days: sub))); }
          DateTime sundayOnOrAfter(DateTime d){ final add=d.weekday==DateTime.sunday?0:(7-d.weekday); return dateOnly(d.add(Duration(days: add))); }
          final first = days.first; final last = days.last; final weeks = <List<DateTime>>[];
          for (DateTime w = mondayOnOrBefore(first); !w.isAfter(sundayOnOrAfter(last)); w = w.add(const Duration(days:7))) {
            weeks.add(List.generate(7, (i)=> w.add(Duration(days:i))));
          }
          return Column(children: [
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal:12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(width: 24),
              Column(children: const [SizedBox(height:6), _WeekdayLabel('L'), SizedBox(height:6), _WeekdayLabel('M'), SizedBox(height:6), _WeekdayLabel('M'), SizedBox(height:6), _WeekdayLabel('J'), SizedBox(height:6), _WeekdayLabel('V'), SizedBox(height:6), _WeekdayLabel('S'), SizedBox(height:6), _WeekdayLabel('D')]),
              const SizedBox(width: 8),
              Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final week in weeks) Column(children: [
                  for (final d in week) _DayCell(date: d, minutes: totals[d] ?? 0, color: colorFor(totals[d] ?? 0), onTap: (){ _showDaySheet(context, d, totals[d] ?? 0); }),
                ]),
              ]))),
            ])),
            const SizedBox(height: 12),
          ]);
        },
      ),
    );
  }
  Future<Map<DateTime,int>> _buildYear(WidgetRef ref, int year) async {
    final db = ref.read(dbProvider);
    final first = DateTime(year,1,1); final last = DateTime(year,12,31,23,59,59,999);
    final sessions = await db.getSessionsBetween(first, last);
    final totals = <DateTime,int>{};
    DateTime dOnly(DateTime d)=>DateTime(d.year,d.month,d.day);
    Duration overlap(DateTime a1,DateTime a2,DateTime b1,DateTime b2){ final s=a1.isAfter(b1)?a1:b1; final e=a2.isBefore(b2)?a2:b2; if(!e.isAfter(s)) return Duration.zero; return e.difference(s); }
    final pausesBy = <int,List<Pause>>{};
    for (final s in sessions) { pausesBy[s.id!] = await db.getPausesForSession(s.id!); }
    for (final s in sessions) {
      final end = s.endAt ?? DateTime.now();
      for (DateTime day = dOnly(s.startAt); !day.isAfter(dOnly(end)); day = day.add(const Duration(days:1))) {
        final dayStart = day; final dayEnd = day.add(const Duration(days:1));
        var active = overlap(s.startAt, end, dayStart, dayEnd);
        for (final p in pausesBy[s.id!] ?? const <Pause>[]) { active -= overlap(p.startAt, p.endAt ?? DateTime.now(), dayStart, dayEnd); }
        if (active.isNegative) continue;
        final m = active.inMinutes; totals.update(dayStart, (v)=>v+m, ifAbsent: ()=>m);
      }
    }
    return totals;
  }
  void _showDaySheet(BuildContext context, DateTime date, int minutes){
    showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx)=>SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${date.day}/${date.month}/${date.year}', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8), Text('Temps actif: ${_fmtHm(minutes)}'), const SizedBox(height: 12),
      Row(children: [
        ElevatedButton.icon(onPressed: (){ Navigator.of(context).pop(); Navigator.of(context).pushNamed('/day-detail', arguments: DateTime(date.year,date.month,date.day)); }, icon: const Icon(Icons.insights), label: const Text('Voir détail du jour')),
        const SizedBox(width: 8), TextButton.icon(onPressed: ()=>Navigator.of(context).pop(), icon: const Icon(Icons.close), label: const Text('Fermer')),
      ]),
    ]))));
  }
  String _fmtHm(int m){ final h=m~/60; final mm=m%60; if (h==0) return '${mm}m'; if (mm==0) return '${h}h'; return '${h}h ${mm}m'; }
}

class _WeekdayLabel extends StatelessWidget { final String text; const _WeekdayLabel(this.text); @override Widget build(BuildContext context)=>SizedBox(height:18,width:24,child:Align(alignment: Alignment.centerLeft, child: Text(text, style: Theme.of(context).textTheme.bodySmall))); }
class _DayCell extends StatelessWidget { final DateTime date; final int minutes; final Color color; final VoidCallback onTap; const _DayCell({required this.date, required this.minutes, required this.color, required this.onTap});
  @override Widget build(BuildContext context){ return Padding(padding: const EdgeInsets.all(2), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(3), child: Tooltip(message: '${_fmtHm(minutes)} le ${date.day}/${date.month}/${date.year}', child: Container(width:14,height:14,decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)))))); }
  String _fmtHm(int m){ final h=m~/60; final mm=m%60; if (h==0) return '${mm}m'; if (mm==0) return '${h}h'; return '${h}h ${mm}m'; }
}
