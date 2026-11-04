import 'package:flutter/material.dart';

import '../ledger.dart';

// ---------- 资产总览 ----------
class AssetsScreen extends StatefulWidget {
  final LedgerService service;
  const AssetsScreen({super.key, required this.service});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final s = widget.service;
        return Scaffold(
          appBar: AppBar(
            title: const Text('资产总览'),
            actions: [
              IconButton(
                icon: const Icon(Icons.currency_exchange),
                tooltip: '汇率设置',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CurrencyRatesScreen(service: s),
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tab,
              tabs: const [
                Tab(text: '资产'),
                Tab(text: '负债'),
              ],
            ),
          ),
          body: Column(
            children: [
              _NetWorthCard(service: s),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _AssetList(service: s),
                    _LiabilityList(service: s),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (_tab.index == 0) {
                _pickAssetType(s);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiabilityEditScreen(service: s),
                  ),
                );
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Future<void> _pickAssetType(LedgerService s) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('普通资产'),
              subtitle: const Text('银行卡、现金、微信等，余额可与记账联动'),
              onTap: () => Navigator.pop(ctx, 'liquid'),
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('行情资产'),
              subtitle: const Text('股票、数字币等，需手动更新价格，不计入净资产'),
              onTap: () => Navigator.pop(ctx, 'market'),
            ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AssetEditScreen(service: s, forceMarket: type == 'market'),
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  final LedgerService service;
  const _NetWorthCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final net = service.netWorthCny;
    final liquid = service.totalLiquidAssetsCny;
    final liabilities = service.totalLiabilitiesCny;
    final market = service.totalMarketAssetsCny;
    final marketPnl = service.totalMarketPnlCny;
    return Card(
      margin: const EdgeInsets.all(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AssetFlowScreen(service: service)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('净资产', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                fmtCny(net),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: net >= 0 ? Colors.teal : Colors.red,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '点击查看各类资产变动',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('总资产', fmtCny(liquid), Colors.green),
                  _stat('总负债', fmtCny(liabilities), Colors.red),
                ],
              ),
              if (market > 0) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.show_chart,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '另有行情资产 ${fmtCny(market)}（未计入）'
                        '${marketPnl != 0 ? '  盈亏 ${marketPnl >= 0 ? '+' : ''}${fmtCny(marketPnl)}' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    ],
  );
}

class _AssetList extends StatelessWidget {
  final LedgerService service;
  const _AssetList({required this.service});

  @override
  Widget build(BuildContext context) {
    final liquid = service.assets.where((a) => !a.isMarket).toList();
    final market = service.assets.where((a) => a.isMarket).toList();

    if (liquid.isEmpty && market.isEmpty) {
      return const Center(child: Text('还没有资产，点右下角 + 添加'));
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (liquid.isNotEmpty) ...[
          _sectionTitle(context, '资产快照', '手动填写，不随记账变化'),
          ...liquid.map((a) => _liquidTile(context, a)),
        ],
        if (market.isNotEmpty) ...[
          if (liquid.isNotEmpty) const SizedBox(height: 20),
          _sectionTitle(context, '行情资产（需手动更新）', '市值波动，不计入净资产'),
          ...market.map((a) => _marketTile(context, a)),
        ],
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String sub) =>
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sub,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
          ],
        ),
      );

  Widget _liquidTile(BuildContext context, AssetItem a) {
    final balance = a.quantity;
    final cny = balance * service.rateOf(a.currency);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text(a.category.characters.first)),
        title: Text(a.name.isEmpty ? a.category : a.name),
        subtitle: Text(
          '${a.category} · ${_num(balance)} ${a.unit}'
          '${a.currency != 'CNY' ? '（${a.currency}）' : ''}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fmtCny(cny),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            Text('≈ 人民币', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AssetEditScreen(service: service, asset: a),
          ),
        ),
      ),
    );
  }

  Widget _marketTile(BuildContext context, AssetItem a) {
    final value = service.marketValueCny(a);
    final cost = service.marketCostCny(a);
    final pnl = value - cost;
    final pnlPct = cost > 0 ? (pnl / cost * 100) : 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.show_chart)),
        title: Text(a.name.isEmpty ? a.category : a.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_num(a.quantity)} ${a.unit} × ${_num(a.currentPrice)} ${a.currency}',
            ),
            if (cost > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '成本 ${fmtCny(cost)} · 盈亏 ${pnl >= 0 ? '+' : ''}${fmtCny(pnl)}'
                  '（${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)}%）',
                  style: TextStyle(
                    fontSize: 11,
                    color: pnl >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fmtCny(value),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
            Text('市值', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AssetEditScreen(service: service, asset: a),
          ),
        ),
      ),
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

// ---------- 资产编辑 ----------
class AssetEditScreen extends StatefulWidget {
  final LedgerService service;
  final AssetItem? asset;
  final bool forceMarket;
  const AssetEditScreen({
    super.key,
    required this.service,
    this.asset,
    this.forceMarket = false,
  });

  @override
  State<AssetEditScreen> createState() => _AssetEditScreenState();
}

class _AssetEditScreenState extends State<AssetEditScreen> {
  late TextEditingController _name;
  late TextEditingController _quantity;
  late TextEditingController _unit;
  late TextEditingController _note;
  late TextEditingController _costPerShare;
  late TextEditingController _currentPrice;
  late String _category;
  late String _currency;

  bool get isEdit => widget.asset != null;
  bool get _isMarket => marketCategories.contains(_category);

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void initState() {
    super.initState();
    final a = widget.asset;
    _name = TextEditingController(text: a?.name ?? '');
    _category = a?.category ?? (widget.forceMarket ? '股票' : '银行卡');
    _currency = a?.currency ?? 'CNY';

    if (a != null) {
      if (a.isMarket) {
        _quantity = TextEditingController(text: _num(a.quantity));
        _currentPrice = TextEditingController(text: _num(a.currentPrice));
        _costPerShare = TextEditingController(text: _num(a.costPerShare));
      } else {
        // 普通资产编辑时显示“实时余额”，用户改了就以此刻为新基准
        final bal = widget.service.currentBalanceOf(a);
        _quantity = TextEditingController(text: _num(bal));
        _currentPrice = TextEditingController();
        _costPerShare = TextEditingController();
      }
      _unit = TextEditingController(
        text: a.unit.isEmpty ? (a.isMarket ? '股' : '元') : a.unit,
      );
    } else {
      _quantity = TextEditingController();
      _currentPrice = TextEditingController();
      _costPerShare = TextEditingController();
      _unit = TextEditingController(text: widget.forceMarket ? '股' : '元');
    }
    _note = TextEditingController(text: a?.note ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _note.dispose();
    _costPerShare.dispose();
    _currentPrice.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final quantityText = _quantity.text.trim();
    if (!RegExp(r'^\d+(\.\d{1,4})?$').hasMatch(quantityText)) {
      _toast('数量/余额最多 4 位小数');
      return;
    }
    final q = double.tryParse(quantityText);
    if (q == null || q < 0) {
      _toast('数量/余额格式不正确');
      return;
    }
    final unit = _unit.text.trim().isEmpty
        ? (_isMarket ? '股' : '元')
        : _unit.text.trim();
    final cost = _isMarket
        ? double.tryParse(_costPerShare.text.trim()) ?? 0
        : 0.0;
    final price = _isMarket
        ? double.tryParse(_currentPrice.text.trim()) ?? 0
        : 0.0;
    final name = _name.text.trim();

    if (isEdit) {
      final a = widget.asset!;
      await widget.service.updateAsset(a.id, {
        'name': name,
        'category': _category,
        'quantity': q,
        'unit': unit,
        'currency': _currency,
        'note': _note.text.trim(),
        'costPerShare': cost,
        'currentPrice': price,
      });
    } else {
      await widget.service.addAsset(
        name: name,
        category: _category,
        quantity: q,
        unit: unit,
        currency: _currency,
        note: _note.text.trim(),
        costPerShare: cost,
        currentPrice: price,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除资产'),
        content: Text('确定删除“${widget.asset!.name}”？'),
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
      await widget.service.deleteAsset(widget.asset!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencies = widget.service.rates.keys.toList();
    final pays = ['', ...widget.service.payments];
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑资产' : '添加资产'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: _isMarket ? '名称（如 苹果股票）' : '名称（如 招商银行卡）',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(
              labelText: '类别',
              border: OutlineInputBorder(),
            ),
            items: assetCategories
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              setState(() {
                _category = v!;
                if (_isMarket && _unit.text.trim() == '元') {
                  _unit.text = '股';
                } else if (!_isMarket && _unit.text.trim() == '股') {
                  _unit.text = '元';
                }
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _isMarket ? '持有数量' : '当前余额',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unit,
                  decoration: const InputDecoration(
                    labelText: '单位',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: currencies.contains(_currency)
                ? _currency
                : currencies.first,
            decoration: const InputDecoration(
              labelText: '币种',
              border: OutlineInputBorder(),
            ),
            items: currencies
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _currency = v!),
          ),
          if (_isMarket) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _costPerShare,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '成本单价（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _currentPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '当前单价',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text(
                '市值 = 持有数量 × 当前单价，不计入净资产',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: '备注',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(isEdit ? '保存修改' : '保存')),
        ],
      ),
    );
  }
}

// ---------- 负债编辑 ----------
class LiabilityEditScreen extends StatefulWidget {
  final LedgerService service;
  final LiabilityItem? liability;
  const LiabilityEditScreen({super.key, required this.service, this.liability});

  @override
  State<LiabilityEditScreen> createState() => _LiabilityEditScreenState();
}

class _LiabilityEditScreenState extends State<LiabilityEditScreen> {
  late TextEditingController _name;
  late TextEditingController _amount;
  late TextEditingController _monthly;
  late TextEditingController _note;
  late String _currency;

  bool get isEdit => widget.liability != null;

  @override
  void initState() {
    super.initState();
    final l = widget.liability;
    _name = TextEditingController(text: l?.name ?? '');
    _amount = TextEditingController(
      text: l == null
          ? ''
          : (l.amount == l.amount.roundToDouble()
                ? l.amount.toInt().toString()
                : l.amount.toString()),
    );
    _monthly = TextEditingController(
      text: l == null || l.monthlyPayment == 0
          ? ''
          : (l.monthlyPayment == l.monthlyPayment.roundToDouble()
                ? l.monthlyPayment.toInt().toString()
                : l.monthlyPayment.toString()),
    );
    _note = TextEditingController(text: l?.note ?? '');
    _currency = l?.currency ?? 'CNY';
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _monthly.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amountText = _amount.text.trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(amountText)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('金额最多 2 位小数')));
      return;
    }
    final monthlyText = _monthly.text.trim();
    if (monthlyText.isNotEmpty &&
        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(monthlyText)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('月供最多 2 位小数')));
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('金额格式不正确')));
      return;
    }
    final monthly = monthlyText.isEmpty
        ? 0.0
        : double.tryParse(monthlyText) ?? 0.0;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写名称')));
      return;
    }
    if (isEdit) {
      await widget.service.updateLiability(widget.liability!.id, {
        'name': name,
        'amount': amount,
        'currency': _currency,
        'monthlyPayment': monthly,
        'note': _note.text.trim(),
      });
    } else {
      await widget.service.addLiability(
        name: name,
        amount: amount,
        currency: _currency,
        monthlyPayment: monthly,
        note: _note.text.trim(),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除负债'),
        content: Text('确定删除“${widget.liability!.name}”？'),
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
      await widget.service.deleteLiability(widget.liability!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencies = widget.service.rates.keys.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑负债' : '添加负债'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '名称（如 欠朋友小李 / 房贷）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '未还总额',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: currencies.contains(_currency)
                ? _currency
                : currencies.first,
            decoration: const InputDecoration(
              labelText: '币种',
              border: OutlineInputBorder(),
            ),
            items: currencies
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _currency = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _monthly,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '月供（可选，仅用于展示）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: '备注',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(isEdit ? '保存修改' : '保存')),
        ],
      ),
    );
  }
}

// ---------- 汇率设置 ----------
class CurrencyRatesScreen extends StatelessWidget {
  final LedgerService service;
  const CurrencyRatesScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final entries = service.rates.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return Scaffold(
          appBar: AppBar(title: const Text('汇率设置（1 单位 = ? CNY）')),
          body: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = entries[i];
              return ListTile(
                title: Text(e.key),
                subtitle: Text('1 ${e.key} = ${e.value} CNY'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _edit(context, e.key, e.value),
                    ),
                    if (e.key != 'CNY')
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await service.removeCurrency(e.key);
                          if (!context.mounted) return;
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('该币种正在被资产/负债使用，无法删除'),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addCurrency(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, String code, double current) async {
    final ctrl = TextEditingController(text: '$current');
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑 $code 汇率'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '1 单位 = ? CNY',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final d = double.tryParse(ctrl.text.trim());
              if (d != null && d > 0) Navigator.pop(ctx, d);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (v != null) await service.setRate(code, v);
  }

  Future<void> _addCurrency(BuildContext context) async {
    final codeCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final result = await showDialog<(String, double)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增币种'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: '币种代码（如 SGD）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '1 单位 = ? CNY',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final code = codeCtrl.text.trim().toUpperCase();
              final rate = double.tryParse(rateCtrl.text.trim());
              if (code.isNotEmpty && rate != null && rate > 0) {
                Navigator.pop(ctx, (code, rate));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null) {
      await service.addCurrency(result.$1, result.$2);
    }
  }
}

class _LiabilityList extends StatelessWidget {
  final LedgerService service;
  const _LiabilityList({required this.service});

  @override
  Widget build(BuildContext context) {
    final list = service.liabilities;
    if (list.isEmpty) {
      return const Center(child: Text('还没有负债，点右下角 + 添加'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final l = list[i];
        final cny = service.liabilityCny(l);
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.trending_down)),
            title: Text(l.name),
            subtitle: Text(
              '${_num(l.amount)} ${l.currency}'
              '${l.monthlyPayment > 0 ? ' · 月供 ${_num(l.monthlyPayment)} ${l.currency}' : ''}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtCny(cny),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                Text('≈ 人民币', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    LiabilityEditScreen(service: service, liability: l),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

// ---------- 资产变动明细 ----------
class AssetFlowScreen extends StatefulWidget {
  final LedgerService service;
  const AssetFlowScreen({super.key, required this.service});

  @override
  State<AssetFlowScreen> createState() => _AssetFlowScreenState();
}

class _AssetFlowScreenState extends State<AssetFlowScreen> {
  String _range = '全部';

  (DateTime?, DateTime?) _bounds() {
    final now = DateTime.now();
    return switch (_range) {
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final (start, end) = _bounds();
        final liquid = widget.service.assets.where((a) => !a.isMarket).toList();
        final flow = widget.service.unallocatedFlow(start: start, end: end);
        final snapshotCny = liquid.fold<double>(
          0,
          (s, a) => s + a.quantity * widget.service.rateOf(a.currency),
        );
        final totalCny = snapshotCny + flow.net;

        return Scaffold(
          appBar: AppBar(title: const Text('总资产构成')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '总资产',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          DropdownButton<String>(
                            value: _range,
                            underline: const SizedBox.shrink(),
                            onChanged: (v) => setState(() => _range = v!),
                            items: ['全部', '本月', '上月', '本年']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fmtCny(totalCny),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '资产快照 ${fmtCny(snapshotCny)}'
                        ' ${flow.net >= 0 ? '+' : '−'} '
                        '收支净额 ${fmtCny(flow.net.abs())}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (liquid.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    '资产快照（手动填写，不随记账变化）',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...liquid.map((a) {
                  final cny = a.quantity * widget.service.rateOf(a.currency);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(a.category.characters.first),
                      ),
                      title: Text(a.name.isEmpty ? a.category : a.name),
                      subtitle: Text(
                        '${_num(a.quantity)} ${a.unit}'
                        '${a.currency != 'CNY' ? '（${a.currency}）' : ''}',
                      ),
                      trailing: Text(
                        fmtCny(cny),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
              _UnallocCard(flow: flow, rangeLabel: _range),
            ],
          ),
        );
      },
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _UnallocCard extends StatelessWidget {
  final UnallocatedFlow flow;
  final String rangeLabel;
  const _UnallocCard({required this.flow, this.rangeLabel = '全部'});

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(
                    Icons.receipt_long,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '收支净额（$rangeLabel）',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Text(
                        '所有记账的汇总，直接计入总资产',
                        style: TextStyle(fontSize: 11, color: Colors.teal),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${flow.net >= 0 ? '+' : ''}${_num(flow.net)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: flow.net >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _row('收入', '+${_num(flow.income)}', Colors.green),
            _row('支出', '-${_num(flow.expense)}', Colors.red),
            _row(
              '净额',
              '${flow.net >= 0 ? '+' : ''}${_num(flow.net)}',
              flow.net >= 0 ? Colors.green : Colors.red,
              bold: true,
            ),
            if (flow.records.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '全部记账明细（${flow.records.length} 笔）',
                  style: const TextStyle(fontSize: 13),
                ),
                children: flow.records.map((r) {
                  final amt = r.amountCents / 100.0;
                  final isIncome = r.kind == '收入';
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r.category}  ${r.note}'),
                    subtitle: Text('${r.date}  ${r.payment}'),
                    trailing: Text(
                      '${isIncome ? '+' : '-'}${_num(amt)}',
                      style: TextStyle(
                        color: isIncome ? Colors.green : Colors.red,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color color, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: bold ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      );
}
