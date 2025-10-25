import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:stretching/score/score_persistence.dart';

class ScoreHistoryScreen extends StatefulWidget {
  const ScoreHistoryScreen({super.key});

  @override
  State<ScoreHistoryScreen> createState() => _ScoreHistoryScreenState();
}

class _ScoreHistoryScreenState extends State<ScoreHistoryScreen> {
  List<int> _scores = [];

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final scores = await ScorePersistence.getScores();
    setState(() {
      _scores = scores;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('점수 기록'),
      ),
      body: _scores.isEmpty
          ? const Center(child: Text('저장된 점수가 없습니다.'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _scores.reduce((a, b) => a > b ? a : b).toDouble() + 10, // Add some padding to the max Y
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(

                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text('${value.toInt() + 1}회');
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  barGroups: _scores.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: Colors.lightBlueAccent,
                          width: 16,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}
