import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../constants/company_info.dart';
import '../../services/api_service.dart';
import '../../widgets/screen_header.dart';

const _atGreen   = Color(0xFF16A34A);
const _atPurple  = Color(0xFF7C3AED);
const _atPrimary = Color(0xFF1B3A27);
const _atBg      = Color(0xFFF4F6F8);
const _atBorder  = Color(0xFFE5E7EB);

class AttendanceReportScreen extends StatelessWidget {
  const AttendanceReportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _atBg,
    body: Column(children: [
      ScreenHeader(title: 'Attendance Report', subtitle: 'Employee attendance & earnings summary'),
      const Expanded(child: _AttReportView()),
    ]),
  );
}

class _AttReportView extends StatefulWidget {
  const _AttReportView();
  @override
  State<_AttReportView> createState() => _AttReportViewState();
}

class _AttReportViewState extends State<_AttReportView> {
  List _items = [], _branches = [];
  bool _loading = false;
  late DateTime _from, _to;
  String? _branchId, _filterEmployeeId;

  static final _dateFmt  = DateFormat('dd MMM yy');
  static final _amtFmt   = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final sun = now.weekday % 7;
    _from = DateTime(now.year, now.month, now.day - sun);
    _to   = _from.add(const Duration(days: 6));
    _loadBranches();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

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
    if (_branchId != null)         params['branch']   = _branchId!;
    if (_filterEmployeeId != null) params['employee'] = _filterEmployeeId!;
    final res = await ApiService.get('/attendance', params: params);
    if (!mounted) return;
    setState(() { _items = res['data'] ?? []; _loading = false; });
  }

  // ── Summaries ─────────────────────────────────────────────────────────────

  /// Employee-wise summary: { empId: { name, code, photo, presentDays, absentDays, otHours, earnings } }
  Map<String, Map<String, dynamic>> get _empSummary {
    final map = <String, Map<String, dynamic>>{};
    for (final item in _items) {
      final emp = item['employee'] is Map ? item['employee'] : null;
      if (emp == null) continue;
      final id   = emp['_id']?.toString() ?? '';
      final entry = map.putIfAbsent(id, () => {
        'name': emp['name'] ?? '—',
        'code': emp['empCode'] ?? '',
        'photo': emp['photo'] ?? '',
        'presentDays': 0, 'absentDays': 0, 'otHours': 0.0, 'earnings': 0.0,
      });
      final present = item['isPresent'] == true;
      final ot      = (item['otHours']  ?? 0).toDouble();
      final rate    = (item['hourRate'] ?? 0).toDouble();
      if (present) { entry['presentDays'] = (entry['presentDays'] as int) + 1; }
      else         { entry['absentDays']  = (entry['absentDays']  as int) + 1; }
      entry['otHours']  = (entry['otHours']  as double) + ot;
      entry['earnings'] = (entry['earnings'] as double) + (present ? 8 : 0) * rate + ot * rate;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => (a.value['name'] as String).compareTo(b.value['name'] as String));
    return Map.fromEntries(sorted);
  }

  int    get _totalPresent  => _items.where((i) => i['isPresent'] == true).length;
  int    get _totalAbsent   => _items.where((i) => i['isPresent'] != true).length;
  double get _totalOt       => _items.fold(0.0, (s, i) => s + ((i['otHours'] ?? 0) as num).toDouble());
  double get _totalEarnings => _empSummary.values.fold(0.0, (s, v) => s + (v['earnings'] as double));

  List<Map<String, dynamic>> get _sortedItems {
    final list = List<Map<String, dynamic>>.from(_items);
    list.sort((a, b) {
      final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
      return da.compareTo(db);
    });
    return list;
  }

  // ── PDF ───────────────────────────────────────────────────────────────────

  Future<void> _generatePdf() async {
    final summary = _empSummary;
    final detail  = _sortedItems;

    showDialog(context: context, barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        contentPadding: EdgeInsets.fromLTRB(24, 24, 24, 20),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_atGreen)),
          SizedBox(height: 18),
          Text('Generating PDF…', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _atPrimary)),
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
      final purple  = PdfColor.fromHex('7C3AED');
      final red     = PdfColor.fromHex('DC2626');
      final grey    = PdfColor.fromHex('6B7280');
      final border  = PdfColor.fromHex('E5E7EB');
      final bgG     = PdfColor.fromHex('F0F9F4');
      final rowAlt  = PdfColor.fromHex('FAFAFA');
      final brName  = _branchId == null ? 'All Branches'
          : (_branches.firstWhere((b) => b['_id'] == _branchId, orElse: () => {})['name'] ?? '—');

      pw.Widget pCell(String t, pw.Font f, PdfColor c, {pw.TextAlign a = pw.TextAlign.left}) =>
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(t, textAlign: a, style: pw.TextStyle(font: f, fontSize: 7.5, color: c)));

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
              pw.Text('ATTENDANCE REPORT', style: pw.TextStyle(font: fontB, fontSize: 11, color: dkGreen, letterSpacing: 0.5)),
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
          // Overall summary
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: bgG, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)), border: pw.Border.all(color: border, width: 0.5)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly, children: [
              _pdfStat('Present', '$_totalPresent days', green, fontR, fontB),
              _pdfDiv(), _pdfStat('Absent', '$_totalAbsent days', red, fontR, fontB),
              _pdfDiv(), _pdfStat('OT Hours', '${_totalOt.toStringAsFixed(1)} hrs', purple, fontR, fontB),
              _pdfDiv(), _pdfStat('Total Earnings', '₹${_amtFmt.format(_totalEarnings)}', dkGreen, fontR, fontB),
            ]),
          ),
          pw.SizedBox(height: 12),
          // Employee summary table
          pw.Text('EMPLOYEE SUMMARY', style: pw.TextStyle(font: fontB, fontSize: 9, color: dkGreen, letterSpacing: 0.4)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: border, width: 0.5),
            columnWidths: const {0: pw.FlexColumnWidth(2.5), 1: pw.FixedColumnWidth(50), 2: pw.FixedColumnWidth(50), 3: pw.FixedColumnWidth(55), 4: pw.FixedColumnWidth(75)},
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: dkGreen), children: [
                for (final h in ['Employee', 'Present', 'Absent', 'OT Hrs', 'Earnings (₹)'])
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      child: pw.Text(h, style: pw.TextStyle(font: fontB, fontSize: 7.5, color: PdfColors.white))),
              ]),
              ...summary.values.toList().asMap().entries.map((en) {
                final i = en.key; final s = en.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : rowAlt),
                  children: [
                    pCell('${s['name']}${(s['code'] as String).isNotEmpty ? ' (${s['code']})' : ''}', fontB, dkGreen),
                    pCell('${s['presentDays']}', fontR, green, a: pw.TextAlign.center),
                    pCell('${s['absentDays']}', fontR, red, a: pw.TextAlign.center),
                    pCell((s['otHours'] as double).toStringAsFixed(1), fontR, purple, a: pw.TextAlign.center),
                    pCell(_amtFmt.format(s['earnings'] as double), fontB, dkGreen, a: pw.TextAlign.right),
                  ],
                );
              }),
              pw.TableRow(decoration: pw.BoxDecoration(color: bgG), children: [
                pCell('TOTAL', fontB, dkGreen),
                pCell('$_totalPresent', fontB, green, a: pw.TextAlign.center),
                pCell('$_totalAbsent', fontB, red, a: pw.TextAlign.center),
                pCell(_totalOt.toStringAsFixed(1), fontB, purple, a: pw.TextAlign.center),
                pCell(_amtFmt.format(_totalEarnings), fontB, green, a: pw.TextAlign.right),
              ]),
            ],
          ),
          pw.SizedBox(height: 14),
          // Detailed table
          pw.Text('DETAILED ATTENDANCE', style: pw.TextStyle(font: fontB, fontSize: 9, color: dkGreen, letterSpacing: 0.4)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: border, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(58), 1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(1.5), 3: pw.FixedColumnWidth(48),
              4: pw.FixedColumnWidth(45), 5: pw.FixedColumnWidth(55), 6: pw.FixedColumnWidth(70),
            },
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: dkGreen), children: [
                for (final h in ['Date', 'Employee', 'Branch', 'Status', 'OT Hrs', 'Rate (₹)', 'Earnings (₹)'])
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: pw.Text(h, style: pw.TextStyle(font: fontB, fontSize: 7.5, color: PdfColors.white))),
              ]),
              ...detail.asMap().entries.map((en) {
                final i = en.key; final item = en.value;
                final present = item['isPresent'] == true;
                final ot   = (item['otHours']  ?? 0).toDouble();
                final rate = (item['hourRate'] ?? 0).toDouble();
                final earn = (present ? 8.0 : 0.0) * rate + ot * rate;
                final emp  = item['employee'] is Map ? item['employee'] : {};
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : rowAlt),
                  children: [
                    pCell(_dateFmt.format(DateTime.parse(item['date'])), fontR, grey, a: pw.TextAlign.center),
                    pCell('${emp['name'] ?? '—'}', fontB, dkGreen),
                    pCell(item['branch']?['name'] ?? '—', fontR, grey),
                    pCell(present ? 'Present' : 'Absent', fontB, present ? green : red, a: pw.TextAlign.center),
                    pCell(ot > 0 ? ot.toStringAsFixed(1) : '—', fontR, purple, a: pw.TextAlign.center),
                    pCell(rate > 0 ? _amtFmt.format(rate) : '—', fontR, grey, a: pw.TextAlign.right),
                    pCell(earn > 0 ? _amtFmt.format(earn) : '—', fontB, dkGreen, a: pw.TextAlign.right),
                  ],
                );
              }),
            ],
          ),
        ],
      ));

      if (mounted) Navigator.of(context).pop();
      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'AttendanceReport_${DateFormat('ddMMyyyy').format(_from)}.pdf',
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

  static pw.Widget _pdfStat(String label, String value, PdfColor color, pw.Font fontR, pw.Font fontB) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text(value, style: pw.TextStyle(font: fontB, fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 2),
        pw.Text(label, style: pw.TextStyle(font: fontR, fontSize: 7.5, color: PdfColor.fromHex('374151'))),
      ]);

  static pw.Widget _pdfDiv() => pw.Container(
      width: 1, height: 28, color: PdfColor.fromHex('2E7D52'),
      margin: const pw.EdgeInsets.symmetric(horizontal: 8));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final summary = _empSummary;
    return Column(children: [
      _filters(),
      // Summary bar
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          _statChip('Present', '$_totalPresent days', _atGreen),
          const SizedBox(width: 14),
          _statChip('Absent', '$_totalAbsent days', const Color(0xFFDC2626)),
          const SizedBox(width: 14),
          _statChip('OT', '${_totalOt.toStringAsFixed(1)} hrs', _atPurple),
          const SizedBox(width: 14),
          _statChip('Earnings', '₹${_amtFmt.format(_totalEarnings)}', _atPrimary, bold: true),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _loading ? null : _generatePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
            label: const Text('PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _atPrimary, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ),
      const Divider(height: 1, color: _atBorder),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _atGreen))
            : summary.isEmpty
                ? Center(child: Text('No attendance records', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)))
                : LayoutBuilder(builder: (_, c) => c.maxWidth >= 700
                    ? _wideView(summary)
                    : _mobileView(summary)),
      ),
    ]);
  }

  Widget _wideView(Map<String, Map<String, dynamic>> summary) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 240, child: _summaryPanel(summary)),
      const VerticalDivider(width: 1, color: _atBorder),
      Expanded(child: _detailTable()),
    ]);
  }

  Widget _mobileView(Map<String, Map<String, dynamic>> summary) {
    return SingleChildScrollView(
      child: Column(children: [
        _summaryPanel(summary),
        const Divider(height: 1, color: _atBorder),
        ..._sortedItems.map(_mobileCard),
      ]),
    );
  }

  Widget _summaryPanel(Map<String, Map<String, dynamic>> summary) {
    return Container(
      color: Colors.white,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        const Text('EMPLOYEE SUMMARY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280), letterSpacing: 0.5)),
        const SizedBox(height: 12),
        ...summary.values.map((s) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _atBg, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _atBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _empAvatar(s),
              const SizedBox(width: 8),
              Expanded(child: Text(s['name'] as String,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _atPrimary))),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _miniStat('Present', '${s['presentDays']}d', _atGreen),
              _miniStat('Absent', '${s['absentDays']}d', const Color(0xFFDC2626)),
              _miniStat('OT', '${(s['otHours'] as double).toStringAsFixed(1)}h', _atPurple),
              _miniStat('₹', _amtFmt.format(s['earnings'] as double), _atPrimary),
            ]),
          ]),
        )),
      ]),
    );
  }

  Widget _detailTable() {
    const hdr = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280));
    final rows = _sortedItems;
    return Column(children: [
      Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: const Row(children: [
          SizedBox(width: 82, child: Text('Date', style: hdr)),
          Expanded(flex: 2, child: Text('Employee', style: hdr)),
          Expanded(flex: 2, child: Text('Branch', style: hdr)),
          SizedBox(width: 70, child: Text('Status', style: hdr, textAlign: TextAlign.center)),
          SizedBox(width: 60, child: Text('OT Hrs', style: hdr, textAlign: TextAlign.center)),
          SizedBox(width: 75, child: Text('Rate', style: hdr, textAlign: TextAlign.right)),
          SizedBox(width: 85, child: Text('Earnings', style: hdr, textAlign: TextAlign.right)),
        ]),
      ),
      const Divider(height: 1, color: _atBorder),
      Expanded(
        child: ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
          itemBuilder: (_, i) {
            final item    = rows[i];
            final present = item['isPresent'] == true;
            final ot      = (item['otHours']  ?? 0).toDouble();
            final rate    = (item['hourRate'] ?? 0).toDouble();
            final earn    = (present ? 8.0 : 0.0) * rate + ot * rate;
            final emp     = item['employee'] is Map ? item['employee'] : {};
            return Container(
              color: i.isEven ? Colors.white : const Color(0xFFFAFAFA),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(children: [
                SizedBox(width: 82, child: Text(_dateFmt.format(DateTime.parse(item['date'])),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Row(children: [
                  _empAvatar(emp, size: 24),
                  const SizedBox(width: 6),
                  Expanded(child: Text(emp['name'] ?? '—',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis)),
                ])),
                Expanded(flex: 2, child: Text(item['branch']?['name'] ?? '—',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                SizedBox(width: 70, child: Center(child: _statusBadge(present))),
                SizedBox(width: 60,
                    child: Text(ot > 0 ? ot.toStringAsFixed(1) : '—',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: ot > 0 ? _atPurple : const Color(0xFFD1D5DB),
                            fontWeight: ot > 0 ? FontWeight.w600 : FontWeight.normal))),
                SizedBox(width: 75,
                    child: Text(rate > 0 ? '₹${_amtFmt.format(rate)}' : '—',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                SizedBox(width: 85,
                    child: Text(earn > 0 ? '₹${_amtFmt.format(earn)}' : '—',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: earn > 0 ? _atPrimary : const Color(0xFFD1D5DB)))),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _mobileCard(Map item) {
    final present = item['isPresent'] == true;
    final ot      = (item['otHours']  ?? 0).toDouble();
    final rate    = (item['hourRate'] ?? 0).toDouble();
    final earn    = (present ? 8.0 : 0.0) * rate + ot * rate;
    final emp     = item['employee'] is Map ? item['employee'] : {};
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _atBorder)),
      child: Row(children: [
        _empAvatar(emp),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emp['name'] ?? '—',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('${item['branch']?['name'] ?? '—'}  ·  ${_dateFmt.format(DateTime.parse(item['date']))}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          if (ot > 0) Text('OT: ${ot.toStringAsFixed(1)} hrs',
              style: const TextStyle(fontSize: 11, color: _atPurple)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _statusBadge(present),
          if (earn > 0) ...[
            const SizedBox(height: 4),
            Text('₹${_amtFmt.format(earn)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _atPrimary)),
          ],
        ]),
      ]),
    );
  }

  Widget _empAvatar(Map emp, {double size = 30}) {
    final photo = emp['photo'] as String?;
    if (photo != null && photo.isNotEmpty) {
      try {
        return ClipRRect(borderRadius: BorderRadius.circular(size * 0.3),
            child: Image.memory(base64Decode(photo), width: size, height: size, fit: BoxFit.cover));
      } catch (_) {}
    }
    final name = (emp['name'] as String? ?? '?');
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: _atGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(size * 0.3)),
      child: Center(child: Text(name[0].toUpperCase(),
          style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w700, color: _atPrimary))),
    );
  }

  Widget _statusBadge(bool present) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: present ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(present ? 'Present' : 'Absent',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: present ? _atGreen : const Color(0xFFDC2626))),
  );

  Widget _statChip(String label, String value, Color color, {bool bold = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        Text(value, style: TextStyle(fontSize: bold ? 14 : 13, fontWeight: FontWeight.bold, color: color)),
      ]);

  Widget _miniStat(String label, String value, Color color) =>
      Column(children: [
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
      ]);

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
                  colorScheme: const ColorScheme.light(primary: _atGreen)), child: ch!));
          if (p != null) { setState(() => _from = p); _load(); }
        }),
        _dateChip('To', _to, () async {
          final now = DateTime.now();
          final p = await showDatePicker(context: context, initialDate: _to,
              firstDate: DateTime(2020), lastDate: DateTime(now.year, now.month, now.day),
              builder: (c, ch) => Theme(data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.light(primary: _atGreen)), child: ch!));
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
        _quickBtn('This Week', () {
          final now = DateTime.now(); final sun = now.weekday % 7;
          setState(() { _from = DateTime(now.year, now.month, now.day - sun); _to = _from.add(const Duration(days: 6)); });
          _load();
        }),
        _quickBtn('This Month', () {
          final n = DateTime.now();
          setState(() { _from = DateTime(n.year, n.month, 1); _to = DateTime(n.year, n.month + 1, 0); });
          _load();
        }),
      ]),
    );
  }

  Widget _dateChip(String label, DateTime date, VoidCallback onTap) =>
      InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(border: Border.all(color: _atBorder),
              borderRadius: BorderRadius.circular(8), color: Colors.white),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: _atGreen),
            const SizedBox(width: 6),
            Text('$label: ${DateFormat('dd MMM yy').format(date)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
          ]),
        ));

  Widget _quickBtn(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        foregroundColor: _atPrimary, backgroundColor: const Color(0xFFF0F9F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
  );
}
