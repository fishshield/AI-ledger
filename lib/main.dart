import 'package:flutter/material.dart';

import 'ledger.dart';
import 'screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = LedgerService(SharedPrefsStore());
  await service.load();
  runApp(LedgerApp(service: service));
}

class LedgerApp extends StatelessWidget {
  final LedgerService service;
  const LedgerApp({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '记账簿',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: HomeShell(service: service),
    );
  }
}

class HomeShell extends StatefulWidget {
  final LedgerService service;
  const HomeShell({super.key, required this.service});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ListScreen(service: widget.service),
      AssetsScreen(service: widget.service),
      StatsScreen(service: widget.service),
      SettingsScreen(service: widget.service),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: '明细'),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet),
            label: '资产',
          ),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '统计'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
