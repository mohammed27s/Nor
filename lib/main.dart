import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ───────────────────────── النماذج ─────────────────────────

const typeNames = {
  'text': 'نص',
  'number': 'رقم',
  'single': 'اختيار واحد',
  'multi': 'اختيار متعدد',
  'date': 'تاريخ',
  'rating': 'تقييم (1-5)',
};
const sectionNames = {'p': 'بيانات الشخص', 'q': 'الأسئلة'};
const sep = '،';

class Q {
  String id, text, type, section;
  List<String> options;
  bool required;
  Q({
    required this.id,
    required this.text,
    this.type = 'text',
    this.section = 'q',
    List<String>? options,
    this.required = false,
  }) : options = options ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'type': type,
        'section': section,
        'options': options,
        'required': required,
      };

  factory Q.fromJson(Map m) => Q(
        id: m['id'],
        text: m['text'],
        type: m['type'] ?? 'text',
        section: m['section'] ?? 'q',
        options: List<String>.from(m['options'] ?? []),
        required: m['required'] ?? false,
      );
}

class Person {
  String id;
  DateTime created;
  Map<String, String> answers;
  Person({required this.id, required this.created, required this.answers});

  Map<String, dynamic> toJson() =>
      {'id': id, 'created': created.toIso8601String(), 'answers': answers};

  factory Person.fromJson(Map m) => Person(
        id: m['id'],
        created: DateTime.tryParse(m['created'] ?? '') ?? DateTime.now(),
        answers: Map<String, String>.from(m['answers'] ?? {}),
      );
}

String newId() => DateTime.now().microsecondsSinceEpoch.toString();
String two(int n) => n.toString().padLeft(2, '0');
String fmt(DateTime d) =>
    '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
String disp(String a) => a.replaceAll(sep, '$sep ');

// ───────────────────────── التخزين ─────────────────────────

class Store extends ChangeNotifier {
  List<Q> qs = [];
  List<Person> people = [];
  late SharedPreferences sp;

  Future<void> load() async {
    sp = await SharedPreferences.getInstance();
    final s = sp.getString('data');
    if (s == null) {
      qs = defaultQs();
    } else {
      final m = jsonDecode(s);
      qs = (m['q'] as List).map((e) => Q.fromJson(e)).toList();
      people = (m['p'] as List).map((e) => Person.fromJson(e)).toList();
    }
  }

  void save() {
    sp.setString('data', jsonEncode(toMap()));
    notifyListeners();
  }

  Map<String, dynamic> toMap() => {
        'q': qs.map((e) => e.toJson()).toList(),
        'p': people.map((e) => e.toJson()).toList(),
      };

  List<Q> defaultQs() => [
        Q(id: 'p1', text: 'الجنس', section: 'p', type: 'single', options: ['أنثى', 'ذكر']),
        Q(id: 'p2', text: 'المسمى الوظيفي', section: 'p', type: 'single', options: ['أخصائي مختبرات طبية', 'فني مختبرات', 'فاحص / باحث أحياء دقيقة', 'أخرى']),
        Q(id: 'p3', text: 'سنوات الخبرة في العمل المخبري', section: 'p', type: 'single', options: ['أقل من سنتين', 'من 2 إلى 5 سنوات', 'أكثر من 5 سنوات إلى 10 سنوات', 'أكثر من 10 سنوات']),
        Q(id: 'q4', text: 'كم يبلغ متوسط عدد الساعات التي ترتدي فيها زوجاً واحداً من القفازات دون نزعها أثناء وردية العمل؟', type: 'single', options: ['أقل من 30 دقيقة', 'من 30 إلى أقل من ساعة', 'من ساعة إلى ساعتين', 'أكثر من ساعتين متواصلتين']),
        Q(id: 'q5', text: 'في حال كثرة ضغط العمل وانشغالك بالعينات، إلى أي مدى تضطر للاستمرار في ارتداء نفس القفازات لفترات طويلة؟', type: 'single', options: ['دائماً', 'غالباً', 'نادراً', 'أبداً']),
        Q(id: 'q6', text: 'هل تفرض مؤسستكم سياسة واضحة تحدد الحد الأقصى لزمن ارتداء زوج القفازات الواحد؟', type: 'single', options: ['نعم، توجد سياسة صارمة ومعلنة', 'نعم، ولكنها غير مطبقة بجدية', 'لا توجد سياسة واضحة بهذا الشأن', 'لا أعلم']),
        Q(id: 'q7', text: 'من خلال خبرتك، ما هي أبرز الأسباب التي تجعل الممارسين يتجنبون تغيير القفازات بشكل متكرر؟', type: 'multi', options: ['ضغط العمل الشديد والسرعة المطلوبة في إنجاز العينات', 'الرغبة في توفير واستهلاك مواد المختبر', 'الكسل أو عدم الإدراك الكافي بمخاطر التلوث المتقاطع', 'صعوبة أو كثرة إزالة وارتداء القفازات']),
        Q(id: 'q8', text: 'هل سجلت في دورات مكافحة العدوى؟', type: 'single', options: ['نعم', 'لا']),
        Q(id: 'q9', text: 'هل تعرف اليوم العالمي لنظافة اليدين؟', type: 'single', options: ['نعم، متى؟', 'لا']),
        Q(id: 'q10', text: 'أدرك تماماً أن الاستمرار في ارتداء القفازات لأكثر من ساعتين بسبب تعرّق ورطوبة داخلية تحفز نمو البكتيريا.', type: 'single', options: ['موافق', 'محايد', 'غير موافق']),
        Q(id: 'q11', text: 'أعتقد أن السطح الخارجي للقفاز يصبح ناقلاً للملوثات والبكتيريا إذا لم يتم تغييره بشكل دوري أثناء العمل.', type: 'single', options: ['موافق', 'محايد', 'غير موافق']),
        Q(id: 'q12', text: 'أحياناً أقوم بلمس الأدوات الشخصية (الهاتف المحمول أو الأقلام) وأنا أرتدي نفس القفاز المخبري.', type: 'single', options: ['موافق', 'محايد', 'غير موافق']),
        Q(id: 'q13', text: 'أقوم بتغيير القفازات فوراً عند الانتقال من التعامل مع عينة ملوثة عالية الخطورة إلى عمل آخر نظيف.', type: 'single', options: ['موافق', 'محايد', 'غير موافق']),
        Q(id: 'q14', text: 'أعتقد أن تشكل الثقوب المجهرية في القفازات يزداد كلما طالت مدة ارتدائها والإجهاد الميكانيكي عليها.', type: 'single', options: ['موافق', 'محايد', 'غير موافق']),
        Q(id: 'q15', text: 'يمنحني ارتداء القفازات لفترة طويلة شعوراً زائفاً بالأمان يجعلني أحياناً أغفل عن تطهير يدي بالمعقم الكحولي فور نزعها.', type: 'single', options: ['موافق', 'محايد', 'غير موافق']),
      ];

  /// دمج بيانات مستوردة (أسئلة + أشخاص). يرجع عدد الأشخاص.
  int importJson(String s) {
    final m = jsonDecode(s) as Map;
    for (final e in (m['q'] as List? ?? [])) {
      final q = Q.fromJson(e);
      if (!qs.any((x) => x.id == q.id)) qs.add(q);
    }
    var n = 0;
    for (final e in (m['p'] as List? ?? [])) {
      final p = Person.fromJson(e);
      final i = people.indexWhere((x) => x.id == p.id);
      if (i >= 0) {
        people[i] = p;
      } else {
        people.add(p);
      }
      n++;
    }
    save();
    return n;
  }
}

final store = Store();

String personName(Person p) {
  for (final q in store.qs.where((q) => q.section == 'p')) {
    final a = (p.answers[q.id] ?? '').trim();
    if (a.isNotEmpty) return a;
  }
  return 'بدون اسم';
}

int answeredCount(Person p) =>
    store.qs.where((q) => (p.answers[q.id] ?? '').trim().isNotEmpty).length;

// ───────────────────────── Excel ─────────────────────────

void put(Sheet s, int c, int r, CellValue v, [CellStyle? st]) {
  final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
  cell.value = v;
  if (st != null) cell.cellStyle = st;
}

CellValue cv(Q q, String a) {
  if (q.type == 'number') {
    final d = double.tryParse(a);
    if (d != null && !a.startsWith('0')) return DoubleCellValue(d);
  }
  return TextCellValue(disp(a));
}

Border thin() => Border(borderStyle: BorderStyle.Thin);

List<int> buildExcel(List<Person> list) {
  final ex = Excel.createExcel();
  ex.rename('Sheet1', 'الإجابات');
  final qs = store.qs;

  final head = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#1F4E78'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: thin(),
    rightBorder: thin(),
    topBorder: thin(),
    bottomBorder: thin(),
  );
  final body = CellStyle(
    verticalAlign: VerticalAlign.Top,
    textWrapping: TextWrapping.WrapText,
    leftBorder: thin(),
    rightBorder: thin(),
    topBorder: thin(),
    bottomBorder: thin(),
  );
  final alt = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#EAF1F8'),
    verticalAlign: VerticalAlign.Top,
    textWrapping: TextWrapping.WrapText,
    leftBorder: thin(),
    rightBorder: thin(),
    topBorder: thin(),
    bottomBorder: thin(),
  );
  final title = CellStyle(
    bold: true,
    fontSize: 13,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#2E75B6'),
  );
  final label = CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#D9E2F3'),
    textWrapping: TextWrapping.WrapText,
    leftBorder: thin(),
    rightBorder: thin(),
    topBorder: thin(),
    bottomBorder: thin(),
  );

  // ── الورقة 1: جدول كل الإجابات
  final s1 = ex['الإجابات'];
  s1.isRTL = true;
  final heads = ['#', 'تاريخ الإدخال', ...qs.map((q) => q.text)];
  for (var i = 0; i < heads.length; i++) {
    put(s1, i, 0, TextCellValue(heads[i]), head);
    s1.setColumnWidth(i, i == 0 ? 5 : (i == 1 ? 19 : 26));
  }
  for (var r = 0; r < list.length; r++) {
    final p = list[r];
    final st = r.isEven ? body : alt;
    put(s1, 0, r + 1, IntCellValue(r + 1), st);
    put(s1, 1, r + 1, TextCellValue(fmt(p.created)), st);
    for (var c = 0; c < qs.length; c++) {
      final a = p.answers[qs[c].id] ?? '';
      put(s1, c + 2, r + 1, a.isEmpty ? TextCellValue('') : cv(qs[c], a), st);
    }
  }

  // ── الورقة 2: تقرير لكل شخص
  final s2 = ex['تقارير فردية'];
  s2.isRTL = true;
  s2.setColumnWidth(0, 38);
  s2.setColumnWidth(1, 48);
  var row = 0;
  for (var i = 0; i < list.length; i++) {
    final p = list[i];
    put(s2, 0, row, TextCellValue('تقرير ${i + 1}: ${personName(p)}'), title);
    put(s2, 1, row, TextCellValue(fmt(p.created)), title);
    row++;
    for (final q in qs) {
      put(s2, 0, row, TextCellValue(q.text), label);
      put(s2, 1, row, TextCellValue(disp(p.answers[q.id] ?? '')), body);
      row++;
    }
    row++;
  }

  // ── الورقة 3: ملخص
  final s3 = ex['ملخص'];
  s3.isRTL = true;
  s3.setColumnWidth(0, 40);
  s3.setColumnWidth(1, 14);
  s3.setColumnWidth(2, 14);
  put(s3, 0, 0, TextCellValue('عدد الأشخاص'), label);
  put(s3, 1, 0, IntCellValue(list.length), body);
  var r3 = 2;
  for (final q in qs) {
    final isChoice = q.type == 'single' || q.type == 'multi' || q.type == 'rating';
    if (!isChoice && q.type != 'number') continue;
    put(s3, 0, r3, TextCellValue(q.text), head);
    put(s3, 1, r3, TextCellValue(q.type == 'number' ? 'المتوسط' : 'العدد'), head);
    put(s3, 2, r3, TextCellValue(q.type == 'number' ? '' : 'النسبة'), head);
    r3++;
    if (q.type == 'number') {
      final nums = list
          .map((p) => double.tryParse(p.answers[q.id] ?? ''))
          .whereType<double>()
          .toList();
      final avg =
          nums.isEmpty ? 0.0 : nums.reduce((a, b) => a + b) / nums.length;
      put(s3, 0, r3, TextCellValue('المتوسط (${nums.length} إجابة)'), body);
      put(s3, 1, r3, DoubleCellValue(double.parse(avg.toStringAsFixed(2))), body);
      put(s3, 2, r3, TextCellValue(''), body);
      r3 += 2;
      continue;
    }
    final opts = q.type == 'rating' ? ['1', '2', '3', '4', '5'] : q.options;
    for (final o in opts) {
      final c = list.where((p) {
        final a = p.answers[q.id] ?? '';
        return q.type == 'multi'
            ? a.split(sep).map((e) => e.trim()).contains(o)
            : a == o;
      }).length;
      final pct = list.isEmpty ? 0 : (c * 100 / list.length).round();
      put(s3, 0, r3, TextCellValue(o), body);
      put(s3, 1, r3, IntCellValue(c), body);
      put(s3, 2, r3, TextCellValue('$pct%'), body);
      r3++;
    }
    r3++;
  }

  return ex.save()!;
}

Future<void> shareBytes(String name, List<int> bytes, String text) async {
  final d = await getTemporaryDirectory();
  final f = File('${d.path}/$name');
  await f.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(f.path)], text: text);
}

String stamp() {
  final n = DateTime.now();
  return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}';
}

Future<void> shareExcel(List<Person> list, String name) =>
    shareBytes(name, buildExcel(list), 'تقرير الاستبيان');

Future<void> shareJson(List<Person> list, String name) {
  final m = {
    'q': store.qs.map((e) => e.toJson()).toList(),
    'p': list.map((e) => e.toJson()).toList(),
  };
  return shareBytes(name, utf8.encode(jsonEncode(m)), 'بيانات استبيان');
}

// ───────────────────────── مساعدات واجهة ─────────────────────────

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<bool> confirm(BuildContext c, String m) async =>
    await showDialog<bool>(
      context: c,
      builder: (_) => AlertDialog(
        content: Text(m),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('تأكيد')),
        ],
      ),
    ) ??
    false;

// ───────────────────────── التطبيق ─────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'استبيان مختبرات Nor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF1F4E78),
        ),
        builder: (c, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;

  Future<void> menu(String v) async {
    if (v == 'excel') {
      if (store.people.isEmpty) return snack(context, 'لا توجد بيانات للتصدير');
      await shareExcel(store.people, 'survey_${stamp()}.xlsx');
    } else if (v == 'backup') {
      await shareJson(store.people, 'survey_backup_${stamp()}.json');
    } else if (v == 'import') {
      final r = await FilePicker.platform.pickFiles(type: FileType.any);
      if (r == null || r.files.single.path == null) return;
      try {
        final s = await File(r.files.single.path!).readAsString();
        final n = store.importJson(s);
        if (mounted) snack(context, 'تم استيراد $n شخص');
      } catch (_) {
        if (mounted) snack(context, 'الملف غير صالح');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (c, _) => Scaffold(
          appBar: AppBar(
            title: Text(tab == 0
                ? 'استبيان مختبرات Nor - الأشخاص (${store.people.length})'
                : 'إدارة الأسئلة'),
            actions: [
              PopupMenuButton<String>(
                onSelected: menu,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'excel', child: Text('تصدير Excel شامل')),
                  PopupMenuItem(
                      value: 'backup', child: Text('مشاركة كل البيانات (ملف)')),
                  PopupMenuItem(
                      value: 'import', child: Text('استيراد بيانات')),
                ],
              ),
            ],
          ),
          body: tab == 0 ? const PeopleTab() : const QuestionsTab(),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: Text(tab == 0 ? 'شخص جديد' : 'سؤال جديد'),
            onPressed: () async {
              if (tab == 0) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PersonForm()));
              } else {
                final q = await Navigator.push<Q>(context,
                    MaterialPageRoute(builder: (_) => const QEditor()));
                if (q != null) {
                  store.qs.add(q);
                  store.save();
                }
              }
            },
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.people_alt_outlined), label: 'الأشخاص'),
              NavigationDestination(
                  icon: Icon(Icons.edit_note), label: 'الأسئلة'),
            ],
          ),
        ),
      );
}

// ───────────────────────── قائمة الأشخاص ─────────────────────────

class PeopleTab extends StatelessWidget {
  const PeopleTab({super.key});
  @override
  Widget build(BuildContext context) {
    if (store.people.isEmpty) {
      return const Center(child: Text('لا يوجد أشخاص بعد.\nاضغط "شخص جديد" للبدء.', textAlign: TextAlign.center));
    }
    final list = store.people.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
      itemCount: list.length,
      itemBuilder: (c, i) {
        final p = list[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(personName(p).characters.first)),
            title: Text(personName(p)),
            subtitle: Text(
                '${fmt(p.created)} · ${answeredCount(p)}/${store.qs.length} إجابة'),
            onTap: () => Navigator.push(c,
                MaterialPageRoute(builder: (_) => PersonForm(person: p))),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'xlsx') {
                  await shareExcel([p], 'report_${p.id}.xlsx');
                } else if (v == 'json') {
                  await shareJson([p], 'person_${p.id}.json');
                } else if (v == 'del') {
                  if (await confirm(c, 'حذف بيانات ${personName(p)}؟')) {
                    store.people.remove(p);
                    store.save();
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'json', child: Text('مشاركة لمستخدم آخر')),
                PopupMenuItem(value: 'xlsx', child: Text('تقرير Excel')),
                PopupMenuItem(value: 'del', child: Text('حذف')),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────── نموذج الإدخال ─────────────────────────

class PersonForm extends StatefulWidget {
  final Person? person;
  const PersonForm({super.key, this.person});
  @override
  State<PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends State<PersonForm> {
  late Map<String, String> ans;
  final ctrls = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    ans = Map.of(widget.person?.answers ?? {});
  }

  @override
  void dispose() {
    for (final c in ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController ctrl(Q q) =>
      ctrls.putIfAbsent(q.id, () => TextEditingController(text: ans[q.id] ?? ''));

  Widget field(Q q) {
    switch (q.type) {
      case 'single':
        return Column(children: [
          for (final o in q.options)
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(o),
              value: o,
              groupValue: ans[q.id],
              onChanged: (v) => setState(() => ans[q.id] = v!),
            ),
        ]);
      case 'multi':
        final sel = (ans[q.id] ?? '')
            .split(sep)
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();
        return Column(children: [
          for (final o in q.options)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(o),
              value: sel.contains(o),
              onChanged: (v) => setState(() {
                v == true ? sel.add(o) : sel.remove(o);
                ans[q.id] = q.options.where(sel.contains).join(sep);
              }),
            ),
        ]);
      case 'date':
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text(ans[q.id] ?? 'اختر التاريخ'),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (d != null) {
                setState(() => ans[q.id] = '${d.year}-${two(d.month)}-${two(d.day)}');
              }
            },
          ),
        );
      case 'rating':
        final cur = int.tryParse(ans[q.id] ?? '') ?? 0;
        return Row(children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              icon: Icon(i <= cur ? Icons.star : Icons.star_border,
                  color: Colors.amber, size: 34),
              onPressed: () => setState(() => ans[q.id] = '$i'),
            ),
        ]);
      default:
        return TextField(
          controller: ctrl(q),
          keyboardType:
              q.type == 'number' ? TextInputType.number : TextInputType.multiline,
          minLines: 1,
          maxLines: q.type == 'number' ? 1 : 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
    }
  }

  void save() {
    for (final q in store.qs) {
      if (q.type == 'text' || q.type == 'number') {
        ans[q.id] = ctrls[q.id]?.text.trim() ?? ans[q.id] ?? '';
      }
    }
    final missing = store.qs
        .where((q) => q.required && (ans[q.id] ?? '').trim().isEmpty)
        .map((q) => q.text)
        .toList();
    if (missing.isNotEmpty) {
      return snack(context, 'أكمل الحقول المطلوبة: ${missing.join('، ')}');
    }
    if (widget.person != null) {
      widget.person!.answers = ans;
    } else {
      store.people.add(Person(id: newId(), created: DateTime.now(), answers: ans));
    }
    store.save();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final sec in ['p', 'q']) {
      final items = store.qs.where((q) => q.section == sec).toList();
      if (items.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Text(sectionNames[sec]!,
            style: Theme.of(context).textTheme.titleLarge),
      ));
      for (final q in items) {
        children.add(Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${q.text}${q.required ? ' *' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                field(q),
              ],
            ),
          ),
        ));
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person == null ? 'شخص جديد' : 'تعديل البيانات'),
        actions: [
          TextButton.icon(
              onPressed: save,
              icon: const Icon(Icons.check),
              label: const Text('حفظ')),
        ],
      ),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 40), children: children),
    );
  }
}

// ───────────────────────── إدارة الأسئلة ─────────────────────────

class QuestionsTab extends StatelessWidget {
  const QuestionsTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
      buildDefaultDragHandles: false,
      itemCount: store.qs.length,
      onReorder: (o, n) {
        if (n > o) n--;
        store.qs.insert(n, store.qs.removeAt(o));
        store.save();
      },
      itemBuilder: (c, i) {
        final q = store.qs[i];
        return Card(
          key: ValueKey(q.id),
          child: ListTile(
            leading: ReorderableDragStartListener(
                index: i, child: const Icon(Icons.drag_handle)),
            title: Text(q.text),
            subtitle: Text(
                '${typeNames[q.type]} · ${sectionNames[q.section]}${q.required ? ' · مطلوب' : ''}'),
            onTap: () async {
              final r = await Navigator.push<Q>(c,
                  MaterialPageRoute(builder: (_) => QEditor(q: q)));
              if (r != null) {
                store.qs[i] = r;
                store.save();
              }
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(c, 'حذف السؤال "${q.text}"؟')) {
                  store.qs.removeAt(i);
                  store.save();
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class QEditor extends StatefulWidget {
  final Q? q;
  const QEditor({super.key, this.q});
  @override
  State<QEditor> createState() => _QEditorState();
}

class _QEditorState extends State<QEditor> {
  late TextEditingController text, opts;
  late String type, section;
  late bool required;

  @override
  void initState() {
    super.initState();
    final q = widget.q;
    text = TextEditingController(text: q?.text ?? '');
    opts = TextEditingController(text: q?.options.join('\n') ?? '');
    type = q?.type ?? 'text';
    section = q?.section ?? 'q';
    required = q?.required ?? false;
  }

  void save() {
    if (text.text.trim().isEmpty) return snack(context, 'اكتب نص السؤال');
    final o = opts.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final choice = type == 'single' || type == 'multi';
    if (choice && o.length < 2) return snack(context, 'أضف خيارين على الأقل');
    Navigator.pop(
      context,
      Q(
        id: widget.q?.id ?? newId(),
        text: text.text.trim(),
        type: type,
        section: section,
        options: choice ? o : [],
        required: required,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final choice = type == 'single' || type == 'multi';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.q == null ? 'سؤال جديد' : 'تعديل السؤال'),
        actions: [
          TextButton.icon(
              onPressed: save,
              icon: const Icon(Icons.check),
              label: const Text('حفظ')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: text,
          decoration: const InputDecoration(
              labelText: 'نص السؤال', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: type,
          decoration: const InputDecoration(
              labelText: 'نوع الإجابة', border: OutlineInputBorder()),
          items: typeNames.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => type = v!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: section,
          decoration: const InputDecoration(
              labelText: 'القسم', border: OutlineInputBorder()),
          items: sectionNames.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => section = v!),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('إجابة مطلوبة'),
          value: required,
          onChanged: (v) => setState(() => required = v),
        ),
        if (choice) ...[
          const SizedBox(height: 8),
          TextField(
            controller: opts,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'الخيارات (كل خيار في سطر)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ]),
    );
  }
}
