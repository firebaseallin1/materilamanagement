import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../constants/company_info.dart';
import '../../services/api_service.dart';
import '../../widgets/screen_header.dart';

const _eGreen   = Color(0xFF16A34A);
const _eOrange  = Color(0xFFEA580C);
const _ePrimary = Color(0xFF1B3A27);
const _eBg      = Color(0xFFF4F6F8);
const _eBorder  = Color(0xFFE5E7EB);

class ExpenseReportScreen extends StatelessWidget {
  const ExpenseReportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _eBg,
    body: Column(children: [
      ScreenHeader(title: 'Expense Report', subtitle: 'Expenses by category and branch'),
      const Expanded(child: _ExpenseReportView()),
    ]),
  );
}

class _ExpenseReportView extends StatefulWidget {
  const _ExpenseReportView();
  @override
  State<_ExpenseReportView> createState() => _ExpenseReportViewState();
}

class _ExpenseReportViewState extends State<_ExpenseReportView> {
  List _items = [], _branches = [];
  bool _loading = false;
  late DateTime _from, _to;
  String? _branchId;
  String? _filterCategory;
  String _search = '';
  final _searchCtrl = TextEditingController();

  static final _dateFmt = DateFormat('dd MMM yy');
  static final _amtFmt  = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to   = DateTime(now.year, now.month + 1, 0);
    _loadBranches();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches', params: {'isActive': 'true', 'limit': '1000'});
    if (mounted) setState(() => _branches = res['data'] ?? []);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final params = <String, String>{
      'from': _from.toIso8601String(),
      'to':   DateTime(_to.year, _to.month, _to.day, 23, 59, 59).toIso8601String(),
      'limit': '5000',
    };
    if (_branchId != null) params['branch'] = _branchId!;
    final res = await ApiService.get('/expenses', params: params);
    if (!mounted) return;
    setState(() { _items = res['data'] ?? []; _loading = false; });
  }

  List get _filtered {
    final q = _search.toLowerCase();
    return _items.where((e) {
      final matchCat = _filterCategory == null || e['category'] == _filterCategory;
      final matchSearch = q.isEmpty ||
          (e['category'] ?? '').toLowerCase().contains(q) ||
          (e['description'] ?? '').toLowerCase().contains(q) ||
          (e['branch']?['name'] ?? '').toLowerCase().contains(q);
      return matchCat && matchSearch;
    }).toList()
      ..sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
  }

  List<String> get _categories {
    final cats = _items.map((e) => e['category'] as String? ?? '').where((c) => c.isNotEmpty).toSet().toList();
    cats.sort();
    return cats;
  }

  Map<String, double> get _byCategory {
    final map = <String, double>{};
    for (final e in _filtered) {
      final cat = e['category'] as String? ?? 'Other';
      map[cat] = (map[cat] ?? 0) + ((e['amount'] as num?)?.toDouble() ?? 0);
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  double get _total => _filtered.fold(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

  // ── PDF ───────────────────────────────────────────────────────────────────

  Future<void> _generatePdf() async {
    final rows = _filtered;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        contentPadding: EdgeInsets.fromLTRB(24, 24, 24, 20),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_eGreen)),
          SizedBox(height: 18),
          Text('Generating PDF…', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ePrimary)),
        ]),
      ),
    );
    try {
      final fontR = await PdfGoogleFonts.notoSansRegular();
      final fontB = await PdfGoogleFonts.notoSansBold();
      pw.ImageProvider? logo;
      try { final d = await rootBundle.load(CompanyInfo.logoAsset); logo = pw.MemoryImage(d.buffer.asUint8List()); } catch (_) {}

      final dkGreen = PdfColor.fromHex('1B3A27');
      final green   = PdfColor.fromHex('16A34A');
      final orange  = PdfColor.fromHex('EA580C');
      final grey    = PdfColor.fromHex('6B7280');
      final border  = PdfColor.fromHex('E5E7EB');
      final bgG     = PdfColor.fromHex('F0F9F4');
      final rowAlt  = PdfColor.fromHex('FAFAFA');
      final brName  = _branchId == null ? 'All Branches'
          : (_branches.firstWhere((b) => b['_id'] == _branchId, orElse: () => {})['name'] ?? '—');

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        theme: pw.ThemeData.withFont(base: fontR, bold: fontB),
        maxPages: 500,
        header: (_) => pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              if (logo != null) ...[pw.Image(logo, width: 36, height: 36), pw.SizedBox(width: 8)],
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(CompanyInfo.name, style: pw.TextStyle(font: fontB, fontSize: 13, color: dkGreen)),
                pw.Text(CompanyInfo.address, style: pw.TextStyle(font: fontR, fontSize: 7, color: grey)),
                pw.Text(CompanyInfo.phone,   style: pw.TextStyle(font: fontR, fontSize: 7, color: grey)),
              ]),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('EXPENSE REPORT', style: pw.TextStyle(font: fontB, fontSize: 11, color: dkGreen, letterSpacing: 0.5)),
              pw.Text('${_dateFmt.format(_from)}  –  ${_dateFmt.format(_to)}',
                  style: pw.TextStyle(font: fontR, fontSize: 8, color: grey)),
              pw.Text('Branch: $brName', style: pw.TextStyle(font: fontR, fontSize: 8, color: grey)),
            ]),
          ]),
          pw.SizedBox(height: 8),
          pw.Divider(color: border, thickness: 1),
        ]),
        footer: (ctx) => pw.Column(children: [
          pw.Divider(color: border, thickness: 0.5),
          pw.SizedBox(height: 3),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Generated by ${CompanyInfo.name}', style: pw.TextStyle(font: fontR, fontSize: 7, color: PdfColor.fromHex('9CA3AF'))),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(font: fontR, fontSize: 7, color: PdfColor.fromHex('9CA3AF'))),
          ]),
        ]),
        build: (_) => [
          // Category summary
          pw.SizedBox(height: 6),
          pw.Text('CATEGORY SUMMARY', style: pw.TextStyle(font: fontB, fontSize: 9, color: dkGreen, letterSpacing: 0.4)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: border, width: 0.5),
            columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FixedColumnWidth(90), 2: pw.FixedColumnWidth(60)},
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: dkGreen), children: [
                for (final h in ['Category', 'Amount (₹)', '% Share'])
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: pw.Text(h, style: pw.TextStyle(font: fontB, fontSize: 8, color: PdfColors.white))),
              ]),
              ..._byCategory.entries.toList().asMap().entries.map((en) {
                final i = en.key; final e = en.value;
                final pct = _total > 0 ? (e.value / _total * 100) : 0.0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : rowAlt),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: pw.Text(e.key, style: pw.TextStyle(font: fontB, fontSize: 8, color: dkGreen))),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: pw.Text(_amtFmt.format(e.value), textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(font: fontB, fontSize: 8, color: orange))),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: pw.Text('${pct.toStringAsFixed(1)}%', textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: fontR, fontSize: 8, color: grey))),
                  ],
                );
              }),
              pw.TableRow(decoration: pw.BoxDecoration(color: bgG), children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: pw.Text('TOTAL', style: pw.TextStyle(font: fontB, fontSize: 9, color: dkGreen))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: pw.Text(_amtFmt.format(_total), textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: fontB, fontSize: 9, color: green))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: pw.Text('100%', textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: fontR, fontSize: 8, color: grey))),
              ]),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text('DETAILED EXPENSES', style: pw.TextStyle(font: fontB, fontSize: 9, color: dkGreen, letterSpacing: 0.4)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: border, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(58), 1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(2),   3: pw.FlexColumnWidth(2.5),
              4: pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: dkGreen), children: [
                for (final h in ['Date', 'Branch', 'Category', 'Description', 'Amount (₹)'])
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      child: pw.Text(h, style: pw.TextStyle(font: fontB, fontSize: 7.5, color: PdfColors.white))),
              ]),
              ...rows.asMap().entries.map((en) {
                final i = en.key; final e = en.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : rowAlt),
                  children: [
                    _pCell(_dateFmt.format(DateTime.parse(e['date'])), fontR, grey, align: pw.TextAlign.center),
                    _pCell(e['branch']?['name'] ?? '—', fontR, grey),
                    _pCell(e['category'] ?? '—', fontB, dkGreen),
                    _pCell(e['description'] ?? '—', fontR, grey),
                    _pCell(_amtFmt.format((e['amount'] as num?)?.toDouble() ?? 0), fontB, orange, align: pw.TextAlign.right),
                  ],
                );
              }),
              pw.TableRow(decoration: pw.BoxDecoration(color: bgG), children: [
                _pCell('TOTAL', fontB, dkGreen),
                _pCell('', fontR, grey), _pCell('', fontR, grey), _pCell('', fontR, grey),
                _pCell(_amtFmt.format(_total), fontB, green, align: pw.TextAlign.right),
              ]),
            ],
          ),
        ],
      ));

      if (mounted) Navigator.of(context).pop();
      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'ExpenseReport_${DateFormat('ddMMyyyy').format(_from)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF error: $e'), backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  static pw.Widget _pCell(String text, pw.Font font, PdfColor color,
      {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: pw.Text(text, textAlign: align,
              style: pw.TextStyle(font: font, fontSize: 7.5, color: color)));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final byCat = _byCategory;
    return Column(children: [
      _filters(),
      // Summary chips
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          _chip('Total', _total, _eOrange, bold: true),
          const SizedBox(width: 16),
          _chip('Entries', rows.length.toDouble(), const Color(0xFF6B7280), isCount: true),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _loading ? null : _generatePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
            label: const Text('PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _ePrimary, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ),
      const Divider(height: 1, color: _eBorder),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _eGreen))
            : rows.isEmpty
                ? Center(child: Text('No expenses found', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)))
                : LayoutBuilder(builder: (_, c) {
                    final wide = c.maxWidth >= 800;
                    return wide ? _wideView(rows, byCat) : _mobileView(rows, byCat);
                  }),
      ),
    ]);
  }

  Widget _wideView(List rows, Map<String, double> byCat) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Category summary panel
      SizedBox(width: 220, child: _categoryPanel(byCat)),
      const VerticalDivider(width: 1, color: _eBorder),
      // Detailed table
      Expanded(child: _detailTable(rows)),
    ]);
  }

  Widget _mobileView(List rows, Map<String, double> byCat) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        _categoryPanel(byCat),
        const SizedBox(height: 16),
        ...rows.map((e) => _mobileCard(e)),
      ]),
    );
  }

  Widget _categoryPanel(Map<String, double> byCat) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('BY CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280), letterSpacing: 0.5)),
        const SizedBox(height: 12),
        ...byCat.entries.map((e) {
          final pct = _total > 0 ? e.value / _total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(e.key,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                Text('₹${_amtFmt.format(e.value)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _eOrange)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct, minHeight: 4,
                      backgroundColor: const Color(0xFFFED7AA),
                      valueColor: const AlwaysStoppedAnimation<Color>(_eOrange))),
              Text('${(pct * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
            ]),
          );
        }),
        const Divider(color: _eBorder),
        Row(children: [
          const Expanded(child: Text('TOTAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Text('₹${_amtFmt.format(_total)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _eOrange)),
        ]),
      ]),
    );
  }

  Widget _detailTable(List rows) {
    const hdr = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280));
    return Column(children: [
      Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: const Row(children: [
          SizedBox(width: 80, child: Text('Date', style: hdr)),
          SizedBox(width: 8),
          Expanded(flex: 2, child: Text('Category', style: hdr)),
          Expanded(flex: 3, child: Text('Description', style: hdr)),
          Expanded(flex: 2, child: Text('Branch', style: hdr)),
          SizedBox(width: 90, child: Text('Amount', style: hdr, textAlign: TextAlign.right)),
        ]),
      ),
      const Divider(height: 1, color: _eBorder),
      Expanded(
        child: ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
          itemBuilder: (_, i) {
            final e = rows[i];
            final amt = (e['amount'] as num?)?.toDouble() ?? 0;
            return Container(
              color: i.isEven ? Colors.white : const Color(0xFFFAFAFA),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                SizedBox(width: 80,
                    child: Text(_dateFmt.format(DateTime.parse(e['date'])),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: Text(e['category'] ?? '—',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ePrimary))),
                Expanded(flex: 3, child: Text(e['description'] ?? '—',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(e['branch']?['name'] ?? '—',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                SizedBox(width: 90,
                    child: Text('₹${_amtFmt.format(amt)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _eOrange))),
              ]),
            );
          },
        ),
      ),
      Container(
        color: const Color(0xFFF0FDF4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Expanded(child: Text('TOTAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ePrimary))),
          Text('₹${_amtFmt.format(_total)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _eGreen)),
        ]),
      ),
    ]);
  }

  Widget _mobileCard(Map e) {
    final amt = (e['amount'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: _eBorder)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e['category'] ?? '—',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ePrimary)),
          const SizedBox(height: 2),
          Text(e['description'] ?? '—',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          Text('${e['branch']?['name'] ?? '—'}  ·  ${_dateFmt.format(DateTime.parse(e['date']))}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ])),
        Text('₹${_amtFmt.format(amt)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _eOrange)),
      ]),
    );
  }

  Widget _filters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Wrap(spacing: 10, runSpacing: 8, children: [
        _dateChip('From', _from, () async {
          final now = DateTime.now();
          final p = await showDatePicker(context: context, initialDate: _from,
              firstDate: DateTime(2020), lastDate: DateTime(now.year, now.month, now.day),
              builder: (c, ch) => Theme(data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.light(primary: _eGreen)), child: ch!));
          if (p != null) { setState(() => _from = p); _load(); }
        }),
        _dateChip('To', _to, () async {
          final now = DateTime.now();
          final p = await showDatePicker(context: context, initialDate: _to,
              firstDate: DateTime(2020), lastDate: DateTime(now.year, now.month, now.day),
              builder: (c, ch) => Theme(data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.light(primary: _eGreen)), child: ch!));
          if (p != null) { setState(() => _to = p); _load(); }
        }),
        DropdownButton<String?>(
          value: _branchId,
          hint: const Text('All Branches', style: TextStyle(fontSize: 13)),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          underline: const SizedBox(),
          items: [const DropdownMenuItem(value: null, child: Text('All Branches')),
            ..._branches.map((b) => DropdownMenuItem(value: b['_id'] as String, child: Text(b['name'] ?? '')))],
          onChanged: (v) { setState(() => _branchId = v); _load(); },
        ),
        DropdownButton<String?>(
          value: _filterCategory,
          hint: const Text('All Categories', style: TextStyle(fontSize: 13)),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          underline: const SizedBox(),
          items: [const DropdownMenuItem(value: null, child: Text('All Categories')),
            ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))],
          onChanged: (v) => setState(() => _filterCategory = v),
        ),
        _quickBtn('This Month', () {
          final n = DateTime.now();
          setState(() { _from = DateTime(n.year, n.month, 1); _to = DateTime(n.year, n.month + 1, 0); });
          _load();
        }),
      ]),
    );
  }

  Widget _chip(String label, double value, Color color, {bool bold = false, bool isCount = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        Text(isCount ? value.toInt().toString() : '₹${_amtFmt.format(value)}',
            style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: FontWeight.bold, color: color)),
      ]);

  Widget _dateChip(String label, DateTime date, VoidCallback onTap) =>
      InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(border: Border.all(color: _eBorder),
              borderRadius: BorderRadius.circular(8), color: Colors.white),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: _eGreen),
            const SizedBox(width: 6),
            Text('$label: ${DateFormat('dd MMM yy').format(date)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
          ]),
        ));

  Widget _quickBtn(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        foregroundColor: _ePrimary, backgroundColor: const Color(0xFFF0F9F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
  );
}
