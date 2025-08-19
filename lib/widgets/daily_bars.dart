import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DailyBars extends StatelessWidget {
  final List<DateTime> days;
  final List<int> minutes;
  final void Function(DateTime day)? onTap;
  const DailyBars({super.key, required this.days, required this.minutes, this.onTap});

  @override
  Widget build(BuildContext context) {
    final maxMin = (minutes.isEmpty ? 0 : minutes.reduce((a,b)=>a>b?a:b));
    final barGroups = List.generate(days.length, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: minutes[i].toDouble()/60.0)]));
    return SizedBox(
      height: 240,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: (days.length*28).toDouble().clamp(300, double.infinity),
          child: BarChart(BarChartData(
            maxY: (maxMin/60.0 + 1).clamp(1, 24).toDouble(),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles:true, reservedSize:36,
                getTitlesWidget: (value, meta) {
                  final v = value.toDouble();
                  if ((v - v.round()).abs() > 1e-6) return const SizedBox.shrink();
                  return Text('${v.toInt()} h', style: const TextStyle(fontSize: 10));
                },
              )),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles:false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles:false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles:true, getTitlesWidget: (value, meta){
                final i = value.toInt();
                if (i<0 || i>=days.length) return const SizedBox.shrink();
                final step = (days.length/8).ceil().clamp(1, 9999);
                if (i % step != 0 && i != days.length-1 && i != 0) return const SizedBox.shrink();
                final d = days[i];
                final dd = d.day.toString().padLeft(2,'0');
                final mm = d.month.toString().padLeft(2,'0');
                return Padding(padding: const EdgeInsets.only(top:4), child: Text('$dd/$mm', style: const TextStyle(fontSize:10)));
              })),
            ),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final d = days[group.x.toInt()];
                  final minutes = (rod.toY * 60).round();
                  final h = (minutes ~/ 60);
                  final m = minutes % 60;
                  final dd = d.day.toString().padLeft(2,'0');
                  final mm = d.month.toString().padLeft(2,'0');
                  final text = '${dd}/${mm} — ' + (h>0 ? (m>0 ? '${h}h ${m}m' : '${h}h') : '${m}m');
                  return BarTooltipItem(text, const TextStyle(fontSize: 12));
                },
              ),
              touchCallback: (event, response){
                if (event is FlTapUpEvent && response?.spot!=null && onTap!=null) {
                  final i=response!.spot!.touchedBarGroupIndex; onTap!(days[i]);
                }
              },
            ),
            gridData: const FlGridData(show:true),
            borderData: FlBorderData(show:false),
            barGroups: barGroups,
          )),
        ),
      ),
    );
  }
}
