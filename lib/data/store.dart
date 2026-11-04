import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class LedgerStore {
  Future<Map<String, dynamic>> load();
  Future<void> save(Map<String, dynamic> data);
}

// ---------- 本地实现：Web 上走 localStorage ----------
class SharedPrefsStore implements LedgerStore {
  final String key;
  SharedPrefsStore({this.key = 'ledger_data'});

  @override
  Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }
}

// ---------- 服务：业务逻辑 ----------
