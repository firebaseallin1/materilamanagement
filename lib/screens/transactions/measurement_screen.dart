import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/measurement_pdf.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

const _msPrimary = Color(0xFF1B3A27);
const _msBlue = Color(0xFF2E7D52);
const _msGreen = Color(0xFF16A34A);
const _msRed = Color(0xFFDC2626);

// ────────────────────────────────────────────────────────────────────────────
//  Row model (in-memory while editing)
// ────────────────────────────────────────────────────────────────────────────
class _MeasRow {
  final TextEditingController lFtCtrl, lInCtrl; // Length: feet, inches
  final TextEditingController dFtCtrl, dInCtrl; // Depth: feet, inches
  final TextEditingController nosCtrl, totalCtrl, beamCtrl, roomCtrl;
  String type; // 'inside' | 'open'
  String? measurementTypeId;
  String measurementTypeName;

  _MeasRow({this.type = 'inside', this.measurementTypeId, this.measurementTypeName = ''})
      : lFtCtrl  = TextEditingController(),
        lInCtrl  = TextEditingController(text: '0'),
        dFtCtrl  = TextEditingController(),
        dInCtrl  = TextEditingController(text: '0'),
        nosCtrl  = TextEditingController(text: '1'),
        totalCtrl = TextEditingController(),
        beamCtrl  = TextEditingController(),
        roomCtrl  = TextEditingController();

  _MeasRow._raw({
    required this.lFtCtrl,
    required this.lInCtrl,
    required this.dFtCtrl,
    required this.dInCtrl,
    required this.nosCtrl,
    required this.totalCtrl,
    required this.beamCtrl,
    required this.roomCtrl,
    required this.type,
    this.measurementTypeId,
    this.measurementTypeName = '',
  });

  factory _MeasRow.fromMap(Map r) {
    int lFt, dFt;
    double lIn, dIn;
    if (r['lFt'] != null) {
      lFt = (r['lFt'] as num).toInt();
      lIn = (r['lIn'] as num? ?? 0).toDouble();
    } else {
      final l = (r['l'] as num?)?.toDouble() ?? 0;
      lFt = l.floor();
      lIn = ((l - lFt) * 12).clamp(0, 11).toDouble();
    }
    if (r['dFt'] != null) {
      dFt = (r['dFt'] as num).toInt();
      dIn = (r['dIn'] as num? ?? 0).toDouble();
    } else {
      final d = (r['d'] as num?)?.toDouble() ?? 0;
      dFt = d.floor();
      dIn = ((d - dFt) * 12).clamp(0, 11).toDouble();
    }
    return _MeasRow._raw(
      lFtCtrl:   TextEditingController(text: lFt > 0 ? lFt.toString() : ''),
      lInCtrl:   TextEditingController(text: _s(lIn)),
      dFtCtrl:   TextEditingController(text: dFt > 0 ? dFt.toString() : ''),
      dInCtrl:   TextEditingController(text: _s(dIn)),
      nosCtrl:   TextEditingController(text: _s(r['nos'] ?? 1)),
      totalCtrl: TextEditingController(text: _s(r['total'])),
      beamCtrl:  TextEditingController(text: (r['beamNo'] ?? '') as String),
      roomCtrl:  TextEditingController(text: (r['room'] ?? '') as String),
      type:               (r['type'] as String?) ?? 'inside',
      measurementTypeId:  r['measurementTypeId'] as String?,
      measurementTypeName: (r['measurementTypeName'] ?? '') as String,
    );
  }

  static String _s(dynamic v) {
    if (v == null) return '';
    if (v is double && v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
  }

  double get _lDecimal =>
      (double.tryParse(lFtCtrl.text) ?? 0) +
      (double.tryParse(lInCtrl.text) ?? 0) / 12;

  double get _dDecimal =>
      (double.tryParse(dFtCtrl.text) ?? 0) +
      (double.tryParse(dInCtrl.text) ?? 0) / 12;

  void recalcTotal() {
    final l = _lDecimal;
    final d = _dDecimal;
    final nos = double.tryParse(nosCtrl.text) ?? 1;
    if (l > 0 && d > 0) {
      final t = l * d * nos;
      totalCtrl.text = t == t.truncateToDouble()
          ? t.toInt().toString()
          : t.toStringAsFixed(2);
    }
  }

  void dispose() {
    lFtCtrl.dispose();
    lInCtrl.dispose();
    dFtCtrl.dispose();
    dInCtrl.dispose();
    nosCtrl.dispose();
    totalCtrl.dispose();
    beamCtrl.dispose();
    roomCtrl.dispose();
  }

  Map<String, dynamic> toJson() => {
        'lFt':   int.tryParse(lFtCtrl.text) ?? 0,
        'lIn':   double.tryParse(lInCtrl.text) ?? 0.0,
        'dFt':   int.tryParse(dFtCtrl.text) ?? 0,
        'dIn':   double.tryParse(dInCtrl.text) ?? 0.0,
        'l':     _lDecimal,
        'd':     _dDecimal,
        'nos':   double.tryParse(nosCtrl.text) ?? 1,
        'total': double.tryParse(totalCtrl.text) ?? 0,
        'beamNo':              beamCtrl.text.trim(),
        'type':                type,
        'room':                roomCtrl.text.trim(),
        'measurementTypeId':   measurementTypeId,
        'measurementTypeName': measurementTypeName,
      };
}

// ════════════════════════════════════════════════════════════════════════════
//  MEASUREMENT LIST SCREEN
// ════════════════════════════════════════════════════════════════════════════
class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key});
  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  List _items = [];
  bool _loading = true;
  String _search = '';
  String _sortBy = 'date_desc'; // date_desc | date_asc | location_asc | net_desc
  String? _filterLocation;
  String? _filterFloor;
  String? _filterRemark;
  DateTime? _filterFrom, _filterTo;

  // ── unique value helpers ──────────────────────────────────────────────────
  List<String> get _allLocations => (_items
        .map((e) => (e['location'] ?? '').toString())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort());

  List<String> get _allFloors => (_items
        .map((e) => (e['floor'] ?? '').toString())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort());

  List<String> get _allRemarks => (_items
        .map((e) => (e['remark'] ?? '').toString())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort());

  int get _activeFilterCount =>
      [_filterLocation, _filterFloor, _filterRemark].where((v) => v != null).length +
      (_filterFrom != null ? 1 : 0) +
      (_filterTo != null ? 1 : 0);

  void _clearFilters() => setState(() {
        _filterLocation = null;
        _filterFloor = null;
        _filterRemark = null;
        _filterFrom = null;
        _filterTo = null;
      });

  List get _filtered {
    final q = _search.toLowerCase().trim();
    var list = _items.where((e) {
      final matchQ = q.isEmpty ||
          (e['location'] ?? '').toLowerCase().contains(q) ||
          (e['site'] ?? '').toLowerCase().contains(q) ||
          (e['villaNo'] ?? '').toLowerCase().contains(q) ||
          (e['remark'] ?? '').toLowerCase().contains(q) ||
          (e['floor'] ?? '').toLowerCase().contains(q);
      final matchLoc = _filterLocation == null ||
          (e['location'] ?? '') == _filterLocation;
      final matchFloor =
          _filterFloor == null || (e['floor'] ?? '') == _filterFloor;
      final matchRemark =
          _filterRemark == null || (e['remark'] ?? '') == _filterRemark;
      final dt = DateTime.tryParse(e['date'] ?? '');
      final d = dt != null ? DateTime(dt.year, dt.month, dt.day) : null;
      final from = _filterFrom != null
          ? DateTime(_filterFrom!.year, _filterFrom!.month, _filterFrom!.day)
          : null;
      final to = _filterTo != null
          ? DateTime(_filterTo!.year, _filterTo!.month, _filterTo!.day)
          : null;
      final matchD =
          (from == null || (d != null && !d.isBefore(from))) &&
          (to == null || (d != null && !d.isAfter(to)));
      return matchQ && matchLoc && matchFloor && matchRemark && matchD;
    }).toList();

    list.sort((a, b) {
      switch (_sortBy) {
        case 'date_asc':
          return (DateTime.tryParse(a['date'] ?? '') ?? DateTime(0))
              .compareTo(DateTime.tryParse(b['date'] ?? '') ?? DateTime(0));
        case 'location_asc':
          return (a['location'] ?? '').compareTo(b['location'] ?? '');
        case 'net_desc':
          final na = _gross(a) - _openAmt(a);
          final nb = _gross(b) - _openAmt(b);
          return nb.compareTo(na);
        default: // date_desc
          return (DateTime.tryParse(b['date'] ?? '') ?? DateTime(0))
              .compareTo(DateTime.tryParse(a['date'] ?? '') ?? DateTime(0));
      }
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/measurements');
    if (mounted) {
      setState(() {
        _items = res['data'] ?? [];
        _loading = false;
      });
    }
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/measurements/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  void _openForm([Map? item]) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'meas-form',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final sw = MediaQuery.of(ctx).size.width;
        final pw = sw > 900 ? sw * 0.70 : sw;
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              elevation: 20,
              child: SizedBox(
                width: pw,
                height: double.infinity,
                child: MeasurementFormPanel(
                  item: item,
                  onSaved: () {
                    Navigator.of(ctx).pop();
                    _load();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static double _gross(Map item) => (item['rows'] as List? ?? [])
      .where((r) => (r['type'] ?? '') != 'open')
      .fold(0.0, (s, r) => s + ((r['total'] as num?) ?? 0).toDouble());

  static double _openAmt(Map item) => (item['rows'] as List? ?? [])
      .where((r) => (r['type'] ?? '') == 'open')
      .fold(0.0, (s, r) => s + ((r['total'] as num?) ?? 0).toDouble());

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        return Column(children: [
          ScreenHeader(
            title: 'Measurements',
            subtitle: 'Site measurement book entries',
            onRefresh: _load,
            onSearchChanged: (v) => setState(() => _search = v),
            searchHint: 'Search location, site, villa…',
            onAdd: () => _openForm(),
            addLabel: 'New Entry',
          ),
          _buildToolbar(isMobile, rows.length),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: _loading
                ? const AppLoader()
                : rows.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: rows.length,
                        itemBuilder: (_, i) => _buildCard(rows[i], i),
                      ),
          ),
        ]);
      }),
    );
  }

  // ── Sort menu ────────────────────────────────────────────────────────────────
  void _showSortMenu(BuildContext anchorCtx) {
    const options = {
      'date_desc': 'Newest First',
      'date_asc': 'Oldest First',
      'location_asc': 'Location A–Z',
      'net_desc': 'Highest Net Qty',
    };
    final box = anchorCtx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final pos = RelativeRect.fromLTRB(
        offset.dx, offset.dy + box.size.height + 4,
        offset.dx + box.size.width, 0);
    showMenu<String>(
      context: anchorCtx,
      position: pos,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 4,
      items: options.entries.map((e) {
        final active = _sortBy == e.key;
        return PopupMenuItem<String>(
          value: e.key,
          child: Row(children: [
            Icon(
              active
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 15,
              color: active ? _msBlue : const Color(0xFFD1D5DB),
            ),
            const SizedBox(width: 10),
            Text(e.value,
                style: TextStyle(
                    fontSize: 13,
                    color: active ? _msBlue : const Color(0xFF374151),
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.normal)),
          ]),
        );
      }).toList(),
    ).then((val) {
      if (val != null) setState(() => _sortBy = val);
    });
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────
  Widget _buildToolbar(bool isMobile, int count) {
    final fmt = DateFormat('dd MMM yyyy');

    InputDecoration dropDec(String hint, IconData icon) => InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 14, color: _msPrimary),
          hintStyle:
              const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _msPrimary, width: 1.5)),
        );

    Widget dateTile(String hint, DateTime? dt, bool isFrom) =>
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: dt ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                    colorScheme:
                        const ColorScheme.light(primary: _msPrimary)),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() =>
                  isFrom ? _filterFrom = picked : _filterTo = picked);
            }
          },
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: dt != null ? _msPrimary : const Color(0xFFDDE3E0)),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_outlined,
                  size: 13,
                  color: dt != null ? _msPrimary : const Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dt != null ? fmt.format(dt) : hint,
                  style: TextStyle(
                      fontSize: 12,
                      color: dt != null
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF)),
                ),
              ),
              if (dt != null)
                GestureDetector(
                  onTap: () => setState(() =>
                      isFrom ? _filterFrom = null : _filterTo = null),
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: Color(0xFF9CA3AF)),
                ),
            ]),
          ),
        );

    Widget countChip() => Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6)),
          child: Text('$count entries',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280))),
        );

    final sortLabels = {
      'date_desc': 'Newest First',
      'date_asc': 'Oldest First',
      'location_asc': 'Location A–Z',
      'net_desc': 'Highest Net Qty',
    };
    final isSorted = _sortBy != 'date_desc';

    Widget sortBtn(BuildContext ctx) => InkWell(
          onTap: () => _showSortMenu(ctx),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.swap_vert_rounded,
                  size: 14,
                  color: isSorted ? _msBlue : const Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(sortLabels[_sortBy] ?? 'Sort',
                  style: TextStyle(
                      fontSize: 12,
                      color: isSorted
                          ? _msBlue
                          : const Color(0xFF374151),
                      fontWeight: isSorted
                          ? FontWeight.w600
                          : FontWeight.w400)),
            ]),
          ),
        );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Row 1: sort + count
          Row(children: [
            Builder(builder: (ctx) => sortBtn(ctx)),
            const Spacer(),
            countChip(),
          ]),
          const SizedBox(height: 8),
          // Row 2: location + floor
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('loc_$_filterLocation'),
                initialValue: _filterLocation,
                decoration:
                    dropDec('All Locations', Icons.place_outlined),
                isExpanded: true,
                borderRadius: BorderRadius.circular(8),
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF111827)),
                items: [
                  const DropdownMenuItem(
                      value: null,
                      child: Text('All Locations',
                          style:
                              TextStyle(color: Color(0xFF9CA3AF)))),
                  ..._allLocations.map((v) =>
                      DropdownMenuItem(value: v, child: Text(v))),
                ],
                onChanged: (v) =>
                    setState(() => _filterLocation = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('fl_$_filterFloor'),
                initialValue: _filterFloor,
                decoration:
                    dropDec('All Floors', Icons.layers_outlined),
                isExpanded: true,
                borderRadius: BorderRadius.circular(8),
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF111827)),
                items: [
                  const DropdownMenuItem(
                      value: null,
                      child: Text('All Floors',
                          style:
                              TextStyle(color: Color(0xFF9CA3AF)))),
                  ..._allFloors.map((v) =>
                      DropdownMenuItem(value: v, child: Text(v))),
                ],
                onChanged: (v) => setState(() => _filterFloor = v),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // Row 3: remark + date range
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('rm_$_filterRemark'),
                initialValue: _filterRemark,
                decoration:
                    dropDec('All Work Types', Icons.notes_rounded),
                isExpanded: true,
                borderRadius: BorderRadius.circular(8),
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF111827)),
                items: [
                  const DropdownMenuItem(
                      value: null,
                      child: Text('All Work Types',
                          style:
                              TextStyle(color: Color(0xFF9CA3AF)))),
                  ..._allRemarks.map((v) =>
                      DropdownMenuItem(value: v, child: Text(v))),
                ],
                onChanged: (v) =>
                    setState(() => _filterRemark = v),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: dateTile('From date', _filterFrom, true)),
            const SizedBox(width: 8),
            Expanded(child: dateTile('To date', _filterTo, false)),
            if (_activeFilterCount > 0) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _clearFilters,
                child: const Icon(Icons.close_rounded,
                    size: 18, color: Color(0xFF9CA3AF)),
              ),
            ],
          ]),
        ]),
      );
    }

    // Desktop: single row
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
        Builder(builder: (ctx) => sortBtn(ctx)),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('loc_$_filterLocation'),
            initialValue: _filterLocation,
            decoration: dropDec('All Locations', Icons.place_outlined),
            isExpanded: true,
            borderRadius: BorderRadius.circular(8),
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('All Locations',
                      style: TextStyle(color: Color(0xFF9CA3AF)))),
              ..._allLocations
                  .map((v) => DropdownMenuItem(value: v, child: Text(v))),
            ],
            onChanged: (v) => setState(() => _filterLocation = v),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('fl_$_filterFloor'),
            initialValue: _filterFloor,
            decoration: dropDec('All Floors', Icons.layers_outlined),
            isExpanded: true,
            borderRadius: BorderRadius.circular(8),
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('All Floors',
                      style: TextStyle(color: Color(0xFF9CA3AF)))),
              ..._allFloors
                  .map((v) => DropdownMenuItem(value: v, child: Text(v))),
            ],
            onChanged: (v) => setState(() => _filterFloor = v),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('rm_$_filterRemark'),
            initialValue: _filterRemark,
            decoration: dropDec('All Work Types', Icons.notes_rounded),
            isExpanded: true,
            borderRadius: BorderRadius.circular(8),
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('All Work Types',
                      style: TextStyle(color: Color(0xFF9CA3AF)))),
              ..._allRemarks
                  .map((v) => DropdownMenuItem(value: v, child: Text(v))),
            ],
            onChanged: (v) => setState(() => _filterRemark = v),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: dateTile('From date', _filterFrom, true)),
        const SizedBox(width: 10),
        Expanded(child: dateTile('To date', _filterTo, false)),
        if (_activeFilterCount > 0) ...[
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.close_rounded, size: 13),
            label:
                const Text('Clear', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10),
            ),
          ),
        ],
        const SizedBox(width: 10),
        countChip(),
      ]),
    );
  }

  Color _accentColor(int i) {
    const p = [
      Color(0xFF16A34A),
      Color(0xFF2E7D52),
      Color(0xFF0D9488),
      Color(0xFF8B5CF6),
      Color(0xFFEA580C),
      Color(0xFFDB2777),
    ];
    return p[i % p.length];
  }

  Widget _buildCard(Map item, int i) {
    final color = _accentColor(i);
    final date = item['date'] != null
        ? DateFormat('dd MMM yyyy')
            .format(DateTime.parse(item['date'] as String))
        : '—';
    final dcNo    = (item['dcNo'] as String? ?? '');
    final location = (item['location'] as String? ?? '—');
    final site = (item['site'] as String? ?? '');
    final floor = (item['floor'] as String? ?? '');
    final villa = (item['villaNo'] as String? ?? '');
    final remark = (item['remark'] as String? ?? '');
    final allRows = (item['rows'] as List? ?? []);
    final gross = _gross(item);
    final openVal = _openAmt(item);
    final net = gross - openVal;
    final rate = (item['amount'] as num?)?.toDouble() ?? 0;
    final totalValue = (item['totalAmount'] as num?)?.toDouble() ??
        (rate > 0 ? net * rate : 0);
    final insideCount =
        allRows.where((r) => (r['type'] ?? '') != 'open').length;
    final openCount = allRows.where((r) => (r['type'] ?? '') == 'open').length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: null,
          borderRadius: BorderRadius.circular(10),
          hoverColor: const Color(0xFFF0F9F4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 4, color: color),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── Row 1: date | dcNo | location | menu ──
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(date,
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: color)),
                                  ),
                                  if (dcNo.isNotEmpty) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Text('DC $dcNo',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2563EB))),
                                    ),
                                  ],
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(location,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827)),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  _actionMenu(item),
                                ]),
                                if (site.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(children: [
                                      const Icon(Icons.location_on_outlined,
                                          size: 10, color: Color(0xFF9CA3AF)),
                                      const SizedBox(width: 3),
                                      Text(site,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6B7280))),
                                    ]),
                                  ),
                                const SizedBox(height: 6),
                                // ── Row 2: chips | net qty + total amt ─
                                Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      if (floor.isNotEmpty)
                                        _chip(Icons.layers_outlined, floor),
                                      if (villa.isNotEmpty) ...[
                                        const SizedBox(width: 4),
                                        _chip(Icons.home_outlined, 'Villa $villa'),
                                      ],
                                      if (remark.isNotEmpty) ...[
                                        const SizedBox(width: 4),
                                        _chip(Icons.notes_rounded, remark),
                                      ],
                                      const Spacer(),
                                      // Net qty and Total Amt side by side
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(_fmtQ(net),
                                                  style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: _msGreen)),
                                              const Text('Net qty',
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      color: Color(0xFF9CA3AF))),
                                            ],
                                          ),
                                          if (totalValue > 0) ...[
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              width: 1,
                                              height: 28,
                                              color: const Color(0xFFE5E7EB),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('₹${_fmtQ(totalValue)}',
                                                    style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFFEA580C))),
                                                const Text('Total Amt',
                                                    style: TextStyle(
                                                        fontSize: 9,
                                                        color: Color(0xFF9CA3AF))),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ]),
                                if (allRows.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    _statBadge('$insideCount inside', _msGreen),
                                    if (openCount > 0) ...[
                                      const SizedBox(width: 4),
                                      _statBadge('$openCount open(-)', _msRed),
                                    ],
                                    const Spacer(),
                                    if (openVal > 0)
                                      Text(
                                        '${_fmtQ(gross)} - ${_fmtQ(openVal)}',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF9CA3AF)),
                                      ),
                                  ]),
                                ],
                              ]),
                        ),
                      ),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: const Color(0xFF6B7280)),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
        ]),
      );

  Widget _statBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(5)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      );

  Widget _actionMenu(Map item) {
    final isAdmin = context.read<AuthService>().isAdmin;
    return SizedBox(
        width: 30,
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded,
              size: 16, color: Color(0xFF9CA3AF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 3,
          itemBuilder: (_) => [
            if (isAdmin) const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 14, color: Color(0xFF374151)),
                  SizedBox(width: 8),
                  Text('Edit', style: TextStyle(fontSize: 13)),
                ])),
            const PopupMenuItem(
                value: 'pdf',
                child: Row(children: [
                  Icon(Icons.picture_as_pdf_outlined,
                      size: 14, color: Color(0xFF1B3A27)),
                  SizedBox(width: 8),
                  Text('Print / PDF', style: TextStyle(fontSize: 13)),
                ])),
            if (isAdmin) const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 14, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Text('Delete',
                      style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                ])),
          ],
          onSelected: (v) async {
            if (v == 'edit') { _openForm(item); return; }
            if (v == 'delete') { _delete(item['_id'] as String); return; }
            if (v == 'pdf') {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14))),
                  contentPadding: EdgeInsets.fromLTRB(24, 24, 24, 20),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D52))),
                      SizedBox(height: 20),
                      Text('Generating PDF…',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1B3A27))),
                      SizedBox(height: 6),
                      Text('Please wait',
                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
              );
              try {
                await MeasurementPdf.generate(item);
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('PDF error: $e'),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
                return;
              }
              if (mounted) Navigator.of(context).pop();
            }
          },
        ),
      );
  }

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(16)),
            child:
                const Icon(Icons.straighten_rounded, size: 28, color: _msGreen),
          ),
          const SizedBox(height: 14),
          const Text('No measurements yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827))),
          const SizedBox(height: 4),
          const Text('Add your first measurement entry to get started.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('New Entry', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _msPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  MEASUREMENT FORM SCREEN
// ════════════════════════════════════════════════════════════════════════════
class MeasurementFormScreen extends StatefulWidget {
  final Map? item;
  final VoidCallback? onSaved;
  const MeasurementFormScreen({super.key, this.item, this.onSaved});
  @override
  State<MeasurementFormScreen> createState() => _MeasurementFormScreenState();
}

class _MeasurementFormScreenState extends State<MeasurementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  List _branches = [];
  List _measTypes = [];
  String? _branchId;
  final _locationCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _villaCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  final List<_MeasRow> _rows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _loadMeasTypes();
    final e = widget.item;
    if (e != null) {
      _branchId = e['branch']?['_id'] as String?;
      _locationCtrl.text = (e['location'] ?? '') as String;
      _siteCtrl.text = (e['site'] ?? '') as String;
      _floorCtrl.text = (e['floor'] ?? '') as String;
      _villaCtrl.text = (e['villaNo'] ?? '') as String;
      _remarkCtrl.text = (e['remark'] ?? '') as String;
      final amt = (e['amount'] as num?)?.toDouble() ?? 0;
      if (amt > 0) _amountCtrl.text = _MeasRow._s(amt);
      if (e['date'] != null) _date = DateTime.parse(e['date'] as String);
      for (final r in (e['rows'] as List? ?? [])) {
        _rows.add(_MeasRow.fromMap(r as Map));
      }
    }
    if (_rows.isEmpty) _addRow();
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _siteCtrl.dispose();
    _floorCtrl.dispose();
    _villaCtrl.dispose();
    _remarkCtrl.dispose();
    _amountCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches');
    if (mounted) setState(() => _branches = res['data'] ?? []);
  }

  Future<void> _loadMeasTypes() async {
    final res = await ApiService.get('/measurement-types');
    if (mounted) setState(() => _measTypes = res['data'] ?? []);
  }

  void _onBranchChanged(String? id) {
    setState(() => _branchId = id);
    if (id == null) return;
    final branch = _branches.firstWhere(
        (b) => b['_id'] == id, orElse: () => {});
    if (branch.isEmpty) return;
    final locationObj = branch['location'];
    final loc = locationObj is Map
        ? ((locationObj['name'] ?? locationObj['address'] ?? '') as String).trim()
        : '';
    if (loc.isNotEmpty) setState(() => _locationCtrl.text = loc);
  }

  void _addRow([String type = 'inside']) =>
      setState(() => _rows.add(_MeasRow(type: type)));

  void _removeRow(int i) {
    _rows[i].dispose();
    setState(() => _rows.removeAt(i));
  }

  double get _grossTotal => _rows
      .where((r) => r.type != 'open')
      .fold(0.0, (s, r) => s + (double.tryParse(r.totalCtrl.text) ?? 0));

  double get _openTotal => _rows
      .where((r) => r.type == 'open')
      .fold(0.0, (s, r) => s + (double.tryParse(r.totalCtrl.text) ?? 0));

  double get _netTotal => _grossTotal - _openTotal;
  double get _totalValue =>
      _netTotal * (double.tryParse(_amountCtrl.text) ?? 0);

  Future<void> _save() async {
    if (_measTypes.isNotEmpty) {
      final untyped = _rows
          .where((r) => r.type != 'open' && r.measurementTypeId == null)
          .length;
      if (untyped > 0) {
        showSnack(context,
            'Select a Measurement Type for every inside row ($untyped row${untyped > 1 ? 's' : ''} missing)',
            error: true);
        return;
      }
    }
    setState(() => _saving = true);
    final rate = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final body = {
      if (_branchId != null) 'branch': _branchId,
      'location': _locationCtrl.text.trim(),
      'site': _siteCtrl.text.trim(),
      'floor': _floorCtrl.text.trim(),
      'villaNo': _villaCtrl.text.trim(),
      'remark': _remarkCtrl.text.trim(),
      'amount': rate,
      'totalAmount': _netTotal * rate,
      'date': _date.toIso8601String(),
      'rows': _rows.map((r) => r.toJson()).toList(),
    };
    final res = widget.item == null
        ? await ApiService.post('/measurements', body)
        : await ApiService.put('/measurements/${widget.item!['_id']}', body);
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Saved!' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) {
        widget.onSaved?.call();
        Navigator.pop(context);
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  // ── Input decorations ─────────────────────────────────────────────────────

  InputDecoration _fieldDec(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, size: 16, color: _msBlue)
            : null,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        filled: true,
        fillColor: const Color(0xFFF7F9F8),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _msPrimary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      );

  InputDecoration _rowDec(String hint, {Color? fill}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
        filled: true,
        fillColor: fill ?? Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _msBlue, width: 1.2)),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: _msPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              widget.item == null
                  ? 'New Measurement Entry'
                  : 'Edit Measurement',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          Text(DateFormat('dd MMM yyyy').format(_date),
              style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton(
                onPressed: _save,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7)),
                ),
                child: const Text('Save',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 12),
            _buildRowsSection(),
            const SizedBox(height: 12),
            _buildTypeSummaryCard(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SafeArea(
          child: Row(children: [
            Expanded(child: _summaryMini()),
            const SizedBox(width: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _msPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Entry',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      );

  Widget _summaryMini() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    return Row(children: [
      _miniStat('Net', _netTotal, _msGreen),
      if (amount > 0) ...[
        const SizedBox(width: 8),
        const Text('×',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        const SizedBox(width: 8),
        _miniStat('Rate', amount, _msBlue),
        const SizedBox(width: 8),
        const Text('=',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        const SizedBox(width: 8),
        _miniStat('Total', _totalValue, const Color(0xFFEA580C)),
      ],
    ]);
  }

  Widget _miniStat(String label, double val, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_fmtQ(val),
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
      ]);

  // ── Header card ───────────────────────────────────────────────────────────
  // Left-page of the diary: Location, Site, Floor, Villa, Remark, Date

  Widget _buildHeaderCard() => _card(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(builder: (context, cs) {
          final isMobile = cs.maxWidth < 480;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionTitle('Site Details', Icons.location_city_outlined),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _branches.isEmpty
                    ? const SizedBox(
                        height: 48, child: Center(child: AppLoader()))
                    : DropdownButtonFormField<String>(
                        key: ValueKey('branch_$_branchId'),
                        initialValue: _branchId,
                        decoration:
                            _fieldDec('Branch', icon: Icons.store_outlined),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF1A1A2E)),
                        borderRadius: BorderRadius.circular(8),
                        isExpanded: true,
                        items: _branches
                            .map<DropdownMenuItem<String>>((b) =>
                                DropdownMenuItem(
                                    value: b['_id'] as String,
                                    child: Text(b['name'] as String)))
                            .toList(),
                        onChanged: _onBranchChanged,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DatePickerField(
                  label: 'Date',
                  value: _date,
                  onChanged: (d) => setState(() => _date = d),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _locationCtrl,
                  decoration: _fieldDec('Location', icon: Icons.place_outlined),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _siteCtrl,
                  decoration:
                      _fieldDec('Site Name', icon: Icons.business_outlined),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            if (isMobile) ...[
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _floorCtrl,
                    decoration: _fieldDec('Floor', icon: Icons.layers_outlined),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _villaCtrl,
                    decoration: _fieldDec('Villa / Unit No.',
                        icon: Icons.home_outlined),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextFormField(
                controller: _remarkCtrl,
                decoration: _fieldDec('Remark / Work type',
                    icon: Icons.notes_rounded),
                style: const TextStyle(fontSize: 13),
              ),
            ] else
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _floorCtrl,
                    decoration: _fieldDec('Floor', icon: Icons.layers_outlined),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _villaCtrl,
                    decoration: _fieldDec('Villa / Unit No.',
                        icon: Icons.home_outlined),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _remarkCtrl,
                    decoration: _fieldDec('Remark / Work type',
                        icon: Icons.notes_rounded),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            const SizedBox(height: 10),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: _fieldDec('Rate per unit (₹)',
                  icon: Icons.currency_rupee_outlined),
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => setState(() {}),
            ),
          ]);
        }),
      );

  // ── Measurement rows section ──────────────────────────────────────────────
  // Right-page of the diary: S.No, L, D, Nos, Total, Beam No., Type, Room

  Widget _buildRowsSection() => _card(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Row(children: [
              Expanded(child: _sectionTitle('Measurement Rows', Icons.table_rows_outlined)),
              const SizedBox(width: 8),
              _addRowBtn('Add Row', 'inside', _msGreen),
              const SizedBox(width: 6),
              _addRowBtn('+ Open(-)', 'open', _msRed),
            ]),
          ),
          LayoutBuilder(builder: (ctx, cs) {
            const minW = 680.0;
            final tableBody = Column(children: [
              _buildColumnHeaders(),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              if (_rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: Text(
                          'No rows yet. Tap Add Row or + Open(-) to add.',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF9CA3AF)))),
                )
              else
                ...List.generate(_rows.length, _buildRowItem),
              const SizedBox(height: 8),
            ]);
            if (cs.maxWidth < minW) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: minW, child: tableBody),
              );
            }
            return tableBody;
          }),
        ]),
      );

  Widget _addRowBtn(String label, String type, Color color) => TextButton(
        onPressed: () => _addRow(type),
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      );

  Widget _buildColumnHeaders() => Container(
        color: const Color(0xFFF0F9F4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          SizedBox(width: 28, child: Text('#', style: _hdr())),
          Expanded(flex: 6, child: Text('Length (ft)', style: _hdr())),
          const SizedBox(width: 3),
          Expanded(flex: 4, child: Text('(in)', style: _hdr())),
          const SizedBox(width: 4),
          Expanded(flex: 6, child: Text('Depth (ft)', style: _hdr())),
          const SizedBox(width: 3),
          Expanded(flex: 4, child: Text('(in)', style: _hdr())),
          const SizedBox(width: 4),
          Expanded(flex: 5, child: Text('Nos', style: _hdr())),
          const SizedBox(width: 4),
          Expanded(flex: 9, child: Text('Total', style: _hdr())),
          const SizedBox(width: 4),
          Expanded(flex: 10, child: Text('Beam No.', style: _hdr())),
          const SizedBox(width: 4),
          Expanded(flex: 10, child: Text('Meas. Type', style: _hdr())),
          const SizedBox(width: 28),
        ]),
      );

  TextStyle _hdr() => const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: Color(0xFF9CA3AF),
      letterSpacing: 0.3);

  Widget _buildRowItem(int i) {
    final row = _rows[i];
    final isOpen = row.type == 'open';

    return Container(
      decoration: BoxDecoration(
        color: isOpen
            ? const Color(0xFFFFF5F5)
            : (i % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA)),
        border: const Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Column(children: [
        // Main row
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 6, 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(
              width: 28,
              child: Text('${i + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isOpen ? _msRed : const Color(0xFF6B7280))),
            ),
            // Length ft
            Expanded(
              flex: 6,
              child: TextFormField(
                controller: row.lFtCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _rowDec('ft'),
                style: const TextStyle(fontSize: 12),
                onChanged: (_) { row.recalcTotal(); setState(() {}); },
              ),
            ),
            const SizedBox(width: 3),
            // Length in
            Expanded(
              flex: 4,
              child: TextFormField(
                controller: row.lInCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: _rowDec('in'),
                style: const TextStyle(fontSize: 12),
                onChanged: (_) { row.recalcTotal(); setState(() {}); },
              ),
            ),
            const SizedBox(width: 4),
            // Depth ft
            Expanded(
              flex: 6,
              child: TextFormField(
                controller: row.dFtCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _rowDec('ft'),
                style: const TextStyle(fontSize: 12),
                onChanged: (_) { row.recalcTotal(); setState(() {}); },
              ),
            ),
            const SizedBox(width: 3),
            // Depth in
            Expanded(
              flex: 4,
              child: TextFormField(
                controller: row.dInCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: _rowDec('in'),
                style: const TextStyle(fontSize: 12),
                onChanged: (_) { row.recalcTotal(); setState(() {}); },
              ),
            ),
            const SizedBox(width: 4),
            // Nos
            Expanded(
              flex: 5,
              child: TextFormField(
                controller: row.nosCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                ],
                decoration: _rowDec('Nos'),
                style: const TextStyle(fontSize: 12),
                onChanged: (_) { row.recalcTotal(); setState(() {}); },
              ),
            ),
            const SizedBox(width: 4),
            // Total (auto or manual)
            Expanded(
              flex: 9,
              child: TextFormField(
                controller: row.totalCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                ],
                decoration: _rowDec('Total',
                    fill: isOpen
                        ? const Color(0xFFFFEDED)
                        : const Color(0xFFF0FDF4)),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOpen ? _msRed : _msBlue),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 4),
            // Beam No.
            Expanded(
              flex: 10,
              child: TextFormField(
                controller: row.beamCtrl,
                decoration: _rowDec('Beam No.'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 4),
            // Measurement Type dropdown (inside rows) or OPEN label
            Expanded(
              flex: 10,
              child: isOpen
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 7),
                      decoration: BoxDecoration(
                        color: _msRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _msRed.withValues(alpha: 0.3)),
                      ),
                      child: const Center(
                        child: Text('OPEN(-)',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _msRed)),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      key: ValueKey('mt_${i}_${row.measurementTypeId}'),
                      initialValue: row.measurementTypeId,
                      decoration: _rowDec('— select —'),
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(6),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF111827)),
                      items: [
                        const DropdownMenuItem<String>(
                            value: null,
                            child: Text('— select —',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF9CA3AF)))),
                        // Ensure current value is present even if types not loaded yet
                        if (row.measurementTypeId != null &&
                            !_measTypes.any(
                                (t) => t['_id'] == row.measurementTypeId))
                          DropdownMenuItem<String>(
                              value: row.measurementTypeId,
                              child: Text(
                                  row.measurementTypeName.isNotEmpty
                                      ? row.measurementTypeName
                                      : row.measurementTypeId!,
                                  style: const TextStyle(fontSize: 11))),
                        ..._measTypes.map((t) => DropdownMenuItem<String>(
                              value: t['_id'] as String,
                              child: Text(t['name'] as String,
                                  style: const TextStyle(fontSize: 11)),
                            )),
                      ],
                      onChanged: (v) => setState(() {
                        _rows[i].measurementTypeId = v;
                        _rows[i].measurementTypeName = v == null
                            ? ''
                            : (_measTypes.firstWhere(
                                    (t) => t['_id'] == v,
                                    orElse: () => {})['name']
                                as String? ??
                                '');
                      }),
                    ),
            ),
            // Delete
            SizedBox(
              width: 28,
              child: IconButton(
                onPressed: () => _removeRow(i),
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    size: 16, color: Color(0xFFDC2626)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ]),
        ),
        // Room / Description sub-row
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 0, 36, 7),
          child: TextFormField(
            controller: row.roomCtrl,
            decoration: _rowDec('Room / Description (optional)'),
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ]),
    );
  }

  // ── Type summary ─────────────────────────────────────────────────────────

  Widget _buildTypeSummaryCard() {
    final Map<String, double> byType = {};
    for (final row in _rows) {
      if (row.type == 'open') continue;
      final qty = double.tryParse(row.totalCtrl.text) ?? 0;
      if (qty == 0 || row.measurementTypeName.isEmpty) continue;
      byType[row.measurementTypeName] =
          (byType[row.measurementTypeName] ?? 0) + qty;
    }
    if (byType.isEmpty) return const SizedBox.shrink();

    return _card(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('By Measurement Type', Icons.pie_chart_outline_rounded),
        const SizedBox(height: 8),
        ...byType.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: _msGreen, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(e.key,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151)))),
                Text(_fmtQ(e.value),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _msBlue)),
              ]),
            )),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
          ],
        ),
        padding: padding,
        child: child,
      );

  Widget _sectionTitle(String text, IconData icon) => Row(children: [
        Icon(icon, size: 14, color: _msPrimary),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151))),
        const SizedBox(width: 8),
        const Expanded(child: Divider(thickness: 1, color: Color(0xFFE5E7EB))),
      ]);
}

// ════════════════════════════════════════════════════════════════════════════
//  MEASUREMENT FORM PANEL  (slide-in dialog version)
// ════════════════════════════════════════════════════════════════════════════
class MeasurementFormPanel extends StatefulWidget {
  final Map? item;
  final VoidCallback onSaved;
  const MeasurementFormPanel({super.key, this.item, required this.onSaved});
  @override
  State<MeasurementFormPanel> createState() => _MeasurementFormPanelState();
}

class _MeasurementFormPanelState extends State<MeasurementFormPanel> {
  final _formKey = GlobalKey<FormState>();
  List _branches = [];
  List _measTypes = [];
  String? _branchId;
  final _locationCtrl = TextEditingController();
  final _siteCtrl     = TextEditingController();
  final _floorCtrl    = TextEditingController();
  final _villaCtrl    = TextEditingController();
  final _remarkCtrl   = TextEditingController();
  final _amountCtrl   = TextEditingController();
  DateTime _date = DateTime.now();
  final List<_MeasRow> _rows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _loadMeasTypes();
    final e = widget.item;
    if (e != null) {
      _branchId         = e['branch']?['_id'] as String?;
      _locationCtrl.text = (e['location'] ?? '') as String;
      _siteCtrl.text     = (e['site']     ?? '') as String;
      _floorCtrl.text    = (e['floor']    ?? '') as String;
      _villaCtrl.text    = (e['villaNo']  ?? '') as String;
      _remarkCtrl.text   = (e['remark']   ?? '') as String;
      final amt = (e['amount'] as num?)?.toDouble() ?? 0;
      if (amt > 0) _amountCtrl.text = _MeasRow._s(amt);
      if (e['date'] != null) _date = DateTime.parse(e['date'] as String);
      for (final r in (e['rows'] as List? ?? [])) {
        _rows.add(_MeasRow.fromMap(r as Map));
      }
    }
    if (_rows.isEmpty) _addRow();
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _siteCtrl.dispose();
    _floorCtrl.dispose();
    _villaCtrl.dispose();
    _remarkCtrl.dispose();
    _amountCtrl.dispose();
    for (final r in _rows) { r.dispose(); }
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches');
    if (mounted) setState(() => _branches = res['data'] ?? []);
  }

  Future<void> _loadMeasTypes() async {
    final res = await ApiService.get('/measurement-types');
    if (mounted) setState(() => _measTypes = res['data'] ?? []);
  }

  void _onBranchChanged(String? id) {
    setState(() => _branchId = id);
    if (id == null) return;
    final branch = _branches.firstWhere(
        (b) => b['_id'] == id, orElse: () => {});
    if (branch.isEmpty) return;
    final locationObj = branch['location'];
    final loc = locationObj is Map
        ? ((locationObj['name'] ?? locationObj['address'] ?? '') as String).trim()
        : '';
    if (loc.isNotEmpty) setState(() => _locationCtrl.text = loc);
  }

  void _addRow([String type = 'inside']) =>
      setState(() => _rows.add(_MeasRow(type: type)));

  void _removeRow(int i) {
    _rows[i].dispose();
    setState(() => _rows.removeAt(i));
  }

  double get _grossTotal => _rows
      .where((r) => r.type != 'open')
      .fold(0.0, (s, r) => s + (double.tryParse(r.totalCtrl.text) ?? 0));

  double get _openTotal => _rows
      .where((r) => r.type == 'open')
      .fold(0.0, (s, r) => s + (double.tryParse(r.totalCtrl.text) ?? 0));

  double get _netTotal => _grossTotal - _openTotal;
  double get _totalValue =>
      _netTotal * (double.tryParse(_amountCtrl.text) ?? 0);

  Future<void> _save() async {
    if (_measTypes.isNotEmpty) {
      final untyped = _rows
          .where((r) => r.type != 'open' && r.measurementTypeId == null)
          .length;
      if (untyped > 0) {
        showSnack(context,
            'Select a Measurement Type for every inside row ($untyped row${untyped > 1 ? 's' : ''} missing)',
            error: true);
        return;
      }
    }
    setState(() => _saving = true);
    final rate = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final body = {
      if (_branchId != null) 'branch': _branchId,
      'location': _locationCtrl.text.trim(),
      'site':     _siteCtrl.text.trim(),
      'floor':    _floorCtrl.text.trim(),
      'villaNo':  _villaCtrl.text.trim(),
      'remark':   _remarkCtrl.text.trim(),
      'amount':   rate,
      'totalAmount': _netTotal * rate,
      'date': _date.toIso8601String(),
      'rows': _rows.map((r) => r.toJson()).toList(),
    };
    final res = widget.item == null
        ? await ApiService.post('/measurements', body)
        : await ApiService.put('/measurements/${widget.item!['_id']}', body);
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Saved!' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) widget.onSaved();
    }
    if (mounted) setState(() => _saving = false);
  }

  // ── Decorations ───────────────────────────────────────────────────────────

  InputDecoration _fd(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, size: 15, color: _msBlue)
            : null,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        filled: true,
        fillColor: const Color(0xFFF7F9F8),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _msPrimary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      );

  InputDecoration _rd(String hint, {Color? fill}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
        filled: true,
        fillColor: fill ?? Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: _msBlue, width: 1.2)),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return Column(children: [
      // ── Gradient header ──────────────────────────────────────────────────
      const SizedBox(height: 10),
      Container(
        width: 36, height: 4,
        decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2)),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_msPrimary, Color(0xFF1E6F5C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.straighten_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(isEdit ? 'Edit Measurement' : 'New Measurement Entry',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(DateFormat('dd MMM yyyy').format(_date),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11)),
            ]),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.close, color: Colors.white70, size: 16),
            ),
          ),
        ]),
      ),
      // ── Scrollable form ──────────────────────────────────────────────────
      Expanded(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _buildSiteSection(),
              const SizedBox(height: 12),
              _buildTableSection(),
              const SizedBox(height: 12),
              _buildTypeSummaryCard(),
            ],
          ),
        ),
      ),
      // ── Bottom save bar ──────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SafeArea(
          child: Row(children: [
            Expanded(child: _miniSummary()),
            const SizedBox(width: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _msPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Update Entry' : 'Save Entry',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _miniSummary() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    return Row(children: [
      _mStat('Net', _netTotal, _msGreen),
      if (amount > 0) ...[
        const SizedBox(width: 6),
        const Text('×', style: TextStyle(color: Color(0xFF9CA3AF))),
        const SizedBox(width: 6),
        _mStat('Rate', amount, _msBlue),
        const SizedBox(width: 6),
        const Text('=', style: TextStyle(color: Color(0xFF9CA3AF))),
        const SizedBox(width: 6),
        _mStat('Total', _totalValue, const Color(0xFFEA580C)),
      ],
    ]);
  }

  Widget _mStat(String label, double val, Color c) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_fmtQ(val),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: c)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
      ]);

  // ── Site details section ──────────────────────────────────────────────────

  Widget _buildSiteSection() => _card(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(builder: (context, cs) {
          final isMobile = cs.maxWidth < 480;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _secTitle('Site Details', Icons.location_city_outlined),
            const SizedBox(height: 10),
            // Branch + Date
            Row(children: [
              Expanded(
                child: _branches.isEmpty
                    ? const SizedBox(height: 46,
                        child: Center(child: AppLoader()))
                    : DropdownButtonFormField<String>(
                        key: ValueKey('br_$_branchId'),
                        initialValue: _branchId,
                        decoration: _fd('Branch', icon: Icons.store_outlined),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                        borderRadius: BorderRadius.circular(8),
                        isExpanded: true,
                        items: _branches.map<DropdownMenuItem<String>>((b) =>
                            DropdownMenuItem(
                                value: b['_id'] as String,
                                child: Text(b['name'] as String))).toList(),
                        onChanged: _onBranchChanged,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DatePickerField(
                  label: 'Date',
                  value: _date,
                  onChanged: (d) => setState(() => _date = d),
                ),
              ),
            ]),
            const SizedBox(height: 9),
            // Location + Site
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _locationCtrl,
                  decoration: _fd('Location', icon: Icons.place_outlined),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _siteCtrl,
                  decoration: _fd('Site Name', icon: Icons.business_outlined),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ]),
            const SizedBox(height: 9),
            // Floor + Villa + Remark — stack on narrow screens
            if (isMobile) ...[
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _floorCtrl,
                    decoration: _fd('Floor', icon: Icons.layers_outlined),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _villaCtrl,
                    decoration: _fd('Villa / Unit No.', icon: Icons.home_outlined),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ]),
              const SizedBox(height: 9),
              TextFormField(
                controller: _remarkCtrl,
                decoration: _fd('Remark / Work type', icon: Icons.notes_rounded),
                style: const TextStyle(fontSize: 13),
              ),
            ] else
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _floorCtrl,
                    decoration: _fd('Floor', icon: Icons.layers_outlined),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _villaCtrl,
                    decoration: _fd('Villa / Unit No.', icon: Icons.home_outlined),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _remarkCtrl,
                    decoration: _fd('Remark / Work type', icon: Icons.notes_rounded),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            const SizedBox(height: 9),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: _fd('Rate per unit (₹)',
                  icon: Icons.currency_rupee_outlined),
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => setState(() {}),
            ),
          ]);
        }),
      );

  // ── Measurement table section ─────────────────────────────────────────────
  // Matches diary right-page: S.No | L | D | Nos | Total | Beam No. | Type

  Widget _buildTableSection() => _card(
        padding: EdgeInsets.zero,
        child: Column(children: [
          // Header bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 10, 8),
            child: Row(children: [
              Expanded(child: _secTitle('Measurement Rows', Icons.table_rows_outlined)),
              const SizedBox(width: 8),
              _addBtn('Add Row', 'inside', _msGreen),
              const SizedBox(width: 6),
              _addBtn('+ Open(-)', 'open', _msRed),
            ]),
          ),
          LayoutBuilder(builder: (ctx, cs) {
            const minW = 680.0;
            final tableBody = Column(children: [
              // Column headers — diary right-page style
              Container(
                color: const Color(0xFFF0F9F4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(children: [
                  _th('#', 28),
                  _thF('Length (ft)', 6),
                  const SizedBox(width: 3),
                  _thF('(in)', 4),
                  _gap(),
                  _thF('Depth (ft)', 6),
                  const SizedBox(width: 3),
                  _thF('(in)', 4),
                  _gap(),
                  _thF('Nos', 5),
                  _gap(),
                  _thF('Total', 9),
                  _gap(),
                  _thF('Beam No.', 10),
                  _gap(),
                  _thF('Meas. Type', 10),
                  const SizedBox(width: 26),
                ]),
              ),
              const Divider(height: 1, color: Color(0xFFDDE3E0)),
              // Rows
              if (_rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                      child: Text(
                          'No rows yet — tap Add Row or + Open(-) to begin.',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF9CA3AF)))),
                )
              else
                ...List.generate(_rows.length, _buildRow),
              const SizedBox(height: 6),
            ]);
            if (cs.maxWidth < minW) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: minW, child: tableBody),
              );
            }
            return tableBody;
          }),
        ]),
      );

  Widget _th(String t, double w) => SizedBox(
      width: w,
      child: Text(t, style: _hdrSty(), textAlign: TextAlign.center));
  Widget _thF(String t, int flex) =>
      Expanded(flex: flex, child: Text(t, style: _hdrSty()));
  Widget _gap() => const SizedBox(width: 4);
  TextStyle _hdrSty() => const TextStyle(
      fontSize: 10, fontWeight: FontWeight.w700,
      color: Color(0xFF6B7280), letterSpacing: 0.3);

  Widget _addBtn(String label, String type, Color color) => TextButton(
        onPressed: () => _addRow(type),
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      );

  Widget _buildRow(int i) {
    final row = _rows[i];
    final isOpen = row.type == 'open';

    return Container(
      decoration: BoxDecoration(
        color: isOpen
            ? const Color(0xFFFFF5F5)
            : (i.isEven ? Colors.white : const Color(0xFFFAFAFB)),
        border: const Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 6, 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // S.No
            SizedBox(
              width: 28,
              child: Text('${i + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isOpen ? _msRed : const Color(0xFF6B7280))),
            ),
            // Length ft
            Expanded(flex: 6, child: _numField(row.lFtCtrl, 'ft', integer: true, onCh: () {
              row.recalcTotal(); setState(() {});
            })),
            const SizedBox(width: 3),
            // Length in
            Expanded(flex: 4, child: _numField(row.lInCtrl, 'in', onCh: () {
              row.recalcTotal(); setState(() {});
            })),
            _gap(),
            // Depth ft
            Expanded(flex: 6, child: _numField(row.dFtCtrl, 'ft', integer: true, onCh: () {
              row.recalcTotal(); setState(() {});
            })),
            const SizedBox(width: 3),
            // Depth in
            Expanded(flex: 4, child: _numField(row.dInCtrl, 'in', onCh: () {
              row.recalcTotal(); setState(() {});
            })),
            _gap(),
            // Nos
            Expanded(flex: 5, child: _numField(row.nosCtrl, 'Nos', onCh: () {
              row.recalcTotal(); setState(() {});
            })),
            _gap(),
            // Total
            Expanded(
              flex: 9,
              child: TextFormField(
                controller: row.totalCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: _rd('Total',
                    fill: isOpen
                        ? const Color(0xFFFFEDED)
                        : const Color(0xFFF0FDF4)),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOpen ? _msRed : _msBlue),
                onChanged: (_) => setState(() {}),
              ),
            ),
            _gap(),
            // Beam No.
            Expanded(flex: 10, child: TextFormField(
              controller: row.beamCtrl,
              decoration: _rd('Beam No.'),
              style: const TextStyle(fontSize: 12),
            )),
            _gap(),
            // Measurement Type dropdown (inside rows) or OPEN label
            Expanded(
              flex: 10,
              child: isOpen
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _msRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: _msRed.withValues(alpha: 0.3)),
                      ),
                      child: const Center(
                        child: Text('OPEN(-)',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _msRed)),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      key: ValueKey('pmt_${i}_${row.measurementTypeId}'),
                      initialValue: row.measurementTypeId,
                      decoration: _rd('— select —'),
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(5),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF111827)),
                      items: [
                        const DropdownMenuItem<String>(
                            value: null,
                            child: Text('— select —',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF9CA3AF)))),
                        // Ensure current value is present even if types not loaded yet
                        if (row.measurementTypeId != null &&
                            !_measTypes.any(
                                (t) => t['_id'] == row.measurementTypeId))
                          DropdownMenuItem<String>(
                              value: row.measurementTypeId,
                              child: Text(
                                  row.measurementTypeName.isNotEmpty
                                      ? row.measurementTypeName
                                      : row.measurementTypeId!,
                                  style: const TextStyle(fontSize: 11))),
                        ..._measTypes.map((t) => DropdownMenuItem<String>(
                              value: t['_id'] as String,
                              child: Text(t['name'] as String,
                                  style: const TextStyle(fontSize: 11)),
                            )),
                      ],
                      onChanged: (v) => setState(() {
                        _rows[i].measurementTypeId = v;
                        _rows[i].measurementTypeName = v == null
                            ? ''
                            : (_measTypes.firstWhere(
                                    (t) => t['_id'] == v,
                                    orElse: () => {})['name']
                                as String? ??
                                '');
                      }),
                    ),
            ),
            // Delete
            SizedBox(
              width: 26,
              child: IconButton(
                onPressed: () => _removeRow(i),
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    size: 15, color: Color(0xFFDC2626)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ]),
        ),
        // Room / Description sub-row
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 0, 36, 5),
          child: TextFormField(
            controller: row.roomCtrl,
            decoration: _rd('Room / Description (optional)'),
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ]),
    );
  }

  Widget _numField(TextEditingController ctrl, String hint,
      {VoidCallback? onCh, bool integer = false}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: integer
            ? TextInputType.number
            : const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          integer
              ? FilteringTextInputFormatter.digitsOnly
              : FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        ],
        decoration: _rd(hint),
        style: const TextStyle(fontSize: 12),
        onChanged: (_) => onCh?.call(),
      );

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
          ],
        ),
        padding: padding,
        child: child,
      );

  Widget _secTitle(String text, IconData icon) => Row(children: [
        Icon(icon, size: 13, color: _msPrimary),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151))),
        const SizedBox(width: 8),
        const Expanded(child: Divider(thickness: 1, color: Color(0xFFE5E7EB))),
      ]);

  Widget _buildTypeSummaryCard() {
    final Map<String, double> byType = {};
    for (final row in _rows) {
      if (row.type == 'open') continue;
      final qty = double.tryParse(row.totalCtrl.text) ?? 0;
      if (qty == 0 || row.measurementTypeName.isEmpty) continue;
      byType[row.measurementTypeName] =
          (byType[row.measurementTypeName] ?? 0) + qty;
    }
    if (byType.isEmpty) return const SizedBox.shrink();

    return _card(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secTitle('By Measurement Type', Icons.pie_chart_outline_rounded),
        const SizedBox(height: 8),
        ...byType.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: _msGreen,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(e.key,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151)))),
                Text(_fmtQ(e.value),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _msBlue)),
              ]),
            )),
      ]),
    );
  }
}

// ── Number formatter ──────────────────────────────────────────────────────────
String _fmtQ(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}
