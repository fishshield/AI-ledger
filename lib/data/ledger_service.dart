import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'store.dart';

class LedgerService extends ChangeNotifier {
  final LedgerStore _store;
  LedgerService(this._store);

  List<AssetItem> assets = [];
  List<LiabilityItem> liabilities = [];
  List<TxRecord> records = [];
  List<AuditEntry> audit = [];
  Map<String, double> rates = Map.of(defaultRates);
  Map<String, List<String>> categories = {
    '支出': ['餐饮', '交通', '购物', '居住', '娱乐', '医疗', '学习', '其他'],
    '收入': ['工资', '奖金', '理财', '兼职', '其他'],
  };
  List<String> payments = ['微信', '支付宝', '银行卡', '现金'];
  int _nextId = 1;
  int _nextAssetId = 1;
  int _nextLiabilityId = 1;

  Future<void> load() async {
    final data = await _store.load();
    records = ((data['records'] as List?) ?? [])
        .map((e) => TxRecord.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    audit = ((data['audit'] as List?) ?? [])
        .map((e) => AuditEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final cats = data['categories'] as Map?;
    if (cats != null) {
      for (final k in ['支出', '收入']) {
        final v = cats[k];
        if (v is List) categories[k] = v.map((e) => '$e').toList();
      }
    }
    final pays = data['payments'];
    if (pays is List) payments = pays.map((e) => '$e').toList();
    assets = ((data['assets'] as List?) ?? [])
        .map((e) => AssetItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    liabilities = ((data['liabilities'] as List?) ?? [])
        .map((e) => LiabilityItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final r = data['rates'];
    if (r is Map) {
      rates = r.map((k, v) => MapEntry('$k', (v as num).toDouble()));
    }
    _nextAssetId = assets.fold<int>(0, (m, a) => a.id > m ? a.id : m) + 1;
    _nextLiabilityId =
        liabilities.fold<int>(0, (m, l) => l.id > m ? l.id : m) + 1;
    _recalcNextId();
    notifyListeners();
  }

  void _recalcNextId() {
    _nextId = records.fold<int>(0, (m, r) => r.id > m ? r.id : m) + 1;
  }

  Future<void> _save() async {
    try {
      await _store.save({
        'version': 3,
        'records': records.map((r) => r.toJson()).toList(),
        'audit': audit.map((a) => a.toJson()).toList(),
        'categories': categories,
        'payments': payments,
        'assets': assets.map((a) => a.toJson()).toList(),
        'liabilities': liabilities.map((l) => l.toJson()).toList(),
        'rates': rates,
      });
    } catch (e) {
      debugPrint('LedgerService._save 失败: $e');
    }
  }

  List<TxRecord> get all =>
      [...records]..sort((a, b) => b.date.compareTo(a.date));

  TxRecord? find(int id) {
    for (final r in records) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<TxRecord> add({
    required String kind,
    required int amountCents,
    required String category,
    required String payment,
    String note = '',
    String? when,
  }) async {
    final r = TxRecord(
      id: _nextId++,
      date: when ?? fmtDate(DateTime.now()),
      kind: kind,
      amountCents: amountCents,
      category: category,
      payment: payment,
      note: note,
    );
    records.add(r);
    if (!categories[kind]!.contains(category)) categories[kind]!.add(category);
    if (!payments.contains(payment)) payments.add(payment);
    await _save();
    notifyListeners();
    return r;
  }

  /// 返回 null=记录不存在，{}=无变化，否则返回字段差异
  Future<Map<String, dynamic>?> update(
    int id,
    Map<String, dynamic> changes, {
    String reason = '',
  }) async {
    final r = find(id);
    if (r == null) return null;
    final diff = <String, dynamic>{};
    for (final k in ['date', 'kind', 'amount', 'category', 'payment', 'note']) {
      if (!changes.containsKey(k)) continue;
      final old = switch (k) {
        'date' => r.date,
        'kind' => r.kind,
        'amount' => r.amountCents,
        'category' => r.category,
        'payment' => r.payment,
        _ => r.note,
      };
      if (old != changes[k]) diff[k] = {'old': old, 'new': changes[k]};
    }
    if (diff.isEmpty) return {};
    for (final k in diff.keys) {
      final v = diff[k]['new'];
      switch (k) {
        case 'date':
          r.date = v as String;
        case 'kind':
          r.kind = v as String;
        case 'amount':
          r.amountCents = (v as num).toInt();
        case 'category':
          r.category = v as String;
        case 'payment':
          r.payment = v as String;
        case 'note':
          r.note = v as String;
      }
    }
    r.updatedAt = fmtDate(DateTime.now());
    audit.add(
      AuditEntry(
        ts: fmtDate(DateTime.now()),
        action: 'update',
        rid: id,
        changes: diff,
        reason: reason,
      ),
    );
    if (!categories[r.kind]!.contains(r.category)) {
      categories[r.kind]!.add(r.category);
    }
    if (!payments.contains(r.payment)) payments.add(r.payment);
    await _save();
    notifyListeners();
    return diff;
  }

  Future<bool> delete(int id, {String reason = ''}) async {
    final r = find(id);
    if (r == null) return false;
    final snapshot = {
      'date': r.date,
      'kind': r.kind,
      'amount': r.amountCents,
      'category': r.category,
      'payment': r.payment,
      'note': r.note,
      'updatedAt': r.updatedAt,
    };
    records.removeWhere((x) => x.id == id);
    audit.add(
      AuditEntry(
        ts: fmtDate(DateTime.now()),
        action: 'delete',
        rid: id,
        snapshot: snapshot,
        reason: reason,
      ),
    );
    await _save();
    notifyListeners();
    return true;
  }

  List<AuditEntry> history({int? rid}) {
    final list = audit.where((e) => rid == null || e.rid == rid).toList();
    list.sort((a, b) => b.ts.compareTo(a.ts));
    return list;
  }

  // ---------- 资产 ----------
  double rateOf(String currency) => rates[currency] ?? 0.0;

  /// 普通资产的余额就是用户填写的值，不再受记账影响
  double currentBalanceOf(AssetItem a) => a.quantity;

  double liquidAssetCny(AssetItem a) =>
      currentBalanceOf(a) * rateOf(a.currency);

  double marketValueCny(AssetItem a) =>
      a.quantity * a.currentPrice * rateOf(a.currency);

  double marketCostCny(AssetItem a) =>
      a.quantity * a.costPerShare * rateOf(a.currency);

  double marketPnlCny(AssetItem a) => marketValueCny(a) - marketCostCny(a);

  double liabilityCny(LiabilityItem l) => l.amount * rateOf(l.currency);

  /// 全部收支汇总（总账模式下，所有记账都计入总资产）
  UnallocatedFlow unallocatedFlow({DateTime? start, DateTime? end}) {
    var income = 0.0;
    var expense = 0.0;
    final items = <TxRecord>[];
    for (final r in records) {
      final dt = parseDate(r.date);
      if (start != null && dt.isBefore(start)) continue;
      if (end != null && dt.isAfter(end)) continue;
      final amt = r.amountCents / 100.0;
      if (r.kind == '收入') {
        income += amt;
      } else {
        expense += amt;
      }
      items.add(r);
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return UnallocatedFlow(income: income, expense: expense, records: items);
  }

  /// 全部收支净额，直接计入总资产
  double get unallocatedNetCny => unallocatedFlow().net;

  double get totalLiquidAssetsCny =>
      assets
          .where((a) => !a.isMarket)
          .fold(0.0, (s, a) => s + liquidAssetCny(a)) +
      unallocatedNetCny;

  double get totalMarketAssetsCny => assets
      .where((a) => a.isMarket)
      .fold(0.0, (s, a) => s + marketValueCny(a));

  double get totalMarketCostCny =>
      assets.where((a) => a.isMarket).fold(0.0, (s, a) => s + marketCostCny(a));

  double get totalMarketPnlCny => totalMarketAssetsCny - totalMarketCostCny;

  double get totalLiabilitiesCny =>
      liabilities.fold(0.0, (s, l) => s + liabilityCny(l));

  double get netWorthCny => totalLiquidAssetsCny - totalLiabilitiesCny;

  Future<AssetItem> addAsset({
    required String name,
    required String category,
    required double quantity,
    required String unit,
    required String currency,
    String note = '',
    double costPerShare = 0,
    double currentPrice = 0,
  }) async {
    final a = AssetItem(
      id: _nextAssetId++,
      name: name,
      category: category,
      quantity: quantity,
      unit: unit,
      currency: currency,
      note: note,
      costPerShare: costPerShare,
      currentPrice: currentPrice,
    );
    assets.add(a);
    await _save();
    notifyListeners();
    return a;
  }

  Future<bool> updateAsset(int id, Map<String, dynamic> changes) async {
    final a = assets.where((x) => x.id == id).firstOrNull;
    if (a == null) return false;
    if (changes.containsKey('name')) a.name = changes['name'] as String;
    if (changes.containsKey('category')) {
      a.category = changes['category'] as String;
    }
    if (changes.containsKey('quantity')) {
      a.quantity = (changes['quantity'] as num).toDouble();
    }
    if (changes.containsKey('unit')) a.unit = changes['unit'] as String;
    if (changes.containsKey('currency')) {
      a.currency = changes['currency'] as String;
    }
    if (changes.containsKey('note')) a.note = changes['note'] as String;
    if (changes.containsKey('costPerShare')) {
      a.costPerShare = (changes['costPerShare'] as num).toDouble();
    }
    if (changes.containsKey('currentPrice')) {
      a.currentPrice = (changes['currentPrice'] as num).toDouble();
    }

    a.updatedAt = fmtDate(DateTime.now());
    await _save();
    notifyListeners();
    return true;
  }

  Future<bool> deleteAsset(int id) async {
    final before = assets.length;
    assets.removeWhere((a) => a.id == id);
    if (assets.length == before) return false;
    await _save();
    notifyListeners();
    return true;
  }

  // ---------- 负债 ----------
  Future<LiabilityItem> addLiability({
    required String name,
    required double amount,
    required String currency,
    double monthlyPayment = 0,
    String note = '',
  }) async {
    final l = LiabilityItem(
      id: _nextLiabilityId++,
      name: name,
      amount: amount,
      currency: currency,
      monthlyPayment: monthlyPayment,
      note: note,
    );
    liabilities.add(l);
    await _save();
    notifyListeners();
    return l;
  }

  Future<bool> updateLiability(int id, Map<String, dynamic> changes) async {
    final l = liabilities.where((x) => x.id == id).firstOrNull;
    if (l == null) return false;
    if (changes.containsKey('name')) l.name = changes['name'] as String;
    if (changes.containsKey('amount')) {
      l.amount = (changes['amount'] as num).toDouble();
    }
    if (changes.containsKey('currency')) {
      l.currency = changes['currency'] as String;
    }
    if (changes.containsKey('monthlyPayment')) {
      l.monthlyPayment = (changes['monthlyPayment'] as num).toDouble();
    }
    if (changes.containsKey('note')) l.note = changes['note'] as String;
    l.updatedAt = fmtDate(DateTime.now());
    await _save();
    notifyListeners();
    return true;
  }

  Future<bool> deleteLiability(int id) async {
    final before = liabilities.length;
    liabilities.removeWhere((l) => l.id == id);
    if (liabilities.length == before) return false;
    await _save();
    notifyListeners();
    return true;
  }

  // ---------- 汇率 ----------
  Future<void> setRate(String currency, double rate) async {
    rates[currency] = rate;
    await _save();
    notifyListeners();
  }

  Future<void> addCurrency(String code, double rate) async {
    rates[code] = rate;
    await _save();
    notifyListeners();
  }

  Future<bool> removeCurrency(String code) async {
    if (code == 'CNY') return false;
    final used =
        assets.any((a) => a.currency == code) ||
        liabilities.any((l) => l.currency == code);
    if (used) return false;
    rates.remove(code);
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> addCategory(String kind, String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    if (!categories[kind]!.contains(n)) {
      categories[kind]!.add(n);
      await _save();
      notifyListeners();
    }
  }

  Future<void> removeCategory(String kind, String name) async {
    categories[kind]!.remove(name);
    await _save();
    notifyListeners();
  }

  Future<void> addPayment(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    if (!payments.contains(n)) {
      payments.add(n);
      await _save();
      notifyListeners();
    }
  }

  Future<void> removePayment(String name) async {
    payments.remove(name);
    await _save();
    notifyListeners();
  }

  int incomeOf(List<TxRecord> rs) =>
      rs.where((r) => r.kind == '收入').fold(0, (s, r) => s + r.amountCents);

  int expenseOf(List<TxRecord> rs) =>
      rs.where((r) => r.kind == '支出').fold(0, (s, r) => s + r.amountCents);

  /// 用整段 JSON 替换当前数据（用于从 Python 版迁移）
  Future<bool> replaceWithJson(String text) async {
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      records = ((data['records'] as List?) ?? [])
          .map((e) => TxRecord.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      audit = ((data['audit'] as List?) ?? [])
          .map((e) => AuditEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      final cats = data['categories'] as Map?;
      if (cats != null) {
        for (final k in ['支出', '收入']) {
          final v = cats[k];
          if (v is List) categories[k] = v.map((e) => '$e').toList();
        }
      }
      final pays = data['payments'];
      if (pays is List) payments = pays.map((e) => '$e').toList();
      assets = ((data['assets'] as List?) ?? [])
          .map((e) => AssetItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      liabilities = ((data['liabilities'] as List?) ?? [])
          .map(
            (e) => LiabilityItem.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
      final r = data['rates'];
      if (r is Map) {
        rates = r.map((k, v) => MapEntry('$k', (v as num).toDouble()));
      }
      _nextAssetId = assets.fold<int>(0, (m, a) => a.id > m ? a.id : m) + 1;
      _nextLiabilityId =
          liabilities.fold<int>(0, (m, l) => l.id > m ? l.id : m) + 1;
      _recalcNextId();
      await _save();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class UnallocatedFlow {
  final double income;
  final double expense;
  final List<TxRecord> records;

  UnallocatedFlow({
    required this.income,
    required this.expense,
    required this.records,
  });

  double get net => income - expense;
}
