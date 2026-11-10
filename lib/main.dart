import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Border, BorderStyle;
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
  String? followUpLabel;
  String? followUpTrigger;
  Q({
    required this.id,
    required this.text,
    this.type = 'text',
    this.section = 'q',
    List<String>? options,
    this.required = false,
    this.followUpLabel,
    this.followUpTrigger,
  }) : options = options ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'type': type,
        'section': section,
        'options': options,
        'required': required,
        'followUpLabel': followUpLabel,
        'followUpTrigger': followUpTrigger,
      };

  factory Q.fromJson(Map m) => Q(
        id: m['id'],
        text: m['text'],
        type: m['type'] ?? 'text',
        section: m['section'] ?? 'q',
        options: List<String>.from(m['options'] ?? []),
        required: m['required'] ?? false,
        followUpLabel: m['followUpLabel'],
        followUpTrigger: m['followUpTrigger'],
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
      qs = [];
      people = [];
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
        Q(id: 'q8', text: 'هل سجلت في دورات مكافحة العدوى؟', type: 'single', options: ['نعم', 'لا'], followUpTrigger: 'نعم', followUpLabel: 'اذكر اسم الدورة أو الجهة إن أمكن'),
        Q(id: 'q9', text: 'هل تعرف اليوم العالمي لنظافة اليدين؟', type: 'single', options: ['نعم', 'لا'], followUpTrigger: 'نعم', followUpLabel: 'اذكر التاريخ أو ما تعرفه عنه'),
        Q(id: 'q10', text: 'أدرك تماماً أن الاستمرار في ارتداء القفازات لأكثر من ساعتين بسبب تعرّق ورطوبة داخلية تحفز نمو البكتيريا.', type: 'single', options: ['موافق', 'محايد', 'غير موافق']),
        Q(id: 'q11', text: 'أعتقد أن السطح الخارجي للقفاز يصبح ناقلاً للملوثات والبكتيريا إذا لم يتم تغييره بشكل دوري أثناء العمل.', type: 'single', options: ['موافق', 'محايد', 'غير موافق']),
        Q(id: 'q12', text: 'أحياناً أقوم بلمس الأدوات الشخصية (الهاتف المحمول أو الأقلام) وأنا أرتدي نفس القفاز المخبري.', type: 'single', options: ['موافق', 'محايد', 'غير موافق']),
        Q(id: 'q13', text: 'أقوم بتغيير القفازات فوراً عند الانتقال من التعامل مع عينة ملوثة عالية الخطورة إلى عمل آخر نظيف.', type: 'single', options: ['موافق', 'محايد', 'غير موافق']),
        Q(id: 'q14', text: 'أعتقد أن تشكل الثقوب المجهرية في القفازات يزداد كلما طالت مدة ارتدائها والإجهاد الميكانيكي عليها.', type: 'single', options: ['موافق', 'محايد', 'غير موافق']),
        Q(id: 'q15', text: 'يمنحني ارتداء القفازات لفترة طويلة شعوراً زائفاً بالأمان يجعلني أحياناً أغفل عن تطهير يدي بالمعقم الكحولي فور نزعها.', type: 'single', options: ['موافق', 'محايد', 'غير موافق']),
      ];

  /// استيراد الأسئلة والإجابات من ملف Excel الموحد.
  int importExcelBytes(List<int> bytes) {
    final ex = Excel.decodeBytes(bytes);
    final questionSheet = ex['الأسئلة'] ?? ex['Questions'];
    final answerSheet = ex['الإجابات'] ?? ex['Responses'] ?? ex['البيانات'];
    if (questionSheet != null) {
      final rows = questionSheet.rows;
      if (rows.isNotEmpty) {
        final header = _rowTexts(rows.first);
        final index = <String, int>{};
        for (var i = 0; i < header.length; i++) index[header[i].trim()] = i;
        final next = <Q>[];
        for (final row in rows.skip(1)) {
          final id = _excelText(_cellAt(row, index['id'] ?? 0));
          final text = _excelText(_cellAt(row, index['text'] ?? 1));
          if (id.isEmpty || text.isEmpty) continue;
          final options = _excelText(_cellAt(row, index['options'] ?? 4))
              .split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          next.add(Q(
            id: id,
            text: text,
            type: _excelText(_cellAt(row, index['type'] ?? 2)).isEmpty ? 'text' : _excelText(_cellAt(row, index['type'] ?? 2)),
            section: _excelText(_cellAt(row, index['section'] ?? 3)).isEmpty ? 'q' : _excelText(_cellAt(row, index['section'] ?? 3)),
            options: options,
            required: _excelText(_cellAt(row, index['required'] ?? 5)).toLowerCase() == 'true' || _excelText(_cellAt(row, index['required'] ?? 5)) == 'نعم',
            followUpLabel: _excelText(_cellAt(row, index['followUpLabel'] ?? 6)).trim().isEmpty ? null : _excelText(_cellAt(row, index['followUpLabel'] ?? 6)).trim(),
            followUpTrigger: _excelText(_cellAt(row, index['followUpTrigger'] ?? 7)).trim().isEmpty ? null : _excelText(_cellAt(row, index['followUpTrigger'] ?? 7)).trim(),
          ));
        }
        if (next.isNotEmpty) qs = next;
      }
    }
    var imported = 0;
    if (answerSheet != null) {
      final rows = answerSheet.rows;
      if (rows.length >= 2) {
        final ids = _rowTexts(rows.first);
        for (final row in rows.skip(1)) {
          final id = _excelText(_cellAt(row, ids.indexOf('id')));
          if (id.isEmpty || id == 'id') continue;
          final createdText = _excelText(_cellAt(row, ids.indexOf('created')));
          final answers = <String, String>{};
          for (var i = 0; i < ids.length; i++) {
            if (i < 2 || ids[i].isEmpty) continue;
            answers[ids[i]] = _excelText(_cellAt(row, i));
          }
          final person = Person(id: id, created: DateTime.tryParse(createdText) ?? DateTime.now(), answers: answers);
          final existing = people.indexWhere((x) => x.id == id);
          if (existing >= 0) people[existing] = person; else people.add(person);
          imported++;
        }
      }
    }
    save();
    return imported;
  }

  List<String> _rowTexts(List<Data?> row) => row.map(_excelText).toList();
  Data? _cellAt(List<Data?> row, int index) => index >= 0 && index < row.length ? row[index] : null;
  String _excelText(Data? cell) {
    final v = cell?.value;
    if (v == null) return '';
    if (v is TextCellValue) return v.value.toString();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toString();
    if (v is BoolCellValue) return v.value.toString();
    if (v is DateTimeCellValue) return v.asDateTimeLocal().toIso8601String();
    return v.toString();
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
  final head = CellStyle(bold: true, fontColorHex: ExcelColor.fromHexString('#FFFFFF'), backgroundColorHex: ExcelColor.fromHexString('#0E5A68'), horizontalAlign: HorizontalAlign.Center, verticalAlign: VerticalAlign.Center, textWrapping: TextWrapping.WrapText, leftBorder: thin(), rightBorder: thin(), topBorder: thin(), bottomBorder: thin());
  final body = CellStyle(verticalAlign: VerticalAlign.Top, textWrapping: TextWrapping.WrapText, leftBorder: thin(), rightBorder: thin(), topBorder: thin(), bottomBorder: thin());
  final alt = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#E8F4F4'), verticalAlign: VerticalAlign.Top, textWrapping: TextWrapping.WrapText, leftBorder: thin(), rightBorder: thin(), topBorder: thin(), bottomBorder: thin());
  final label = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D8ECEE'), textWrapping: TextWrapping.WrapText, leftBorder: thin(), rightBorder: thin(), topBorder: thin(), bottomBorder: thin());

  final qSheet = ex['الأسئلة'];
  qSheet.isRTL = true;
  final qHeaders = ['id', 'text', 'type', 'section', 'options', 'required', 'followUpLabel', 'followUpTrigger'];
  for (var i = 0; i < qHeaders.length; i++) put(qSheet, i, 0, TextCellValue(qHeaders[i]), head);
  for (var r = 0; r < qs.length; r++) {
    final q = qs[r];
    final values = [q.id, q.text, q.type, q.section, q.options.join('\n'), q.required ? 'true' : 'false', q.followUpLabel ?? '', q.followUpTrigger ?? ''];
    for (var c = 0; c < values.length; c++) put(qSheet, c, r + 1, TextCellValue(values[c]), r.isEven ? body : alt);
  }
  final widths = [18, 55, 16, 16, 42, 12, 40, 20];
  for (var i = 0; i < widths.length; i++) qSheet.setColumnWidth(i, widths[i].toDouble());

  final s1 = ex['الإجابات'];
  s1.isRTL = true;
  final heads = ['id', 'created', ...qs.expand((q) => [q.id, if (q.followUpTrigger != null) '${q.id}__followup'])];
  final labels = ['معرّف السجل', 'تاريخ الإدخال', ...qs.expand((q) => [q.text, if (q.followUpTrigger != null) '${q.followUpLabel ?? 'إجابة إضافية'} (${q.text})'])];
  for (var i = 0; i < heads.length; i++) {
    put(s1, i, 0, TextCellValue(heads[i]), head);
    put(s1, i, 1, TextCellValue(labels[i]), label);
    s1.setColumnWidth(i, i < 2 ? 22 : 30);
  }
  for (var r = 0; r < list.length; r++) {
    final person = list[r];
    final st = r.isEven ? body : alt;
    put(s1, 0, r + 2, TextCellValue(person.id), st);
    put(s1, 1, r + 2, TextCellValue(person.created.toIso8601String()), st);
    var c = 2;
    for (final q in qs) {
      put(s1, c++, r + 2, TextCellValue(disp(person.answers[q.id] ?? '')), st);
      if (q.followUpTrigger != null) put(s1, c++, r + 2, TextCellValue(person.answers['${q.id}__followup'] ?? ''), st);
    }
  }
  final s2 = ex['تقارير فردية']; s2.isRTL = true; s2.setColumnWidth(0, 38); s2.setColumnWidth(1, 48);
  var row = 0;
  for (var i = 0; i < list.length; i++) { final person = list[i]; put(s2, 0, row, TextCellValue('تقرير ${i + 1}: ${personName(person)}'), head); put(s2, 1, row, TextCellValue(fmt(person.created)), head); row++; for (final q in qs) { put(s2, 0, row, TextCellValue(q.text), label); put(s2, 1, row, TextCellValue(disp(person.answers[q.id] ?? '')), body); row++; if (q.followUpTrigger != null) { put(s2, 0, row, TextCellValue(q.followUpLabel ?? 'إجابة إضافية'), label); put(s2, 1, row, TextCellValue(disp(person.answers['${q.id}__followup'] ?? '')), body); row++; } } row++; }
  final s3 = ex['ملخص']; s3.isRTL = true; s3.setColumnWidth(0, 40); s3.setColumnWidth(1, 14); s3.setColumnWidth(2, 14); put(s3, 0, 0, TextCellValue('عدد الأشخاص'), label); put(s3, 1, 0, IntCellValue(list.length), body);
  var r3 = 2;
  for (final q in qs) { final isChoice = q.type == 'single' || q.type == 'multi' || q.type == 'rating'; if (!isChoice && q.type != 'number') continue; put(s3, 0, r3, TextCellValue(q.text), head); put(s3, 1, r3, TextCellValue(q.type == 'number' ? 'المتوسط' : 'العدد'), head); put(s3, 2, r3, TextCellValue(q.type == 'number' ? '' : 'النسبة'), head); r3++; final opts = q.type == 'rating' ? ['1', '2', '3', '4', '5'] : q.options; for (final o in opts) { final count = list.where((p) { final a = p.answers[q.id] ?? ''; return q.type == 'multi' ? a.split(sep).map((e) => e.trim()).contains(o) : a == o; }).length; put(s3, 0, r3, TextCellValue(o), body); put(s3, 1, r3, IntCellValue(count), body); put(s3, 2, r3, TextCellValue(list.isEmpty ? '0%' : '${(count * 100 / list.length).round()}%'), body); r3++; } r3++; }
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
        title: 'استبيان نور',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF167D8D),
          scaffoldBackgroundColor: const Color(0xFFF4F8FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0E5A68),
            foregroundColor: Colors.white,
            centerTitle: false,
            elevation: 0,
          ),
          cardTheme: CardTheme(
            color: Colors.white,
            elevation: 2,
            margin: EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: Color(0xFFD7E5E8))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: Color(0xFF167D8D), width: 2)),
          ),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (store.sp.getBool('welcome_shown') != true && mounted) {
        await showDialog<void>(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(children: [Icon(Icons.auto_awesome, color: Color(0xFF167D8D)), SizedBox(width: 8), Text('أهلاً بكم في نور')]),
          content: const Text('أهلاً بكم في تطبيق نور لعمل استبيان سريع\n\nابدأ باستيراد قالب الأسئلة Excel أو أنشئ أسئلتك من داخل التطبيق.', style: TextStyle(height: 1.7)),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('ابدأ الآن'))],
        ));
        await store.sp.setBool('welcome_shown', true);
      }
    });
  }

  Future<void> menu(String v) async {
    if (v == 'excel') {
      if (store.people.isEmpty) return snack(context, 'لا توجد بيانات للتصدير');
      await shareExcel(store.people, 'survey_${stamp()}.xlsx');
    } else if (v == 'backup') {
      await shareExcel(store.people, 'nor_labs_backup_${stamp()}.xlsx');
    } else if (v == 'import') {
      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
      if (r == null) return;
      try {
        final f = r.files.single;
        final bytes = f.bytes ?? (f.path == null ? null : await File(f.path!).readAsBytes());
        if (bytes == null || bytes.isEmpty) throw const FormatException();
        final n = store.importExcelBytes(bytes);
        if (mounted) snack(context, 'تم استيراد الملف Excel بنجاح ($n سجل)');
      } catch (_) {
        if (mounted) snack(context, 'تعذر الاستيراد. اختر قالب Excel صادرًا من التطبيق أو قالب الأسئلة.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (c, _) => Scaffold(
          appBar: AppBar(
            title: Text(tab == 0
                ? 'استبيان نور - الأشخاص (${store.people.length})'
                : tab == 1 ? 'إدارة الأسئلة' : 'الرسومات البيانية'),
            actions: [
              PopupMenuButton<String>(
                onSelected: menu,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'excel', child: Text('تصدير Excel شامل')),
                  PopupMenuItem(
                      value: 'backup', child: Text('تصدير Excel قابل للاستيراد')),
                  PopupMenuItem(
                      value: 'import', child: Text('استيراد Excel')),
                ],
              ),
            ],
          ),
          body: tab == 0
              ? const PeopleTab()
              : tab == 1 ? const QuestionsTab() : const ChartsTab(),
          floatingActionButton: tab == 2 ? null : FloatingActionButton.extended(
            backgroundColor: const Color(0xFF0E5A68),
            foregroundColor: Colors.white,
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
              NavigationDestination(
                  icon: Icon(Icons.bar_chart_rounded), label: 'الرسومات'),
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
                  await shareExcel([p], 'person_${p.id}.xlsx');
                } else if (v == 'del') {
                  if (await confirm(c, 'حذف بيانات ${personName(p)}؟')) {
                    store.people.remove(p);
                    store.save();
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'json', child: Text('مشاركة Excel')),
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

  void setAnswer(String key, String value) {
    setState(() => ans[key] = value);
    if (widget.person != null) {
      widget.person!.answers = ans;
      store.save();
    }
  }

  Widget field(Q q) {
    switch (q.type) {
      case 'single':
        final selected = ans[q.id];
        final followKey = '${q.id}__followup';
        return Column(children: [
          for (final o in q.options)
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF167D8D),
              title: Text(o),
              value: o,
              groupValue: selected,
              onChanged: (v) => setAnswer(q.id, v!),
            ),
          if (q.followUpTrigger != null && selected == q.followUpTrigger)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: TextField(
                controller: ctrl(Q(id: followKey, text: q.followUpLabel ?? 'تفاصيل إضافية')),
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(labelText: q.followUpLabel ?? 'تفاصيل إضافية', prefixIcon: const Icon(Icons.edit_note)),
                onChanged: (v) => setAnswer(followKey, v),
              ),
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
      if (q.followUpTrigger != null) {
        final key = '${q.id}__followup';
        ans[key] = ctrls[key]?.text.trim() ?? ans[key] ?? '';
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

// ───────────────────────── الرسومات البيانية ─────────────────────────
class ChartsTab extends StatefulWidget {
  const ChartsTab({super.key});
  @override
  State<ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends State<ChartsTab> {
  String style = 'bars';
  String first = '';
  String second = '';

  List<Q> get questions => store.qs.where((q) => q.type == 'single' || q.type == 'multi' || q.type == 'rating').toList();

  @override
  void initState() {
    super.initState();
    final savedStyle = store.sp.getString('chart_style');
    final savedFirst = store.sp.getString('chart_first');
    final savedSecond = store.sp.getString('chart_second');
    if (savedStyle != null) style = savedStyle;
    if (savedFirst != null) first = savedFirst;
    if (savedSecond != null) second = savedSecond;
  }

  Future<void> saveView() async {
    await store.sp.setString('chart_style', style);
    await store.sp.setString('chart_first', first);
    await store.sp.setString('chart_second', second);
    if (mounted) snack(context, 'تم حفظ شكل الرسومات والمقارنة على الجهاز');
  }

  @override
  Widget build(BuildContext context) {
    if (store.people.isEmpty) {
      return const Center(child: Text('أضف إجابات أولاً لعرض الرسومات البيانية.', textAlign: TextAlign.center));
    }
    final validIds = questions.map((q) => q.id).toSet();
    if (!validIds.contains(first)) first = questions.isNotEmpty ? questions.first.id : '';
    if (!validIds.contains(second)) second = questions.length > 1 ? questions[1].id : '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: [
        Card(color: const Color(0xFFE4F3F3), child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFF0E5A68), child: Icon(Icons.insights, color: Colors.white)), title: const Text('ملخص الاستبيان', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('إجمالي السجلات: ${store.people.length} · تحكم في شكل العرض والمقارنة'))),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('إعدادات العرض', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: style, decoration: const InputDecoration(labelText: 'شكل الرسم'), items: const [DropdownMenuItem(value: 'bars', child: Text('أشرطة ومؤشرات')), DropdownMenuItem(value: 'percent', child: Text('نسب مئوية')), DropdownMenuItem(value: 'numbers', child: Text('بطاقات أرقام'))], onChanged: (v) => setState(() => style = v ?? 'bars')),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: saveView, icon: const Icon(Icons.bookmark_outline), label: const Text('حفظ الشكل محليًا')),
        ]))),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('مقارنة يدوية بين سؤالين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: first.isEmpty ? null : first, decoration: const InputDecoration(labelText: 'السؤال الأول'), items: questions.map((q) => DropdownMenuItem(value: q.id, child: Text(q.text, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => first = v ?? '')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: second.isEmpty ? null : second, decoration: const InputDecoration(labelText: 'السؤال الثاني'), items: questions.map((q) => DropdownMenuItem(value: q.id, child: Text(q.text, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => second = v ?? '')),
          if (first.isNotEmpty && second.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ComparisonCard(first: questions.firstWhere((q) => q.id == first), second: questions.firstWhere((q) => q.id == second)),
          ],
        ]))),
        for (final q in questions) _ChartCard(q: q, style: style),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Q q;
  final String style;
  const _ChartCard({required this.q, required this.style});

  Map<String, int> counts() {
    final options = q.type == 'rating' ? ['1', '2', '3', '4', '5'] : q.options;
    final result = <String, int>{for (final o in options) o: 0};
    for (final p in store.people) {
      final a = p.answers[q.id] ?? '';
      if (q.type == 'multi') {
        for (final value in a.split(sep).map((e) => e.trim())) if (result.containsKey(value)) result[value] = result[value]! + 1;
      } else if (result.containsKey(a)) result[a] = result[a]! + 1;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final data = counts();
    final total = store.people.length;
    final maxCount = data.values.fold<int>(0, (m, v) => v > m ? v : m);
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(q.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 14),
      for (final entry in data.entries) Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(entry.key)), Text(style == 'percent' ? '${total == 0 ? 0 : (entry.value * 100 / total).round()}%' : '${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold))]),
        if (style == 'bars') ...[const SizedBox(height: 5), LinearProgressIndicator(value: maxCount == 0 ? 0 : entry.value / maxCount, minHeight: 9, borderRadius: BorderRadius.circular(10), backgroundColor: const Color(0xFFE5EEF0), color: const Color(0xFF20A39E))],
        if (style == 'percent') ...[const SizedBox(height: 5), LinearProgressIndicator(value: total == 0 ? 0 : entry.value / total, minHeight: 9, borderRadius: BorderRadius.circular(10), backgroundColor: const Color(0xFFE5EEF0), color: const Color(0xFF167D8D))],
      ])),
    ])));
  }
}

class _ComparisonCard extends StatelessWidget {
  final Q first;
  final Q second;
  const _ComparisonCard({required this.first, required this.second});
  @override
  Widget build(BuildContext context) => Column(children: [
    _ComparisonQuestion(q: first),
    const Divider(height: 24),
    _ComparisonQuestion(q: second),
  ]);
}

class _ComparisonQuestion extends StatelessWidget {
  final Q q;
  const _ComparisonQuestion({required this.q});
  @override
  Widget build(BuildContext context) {
    final options = q.type == 'rating' ? ['1', '2', '3', '4', '5'] : q.options;
    final total = store.people.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final option in options) Builder(builder: (_) {
        final count = store.people.where((p) { final a = p.answers[q.id] ?? ''; return q.type == 'multi' ? a.split(sep).map((e) => e.trim()).contains(option) : a == option; }).length;
        return Chip(avatar: CircleAvatar(child: Text('$count')), label: Text('$option · ${total == 0 ? 0 : (count * 100 / total).round()}%'));
      })]),
    ]);
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
  late TextEditingController text, opts, followLabel, followTrigger;
  late String type, section;
  late bool required;

  @override
  void initState() {
    super.initState();
    final q = widget.q;
    text = TextEditingController(text: q?.text ?? '');
    opts = TextEditingController(text: q?.options.join('\n') ?? '');
    followLabel = TextEditingController(text: q?.followUpLabel ?? '');
    followTrigger = TextEditingController(text: q?.followUpTrigger ?? 'نعم');
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
        followUpLabel: choice && type == 'single' && followLabel.text.trim().isNotEmpty ? followLabel.text.trim() : null,
        followUpTrigger: choice && type == 'single' && followLabel.text.trim().isNotEmpty ? followTrigger.text.trim() : null,
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
          if (type == 'single') ...[
            const SizedBox(height: 12),
            TextField(controller: followLabel, decoration: const InputDecoration(labelText: 'سؤال نصي يظهر بعد اختيار نعم (اختياري)')),
            const SizedBox(height: 8),
            TextField(controller: followTrigger, decoration: const InputDecoration(labelText: 'الإجابة التي تُظهر السؤال الإضافي', hintText: 'مثال: نعم')),
          ],
        ],
      ]),
    );
  }
}
