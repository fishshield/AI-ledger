import 'package:flutter/material.dart';

import '../ledger.dart';
import 'transactions.dart';

// ---------- 设置 ----------
class SettingsScreen extends StatelessWidget {
  final LedgerService service;
  const SettingsScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('支出分类'),
                subtitle: Text(service.categories['支出']!.join('、')),
                onTap: () => _openManage(
                  context,
                  '支出分类',
                  service.categories['支出']!,
                  (n) => service.addCategory('支出', n),
                  (n) => service.removeCategory('支出', n),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('收入分类'),
                subtitle: Text(service.categories['收入']!.join('、')),
                onTap: () => _openManage(
                  context,
                  '收入分类',
                  service.categories['收入']!,
                  (n) => service.addCategory('收入', n),
                  (n) => service.removeCategory('收入', n),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('收支方式'),
                subtitle: Text(service.payments.join('、')),
                onTap: () => _openManage(
                  context,
                  '收支方式',
                  service.payments,
                  service.addPayment,
                  service.removePayment,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('操作日志'),
                subtitle: const Text('查看所有修改和删除，可按时间段筛选'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuditLogScreen(service: service),
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('导入 JSON（从 Python 版迁移）'),
                subtitle: const Text('粘贴 ledger.json 的内容，会替换当前数据'),
                onTap: () => _importJson(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openManage(
    BuildContext context,
    String title,
    List<String> items,
    Future<void> Function(String) onAdd,
    Future<void> Function(String) onRemove,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ManagePage(
          title: title,
          items: items,
          onAdd: onAdd,
          onRemove: onRemove,
        ),
      ),
    );
  }

  Future<void> _importJson(BuildContext context) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入 JSON'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: ctrl,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: '把 ledger.json 的内容粘贴到这里',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('导入并替换'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final ok = await service.replaceWithJson(text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? '导入成功' : '导入失败：JSON 格式不正确')));
  }
}

class _ManagePage extends StatefulWidget {
  final String title;
  final List<String> items;
  final Future<void> Function(String) onAdd;
  final Future<void> Function(String) onRemove;
  const _ManagePage({
    required this.title,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<_ManagePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        children: widget.items
            .map(
              (e) => ListTile(
                title: Text(e),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除确认'),
                        content: Text('确定删除“$e”？\n已有记录不受影响，但之后录入时不再出现在选项里。'),
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
                      await widget.onRemove(e);
                      setState(() {});
                    }
                  },
                ),
              ),
            )
            .toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ctrl = TextEditingController();
          final name = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('新增${widget.title}'),
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
          if (name != null && name.isNotEmpty) {
            await widget.onAdd(name);
            setState(() {});
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
