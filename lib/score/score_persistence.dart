import 'package:shared_preferences/shared_preferences.dart';

class ScorePersistence {
  static const _scoresKey = 'stretching_scores';

  static Future<void> saveScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final scores = await getScores();
    scores.add(score);
    // We are storing scores as a list of strings
    await prefs.setStringList(_scoresKey, scores.map((s) => s.toString()).toList());
  }

  static Future<List<int>> getScores() async {
    final prefs = await SharedPreferences.getInstance();
    final scoresString = prefs.getStringList(_scoresKey) ?? [];
    return scoresString.map((s) => int.tryParse(s) ?? 0).toList();
  }
}
