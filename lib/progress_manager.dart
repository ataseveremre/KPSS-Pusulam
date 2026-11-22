import 'package:shared_preferences/shared_preferences.dart';

class ProgressManager {
  static const String _completedTopicsKey = 'completed_topics';
  static const String _userNameKey = 'user_name';

  /// Belirtilen konu ID'sini tamamlananlar listesine ekler.
  static Future<void> saveTopic(String topicId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> existing =
        prefs.getStringList(_completedTopicsKey) ?? <String>[];

    if (!existing.contains(topicId)) {
      final updated = List<String>.from(existing)..add(topicId);
      await prefs.setStringList(_completedTopicsKey, updated);
    }
  }

  /// Tamamlanan tüm konu ID'lerini döndürür.
  static Future<List<String>> getCompletedTopics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_completedTopicsKey) ?? <String>[];
  }

  /// Verilen konu ID'sinin tamamlanıp tamamlanmadığını kontrol eder.
  static Future<bool> isCompleted(String topicId) async {
    final completed = await getCompletedTopics();
    return completed.contains(topicId);
  }

  /// Tüm ilerlemeyi temizler (tamamlanan konu kayıtlarını siler).
  static Future<void> clearAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_completedTopicsKey);
  }

  /// Kullanıcının adını kalıcı olarak kaydeder.
  static Future<void> saveUserName(String userName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, userName);
  }

  /// Kayıtlı kullanıcı adını döndürür.
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }
}

