import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class MeasurementPdf {
  // ── Colours ──────────────────────────────────────────────────────────────
  static final _darkGreen  = PdfColor.fromHex('1B3A27');
  static final _green      = PdfColor.fromHex('16A34A');
  static final _greenLight = PdfColor.fromHex('DCFCE7');
  static final _blue       = PdfColor.fromHex('2E7D52');
  static final _orange     = PdfColor.fromHex('EA580C');
  static final _red        = PdfColor.fromHex('DC2626');
  static final _redLight   = PdfColor.fromHex('FFF5F5');
  static final _grey       = PdfColor.fromHex('6B7280');
  static final _greyLight  = PdfColor.fromHex('9CA3AF');
  static final _bg         = PdfColor.fromHex('F9FAFB');
  static final _bgGreen    = PdfColor.fromHex('F0F9F4');
  static final _border     = PdfColor.fromHex('E5E7EB');
  static final _rowAlt     = PdfColor.fromHex('FAFAFA');

  // ── Public entry point ────────────────────────────────────────────────────
  static Future<void> generate(Map item) async {
    // Load Unicode-capable fonts from Google Fonts
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold    = await PdfGoogleFonts.notoSansBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final pdf = pw.Document();

    // ── Parse item ──
    final date = item['date'] != null
        ? DateFormat('dd MMM yyyy')
            .format(DateTime.parse(item['date'] as String))
        : '-';
    final dcNo    = (item['dcNo']     ?? '') as String;
    final branch =
        item['branch'] is Map ? ((item['branch']['name'] ?? '') as String) : '';
    final location  = (item['location']  ?? '') as String;
    final site      = (item['site']      ?? '') as String;
    final floor     = (item['floor']     ?? '') as String;
    final villa     = (item['villaNo']   ?? '') as String;
    final remark    = (item['remark']    ?? '') as String;
    final rate      = (item['amount']    as num?)?.toDouble() ?? 0;
    final rows      = (item['rows']      as List? ?? []);

    // ── Aggregate ──
    double grossTotal = 0, openTotal = 0;
    final Map<String, double> byType = {};
    for (final r in rows) {
      final qty = (r['total'] as num?)?.toDouble() ?? 0;
      if ((r['type'] ?? 'inside') == 'open') {
        openTotal += qty;
      } else {
        grossTotal += qty;
        final typeName = (r['measurementTypeName'] ?? '') as String;
        if (typeName.isNotEmpty) {
          byType[typeName] = (byType[typeName] ?? 0) + qty;
        }
      }
    }
    final netTotal = grossTotal - openTotal;
    final totalAmt = (item['totalAmount'] as num?)?.toDouble() ??
        (rate > 0 ? netTotal * rate : 0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        theme: theme,
        maxPages: 500,
        header: (ctx) => _pageHeader(location, date, dcNo, fontBold, fontRegular),
        footer: (ctx) => _pageFooter(ctx, fontRegular),
        build: (_) => [
          pw.SizedBox(height: 14),
          _entryDetails(
              dcNo, branch, location, site, floor, villa, remark, date,
              fontRegular, fontBold),
          pw.SizedBox(height: 16),
          _rowsTable(rows, fontRegular, fontBold),
          if (byType.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _typeSummary(byType, fontRegular, fontBold),
          ],
          pw.SizedBox(height: 16),
          _financialSummary(
              netTotal, rate, totalAmt, grossTotal, openTotal,
              fontRegular, fontBold),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name:
          'Measurement_${location.isNotEmpty ? location : date.replaceAll(' ', '_')}.pdf',
    );
  }

  // ── Page header ───────────────────────────────────────────────────────────
  static pw.Widget _pageHeader(String location, String date, String dcNo,
      pw.Font fontBold, pw.Font fontRegular) {
    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('MMS',
                style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkGreen)),
            pw.Text('Material Management System',
                style: pw.TextStyle(
                    font: fontRegular, fontSize: 8, color: _greyLight)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('MEASUREMENT REPORT',
                style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkGreen,
                    letterSpacing: 0.6)),
            pw.SizedBox(height: 3),
            pw.Text(date,
                style: pw.TextStyle(
                    font: fontRegular, fontSize: 9, color: _greyLight)),
            if (dcNo.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text('DC No: $dcNo',
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _darkGreen)),
            ],
          ]),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Divider(color: _border, thickness: 1),
    ]);
  }

  // ── Page footer ───────────────────────────────────────────────────────────
  static pw.Widget _pageFooter(pw.Context ctx, pw.Font fontRegular) {
    return pw.Column(children: [
      pw.Divider(color: _border, thickness: 0.5),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated by MMS App',
              style: pw.TextStyle(
                  font: fontRegular, fontSize: 7, color: _greyLight)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: fontRegular, fontSize: 7, color: _greyLight)),
        ],
      ),
    ]);
  }

  // ── Entry details ─────────────────────────────────────────────────────────
  static pw.Widget _entryDetails(String dcNo, String branch, String location,
      String site, String floor, String villa, String remark, String date,
      pw.Font fontRegular, pw.Font fontBold) {
    final fields = <String, String>{};
    if (dcNo.isNotEmpty)     fields['DC No.']       = dcNo;
    if (branch.isNotEmpty)   fields['Branch']       = branch;
    if (location.isNotEmpty) fields['Location']     = location;
    if (site.isNotEmpty)     fields['Site']         = site;
    if (floor.isNotEmpty)    fields['Floor']        = floor;
    if (villa.isNotEmpty)    fields['Villa / Unit'] = villa;
    if (remark.isNotEmpty)   fields['Description']  = remark;
    fields['Date'] = date;

    final half = (fields.length / 2).ceil();
    final leftEntries  = fields.entries.toList().sublist(0, half);
    final rightEntries = fields.entries.toList().sublist(half);

    pw.Widget kvPair(MapEntry<String, String> e) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(children: [
            pw.SizedBox(
              width: 72,
              child: pw.Text(e.key,
                  style: pw.TextStyle(
                      font: fontRegular, fontSize: 8.5, color: _grey)),
            ),
            pw.Text(': ',
                style: pw.TextStyle(
                    font: fontRegular, fontSize: 8.5, color: _grey)),
            pw.Expanded(
              child: pw.Text(e.value,
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold)),
            ),
          ]),
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeader('ENTRY DETAILS', fontBold),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _bg,
            border: pw.Border.all(color: _border, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                  child:
                      pw.Column(children: leftEntries.map(kvPair).toList())),
              pw.SizedBox(width: 24),
              pw.Expanded(
                  child:
                      pw.Column(children: rightEntries.map(kvPair).toList())),
            ],
          ),
        ),
      ],
    );
  }

  // ── Measurement rows table ────────────────────────────────────────────────
  static pw.Widget _rowsTable(
      List rows, pw.Font fontRegular, pw.Font fontBold) {
    const hdrs = [
      '#', 'Meas. Type', 'Length', 'Width',
      'Nos', 'Total', 'Beam No.', 'Room / Desc'
    ];
    const colW = {
      0: pw.FixedColumnWidth(18),
      1: pw.FlexColumnWidth(2.2),
      2: pw.FlexColumnWidth(1.5),
      3: pw.FlexColumnWidth(1.5),
      4: pw.FlexColumnWidth(0.8),
      5: pw.FlexColumnWidth(1.2),
      6: pw.FlexColumnWidth(1.4),
      7: pw.FlexColumnWidth(2.0),
    };

    pw.Widget cell(String text,
        {pw.TextStyle? style, pw.Alignment align = pw.Alignment.centerLeft}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          alignment: align,
          child: pw.Text(text,
              style: style ??
                  pw.TextStyle(
                      font: fontRegular,
                      fontSize: 7.5,
                      color: PdfColors.black)),
        );

    pw.TextStyle cellStyle({bool bold = false, PdfColor? color}) =>
        pw.TextStyle(
            font: bold ? fontBold : fontRegular,
            fontSize: 7.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeader('MEASUREMENT ROWS  (${rows.length} rows)', fontBold),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _border, width: 0.5),
          columnWidths: colW,
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _bgGreen),
              children: hdrs
                  .map((h) => cell(h,
                      style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _darkGreen)))
                  .toList(),
            ),
            // Data rows
            ...List.generate(rows.length, (i) {
              final r = rows[i];
              final isOpen = (r['type'] ?? 'inside') == 'open';
              // Use ASCII minus to avoid Unicode rendering issues
              final typeLabel = isOpen
                  ? 'OPEN(-)'
                  : ((r['measurementTypeName'] ?? '') as String);
              final total =
                  _fmt((r['total'] as num?)?.toDouble() ?? 0);

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: isOpen
                      ? _redLight
                      : (i.isEven ? PdfColors.white : _rowAlt),
                ),
                children: [
                  cell('${i + 1}',
                      style: cellStyle(color: _grey),
                      align: pw.Alignment.center),
                  cell(typeLabel,
                      style: cellStyle(
                          bold: !isOpen,
                          color: isOpen ? _red : _blue)),
                  cell(_fmtFtIn(r['lFt'] ?? 0, r['lIn'] ?? 0)),
                  cell(_fmtFtIn(r['dFt'] ?? 0, r['dIn'] ?? 0)),
                  cell('${r['nos'] ?? 1}'),
                  cell(total,
                      style: cellStyle(
                          bold: true,
                          color: isOpen ? _red : _green)),
                  cell((r['beamNo'] ?? '') as String),
                  cell((r['room'] ?? '') as String,
                      style: cellStyle(color: _grey)),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── Type summary ──────────────────────────────────────────────────────────
  static pw.Widget _typeSummary(
      Map<String, double> byType, pw.Font fontRegular, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeader('MEASUREMENT TYPE SUMMARY', fontBold),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _border, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _bgGreen),
              children: [
                _tCell('Measurement Type',
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkGreen)),
                _tCell('Total Qty',
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkGreen)),
              ],
            ),
            // Data
            ...byType.entries.toList().asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isEven ? PdfColors.white : _rowAlt),
                children: [
                  _tCell(e.key,
                      style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold)),
                  _tCell(_fmt(e.value),
                      style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: _green)),
                ],
              );
            }),
            // Total row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _greenLight),
              children: [
                _tCell('Total',
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkGreen)),
                _tCell(
                    _fmt(byType.values
                        .fold(0.0, (s, v) => s + v)),
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkGreen)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Financial summary ─────────────────────────────────────────────────────
  static pw.Widget _financialSummary(double net, double rate, double totalAmt,
      double gross, double open, pw.Font fontRegular, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeader('FINANCIAL SUMMARY', fontBold),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _darkGreen,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              if (open > 0) ...[
                _finStat('Gross Qty', _fmt(gross), PdfColors.white,
                    fontRegular, fontBold),
                _finDivider(),
                // ASCII minus instead of Unicode U+2212
                _finStat('Open (-)', _fmt(open),
                    PdfColor.fromHex('FCA5A5'), fontRegular, fontBold),
                _finDivider(),
              ],
              _finStat('Net Qty', _fmt(net), PdfColor.fromHex('86EFAC'),
                  fontRegular, fontBold),
              if (rate > 0) ...[
                _finDivider(),
                _finStat('Rate (Rs.)', _fmt(rate),
                    PdfColor.fromHex('93C5FD'), fontRegular, fontBold),
                _finDivider(),
                _finStat('Total Amount', 'Rs.${_fmt(totalAmt)}',
                    PdfColor.fromHex('FED7AA'), fontRegular, fontBold),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Small helpers ─────────────────────────────────────────────────────────

  static pw.Widget _sectionHeader(String title, pw.Font fontBold) =>
      pw.Row(children: [
        pw.Container(
            width: 3,
            height: 14,
            decoration: pw.BoxDecoration(
                color: _green,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(2)))),
        pw.SizedBox(width: 7),
        pw.Text(title,
            style: pw.TextStyle(
                font: fontBold,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _darkGreen,
                letterSpacing: 0.4)),
      ]);

  static pw.Widget _tCell(String text, {pw.TextStyle? style}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Text(text, style: style),
      );

  static pw.Widget _finStat(String label, String value, PdfColor color,
      pw.Font fontRegular, pw.Font fontBold) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
          pw.SizedBox(height: 4),
          pw.Text(label,
              style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 7.5,
                  color: PdfColor.fromHex('D1FAE5'))),
        ],
      );

  static pw.Widget _finDivider() => pw.Container(
        width: 1,
        height: 36,
        color: PdfColor.fromHex('2E7D52'),
        margin: const pw.EdgeInsets.symmetric(horizontal: 8),
      );

  static String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  static String _fmtFtIn(num ft, num inches) {
    final f = ft.toInt();
    final i = inches.toDouble();
    if (i == 0) return "$f'";
    final iStr = i == i.truncateToDouble()
        ? i.toInt().toString()
        : i.toStringAsFixed(1);
    return "$f'$iStr\"";
  }
}
