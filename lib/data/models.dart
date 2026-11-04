int? parseMoneyCents(String text) {
  final t = text.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)) return null;
  final parts = t.split('.');
  final yuan = int.parse(parts[0]);
  final cents = parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0;
  final v = yuan * 100 + cents;
  if (v <= 0) return null;
  if (v > 100000000 * 100) return null;
  return v;
}

String fmtMoney(int cents) {
  final sign = cents < 0 ? '-' : '';
  final c = cents.abs();
  return '$sign${c ~/ 100}.${(c % 100).toString().padLeft(2, '0')}';
}

String fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

DateTime parseDate(String s) => DateTime.parse(s.replaceFirst(' ', 'T'));

const fieldNames = {
  'date': '日期',
  'kind': '类型',
  'amount': '金额',
  'category': '分类',
  'payment': '方式',
  'note': '备注',
};

String fmtField(String field, dynamic value) {
  if (field == 'amount') {
    if (value is num) return fmtMoney(value.toInt());
    return '$value';
  }
  if (value == null || value == '') return '（空）';
  return '$value';
}

// ---------- 模型 ----------
class TxRecord {
  int id;
  String date;
  String kind;
  int amountCents;
  String category;
  String payment;
  String note;
  String updatedAt;

  TxRecord({
    required this.id,
    required this.date,
    required this.kind,
    required this.amountCents,
    required this.category,
    required this.payment,
    this.note = '',
    String? updatedAt,
  }) : updatedAt = updatedAt ?? date;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'kind': kind,
    'amount': amountCents,
    'category': category,
    'payment': payment,
    'note': note,
    'updatedAt': updatedAt,
  };

  factory TxRecord.fromJson(Map<String, dynamic> j) => TxRecord(
    id: (j['id'] as num).toInt(),
    date: j['date'] as String,
    kind: j['kind'] as String? ?? '支出',
    amountCents: j['amount'] is double
        ? ((j['amount'] as double) * 100).round()
        : (j['amount'] as num).toInt(),
    category: j['category'] as String? ?? '其他',
    payment: j['payment'] as String? ?? '未指定',
    note: (j['note'] ?? '') as String,
    updatedAt: j['updatedAt'] as String?,
  );
}

class AuditEntry {
  final String ts;
  final String action;
  final int rid;
  final Map<String, dynamic>? changes;
  final Map<String, dynamic>? snapshot;
  final String? reason;

  AuditEntry({
    required this.ts,
    required this.action,
    required this.rid,
    this.changes,
    this.snapshot,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
    'ts': ts,
    'action': action,
    'rid': rid,
    if (changes != null) 'changes': changes,
    if (snapshot != null) 'snapshot': snapshot,
    if (reason != null && reason!.isNotEmpty) 'reason': reason,
  };

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    ts: j['ts'] as String,
    action: j['action'] as String,
    rid: (j['rid'] as num).toInt(),
    changes: (j['changes'] as Map?)?.cast<String, dynamic>(),
    snapshot: (j['snapshot'] as Map?)?.cast<String, dynamic>(),
    reason: j['reason'] as String?,
  );
}

// ---------- 资产 / 负债 ----------
const assetCategories = ['银行卡', '现金', '微信', '支付宝', '股票', '数字币', '其他'];
const marketCategories = {'股票', '数字币'};

const defaultRates = <String, double>{
  'CNY': 1.0,
  'USD': 7.2,
  'EUR': 7.8,
  'HKD': 0.92,
  'JPY': 0.048,
  'GBP': 9.1,
  'BTC': 500000,
};

String fmtCny(double v) => fmtMoney((v * 100).round());

class AssetItem {
  int id;
  String name;
  String category;
  double quantity;
  String unit;
  String currency;
  String note;
  String updatedAt;
  String initialDate;
  double costPerShare;
  double currentPrice;

  AssetItem({
    required this.id,
    required this.name,
    this.category = '银行卡',
    required this.quantity,
    this.unit = '元',
    this.currency = 'CNY',
    this.note = '',
    String? updatedAt,
    String? initialDate,
    this.costPerShare = 0,
    this.currentPrice = 0,
  }) : updatedAt = updatedAt ?? fmtDate(DateTime.now()),
       initialDate = initialDate ?? updatedAt ?? fmtDate(DateTime.now());

  bool get isMarket => marketCategories.contains(category);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'quantity': quantity,
    'unit': unit,
    'currency': currency,
    'note': note,
    'updatedAt': updatedAt,
    'initialDate': initialDate,
    'costPerShare': costPerShare,
    'currentPrice': currentPrice,
  };

  factory AssetItem.fromJson(Map<String, dynamic> j) {
    final cat = j['category'] as String? ?? '银行卡';
    final qty = (j['quantity'] as num?)?.toDouble() ?? 0;
    final isMarket = marketCategories.contains(cat);
    final migratedQty = isMarket && j['currentPrice'] == null ? 1.0 : qty;
    final migratedPrice = isMarket && j['currentPrice'] == null
        ? qty
        : (j['currentPrice'] as num?)?.toDouble() ?? 0;
    final migratedCost = isMarket && j['costPerShare'] == null
        ? qty
        : (j['costPerShare'] as num?)?.toDouble() ?? 0;
    return AssetItem(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String? ?? '',
      category: cat,
      quantity: migratedQty,
      unit: j['unit'] as String? ?? (isMarket ? '股' : '元'),
      currency: j['currency'] as String? ?? 'CNY',
      note: (j['note'] ?? '') as String,
      updatedAt: j['updatedAt'] as String?,
      initialDate: j['initialDate'] as String?,
      costPerShare: migratedCost,
      currentPrice: migratedPrice,
    );
  }
}

class LiabilityItem {
  int id;
  String name;
  double amount;
  String currency;
  double monthlyPayment;
  String note;
  String updatedAt;

  LiabilityItem({
    required this.id,
    required this.name,
    required this.amount,
    this.currency = 'CNY',
    this.monthlyPayment = 0,
    this.note = '',
    String? updatedAt,
  }) : updatedAt = updatedAt ?? fmtDate(DateTime.now());

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'currency': currency,
    'monthlyPayment': monthlyPayment,
    'note': note,
    'updatedAt': updatedAt,
  };

  factory LiabilityItem.fromJson(Map<String, dynamic> j) => LiabilityItem(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String? ?? '',
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    currency: j['currency'] as String? ?? 'CNY',
    monthlyPayment: (j['monthlyPayment'] as num?)?.toDouble() ?? 0,
    note: (j['note'] ?? '') as String,
    updatedAt: j['updatedAt'] as String?,
  );
}

// ---------- 存储接口：以后换 HTTP / SQLite 只加实现，业务层不动 ----------
