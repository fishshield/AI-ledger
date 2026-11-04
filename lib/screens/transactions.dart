import 'package:flutter/material.dart';

import '../ledger.dart';

// ---------- 明细 ----------
class ListScreen extends StatelessWidget {
  final LedgerService service;
  const ListScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final all = service.all;
        final income = service.incomeOf(all);
        final expense = service.expenseOf(all);
        return Scaffold(
          appBar: AppBar(title: const Text('记账簿')),
          body: Column(
            children: [
              _SummaryCard(income: income, expense: expense, count: all.length),
              Expanded(
                child: all.isEmpty
                    ? const Center(child: Text('还没有记录，点右下角 + 添加'))
                    : ListView.separated(
                        itemCount: all.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = all[i];
                          final isIncome = r.kind == '收入';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isIncome
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              child: Icon(
                                isIncome
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: isIncome ? Colors.green : Colors.red,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              '${r.category}'
                              '${r.note.isNotEmpty ? ' · ${r.note}' : ''}',
                            ),
                            subtitle: Text('${r.date}  ${r.payment}'),
                            trailing: Text(
                              '${isIncome ? '+' : '-'}${fmtMoney(r.amountCents)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isIncome ? Colors.green : Colors.red,
                              ),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DetailScreen(service: service, id: r.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditScreen(service: service)),
            ),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int income;
  final int expense;
  final int count;
  const _SummaryCard({
    required this.income,
    required this.expense,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stat('收入', fmtMoney(income), Colors.green),
            _stat('支出', fmtMoney(expense), Colors.red),
            _stat('结余', fmtMoney(income - expense), Colors.teal),
            _stat('笔数', '$count', Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ---------- 添加 / 编辑 ----------
class EditScreen extends StatefulWidget {
  final LedgerService service;
  final TxRecord? record;
  const EditScreen({super.key, required this.service, this.record});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late String _kind;
  late String _category;
  late String _payment;
  late DateTime _date;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  bool get isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _kind = r?.kind ?? '支出';
    _category = r?.category ?? widget.service.categories[_kind]!.first;
    if (!widget.service.categories[_kind]!.contains(_category)) {
      widget.service.categories[_kind]!.add(_category);
    }
    _payment = r?.payment ?? widget.service.payments.first;
    if (!widget.service.payments.contains(_payment)) {
      widget.service.payments.add(_payment);
    }
    _date = r != null ? parseDate(r.date) : DateTime.now();
    _amountCtrl.text = r != null ? fmtMoney(r.amountCents) : '';
    _noteCtrl.text = r?.note ?? '';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    setState(() {
      _date = DateTime(
        d.year,
        d.month,
        d.day,
        t?.hour ?? _date.hour,
        t?.minute ?? _date.minute,
      );
    });
  }

  Future<void> _save() async {
    final cents = parseMoneyCents(_amountCtrl.text);
    if (cents == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('金额格式不正确（例如 25 或 25.5）')));
      return;
    }
    if (isEdit) {
      final diff = await widget.service.update(widget.record!.id, {
        'kind': _kind,
        'amount': cents,
        'category': _category,
        'payment': _payment,
        'date': fmtDate(_date),
        'note': _noteCtrl.text.trim(),
      }, reason: _reasonCtrl.text.trim());
      if (!mounted) return;
      if (diff == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('记录不存在')));
      } else if (diff.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('没有任何变化')));
      } else {
        Navigator.pop(context, diff);
      }
    } else {
      await widget.service.add(
        kind: _kind,
        amountCents: cents,
        category: _category,
        payment: _payment,
        note: _noteCtrl.text.trim(),
        when: fmtDate(_date),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  Future<void> _newCategory() async {
    final name = await _askText('新建${_kind}分类');
    if (name != null && name.isNotEmpty) {
      await widget.service.addCategory(_kind, name);
      setState(() => _category = name);
    }
  }

  Future<void> _newPayment() async {
    final name = await _askText('新建收支方式');
    if (name != null && name.isNotEmpty) {
      await widget.service.addPayment(name);
      setState(() => _payment = name);
    }
  }

  Future<String?> _askText(String title) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.service.categories[_kind]!;
    final pays = widget.service.payments;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '编辑记录' : '添加记录')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '支出', label: Text('支出')),
              ButtonSegment(value: '收入', label: Text('收入')),
            ],
            selected: {_kind},
            onSelectionChanged: (v) {
              setState(() {
                _kind = v.first;
                if (!widget.service.categories[_kind]!.contains(_category)) {
                  _category = widget.service.categories[_kind]!.first;
                }
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '金额',
              border: OutlineInputBorder(),
              prefixText: '¥ ',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    border: OutlineInputBorder(),
                  ),
                  items: cats
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
              IconButton(
                onPressed: _newCategory,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: '新建分类',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _payment,
                  decoration: const InputDecoration(
                    labelText: '收支方式',
                    border: OutlineInputBorder(),
                  ),
                  items: pays
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _payment = v!),
                ),
              ),
              IconButton(
                onPressed: _newPayment,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: '新建方式',
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '日期',
                border: OutlineInputBorder(),
              ),
              child: Text(fmtDate(_date)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: '备注（可留空）',
              border: OutlineInputBorder(),
            ),
          ),
          if (isEdit) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: '修改原因（可留空，方便日后回忆）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(isEdit ? '保存修改' : '保存')),
        ],
      ),
    );
  }
}

// ---------- 详情 + 修改历史 ----------
class DetailScreen extends StatelessWidget {
  final LedgerService service;
  final int id;
  const DetailScreen({super.key, required this.service, required this.id});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final r = service.find(id);
        if (r == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('详情')),
            body: const Center(child: Text('记录已删除')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('详情'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditScreen(service: service, record: r),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, r),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.kind}  ${fmtMoney(r.amountCents)}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('日期：${r.date}'),
                      Text('分类：${r.category}'),
                      Text('方式：${r.payment}'),
                      Text('备注：${r.note.isEmpty ? '（空）' : r.note}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, TxRecord r) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${r.date}  ${r.kind} ${fmtMoney(r.amountCents)}  '
              '[${r.category}] ${r.payment}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: '删除原因（可留空）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await service.delete(r.id, reason: reasonCtrl.text.trim());
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ---------- 修改历史 ----------
class _AuditTile extends StatelessWidget {
  final AuditEntry entry;
  const _AuditTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isUpdate = entry.action == 'update';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(isUpdate ? '修改' : '删除'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isUpdate
                      ? Colors.blue.shade50
                      : Colors.red.shade50,
                ),
                const SizedBox(width: 8),
                Text(
                  '#${entry.rid}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(entry.ts, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (entry.reason != null && entry.reason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('原因：${entry.reason}'),
              ),
            if (isUpdate && entry.changes != null)
              ...entry.changes!.entries.map((e) {
                final old = e.value['old'];
                final nw = e.value['new'];
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${fieldNames[e.key] ?? e.key}：'
                    '${fmtField(e.key, old)} → ${fmtField(e.key, nw)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }),
            if (!isUpdate && entry.snapshot != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '删除时：${entry.snapshot!['date']}  '
                  '${entry.snapshot!['kind']}  '
                  '${fmtMoney((entry.snapshot!['amount'] as num).toInt())}  '
                  '[${entry.snapshot!['category']}] '
                  '${entry.snapshot!['payment']}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --------- 操作日志 ----------
class AuditLogScreen extends StatefulWidget {
  final LedgerService service;
  const AuditLogScreen({super.key, required this.service});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  String _range = '全部';
  DateTimeRange? _customRange;

  (DateTime?, DateTime?) _bounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case '今天':
        return (today, today.add(const Duration(days: 1)));
      case '本周':
        final monday = today.subtract(Duration(days: now.weekday - 1));
        return (monday, monday.add(const Duration(days: 7)));
      case '本月':
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 1),
        );
      case '自定义':
        if (_customRange == null) return (null, null);
        final s = _customRange!.start;
        final e = _customRange!.end;
        return (
          DateTime(s.year, s.month, s.day),
          DateTime(e.year, e.month, e.day).add(const Duration(days: 1)),
        );
      default:
        return (null, null);
    }
  }

  List<AuditEntry> _filtered() {
    final (start, end) = _bounds();
    return widget.service.history().where((e) {
      if (start == null && end == null) return true;
      final d = parseDate(e.ts);
      if (start != null && d.isBefore(start)) return false;
      if (end != null && !d.isBefore(end)) return false;
      return true;
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    final entries = _filtered();
    return Scaffold(
      appBar: AppBar(title: const Text('操作日志')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _range,
                    decoration: const InputDecoration(
                      labelText: '时间段',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ['全部', '今天', '本周', '本月', '自定义']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v == '自定义') {
                        _pickCustom();
                      } else {
                        setState(() => _range = v!);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${entries.length} 条',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (_range == '自定义' && _customRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${_customRange!.start.year}-${_customRange!.start.month.toString().padLeft(2, '0')}-'
                '${_customRange!.start.day.toString().padLeft(2, '0')} 至 '
                '${_customRange!.end.year}-${_customRange!.end.month.toString().padLeft(2, '0')}-'
                '${_customRange!.end.day.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('该时间段内没有操作记录'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => _AuditTile(entry: entries[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
