# AI-ledger Flutter 应用

Flutter 图形界面的个人记账与资产管理应用。数据保存在当前设备，当前版本没有接入 AI 对话、自然语言记账、云端账号或自动同步。

## 功能

- **收支明细**：新增、编辑、删除收入和支出，填写金额、分类、收支方式、日期和备注；支持查看详情。
- **修改历史**：记录账目修改和删除的时间、字段差异或删除时快照，以及可选原因；可按时间段查看操作日志。
- **收支统计**：按全部、本月、上月、本年或自定义日期范围筛选，并按类型、分类、收支方式过滤；展示收入、支出、结余、分类饼图、分类收支对比图和收支方式汇总。
- **资产管理**：维护银行卡、现金、微信、支付宝等普通资产余额，以及股票、数字币等行情资产的持仓数量、成本和手动填写的当前价格。
- **负债管理**：维护负债金额、币种、月供和备注。
- **净资产与变动**：按汇率折算资产和负债，展示净资产、普通资产、负债，以及独立展示的行情资产市值和盈亏。普通资产是手动维护的余额快照，不随每笔记账自动变化；全部记账收入减支出会另行计入总资产，行情资产不计入净资产。
- **汇率管理**：提供初始汇率，可手动调整或添加币种；CNY 不可删除，仍被资产或负债使用的币种不可删除。没有自动汇率或行情更新。
- **设置与迁移**：管理收入/支出分类和收支方式；支持粘贴 Python 命令行版的 JSON 数据并替换当前应用数据。当前没有 JSON 导出入口。
- **本地存储**：使用 `shared_preferences` 持久化应用数据；Web 端由插件使用浏览器本地存储。

## 运行

需要安装 Flutter，并使用 `pubspec.yaml` 中声明的 Dart SDK 约束。

```powershell
flutter pub get
flutter run
```

常用格式和静态分析检查：

```powershell
dart format --output=none --set-exit-if-changed lib
flutter analyze
```

## 代码结构

```text
.
├── README.md
├── pubspec.yaml                 # Flutter/Dart SDK 约束和依赖
├── analysis_options.yaml        # Dart 静态分析配置
├── android/                     # Android 平台工程
├── ios/                         # iOS 平台工程
├── linux/                       # Linux 平台工程
├── macos/                       # macOS 平台工程
├── web/                         # Web 平台工程
├── windows/                     # Windows 平台工程
└── lib/
    ├── main.dart                # 应用启动、主题和底部导航
    ├── ledger.dart              # 数据层兼容导出入口
    ├── screens.dart             # 页面层兼容导出入口
    ├── data/
    │   ├── models.dart          # 收支、资产、负债、审计记录模型
    │   ├── store.dart           # 存储接口和 SharedPreferences 实现
    │   └── ledger_service.dart  # 数据加载、保存及业务逻辑
    └── screens/
        ├── transactions.dart    # 明细、编辑、详情和操作日志
        ├── statistics.dart      # 收支筛选、汇总和图表
        ├── assets.dart          # 资产、负债、汇率和资产变动
        └── settings.dart        # 分类、收支方式和 JSON 导入
```

## 维护提示

- 数据模型和业务操作放在 `lib/data/`；页面按功能放在 `lib/screens/`。
- 以下划线开头的 Dart 私有类和成员只在其定义文件内可见。跨文件复用的页面入口使用公开类。
- `ledger.dart` 与 `screens.dart` 是兼容导出层；现有导入可以继续使用，也可以在新代码中按功能直接导入对应模块。
- Python 版 JSON 可在“设置 → 导入 JSON”中粘贴导入；此操作会替换 Flutter 应用当前数据。
