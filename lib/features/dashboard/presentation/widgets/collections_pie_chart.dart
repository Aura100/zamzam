import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class CollectionsPieChart extends StatelessWidget {
  final double collected;
  final double pending;
  final double overdue;

  const CollectionsPieChart({
    super.key,
    required this.collected,
    required this.pending,
    required this.overdue,
  });

  @override
  Widget build(BuildContext context) {
    if (collected == 0 && pending == 0 && overdue == 0) {
      return const Center(child: Text('لا توجد بيانات للأقساط'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'حالة الأقساط',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                if (collected > 0)
                  PieChartSectionData(
                    color: Colors.green,
                    value: collected,
                    title: 'محصلة\n${collected.toStringAsFixed(0)}',
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                if (pending > 0)
                  PieChartSectionData(
                    color: Colors.blue,
                    value: pending,
                    title: 'قادمة\n${pending.toStringAsFixed(0)}',
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                if (overdue > 0)
                  PieChartSectionData(
                    color: Colors.red,
                    value: overdue,
                    title: 'متأخرة\n${overdue.toStringAsFixed(0)}',
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Indicator(color: Colors.green, text: 'محصلة'),
            _Indicator(color: Colors.blue, text: 'قادمة'),
            _Indicator(color: Colors.red, text: 'متأخرة'),
          ],
        )
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;

  const _Indicator({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
