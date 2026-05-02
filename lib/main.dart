import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

final uuid = Uuid();

class NotifyService {
  static final _notif = FlutterLocalNotificationsPlugin();

static Future<void> cancelAll(String id) async {
  await _notif.cancel(_stableId("${id}_start"));
  await _notif.cancel(_stableId("${id}_end"));
  await _notif.cancel(_stableId("${id}_announce"));
  await _notif.cancel(_stableId("${id}_remind"));
}

  // ★ここを追加（必須）
  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: android,
    );

    await _notif.initialize(settings);
  }


static int _stableId(String key) {
  return key.hashCode & 0x7fffffff;
}

static Future<void> schedule({
  required String id,
  required String title,
  required String body,
  required DateTime date,
}) async {
  final android = AndroidNotificationDetails(
    'lottery',
    '抽選通知',
    importance: Importance.max,
    priority: Priority.high,
  );

  final target = tz.TZDateTime.from(date, tz.local);
  final now = tz.TZDateTime.now(tz.local);

if (target.isBefore(now.add(const Duration(seconds: 10)))) return;

  // ★これ追加（超重要）
  await _notif.cancel(_stableId(id));

  await _notif.zonedSchedule(
    _stableId(id),
    title,
    body,
    target,
    NotificationDetails(android: android),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}
}



////////////////////////////////////////////////////////////////////////////////
/// MAIN
////////////////////////////////////////////////////////////////////////////////

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja');

  await LotteryCore.load();

  // 🔔 通知初期化
  await NotifyService.init();

  runApp(const MyApp());
}


////////////////////////////////////////////////////////////////////////////////
/// ENUM
////////////////////////////////////////////////////////////////////////////////

enum LotteryMethod { mail, x, sms, hp, auto }

enum SortType {
  priority,
  deadline,
  name,
}

class LotteryMethodUtil {
  static LotteryMethod from(dynamic v) {
    switch (v?.toString()) {
      case "x":
      case "X":
        return LotteryMethod.x;
      case "sms":
      case "SMS":
        return LotteryMethod.sms;
      case "hp":
        return LotteryMethod.hp;
      case "auto":
        return LotteryMethod.auto;
      default:
        return LotteryMethod.mail;
    }
  }

  static String label(LotteryMethod m) {
    switch (m) {
      case LotteryMethod.mail:
        return "メール";
      case LotteryMethod.x:
        return "X";
      case LotteryMethod.sms:
        return "SMS";
      case LotteryMethod.hp:
        return "HP";
      case LotteryMethod.auto:
        return "自動";
    }
  }
}

////////////////////////////////////////////////////////////////////////////////
/// SAFE
////////////////////////////////////////////////////////////////////////////////

class SafeLottery {
  static String text(String? v) =>
      (v == null || v.trim().isEmpty) ? "不明" : v;

  static String date(String? v) =>
      (v == null || v.isEmpty) ? "未設定" : v;

  static String time(String? v) =>
      (v == null || v.isEmpty) ? "未設定" : v;
}

////////////////////////////////////////////////////////////////////////////////
/// MODEL
////////////////////////////////////////////////////////////////////////////////

class Lottery {
  String id;
  String store;
  String item;
  int? _cachedEndDay;
  String category;
  String drawDate;
  String drawTime;
  String announceDate;
  LotteryMethod method;
  String note;
  bool won;
  bool favorite;
  bool archived;
  bool applied;
  String url;        // ←追加
  List<String> statusHistory;
  bool reminderEnabled;
  String reminderDate;
  bool isDeleted;
  int priorityScore;
  String startDate;
  String endDate;
  String startTime;
  String endTime;
  String announceTime;
  
  
Lottery({
  required this.id,
  required this.store,
  required this.item,
  this.category = "",
  required this.drawDate,
  required this.drawTime,
  required this.announceDate,
  required this.method,
  this.startDate = "",
  this.endDate = "",
  this.startTime = "",
  this.endTime = "",
  this.announceTime = "",
  this.note = "",

  this.url = "",

  // ★↑↑ここまで追加↑↑★

  this.won = false,
  this.favorite = false,
  this.archived = false,
  this.applied = false,
  this.statusHistory = const [],
  this.reminderEnabled = false,
  this.reminderDate = "",
  this.isDeleted = false,
  this.priorityScore = 0,
});

  Map<String, dynamic> toJson() => {
        "id": id,
        "store": store,
        "item": item,
        "category": category,
        "drawDate": drawDate,
        "drawTime": drawTime,
        "announceDate": announceDate,
        "method": method.name,
        "note": note,
        "won": won,
        "favorite": favorite,
        "archived": archived,
        "applied": applied,
        "statusHistory": statusHistory,
        "reminderEnabled": reminderEnabled,
        "reminderDate": reminderDate,
        "isDeleted": isDeleted,
        "priorityScore": priorityScore,
        "url": url,
        "startDate": startDate,
        "endDate": endDate,
        "startTime": startTime,
        "endTime": endTime,
        "announceTime": announceTime,
       };

static Lottery fromJson(Map<String, dynamic> j) {
  return Lottery(
    id: (j["id"] ?? "").toString().isEmpty ? uuid.v4() : j["id"].toString(),

    store: (j["store"] ?? "").toString(),
    item: (j["item"] ?? "").toString(),
    category: (j["category"] ?? "").toString(),

    drawDate: (j["drawDate"] ?? "").toString(),
    drawTime: (j["drawTime"] ?? "").toString(),
    announceDate: (j["announceDate"] ?? "").toString(),

    method: LotteryMethodUtil.from(j["method"]?.toString()),

    note: (j["note"] ?? "").toString(),

    won: j["won"] == true,
    favorite: j["favorite"] == true,
    archived: j["archived"] == true,
    applied: j["applied"] == true,

    statusHistory: (j["statusHistory"] is List)
        ? List<String>.from(j["statusHistory"] ?? [])
        : [],

    reminderEnabled: j["reminderEnabled"] == true,
    reminderDate: (j["reminderDate"] ?? "").toString(),
    isDeleted: j["isDeleted"] == true,
priorityScore: int.tryParse(j["priorityScore"].toString()) ?? 0,
    url: (j["url"] ?? "").toString(),
    startDate: (j["startDate"] ?? "").toString(),
    endDate: (j["endDate"] ?? "").toString(),
    startTime: (j["startTime"] ?? "").toString(),
    endTime: (j["endTime"] ?? "").toString(),
    announceTime: (j["announceTime"] ?? "").toString(),
  );
}
}

/// NOTIFY（完全修正）
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
/// ★ LotteryCore（復元＋移行込み）
////////////////////////////////////////////////////////////////////////////////

class LotteryCore {
  static List<Lottery> list = [];
  static final _stream = StreamController<void>.broadcast();
  static Stream<void> get stream => _stream.stream;
  static List<int> reminderDays = [3, 1, 0];
  static Future<void> load() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString("data");
 
  
try {
  if (raw != null) {
    final decoded = jsonDecode(raw);

    list = (decoded as List)
        .map((e) => Lottery.fromJson(e))
        .toList();

    // 移行
    for (final l in list) {
      if (l.startDate.isEmpty) l.startDate = l.drawDate;
      if (l.endDate.isEmpty) l.endDate = l.drawDate;
    }
  }
} catch (e) {
  print("JSON ERROR: $e");
  print("RAW DATA: $raw");
}

_stream.add(null);
}

  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString("data", jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> add(Lottery l) async {
    list.add(l);
    await save();

    if (!l.applied && l.reminderEnabled && l.endDate.isNotEmpty) {
      _schedule(l);
    }

    _stream.add(null);
  }

static Future<void> update(Lottery l) async {
  // ① まず完全に通知を消す（最優先）
await NotifyService.cancelAll(l.id);

l.priorityScore = calcPriority(l);

final i = list.indexWhere((e) => e.id == l.id);
if (i != -1) list[i] = l;

await save();

if (!l.applied && l.reminderEnabled && l.endDate.isNotEmpty) {
  await Future.delayed(const Duration(milliseconds: 50));
  _schedule(l);
}

  _stream.add(null);
}

  static Future<void> delete(String id) async {
    await NotifyService.cancelAll(id);
    list.removeWhere((e) => e.id == id);
    await save();
    _stream.add(null);
  }

static Future<void> _schedule(Lottery l) async {
  await NotifyService.cancelAll(l.id);

  // ① 開始
  final start = getStart(l);
  if (start != null) {
    await NotifyService.schedule(
      id: "${l.id}_start",
      title: "抽選開始",
      body: "${l.item} / ${l.store}",
      date: start,
    );
  }

  // ② 締切
  final end = getEnd(l);
  if (end != null) {
    await NotifyService.schedule(
      id: "${l.id}_end",
      title: "応募締切",
      body: "${l.item} / ${l.store}",
      date: end,
    );
  }

  // ③ 発表
  final announce = getAnnounce(l);
  if (announce != null) {
    await NotifyService.schedule(
      id: "${l.id}_announce",
      title: "当選発表",
      body: "${l.item} / ${l.store}",
      date: announce,
    );
  }
}
  /// ▼ 以下は既存UIが使ってるやつ（消すと壊れる）

  static void toggleFavorite(Lottery l) {
    l.favorite = !l.favorite;
    update(l);
  }

  static void toggleArchive(Lottery l) {
    l.archived = !l.archived;
    update(l);
  }

  static void toggleApplied(Lottery l) {
    l.applied = !l.applied;
    update(l);
  }

  static void toggleWon(Lottery l) {
    l.won = !l.won;
    update(l);
  }

  static void softDelete(Lottery l) {
    l.isDeleted = true;
    update(l);
  }

  static void restore(Lottery l) {
    l.isDeleted = false;
    update(l);
  }

  static int calcPriority(Lottery l) {
    int score = 0;

    if (!l.applied) score += 50;
    if (l.favorite) score += 30;

    final d = getEnd(l);
    if (d != null) {
      final diff = d.difference(DateTime.now()).inDays;
      score += (30 - diff).clamp(0, 30);
    }

    return score;
  }

  static Map<String, dynamic> getStats() {
    final applied = list.where((e) => e.applied).length;
    final won = list.where((e) => e.won).length;
    final rate = applied == 0 ? 0.0 : (won / applied) * 100;

    return {
      "applied": applied,
      "won": won,
      "rate": rate,
    };
  }
}



////////////////////////////////////////////////////////////////////////////////
/// APP
////////////////////////////////////////////////////////////////////////////////

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const MainPage(),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
/// MAIN
////////////////////////////////////////////////////////////////////////////////

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: tab == 0
          ? const HomePage()
          : tab == 1
              ? const CollectPage()
              : const ArchivePage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab,
        selectedItemColor: Colors.red,
        onTap: (i) => setState(() => tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "抽選"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "収集"),
          BottomNavigationBarItem(icon: Icon(Icons.archive), label: "アーカイブ"),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
/// HOME (UI強化版)
////////////////////////////////////////////////////////////////////////////////

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool showFavOnly = false;
  bool showWonOnly = false;
  bool showUnappliedOnly = false;
  bool showDeadlineOnly = false;

  SortType sortType = SortType.priority;

  String keyword = "";

  void copyUrl(String url) {
  if (url.isEmpty) return;

  Clipboard.setData(ClipboardData(text: url));

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("URLをコピーしました"),
      duration: Duration(seconds: 1),
    ),
  );
  }
  String _label(LotteryMethod m) => LotteryMethodUtil.label(m);

Future<void> openUrl(String url) async {
  if (url.trim().isEmpty) return;

  try {
    var fixed = url.trim();

    if (!fixed.startsWith("http")) {
      fixed = "https://$fixed";
    }

    final uri = Uri.parse(fixed);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("URLを開けませんでした")),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("URL形式が不正です")),
    );
  }
}

//抽選締切色変
  String _deadlineStatus(Lottery l) {
   if (l.endDate.isEmpty) return "⚪ 未設定";

    final d = getEnd(l);
    if (d == null) return "⚪ 未設定";

    final diff = d.difference(DateTime.now()).inDays;

    if (diff < 0) return "❌ 締切済";
    if (diff <= 1) return "🔴 締切直前";
    if (diff <= 3) return "🟠 締切間近";
    return "🟢 余裕あり";
  }

int _deadlineDays(Lottery l) {
  final d = getEnd(l);
  if (d == null) return 999;

  return d.difference(DateTime.now()).inDays;
}

//状況別カウントダウン
String _countdownText(Lottery l) {
  DateTime now = DateTime.now();

   DateTime? deadline = getEnd(l);
  DateTime? draw = parseDateTime(l.drawDate);
  DateTime? announce = parseDateTime(l.announceDate);

  String format(Duration d) {
    if (d.inDays >= 1) return "あと${d.inDays}日";
    if (d.inHours >= 1) return "あと${d.inHours}時間";
    return "あと${d.inMinutes}分";
  }

  // ① 未応募 & 締切前
  if (!l.applied && deadline != null && deadline.isAfter(now)) {
    return "応募締切まで：${format(deadline.difference(now))}";
  }

  // ② 抽選待ち
  if (draw != null && draw.isAfter(now)) {
    return "抽選まで：${format(draw.difference(now))}";
  }

  // ③ 発表待ち
  if (announce != null && announce.isAfter(now)) {
    return "発表まで：${format(announce.difference(now))}";
  }

  return "終了";
}

bool _isCritical(Lottery l) {
  final days = _deadlineDays(l);
  return !l.applied && days <= 1;
}

  Color _deadlineColor(Lottery l) {
if (l.endDate.isEmpty) return Colors.grey;
  final d = getEnd(l);
  if (d == null) return Colors.grey;

  final diff = d.difference(DateTime.now()).inDays;

  if (diff < 0) return Colors.grey;
  if (diff <= 1) return Colors.red;
  if (diff <= 3) return Colors.orange;
  return Colors.green;
}

//ミニチップ
  Widget _miniChip(String text, {Color? color}) {
  return Chip(
    label: Text(
      text,
      style: TextStyle(fontSize: 10, color: color),
    ),
    backgroundColor: color != null ? color.withOpacity(0.1) : null,
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

List<IconData> _icons(Lottery l) {
  final icons = <IconData>[];

  if (l.won) icons.add(Icons.emoji_events);
  if (l.favorite && icons.length < 2) icons.add(Icons.star);

  return icons;
}

  Color _statusColor(String status) {
    if (status.contains("🔴")) return Colors.red;
    if (status.contains("🟠")) return Colors.orange;
    if (status.contains("🟢")) return Colors.green;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
  stream: LotteryCore.stream,
  builder: (_, __) {

    final stats = LotteryCore.getStats();

final baseList = [...LotteryCore.list];
final filteredList = baseList
    .where((e) =>
        !e.isDeleted &&
        !e.archived &&
        (
          keyword.isEmpty ||
          e.item.toLowerCase().contains(keyword.toLowerCase()) ||
          e.store.toLowerCase().contains(keyword.toLowerCase()) ||
          e.category.toLowerCase().contains(keyword.toLowerCase()) ||
          e.note.toLowerCase().contains(keyword.toLowerCase())
        )
    )
    .toList()
  ..sort((a, b) {
    final now = DateTime.now();

    int days(Lottery l) {
      if (l.endDate.isEmpty) return 999;
      final d = getEnd(l);
      if (d == null) return 999;
      return d.difference(now).inDays;
    }

    switch (sortType) {
      case SortType.deadline:
        return days(a).compareTo(days(b));
      case SortType.name:
        return a.item.compareTo(b.item);
        case SortType.priority:
  return b.priorityScore.compareTo(a.priorityScore);
    }
  });

        return Scaffold(
          floatingActionButton: Padding(
  padding: const EdgeInsets.only(bottom: 70),
  child: FloatingActionButton(
    tooltip: "新規登録",
    backgroundColor: Colors.blue, // ← 色変更
    elevation: 6,
    child: const Icon(Icons.add),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddPage()),
      );
    },
  ),
),
          appBar: AppBar(
  title: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("抽選管理"),
      Text(
        "応募:${stats["applied"]} / 当選:${stats["won"]} / 率:${stats["rate"].toStringAsFixed(1)}%",
        style: const TextStyle(fontSize: 11),
      )
    ],
  ),

  // 🔽 これを追加
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(48),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        decoration: InputDecoration(
          hintText: "検索（商品・店舗・カテゴリ）",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (v) => setState(() => keyword = v),
      ),
    ),
  ),

  actions: [
              IconButton(
                tooltip: "お気に入りのみ表示",
                icon: Icon(showFavOnly ? Icons.star : Icons.star_border),
                onPressed: () => setState(() => showFavOnly = !showFavOnly),
              ),
              IconButton(
                tooltip: "当選のみ表示",
                icon: const Icon(Icons.emoji_events),
                onPressed: () => setState(() => showWonOnly = !showWonOnly),
              ),
              IconButton(
                tooltip: "未応募のみ表示",
                icon: const Icon(Icons.mail),
                onPressed: () =>
                    setState(() => showUnappliedOnly = !showUnappliedOnly),
              ),
              IconButton(
                tooltip: "締切3日以内のみ表示",
                icon: const Icon(Icons.schedule),
                onPressed: () =>
                    setState(() => showDeadlineOnly = !showDeadlineOnly),
              ),
            ],
          ),
        body: LotteryCore.list.isEmpty
              ? const Center(child: Text("データなし"))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                itemCount: filteredList.length,
itemBuilder: (_, i) {
  final e = filteredList[i];
  final now = DateTime.now();

final isExpiredUnapplied =
    getEnd(e)?.isBefore(DateTime.now()) == true && !e.applied;

final isCritical = _isCritical(e);

return Card(
  elevation: isCritical ? 4 : 1,
  color: isCritical
      ? Colors.red.withOpacity(0.08)
      : (isExpiredUnapplied
          ? Colors.grey.withOpacity(0.1)
          : null),
  margin: const EdgeInsets.symmetric(vertical: 3),
  child: 
  ListTile(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 8,
    ),

    leading: Row(
      mainAxisSize: MainAxisSize.min,
      children: _icons(e).map((i) => Icon(i, size: 16)).toList(),
    ),

    title: Text(
      "${e.store} / ${e.item}",
      style: TextStyle(
  fontWeight: FontWeight.bold,
color: isCritical
    ? Colors.red
    : (isExpiredUnapplied ? Colors.grey : null),
),
    ),

   subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
      children: [        
  RichText(
    text: TextSpan(
      style: const TextStyle(fontSize: 11, color: Colors.black),
      children: [
 TextSpan(
text: "発表:${e.announceDate.isEmpty ? "未設定" : SafeLottery.date(e.announceDate)} / ",
  style: TextStyle(color: _deadlineColor(e)),
),

        TextSpan(text: "発:${SafeLottery.date(e.announceDate)}"),
      ],
    ),
  ),

  // ★ これ追加（超重要）
  Text(
    _countdownText(e),
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: isCritical ? Colors.red : Colors.blue,
    ),
  ),

  const SizedBox(height: 2),

  Wrap(
    spacing: 4,
    runSpacing: -8,
    children: [
_miniChip(
  e.applied ? "✔応募済" : "未応募",
  color: isCritical
      ? Colors.red
      : (isExpiredUnapplied
          ? Colors.grey
          : (!e.applied ? Colors.red : null)),
),
            _miniChip(e.won ? "当選" : "落選"),
            _miniChip(
  _deadlineStatus(e),
  color: isCritical ? Colors.red : null,
),
            _miniChip(_label(e.method)),
          ],
        ),
      ],
    ),

    trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
if (e.url.trim().isNotEmpty)
IconButton(
  icon: const Icon(Icons.open_in_new),
  color: Colors.blue,
    tooltip: "開く（長押しでコピー）",

  onPressed: () => openUrl(e.url),

  onLongPress: () => copyUrl(e.url), // ←これに変更！！
),

    PopupMenuButton<String>(
      onSelected: (v) {
        if (v == "fav") LotteryCore.toggleFavorite(e);
        if (v == "archive") LotteryCore.toggleArchive(e);
        if (v == "applied") LotteryCore.toggleApplied(e);
        if (v == "won") LotteryCore.toggleWon(e);
        if (v == "edit") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddPage(editTarget: e),
            ),
          );
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: "fav", child: Text("お気に入り")),
        PopupMenuItem(value: "archive", child: Text("アーカイブ")),
        PopupMenuItem(value: "applied", child: Text("応募切替")),
        PopupMenuItem(value: "won", child: Text("当選切替")),
        PopupMenuItem(value: "edit", child: Text("編集")),
      ],
    ),
  ],
),

    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddPage(editTarget: e),
        ),
      );
    },

    onLongPress: () {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("削除確認"),
          content: const Text("このデータを削除しますか？"),
          actions: [
            TextButton(
              child: const Text("キャンセル"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("削除"),
              onPressed: () {
                LotteryCore.softDelete(e);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    },
  ),
);


                  },
                ),
        );
      },
    );
  }

}

////////////////////////////////////////////////////////////////////////////////
/// ADD (UI強化のみ)
////////////////////////////////////////////////////////////////////////////////

class AddPage extends StatefulWidget {
  final Lottery? editTarget;

  const AddPage({super.key, this.editTarget});
  
  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final startDate = TextEditingController();
  final endDate = TextEditingController();
  final startTime = TextEditingController();
  final endTime = TextEditingController();
  final announceTime = TextEditingController();
 

 
  bool reminderEnabled = true;

  void _autoFillFromUrl(String urlText) {
  if (urlText.isEmpty) return;

  final u = urlText.toLowerCase();

  if (u.contains("rakuten")) {
    if (store.text.isEmpty) store.text = "楽天";
    if (category.text.isEmpty) category.text = "EC";
  } else if (u.contains("amazon")) {
    if (store.text.isEmpty) store.text = "Amazon";
    if (category.text.isEmpty) category.text = "EC";
  } else if (u.contains("pokemon")) {
    if (category.text.isEmpty) category.text = "ポケモン";
  }

  setState(() {});
}

  
  void _syncDates() {
  if (startDate.text.isNotEmpty && endDate.text.isEmpty) {
    endDate.text = startDate.text;
  }

  final s = parseDateTime(startDate.text);
  final e = parseDateTime(endDate.text);

  if (s != null && e != null && e.isBefore(s)) {
    endDate.text = startDate.text;
  }
}
  InputDecoration _dec(String label) {
  return InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
  );
}

Widget _dateField(TextEditingController controller, String label) {
  return TextField(
    controller: controller,
    readOnly: true,
    decoration: _dec(label),
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );

      if (picked != null) {
        controller.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      }
    },
  );
}
  
  
  final store = TextEditingController();
  final item = TextEditingController();
  final category = TextEditingController();
  final url = TextEditingController();
  final drawDate = TextEditingController();
  final drawTime = TextEditingController();
  final announceDate = TextEditingController();
  final note = TextEditingController();

  

  LotteryMethod method = LotteryMethod.mail;
  bool applied = false;

  bool get isEdit => widget.editTarget != null;


  @override
  void initState() {
    
    
    super.initState();

    if (isEdit) {
      final e = widget.editTarget!;
      url.text = e.url;
      store.text = e.store;
      item.text = e.item;
      category.text = e.category;
      drawDate.text = e.drawDate;
      drawTime.text = e.drawTime;
      announceDate.text = e.announceDate;
      note.text = e.note;
      method = e.method;
      applied = e.applied;
      startDate.text = e.startDate;
      endDate.text = e.endDate;
      startTime.text = e.startTime;
      endTime.text = e.endTime;
      announceTime.text = e.announceTime;
    }
  }

void save() async {
  _syncDates();

  // ★ここ追加
  startTime.text = startTime.text.trim().isEmpty ? "00:00" : startTime.text;
  endTime.text = endTime.text.trim().isEmpty ? "00:00" : endTime.text;
  announceTime.text = announceTime.text.trim().isEmpty ? "00:00" : announceTime.text;

  if (isEdit) {
    final e = widget.editTarget!;

final updated = Lottery(
  id: e.id,
  store: store.text,
  item: item.text,
  category: category.text,
  drawDate: drawDate.text,
  drawTime: drawTime.text,
  announceDate: announceDate.text,
  method: method,
  note: note.text,
  applied: applied,

  // ★追加
  startDate: startDate.text,
  endDate: endDate.text,
  startTime: startTime.text,
  endTime: endTime.text,
  announceTime: announceTime.text,

  reminderEnabled: reminderEnabled,
  url: url.text,

  // ★超重要：既存データ引き継ぎ
  won: e.won,
  favorite: e.favorite,
  archived: e.archived,
  statusHistory: e.statusHistory,
  reminderDate: e.reminderDate,
  isDeleted: e.isDeleted,
  priorityScore: e.priorityScore,
);

    await LotteryCore.update(updated);

  } else {
final newLottery = Lottery(
  id: uuid.v4(),
  store: store.text,
  item: item.text,
  category: category.text,
  drawDate: drawDate.text,
  drawTime: drawTime.text,
  announceDate: announceDate.text,
  method: method,
  note: note.text,
  applied: applied,
  startDate: startDate.text,
  endDate: endDate.text,
  reminderEnabled: reminderEnabled,
  url: url.text,
);

newLottery.priorityScore = LotteryCore.calcPriority(newLottery);

    await LotteryCore.add(newLottery);

    if (!newLottery.applied &&
        newLottery.reminderEnabled &&
        newLottery.endDate.isNotEmpty) {
      final deadline = parseDateTime(newLottery.endDate);

      if (deadline != null) {
        NotifyService.schedule(
id: "${newLottery.id}_remind",
          title: "応募リマインド",
          body: "${newLottery.item} / ${newLottery.store}",
date: parseDateTime(newLottery.endDate) ?? DateTime.now().add(const Duration(minutes: 1)),        );
      }
    }
  }

  if (!mounted) return;
  Navigator.pop(context);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? "編集" : "追加")),
      body: ListView(
  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80), // ← ★下に余白
        children: [

          /// ▼ 上段：店舗 + 商品
          Row(
            children: [
              Expanded(child: TextField(controller: store, decoration: _dec("店舗名"))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: item, decoration: _dec("商品名"))),
            ],
          ),

          const SizedBox(height: 8),

          /// ▼ カテゴリ
           // ↓ 余白追加（重要）
const SizedBox(height: 16),

// ▼ カテゴリ（本来の役割に戻す）
TextField(
  controller: category,
  decoration: _dec("カテゴリ"),
),

const SizedBox(height: 8),
//URL
const SizedBox(height: 8),

TextField(
  controller: url,
  decoration: _dec("URL"),
    onChanged: _autoFillFromUrl, // ★追加
),
          /// ▼ 日付系（4段構成）
Column(
  children: [
    const SizedBox(height: 8),

Row(
  children: [
    Expanded(child: _dateField(startDate, "抽選開始")),
    const SizedBox(width: 8),
    Expanded(
      child: TextField(
        controller: startTime,
        decoration: _dec("開始時間"),
      ),
    ),
  ],
),

    const SizedBox(height: 12), // ← ★増やす

Row(
  children: [
    Expanded(child: _dateField(endDate, "応募締切")),
    const SizedBox(width: 8),
    Expanded(
      child: TextField(
        controller: endTime,
        decoration: _dec("締切時間"),
      ),
    ),
  ],
),

    const SizedBox(height: 12), // ← ★増やす

Row(
  children: [
    Expanded(child: _dateField(announceDate, "当選発表")),
    const SizedBox(width: 8),
    Expanded(
      child: TextField(
        controller: announceTime,
        decoration: _dec("発表時間"),
      ),
    ),
  ],
),

    const SizedBox(height: 12), // ← ★増やす



    const SizedBox(height: 16), // ← ★ここ重要（備考との距離）
  ],
),

          const SizedBox(height: 8),

          /// ▼ 当選発表方法（NEW）
          DropdownButtonFormField<LotteryMethod>(
            value: method,
            decoration: _dec("当選発表方法"),
            items: LotteryMethod.values.map((m) {
              return DropdownMenuItem(
                value: m,
                child: Text(LotteryMethodUtil.label(m)),
              );
            }).toList(),
            onChanged: (v) => setState(() => method = v!),
          ),

TextField(
  controller: note,
  decoration: _dec("備考"),
  maxLines: 3,
  minLines: 3, // ← ★追加（これが効く）
),


          const SizedBox(height: 8),

          /// ▼ 応募スイッチ（コンパクト化）
          Row(
            children: [
              const Text("応募"),
              const Spacer(),
              Switch(
                value: applied,
                onChanged: (v) => setState(() => applied = v),
              ),
            ],
          ),
Row(
  children: [
    const Text("通知"),
    const Spacer(),
    Switch(
      value: reminderEnabled,
      onChanged: (v) => setState(() => reminderEnabled = v),
    ),
  ],
),
          const SizedBox(height: 8),

          /// ▼ 保存ボタン（スリム化）
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save, size: 18),
              label: const Text("保存"),
            ),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
/// ARCHIVE PAGE（実データ対応）
////////////////////////////////////////////////////////////////////////////////

class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: LotteryCore.stream,
      builder: (_, __) {
        final list = LotteryCore.list.where((e) => e.archived).toList();
list.sort((a, b) {
  final now = DateTime.now();

DateTime? daRaw = parseDateTime(a.endDate, a.endTime);
DateTime? dbRaw = parseDateTime(b.endDate, b.endTime);

  // ★① 締切過ぎチェック
  final aExpired = daRaw != null && daRaw.isBefore(now);
  final bExpired = dbRaw != null && dbRaw.isBefore(now);

  // どっちかだけ締切過ぎ → 過ぎてる方を下へ
  if (aExpired != bExpired) {
    return aExpired ? 1 : -1;
  }

  // ★② 通常の優先度
  final pa = LotteryCore.calcPriority(a);
  final pb = LotteryCore.calcPriority(b);

  if (pa != pb) return pb.compareTo(pa);

  // ★③ 同点なら締切近い順
  int days(Lottery l) {
    if (l.endDate.isEmpty) return 999;

    final d = getEnd(l);
    if (d == null) return 999;

    return d.difference(now).inDays;
  }

  return days(a).compareTo(days(b));
});
        return Scaffold(
          appBar: AppBar(title: const Text("アーカイブ")),
          body: list.isEmpty
    ? const Center(child: Text("データなし"))
    : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final e = list[i];
                    return Card(
                      child: ListTile(
                        title: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      e.item,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    ),
    Text(
      e.store,
      style: const TextStyle(
        fontSize: 11,
        color: Colors.grey,
      ),
    ),
  ],
),
                        subtitle: Text(
                          e.note.isNotEmpty ? e.note : e.category,
                         ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.unarchive),
                              onPressed: () => LotteryCore.toggleArchive(e),
                            ),
                            // 追加③
                            IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: "完全復元",
                              onPressed: () => LotteryCore.restore(e),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddPage(editTarget: e),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
/// COLLECT SOURCE
////////////////////////////////////////////////////////////////////////////////

enum CollectSource {
  dummy,
  rakuten,
  manual,
}

////////////////////////////////////////////////////////////////////////////////
/// COLLECT ENGINE
////////////////////////////////////////////////////////////////////////////////

class CollectEngine {
  static Future<List<Map<String, String>>> fetch(
  String keyword,
  CollectSource source,
) async {
  switch (source) {
    case CollectSource.dummy:
      return _dummy(keyword);

    case CollectSource.rakuten:
      return _rakuten(keyword);

    case CollectSource.manual:
      return _manual(keyword);
  }
}
static Future<Map<String, String>> parseXPost(String text) async {
  String store = "";
  String item = "";
  String startDate = "";
  String endDate = "";

  final lines = text.split("\n");

  for (final l in lines) {
    final line = l.trim();

    // ■ 商品判定
    if (item.isEmpty &&
        (line.contains("抽選") ||
         line.contains("販売") ||
         line.contains("BOX") ||
         line.contains("セット"))) {
      item = line;
    }

    // ■ 店舗判定
    if (store.isEmpty &&
        (line.contains("店") ||
         line.contains("ショップ") ||
         line.contains("オンライン"))) {
      store = line;
    }

    // ■ 日付抽出
    final reg = RegExp(r'(20\d{2})[/-](\d{1,2})[/-](\d{1,2})');
    final match = reg.firstMatch(line);

    if (match != null) {
      final y = match.group(1);
      final m = match.group(2)!.padLeft(2, '0');
      final d = match.group(3)!.padLeft(2, '0');

      final formatted = "$y-$m-$d";

      // 🔥 キーワード判定
      if (line.contains("開始") || line.contains("スタート")) {
        startDate = formatted;
      } else if (line.contains("締切") || line.contains("まで")) {
        endDate = formatted;
      } else {
        if (startDate.isEmpty) {
          startDate = formatted;
        } else if (endDate.isEmpty) {
          endDate = formatted;
        }
      }
    }

    // ■ 応募期間パターン（〜から〜まで）
    if (line.contains("応募期間")) {
      final reg2 = RegExp(r'(20\d{2})[/-](\d{1,2})[/-](\d{1,2})');
      final matches = reg2.allMatches(line).toList();

      if (matches.length >= 2) {
        final m1 = matches[0];
        final m2 = matches[1];

        startDate =
            "${m1.group(1)}-${m1.group(2)!.padLeft(2, '0')}-${m1.group(3)!.padLeft(2, '0')}";
        endDate =
            "${m2.group(1)}-${m2.group(2)!.padLeft(2, '0')}-${m2.group(3)!.padLeft(2, '0')}";
      }
    }
  }

  return {
    "store": store,
    "item": item,
    "category": "x",
    "startDate": startDate,
    "endDate": endDate,
  };
}
  /// 楽天（擬似）
  static Future<List<Map<String, String>>> _rakuten(String keyword) async {
    await Future.delayed(const Duration(seconds: 1));

    return List.generate(3, (i) {
      return {
        "store": "楽天ストア $i",
        "item": "$keyword BOX $i",
        "category": "rakuten",
      };
    });
  }
static Future<List<Map<String, String>>> _dummy(String keyword) async {
  await Future.delayed(const Duration(milliseconds: 300));

  return List.generate(5, (i) {
    return {
      "store": "ダミー店舗 $i",
      "item": "$keyword サンプル $i",
      "category": "dummy",
    };
  });
}
  /// 手動
  static Future<List<Map<String, String>>> _manual(String keyword) async {
    return [
      {
        "store": "手動入力",
        "item": keyword,
        "category": "manual",
      }
    ];
  }
}

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  final controller = TextEditingController();
    final xInput = TextEditingController();
  List<Map<String, String>> results = [];
  bool loading = false;
  CollectSource source = CollectSource.dummy;
  
  Future<void> search() async {
  setState(() => loading = true);

  final keyword = controller.text;

  results = await CollectEngine.fetch(keyword, source);

  setState(() => loading = false);
}


Future<void> addToLottery(Map<String, String> data) async {
  final l = Lottery(
    id: uuid.v4(),
item: (data["item"] ?? "不明").toString(),
store: (data["store"] ?? "不明").toString(),
    category: data["category"] ?? "",

    drawDate: "",
drawTime: "",
announceDate: "",
startDate: data["startDate"] ?? "",
endDate: data["endDate"] ?? "",


    method: LotteryMethod.auto,

    note: "",


    applied: false,
    favorite: false,
    archived: false,
    won: false,

    statusHistory: [],
    reminderEnabled: false,
    reminderDate: "",
    isDeleted: false,
    priorityScore: 0,
  );

l.priorityScore = LotteryCore.calcPriority(l);
await LotteryCore.add(l);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("追加しました")),
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text("収集")),
    body: Column(
      children: [

TextField(
  controller: xInput,
  decoration: const InputDecoration(
    hintText: "X投稿テキスト貼り付け",
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 8),

ElevatedButton(
  onPressed: () async {
    final data = await CollectEngine.parseXPost(xInput.text);

    await addToLottery(data);

    xInput.clear();
  },
  child: const Text("Xから追加"),
),

        /// 🔍 検索エリア
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: "キーワード入力",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<CollectSource>(
                value: source,
                decoration: const InputDecoration(
                  labelText: "収集方式",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: CollectSource.dummy,
                    child: Text("ダミー（テスト用）"),
                  ),
                  DropdownMenuItem(
                    value: CollectSource.rakuten,
                    child: Text("楽天（擬似データ）"),
                  ),
                  DropdownMenuItem(
                    value: CollectSource.manual,
                    child: Text("手動"),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    source = v!;
                  });
                },
              ),
            ],
          ),
        ),

        /// 🔘 ボタン
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: search,
              child: const Text("収集"),
            ),
          ),
        ),

        /// ⏳ ローディング
        if (loading) const Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),

        /// 📋 リスト（ここが重要）
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (_, i) {
              final r = results[i];

              return ListTile(
                title: Text(r["item"] ?? ""),
                subtitle: Text(r["store"] ?? ""),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => addToLottery(r),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
}


DateTime? parseDateTime(String date, [String? time]) {
  if (date.isEmpty) return null;

  try {
    final cleaned = date.trim().replaceAll("/", "-").split(" ")[0];
    final parts = cleaned.split("-");

    if (parts.length != 3) return null;

    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    // ★ここが今回の本体
    int hour = 0;
    int minute = 0;

    if (time != null && time.contains(":")) {
      final t = time.split(":");

      hour = int.tryParse(t[0]) ?? 0;
      minute = int.tryParse(t[1]) ?? 0;
    }

    // ★未入力でも明示的に 00:00 に固定
    return DateTime(year, month, day, hour, minute);
  } catch (_) {
    return null;
  }
}


DateTime? getEnd(Lottery l) {
  return parseDateTime(l.endDate, l.endTime);
}

DateTime? getStart(Lottery l) {
  return parseDateTime(l.startDate, l.startTime);
}

DateTime? getAnnounce(Lottery l) {
  return parseDateTime(l.announceDate, l.announceTime);
}