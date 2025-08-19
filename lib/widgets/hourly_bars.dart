import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HourlyBars extends StatelessWidget {
  final List<int> minutes; // length 24
  const HourlyBars({super.key, required this.minutes});

  @override
  Widget build(BuildContext context) {
    final maxMin = minutes.isEmpty ? 0 : minutes.reduce((a,b)=>a>b?a:b);
    final groups = List.generate(24, (h) => BarChartGroupData(
      x: h,
      barRods: [BarChartRodData(toY: minutes[h].toDouble()/60.0)],
    ));
    return SizedBox(
      height: 240,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: (24*20).toDouble().clamp(320, double.infinity),
          child: BarChart(BarChartData(
            maxY: (maxMin/60.0 + 1).clamp(1, 24).toDouble(),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final v = value.toDouble();
                  if ((v - v.round()).abs() > 1e-6) return const SizedBox.shrink();
                  return Text('${v.toInt()} h', style: const TextStyle(fontSize: 10));
                },
              )),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final h = value.toInt(); if (h < 0 || h > 23) return const SizedBox.shrink();
                  if (h % 2 != 0 && h != 0 && h != 23) return const SizedBox.shrink();
                  final hh = h.toString().padLeft(2,'0');
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('$hh', style: const TextStyle(fontSize: 10)),
                  );
                },
              )),
            ),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final h = group.x.toInt();
                  final minutes = (rod.toY * 60).round();
                  final hh = h.toString().padLeft(2,'0');
                  final m = minutes % 60;
                  final H = (minutes ~/ 60);
                  final text = '$hh:00 — ' + (H>0 ? (m>0 ? '${H}h ${m}m' : '${H}h') : '${m}m');
                  return BarTooltipItem(text, const TextStyle(fontSize: 12));
                },
              ),
            ),
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: false),
            barGroups: groups,
          )),
        ),
      ),
    );
  }
}
