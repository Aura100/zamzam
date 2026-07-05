import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SalesChart extends StatelessWidget {
  final List<double> weeklySales;
  
  const SalesChart({super.key, required this.weeklySales});

  @override
  Widget build(BuildContext context) {
    if (weeklySales.isEmpty || weeklySales.length != 7) {
      return const Center(child: Text('لا توجد بيانات كافية'));
    }

    final maxY = (weeklySales.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1000.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'مبيعات الأسبوع الحالي (ج.م)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      const days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(days[value.toInt()], style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(7, (index) {
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: weeklySales[index],
                      color: Colors.blue,
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
