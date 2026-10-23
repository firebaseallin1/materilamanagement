import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../constants/company_info.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

const _rPrimary = Color(0xFF1B3A27);
const _rBg      = Color(0xFFF4F6F8);
const _rBorder  = Color(0xFFE5E7EB);
const _rGrey    = Color(0xFF6B7280);
const _rGreen   = Color(0xFF16A34A);
const _rRed     = Color(0xFFDC2626);
const _rPurple  = Color(0xFF7C3AED);

// ── Ledger entry ──────────────────────────────────────────────────────────────

class _Entry {
  final DateTime date;
  final bool isMeas;
  final String dcNo, description, mode;
  final double debit, credit;
  double balance = 0;

  _Entry({required this.date, required this.isMeas, required this.dcNo,
      required this.description, required this.mode,
      required this.debit, required this.credit});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _rBg,
    body: Column(children: [
      ScreenHeader(title: 'Mesr vs Payments',
          subtitle: 'Credit / Debit account ledger'),
      const Expanded(child: _LedgerView()),
    ]),
  );
}

// ── Ledger view ───────────────────────────────────────────────────────────────

class _LedgerView extends StatefulWidget {
  const _LedgerView();
  @override
  State<_LedgerView> createState() => _LedgerViewState();
}

class _LedgerViewState extends State<_LedgerView> {
  List _measurements = [], _payments = [], _branches = [];
  bool _loading = false, _fetched = false;
  late DateTime _from, _to;
  String? _branchId;
  String _search = '';
  final _searchCtrl = TextEditingController();

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

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches',
        params: {'isActive': 'true', 'limit': '1000'});
    if (mounted) setState(() => _branches = res['data'] ?? []);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final from = _from.toIso8601String();
    final to   = DateTime(_to.year, _to.month, _to.day, 23, 59, 59).toIso8601String();
    final params = <String, String>{'from': from, 'to': to, 'limit': '1000'};
    if (_branchId != null) params['branch'] = _branchId!;
    final res  = await Future.wait([
      ApiService.get('/measurements', params: params),
      ApiService.get('/payments',     params: params),
    ]);
    if (mounted) setState(() {
      _measurements = res[0]['data'] ?? [];
      _payments     = res[1]['data'] ?? [];
      _loading = false;
      _fetched = true;
    });
  }

  // ── Entries ─────────────────────────────────────────────────────────────────

  List<_Entry> get _entries {
    final list = <_Entry>[];

    for (final m in _measurements) {
      final date = m['date'] != null ? DateTime.parse(m['date'] as String) : _from;
      final amt  = ((m['totalAmount'] ?? 0) as num).toDouble();
      final dc   = (m['dcNo'] ?? '').toString();
      final loc  = [m['location'], m['villaNo'], m['site']]
          .where((s) => s != null && s.toString().isNotEmpty)
          .map((s) => s.toString()).join(' · ');
      list.add(_Entry(date: date, isMeas: true, dcNo: dc,
          description: loc.isNotEmpty ? loc : 'Measurement',
          mode: '', debit: amt, credit: 0));
    }

    for (final p in _payments) {
      final date  = p['date'] != null ? DateTime.parse(p['date'] as String) : _from;
      final amt   = ((p['amount'] ?? 0) as num).toDouble();
      final party = (p['partyName'] ?? 'Payment').toString();
      final mode  = (p['paymentMode'] ?? '').toString().toUpperCase();
      final isOut = p['type'] == 'paid';
      list.add(_Entry(date: date, isMeas: false,
          dcNo: (p['category'] ?? '').toString(),
          description: party, mode: mode,
          debit: isOut ? amt : 0, credit: isOut ? 0 : amt));
    }

    list.sort((a, b) => a.date.compareTo(b.date));

    // Apply search filter (client-side, after sorting)
    final q = _search.toLowerCase().trim();
    final filtered = q.isEmpty ? list : list.where((e) =>
        e.dcNo.toLowerCase().contains(q) ||
        e.description.toLowerCase().contains(q) ||
        e.mode.toLowerCase().contains(q)).toList();

    double bal = 0;
    for (final e in filtered) {
      bal += e.debit - e.credit;
      e.balance = bal;
    }
    return filtered;
  }

  double get _totalDebit  => _measurements.fold(
      0.0, (s, m) => s + ((m['totalAmount'] ?? 0) as num).toDouble());
  double get _totalCredit => _payments
      .where((p) => p['type'] != 'paid')
      .fold(0.0, (s, p) => s + ((p['amount'] ?? 0) as num).toDouble());
  double get _outstanding => _totalDebit - _totalCredit;

  // ── Date picker ──────────────────────────────────────────────────────────────

  Future<void> _pick(bool isFrom) async {
    final d = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(
            primary: _rPrimary, onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (d != null) setState(() => isFrom ? _from = d : _to = d);
  }

  // ── PDF ──────────────────────────────────────────────────────────────────────

  Future<void> _pdf() async {
    final fontR = await PdfGoogleFonts.notoSansRegular();
    final fontB = await PdfGoogleFonts.notoSansBold();
    final nfmt  = NumberFormat('#,##0.00');
    final dfmt  = DateFormat('dd-MMM-yyyy');
    final entries = _entries;
    final doc = pw.Document();

    // Load company logo
    pw.ImageProvider? logoImg;
    try {
      final ByteData data = await rootBundle.load(CompanyInfo.logoAsset);
      logoImg = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}

    pw.Widget hCell(String t) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(t, style: pw.TextStyle(font: fontB, fontSize: 8,
          color: PdfColor.fromHex('1B3A27'))));

    pw.Widget dCell(String t, {pw.TextAlign a = pw.TextAlign.left, bool bold = false, PdfColor? c}) =>
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: pw.Text(t, textAlign: a,
                style: pw.TextStyle(font: bold ? fontB : fontR, fontSize: 8,
                    color: c ?? PdfColors.black)));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      header: (ctx) => pw.Column(children: [
        // Company header with logo
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            if (logoImg != null) ...[
              pw.Image(logoImg, width: 38, height: 38),
              pw.SizedBox(width: 8),
            ],
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(CompanyInfo.name, style: pw.TextStyle(font: fontB,
                  fontSize: 14, fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('1B3A27'))),
              pw.Text(CompanyInfo.address, style: pw.TextStyle(font: fontR,
                  fontSize: 7, color: PdfColors.grey600)),
              pw.Text(CompanyInfo.phone, style: pw.TextStyle(font: fontR,
                  fontSize: 7, color: PdfColors.grey600)),
            ]),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('MEASUREMENT vs PAYMENT LEDGER',
                style: pw.TextStyle(font: fontB, fontSize: 11,
                    fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1B3A27'))),
            pw.SizedBox(height: 3),
            pw.Text('${dfmt.format(_from)}  –  ${dfmt.format(_to)}',
                style: pw.TextStyle(font: fontR, fontSize: 9, color: PdfColors.grey600)),
          ]),         // close right pw.Column
        ]),           // close outer pw.Row
        pw.SizedBox(height: 6),
        pw.Divider(color: PdfColor.fromHex('1B3A27'), thickness: 1.2),
        pw.SizedBox(height: 4),
      ]),             // close header pw.Column
      build: (_) => [
        // Summary
        pw.Table(border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey300),
          columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1)},
          children: [
            pw.TableRow(decoration: pw.BoxDecoration(color: PdfColor.fromHex('F0F9F4')),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Column(children: [
                  pw.Text('Total Debit (Measurements)', style: pw.TextStyle(font: fontR, fontSize: 8, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('₹${nfmt.format(_totalDebit)}', style: pw.TextStyle(font: fontB, fontSize: 11, color: PdfColor.fromHex('7C3AED'))),
                ])),
                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Column(children: [
                  pw.Text('Total Credit (Received)', style: pw.TextStyle(font: fontR, fontSize: 8, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('₹${nfmt.format(_totalCredit)}', style: pw.TextStyle(font: fontB, fontSize: 11, color: PdfColor.fromHex('16A34A'))),
                ])),
                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Column(children: [
                  pw.Text(_outstanding > 0 ? 'Outstanding' : 'Advance', style: pw.TextStyle(font: fontR, fontSize: 8, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('₹${nfmt.format(_outstanding.abs())}', style: pw.TextStyle(font: fontB, fontSize: 11,
                      color: _outstanding > 0 ? PdfColor.fromHex('DC2626') : PdfColor.fromHex('16A34A'))),
                ])),
              ]),
          ]),
        pw.SizedBox(height: 12),
        // Table
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey300),
          columnWidths: const {
            0: pw.FixedColumnWidth(52), 1: pw.FixedColumnWidth(58),
            2: pw.FlexColumnWidth(2.5), 3: pw.FixedColumnWidth(30),
            4: pw.FixedColumnWidth(68), 5: pw.FixedColumnWidth(68), 6: pw.FixedColumnWidth(72),
          },
          children: [
            pw.TableRow(decoration: pw.BoxDecoration(color: PdfColor.fromHex('1B3A27')),
              children: ['Date', 'DC No', 'Description', 'Type', 'Debit', 'Credit', 'Balance']
                  .map((h) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                      child: pw.Text(h, style: pw.TextStyle(font: fontB, fontSize: 8, color: PdfColors.white),
                          textAlign: ['Debit','Credit','Balance'].contains(h) ? pw.TextAlign.right : pw.TextAlign.left)))
                  .toList()),
            ...entries.asMap().entries.map((e) {
              final i = e.key;
              final en = e.value;
              final bg = i.isEven ? PdfColors.white : PdfColor.fromHex('FAFAFA');
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bg),
                children: [
                  dCell(DateFormat('d MMM').format(en.date)),
                  dCell(en.dcNo, bold: en.isMeas, c: en.isMeas ? PdfColor.fromHex('7C3AED') : PdfColors.black),
                  dCell(en.description),
                  dCell(en.isMeas ? 'DC' : (en.credit > 0 ? 'RCV' : 'PAY'),
                      c: en.isMeas ? PdfColor.fromHex('7C3AED') : (en.credit > 0 ? PdfColor.fromHex('16A34A') : PdfColor.fromHex('DC2626'))),
                  dCell(en.debit > 0 ? nfmt.format(en.debit) : '—', a: pw.TextAlign.right,
                      c: en.debit > 0 ? PdfColor.fromHex('7C3AED') : PdfColors.grey),
                  dCell(en.credit > 0 ? nfmt.format(en.credit) : '—', a: pw.TextAlign.right,
                      c: en.credit > 0 ? PdfColor.fromHex('16A34A') : PdfColors.grey),
                  dCell(nfmt.format(en.balance.abs()), a: pw.TextAlign.right, bold: true,
                      c: en.balance > 0 ? PdfColor.fromHex('DC2626') : PdfColor.fromHex('16A34A')),
                ]);
            }),
            // Totals row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('1B3A27')),
              children: [
                hCell('TOTAL'),
                pw.SizedBox(), pw.SizedBox(), pw.SizedBox(),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                    child: pw.Text(nfmt.format(entries.fold(0.0, (s, e) => s + e.debit)),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: fontB, fontSize: 9, color: PdfColor.fromHex('DDD6FE')))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                    child: pw.Text(nfmt.format(entries.fold(0.0, (s, e) => s + e.credit)),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: fontB, fontSize: 9, color: PdfColor.fromHex('BBF7D0')))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                    child: pw.Text(nfmt.format(_outstanding.abs()),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: fontB, fontSize: 9,
                            color: _outstanding > 0 ? PdfColor.fromHex('FCA5A5') : PdfColor.fromHex('BBF7D0')))),
              ]),
          ]),
      ],
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'Ledger_${DateFormat('ddMMyy').format(_from)}_${DateFormat('ddMMyy').format(_to)}.pdf',
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dfmt  = DateFormat('d MMM');
    final nfmt  = NumberFormat('#,##0.##');
    final entries = _entries;

    return Column(children: [
      // ── Filter bar ──────────────────────────────────────────────────────────
      Container(color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(children: [
          // Single row: dates + branch + search + Go + PDF
          Row(children: [
            _Chip(label: dfmt.format(_from), onTap: () => _pick(true)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(width: 14, height: 1.5, color: _rBorder)),
            _Chip(label: dfmt.format(_to), onTap: () => _pick(false)),
            const SizedBox(width: 8),
            // Branch
            SizedBox(width: 150, height: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _branchId != null ? _rPrimary.withValues(alpha: 0.06) : _rBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _branchId != null
                      ? _rPrimary.withValues(alpha: 0.4) : _rBorder)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _branchId,
                    isExpanded: true,
                    icon: Icon(Icons.expand_more_rounded, size: 16,
                        color: _branchId != null ? _rPrimary : _rGrey),
                    hint: const Row(children: [
                      Icon(Icons.store_outlined, size: 14, color: _rGrey),
                      SizedBox(width: 5),
                      Text('Branch', style: TextStyle(fontSize: 12, color: _rGrey)),
                    ]),
                    style: const TextStyle(fontSize: 12, color: _rPrimary, fontWeight: FontWeight.w600),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Branches',
                            style: TextStyle(color: _rGrey, fontWeight: FontWeight.normal))),
                      ..._branches.map<DropdownMenuItem<String>>((b) =>
                          DropdownMenuItem(value: b['_id'] as String,
                              child: Text(b['name'] ?? ''))),
                    ],
                    onChanged: (v) { setState(() => _branchId = v); _load(); },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Search
            Expanded(child: SizedBox(height: 40,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search DC, party…',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF9CA3AF)),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF9CA3AF)),
                          onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                      : null,
                  filled: true, fillColor: _rBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _rBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _rBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _rPrimary, width: 1.5)),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            )),
            const SizedBox(width: 8),
            SizedBox(height: 40, child: ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: _rPrimary,
                  foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: const Text('Go', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))),
            if (_fetched && entries.isNotEmpty) ...[
              const SizedBox(width: 8),
              SizedBox(height: 40, child: ElevatedButton.icon(
                onPressed: _pdf,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                label: const Text('PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: _rRed,
                    foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14)))),
            ],
          ]),
        ]),
      ),
      const Divider(height: 1, color: _rBorder),

      // ── Summary ─────────────────────────────────────────────────────────────
      if (_fetched)
        Container(color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(children: [
            _SumCard(label: 'Total Debit', sub: '${_measurements.length} DCs',
                value: '₹${nfmt.format(_totalDebit)}', color: _rPurple,
                icon: Icons.receipt_long_outlined),
            const SizedBox(width: 8),
            _SumCard(label: 'Total Received', sub: '${_payments.where((p) => p['type'] != 'paid').length} payments',
                value: '₹${nfmt.format(_totalCredit)}', color: _rGreen,
                icon: Icons.arrow_downward_rounded),
            const SizedBox(width: 8),
            _SumCard(
                label: _outstanding > 0 ? 'Outstanding' : 'Advance',
                sub: _outstanding == 0 ? 'Settled' : (_outstanding > 0 ? 'Due' : 'Excess'),
                value: '₹${nfmt.format(_outstanding.abs())}',
                color: _outstanding > 0 ? _rRed : _rGreen,
                icon: _outstanding > 0 ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded),
          ]),
        ),
      if (_fetched) const Divider(height: 1, color: _rBorder),

      // ── List ─────────────────────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const AppLoader()
            : !_fetched
                ? _EmptyState()
                : entries.isEmpty
                    ? const EmptyState(message: 'No records for this period')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                        itemCount: entries.length + 1,
                        itemBuilder: (_, i) {
                          if (i == entries.length) {
                            return _TotalsCard(entries: entries, nfmt: nfmt);
                          }
                          return _EntryCard(entry: entries[i], nfmt: nfmt);
                        },
                      ),
      ),
    ]);
  }
}

// ── Date chip ─────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _rPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _rPrimary.withValues(alpha: 0.35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.calendar_today_outlined, size: 13, color: _rPrimary),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontSize: 12,
            fontWeight: FontWeight.w600, color: _rPrimary)),
      ]),
    ),
  );
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SumCard extends StatelessWidget {
  final String label, sub, value;
  final Color color;
  final IconData icon;
  const _SumCard({required this.label, required this.sub, required this.value,
      required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: _rGrey,
              fontWeight: FontWeight.w500)),
          const SizedBox(height: 1),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
              overflow: TextOverflow.ellipsis),
          Text(sub, style: const TextStyle(fontSize: 9, color: _rGrey)),
        ])),
      ]),
    ),
  );
}

// ── Entry card ────────────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  final _Entry entry;
  final NumberFormat nfmt;
  const _EntryCard({required this.entry, required this.nfmt});

  @override
  Widget build(BuildContext context) {
    final isMeas   = entry.isMeas;
    final isCredit = entry.credit > 0;
    final barColor = isMeas ? _rPurple : (isCredit ? _rGreen : _rRed);
    final typeLbl  = isMeas ? 'DC' : (isCredit ? 'RECEIVED' : 'PAID');
    final typeBg   = isMeas
        ? const Color(0xFFEDE9FE)
        : (isCredit ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2));
    final typeClr  = isMeas ? _rPurple : (isCredit ? _rGreen : _rRed);
    final balColor = entry.balance > 0 ? _rRed : (entry.balance < 0 ? _rGreen : _rGrey);
    final amount   = isMeas ? entry.debit : (isCredit ? entry.credit : entry.debit);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _rBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4, offset: const Offset(0, 1))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Left accent bar
          Container(width: 4, color: barColor),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Row 1: type badge + date + amount
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: typeBg,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(typeLbl, style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700, color: typeClr))),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(entry.date),
                    style: const TextStyle(fontSize: 11, color: _rGrey)),
                const Spacer(),
                Text(
                  '${isMeas || entry.debit > 0 ? 'Dr' : 'Cr'}  ₹${nfmt.format(amount)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: barColor)),
              ]),
              const SizedBox(height: 6),
              // Row 2: DC No (full width, no truncation)
              if (entry.dcNo.isNotEmpty)
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: barColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(entry.dcNo,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: barColor, fontFamily: 'monospace'))),
                ]),
              if (entry.dcNo.isNotEmpty) const SizedBox(height: 4),
              // Row 3: description
              Text(entry.description,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                      color: Color(0xFF374151))),
              if (entry.mode.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.payment_outlined, size: 11, color: _rGrey),
                  const SizedBox(width: 4),
                  Text(entry.mode,
                      style: const TextStyle(fontSize: 10, color: _rGrey)),
                ]),
              ],
              const SizedBox(height: 8),
              // Row 4: running balance
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: balColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: balColor.withValues(alpha: 0.2))),
                child: Row(children: [
                  Icon(Icons.account_balance_outlined, size: 12, color: balColor),
                  const SizedBox(width: 5),
                  const Text('Running Balance', style: TextStyle(
                      fontSize: 10, color: _rGrey)),
                  const Spacer(),
                  Text('₹${nfmt.format(entry.balance.abs())}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: balColor)),
                  const SizedBox(width: 4),
                  Text(entry.balance > 0 ? 'Due' : (entry.balance < 0 ? 'Advance' : ''),
                      style: TextStyle(fontSize: 9, color: balColor)),
                ]),
              ),
            ]),
          )),
        ])),
      ),
    );
  }
}

// ── Totals card ───────────────────────────────────────────────────────────────

class _TotalsCard extends StatelessWidget {
  final List<_Entry> entries;
  final NumberFormat nfmt;
  const _TotalsCard({required this.entries, required this.nfmt});

  @override
  Widget build(BuildContext context) {
    final totalD = entries.fold(0.0, (s, e) => s + e.debit);
    final totalC = entries.fold(0.0, (s, e) => s + e.credit);
    final bal    = entries.isEmpty ? 0.0 : entries.last.balance;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(color: _rPrimary,
          borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        const Text('TOTAL', style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w800, color: Colors.white)),
        const Spacer(),
        _tot('Total Debit', '₹${nfmt.format(totalD)}', const Color(0xFFDDD6FE)),
        const SizedBox(width: 20),
        _tot('Total Credit', '₹${nfmt.format(totalC)}', const Color(0xFFBBF7D0)),
        const SizedBox(width: 20),
        _tot('Balance', '₹${nfmt.format(bal.abs())}',
            bal > 0 ? const Color(0xFFFCA5A5) : const Color(0xFFBBF7D0)),
      ]),
    );
  }

  Widget _tot(String l, String v, Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(l, style: const TextStyle(fontSize: 9, color: Colors.white60)),
      Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
    ]);
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(color: _rPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20)),
        child: Icon(Icons.account_balance_outlined, size: 32,
            color: _rPrimary.withValues(alpha: 0.5))),
      const SizedBox(height: 14),
      const Text('Credit / Debit Ledger', style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: _rPrimary)),
      const SizedBox(height: 6),
      const Text('Select week and tap Go',
          style: TextStyle(fontSize: 13, color: _rGrey)),
    ]),
  );
}
