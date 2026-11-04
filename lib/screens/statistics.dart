import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../ledger.dart';

const _chartPalette = [
  Color(0xFF26A69A),
  Color(0xFFEF5350),
  Color(0xFF42A5F5),
  Color(0xFFFFA726),
  Color(0xFFAB47BC),
  Color(0xFF66BB6A),
  Color(0xFF8D6E63),
  Color(0xFF29B6F6),
  Color(0xFFFFCA28),
  Color(0xFFEC407A),
  Color(0xFF7E57C2),
  Color(0xFF26C6DA),
];

// ---------- 统计 ----------
class StatsScreen extends StatefulWidget {
  final LedgerService service;
  const StatsScreen({super.key, required this.service});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _range = '全部';
  DateTimeRange? _customRange;
  String? _kind;
  String? _category;
  String? _payment;

  (DateTime?, DateTime?) _bounds() {
    final now = DateTime.now();
    return switch (_range) {
      '自定义' =>
        _customRange == null
            ? (null, null)
            : (
                DateTime(
                  _customRange!.start.year,
                  _customRange!.start.month,
                  _customRange!.start.day,
                ),
                DateTime(
                  _customRange!.end.year,
                  _customRange!.end.month,
                  _customRange!.end.day,
                ).add(const Duration(days: 1)),
              ),
      '本月' => (
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 1),
      ),
      '上月' => (
        DateTime(now.year, now.month - 1, 1),
        DateTime(now.year, now.month, 1),
      ),
      '本年' => (DateTime(now.year, 1, 1), DateTime(now.year + 1, 1, 1)),
      _ => (null, null),
    };
  }

  Future<void> _pickCustom() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customRange,
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _range = '自定义';
      });
    }
  }

  List<TxRecord> _filtered() {
    final (start, end) = _bounds();
    return widget.service.all.where((r) {
      if (_kind != null && r.kind != _kind) return false;
      if (_category != null && r.category != _category) return false;
      if (_payment != null && r.payment != _payment) return false;
      final d = parseDate(r.date);
      if (start != null && d.isBefore(start)) return false;
      if (end != null && !d.isBefore(end)) return false;
      return true;
    }).toList();
  }

  Map<String, Map<String, int>> _group(List<TxRecord> rs, String key) {
    final m = <String, Map<String, int>>{};
    for (final r in rs) {
      if (r.kind != '收入' && r.kind != '支出') continue;
      final k = key == 'category' ? r.category : r.payment;
      final d = m.putIfAbsent(k, () => {'收入': 0, '支出': 0, '笔数': 0});
      d[r.kind] = (d[r.kind] ?? 0) + r.amountCents;
      d['笔数'] = (d['笔数'] ?? 0) + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final rs = _filtered();
        final income = widget.service.incomeOf(rs);
        final expense = widget.service.expenseOf(rs);
        final byCat = _group(rs, 'category');
        final byPay = _group(rs, 'payment');
        final categoryOptions = _kind == '支出'
            ? widget.service.categories['支出']!
            : _kind == '收入'
            ? widget.service.categories['收入']!
            : [
                ...widget.service.categories['支出']!,
                ...widget.service.categories['收入']!,
              ];
        final pays = widget.service.payments;

        final expenseByCat = <String, int>{};
        final incomeByCat = <String, int>{};
        for (final e in byCat.entries) {
          if (e.value['支出']! > 0) expenseByCat[e.key] = e.value['支出']!;
          if (e.value['收入']! > 0) incomeByCat[e.key] = e.value['收入']!;
        }

        return Scaffold(
          appBar: AppBar(title: const Text('统计')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DropdownButton<String>(
                    value: _range,
                    onChanged: (v) {
                      if (v == '自定义') {
                        _pickCustom();
                      } else {
                        setState(() => _range = v!);
                      }
                    },
                    items: ['全部', '本月', '上月', '本年', '自定义']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                  ),
                  DropdownButton<String?>(
                    value: _kind,
                    hint: const Text('类型'),
                    onChanged: (v) => setState(() {
                      _kind = v;
                      if (_category != null) {
                        final valid = v == '支出'
                            ? widget.service.categories['支出']!
                            : v == '收入'
                            ? widget.service.categories['收入']!
                            : [
                                ...widget.service.categories['支出']!,
                                ...widget.service.categories['收入']!,
                              ];
                        if (!valid.contains(_category)) _category = null;
                      }
                    }),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('全部')),
                      const DropdownMenuItem(value: '支出', child: Text('支出')),
                      const DropdownMenuItem(value: '收入', child: Text('收入')),
                    ],
                  ),
                  DropdownButton<String?>(
                    value: _category,
                    hint: const Text('分类'),
                    onChanged: (v) => setState(() => _category = v),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('全部分类')),
                      ...categoryOptions.toSet().map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                  ),
                  DropdownButton<String?>(
                    value: _payment,
                    hint: const Text('方式'),
                    onChanged: (v) => setState(() => _payment = v),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('全部方式')),
                      ...pays.map(
                        (p) => DropdownMenuItem(value: p, child: Text(p)),
                      ),
                    ],
                  ),
                ],
              ),
              if (_range == '自定义' && _customRange != null)
                Text(
                  '${_customRange!.start.year}-${_customRange!.start.month.toString().padLeft(2, '0')}-${_customRange!.start.day.toString().padLeft(2, '0')} 至 ${_customRange!.end.year}-${_customRange!.end.month.toString().padLeft(2, '0')}-${_customRange!.end.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('笔数', '${rs.length}'),
                      _row('收入', fmtMoney(income)),
                      _row('支出', fmtMoney(expense)),
                      _row(
                        '结余',
                        fmtMoney(income - expense),
                        valueColor: income - expense < 0 ? Colors.red : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _pieCard(expenseByCat),
              const SizedBox(height: 16),
              _barCard(incomeByCat, expenseByCat),
              const SizedBox(height: 16),
              _groupCard('按收支方式', byPay),
            ],
          ),
        );
      },
    );
  }

  // ---------- 扇形图：支出分类占比 ----------
  Widget _pieCard(Map<String, int> data) {
    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 36,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                '当前筛选条件下没有支出数据',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }
    final total = data.values.fold<int>(0, (s, v) => s + v);
    final entries = data.entries.toList()..sort((a, b) => b.value - a.value);

    final sections = entries.asMap().entries.map((e) {
      final i = e.key;
      return PieChartSectionData(
        value: e.value.value.toDouble(),
        color: _chartPalette[i % _chartPalette.length],
        title: '',
        radius: 60,
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '支出分类占比',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '合计 ${fmtMoney(total)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 42,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...entries.asMap().entries.map((e) {
              final i = e.key;
              final cat = e.value.key;
              final val = e.value.value;
              final pct = val / total * 100;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _chartPalette[i % _chartPalette.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(cat, style: const TextStyle(fontSize: 13)),
                    ),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 88,
                      child: Text(
                        fmtMoney(val),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ---------- 条形图：分类收支对比 ----------
  Widget _barCard(Map<String, int> incomeData, Map<String, int> expenseData) {
    final allCats = <String>{...incomeData.keys, ...expenseData.keys}.toList();
    if (allCats.isEmpty) {
      return const SizedBox.shrink();
    }
    allCats.sort((a, b) {
      final ta = (incomeData[a] ?? 0) + (expenseData[a] ?? 0);
      final tb = (incomeData[b] ?? 0) + (expenseData[b] ?? 0);
      return tb.compareTo(ta);
    });
    final cats = allCats;
    final scrollable = cats.length > 8;

    var maxY = 0.0;
    for (final c in cats) {
      final iv = (incomeData[c] ?? 0) / 100.0;
      final ev = (expenseData[c] ?? 0) / 100.0;
      if (iv > maxY) maxY = iv;
      if (ev > maxY) maxY = ev;
    }
    if (maxY <= 0) maxY = 100;
    maxY *= 1.2;

    final groups = cats.asMap().entries.map((e) {
      final cat = e.value;
      return BarChartGroupData(
        x: e.key,
        barsSpace: 2,
        barRods: [
          BarChartRodData(
            toY: (incomeData[cat] ?? 0) / 100.0,
            color: Colors.green,
            width: 10,
            borderRadius: BorderRadius.circular(2),
          ),
          BarChartRodData(
            toY: (expenseData[cat] ?? 0) / 100.0,
            color: Colors.red,
            width: 10,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '分类收支对比',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _legendDot(Colors.green, '收入'),
                const SizedBox(width: 10),
                _legendDot(Colors.red, '支出'),
                if (scrollable) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.swipe, size: 14, color: Colors.grey),
                  const Text(
                    '可左右滑动',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 240,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const perBar = 64.0;
                  final chartWidth = scrollable
                      ? cats.length * perBar
                      : constraints.maxWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxY,
                          barGroups: groups,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: maxY / 4,
                            getDrawingHorizontalLine: (v) => FlLine(
                              color: Colors.grey.shade200,
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 42,
                                getTitlesWidget: (v, _) => Text(
                                  _formatY(v),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                getTitlesWidget: (v, meta) {
                                  final i = v.toInt();
                                  if (i < 0 || i >= cats.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final name = cats[i];
                                  final display = name.length > 4
                                      ? '${name.substring(0, 4)}…'
                                      : name;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      display,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatY(double v) {
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  Widget _legendDot(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ],
  );

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: TextStyle(color: valueColor)),
      ],
    ),
  );

  Widget _groupCard(String title, Map<String, Map<String, int>> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    final entries = data.entries.toList()
      ..sort(
        (a, b) =>
            (b.value['收入']! + b.value['支出']!) -
            (a.value['收入']! + a.value['支出']!),
      );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key)),
                    Text(
                      '收 ${fmtMoney(e.value['收入']!)}  '
                      '支 ${fmtMoney(e.value['支出']!)}  '
                      '(${e.value['笔数']}笔)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
