import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

class AdvanceScreen extends StatefulWidget {
  const AdvanceScreen({super.key});
  @override
  State<AdvanceScreen> createState() => _AdvanceScreenState();
}

class _AdvanceScreenState extends State<AdvanceScreen> {
  List _items = [];
  List _branches = [];
  List _employees = [];
  bool _loading = true;
  String _search = '';

  DateTime? _fromDate;
  DateTime? _toDate;
  String? _filterBranchId;
  String? _filterEmployeeId;

  static const _primary = Color(0xFF111827);
  static const _accent = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
    _load();
  }

  Future<void> _loadDropdownData() async {
    final results = await Future.wait([
      ApiService.get('/branches'),
      ApiService.get('/employees'),
    ]);
    if (mounted) {
      setState(() {
        _branches = results[0]['data'] ?? [];
        _employees = results[1]['data'] ?? [];
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final params = <String, String>{};
    if (_fromDate != null) params['from'] = _fromDate!.toIso8601String();
    if (_toDate != null) {
      final end =
          DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
      params['to'] = end.toIso8601String();
    }
    if (_filterBranchId != null) params['branch'] = _filterBranchId!;
    if (_filterEmployeeId != null) params['employee'] = _filterEmployeeId!;
    final res = await ApiService.get('/advances', params: params);
    if (mounted)
      setState(() {
        _items = res['data'] ?? [];
        _loading = false;
      });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/advances/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  void _openForm([Map? item]) {
    final sw = MediaQuery.of(context).size.width;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, a1, a2) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          elevation: 16,
          borderRadius:
              const BorderRadius.horizontal(left: Radius.circular(20)),
          child: SizedBox(
            width: sw > 900 ? sw * 0.36 : sw * 0.92,
            height: MediaQuery.of(ctx).size.height,
            child: AdvanceFormPanel(item: item, onSaved: _load),
          ),
        ),
      ),
      transitionBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(a),
        child: child,
      ),
    );
  }

  // ── Computed ────────────────────────────────────────────────────────────────

  List get _filtered {
    if (_search.isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items
        .where((i) =>
            (i['employee']?['name'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  int get _activeFilterCount {
    int c = 0;
    if (_fromDate != null || _toDate != null) c++;
    if (_filterBranchId != null) c++;
    if (_filterEmployeeId != null) c++;
    return c;
  }

  double get _totalAmount =>
      _filtered.fold(0.0, (s, i) => s + ((i['amount'] ?? 0).toDouble()));

  // ── Date picker ─────────────────────────────────────────────────────────────

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_fromDate ?? now) : (_toDate ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _accent),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_fromDate != null && _fromDate!.isAfter(picked)) _fromDate = picked;
      }
    });
    _load();
  }

  // ── Photo viewer ─────────────────────────────────────────────────────────────

  void _viewPhoto(Map employee) {
    final photo = employee['photo'] as String?;
    if (photo == null || photo.isEmpty) return;
    late final List<int> bytes;
    try {
      bytes = base64Decode(photo);
    } catch (_) {
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.72;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(employee['name'] as String? ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(ctx),
              ),
            ]),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: InteractiveViewer(
                  child: Image.memory(Uint8List.fromList(bytes),
                      fit: BoxFit.contain, width: double.infinity),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final rows = _filtered;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ScreenHeader(
            title: 'Advances',
            subtitle: 'Track advance payments given to employees',
            onRefresh: _load,
            onSearchChanged: (v) => setState(() => _search = v),
            searchHint: 'Search by name...',
            onAdd: _openForm,
            addLabel: 'Add Advance',
          ),
          _buildToolbar(isMobile),
          if (!_loading && rows.isNotEmpty) _buildTotalsStrip(rows.length),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: _loading
                ? const AppLoader()
                : rows.isEmpty
                    ? _buildEmpty()
                    : isMobile
                        ? _buildMobileList(rows)
                        : _buildTable(rows),
          ),
        ]);
      }),
    );
  }

  // ── Totals strip ─────────────────────────────────────────────────────────────

  Widget _buildTotalsStrip(int count) {
    final fmt = NumberFormat('#,##0.00');
    return Container(
      color: const Color(0xFFF5F3FF),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      child: Row(children: [
        _chip(Icons.people_outline_rounded, '$count records',
            const Color(0xFF374151), const Color(0xFFE5E7EB)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
              color: _accent, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.currency_rupee_rounded,
                size: 13, color: Colors.white),
            Text(fmt.format(_totalAmount),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String label, Color color, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: color)),
        ]),
      );

  // ── Toolbar ──────────────────────────────────────────────────────────────────

  Widget _buildToolbar(bool isMobile) {
    final fmt = DateFormat('dd MMM yyyy');
    final hasFilter = _activeFilterCount > 0;

    // Only the filter chips scroll horizontally — Spacer/Expanded not allowed inside
    final filterChips = Row(mainAxisSize: MainAxisSize.min, children: [
      _filterBox(
          child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _filterEmployeeId,
          hint: const Text('All Employees',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded,
              size: 15, color: Color(0xFF6B7280)),
          style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
          borderRadius: BorderRadius.circular(8),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Employees')),
            ..._employees.map((emp) {
              final active = emp['isActive'] ?? true;
              final name = emp['name'] as String? ?? '';
              final code = emp['empCode'] as String? ?? '';
              final label = code.isNotEmpty ? '$name ($code)' : name;
              return DropdownMenuItem(
                value: emp['_id'] as String,
                child: Text(active ? label : '$label – Inactive',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: active ? null : Colors.grey)),
              );
            }),
          ],
          onChanged: (v) {
            setState(() => _filterEmployeeId = v);
            _load();
          },
        ),
      )),
      const SizedBox(width: 8),
      _filterBox(
          child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _filterBranchId,
          hint: const Text('All Branches',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded,
              size: 15, color: Color(0xFF6B7280)),
          style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
          borderRadius: BorderRadius.circular(8),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Branches')),
            ..._branches.map((b) => DropdownMenuItem(
                  value: b['_id'] as String,
                  child: Text(b['name'] as String? ?? '',
                      overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: (v) {
            setState(() => _filterBranchId = v);
            _load();
          },
        ),
      )),
      const SizedBox(width: 8),
      _dateTapBox(
          label: 'From',
          date: _fromDate,
          fmt: fmt,
          onTap: () => _pickDate(isFrom: true),
          onClear: _fromDate != null
              ? () {
                  setState(() => _fromDate = null);
                  _load();
                }
              : null),
      const SizedBox(width: 8),
      _dateTapBox(
          label: 'To',
          date: _toDate,
          fmt: fmt,
          onTap: () => _pickDate(isFrom: false),
          onClear: _toDate != null
              ? () {
                  setState(() => _toDate = null);
                  _load();
                }
              : null),
      if (hasFilter) ...[
        const SizedBox(width: 8),
        _toolbarSurface(
          onTap: () {
            setState(() {
              _fromDate = null;
              _toDate = null;
              _filterBranchId = null;
              _filterEmployeeId = null;
            });
            _load();
          },
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.close_rounded, size: 13, color: Color(0xFFDC2626)),
            SizedBox(width: 5),
            Text('Clear',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ],
    ]);

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
      child: Row(children: [
        // Scrollable filter chips
        Expanded(
          child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, child: filterChips),
        ),
        const SizedBox(width: 12),
        // Row count — fixed, outside the scroll view
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6)),
          child: Text('${_filtered.length} rows',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ),
        if (isMobile) ...[
          const SizedBox(width: 8),
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: _openForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Icon(Icons.add_rounded, size: 16),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _toolbarSurface(
          {required VoidCallback onTap, required Widget child}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(7),
            color: Colors.white,
          ),
          child: child,
        ),
      );

  Widget _filterBox({required Widget child}) => Container(
        height: 34,
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 170),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Center(child: child),
      );

  Widget _dateTapBox({
    required String label,
    required DateTime? date,
    required DateFormat fmt,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final active = date != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF5F3FF) : Colors.white,
          border: Border.all(
              color:
                  active ? const Color(0xFFC4B5FD) : const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_rounded,
              size: 13, color: active ? _accent : const Color(0xFF9CA3AF)),
          const SizedBox(width: 5),
          Text(active ? fmt.format(date) : label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? _accent : const Color(0xFF6B7280))),
          if (onClear != null) ...[
            const SizedBox(width: 5),
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded,
                  size: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Desktop table ─────────────────────────────────────────────────────────────

  Widget _buildTable(List rows) {
    return Column(children: [
      Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: const Row(children: [
          SizedBox(width: 28, child: Text('#', style: _kAdvHdr)),
          SizedBox(width: 10),
          SizedBox(width: 36),
          SizedBox(width: 10),
          Expanded(flex: 3, child: Text('Employee', style: _kAdvHdr)),
          Expanded(flex: 2, child: Text('Branch', style: _kAdvHdr)),
          Expanded(flex: 2, child: Text('Amount', style: _kAdvHdr)),
          Expanded(flex: 2, child: Text('Date', style: _kAdvHdr)),
          Expanded(flex: 2, child: Text('Remarks', style: _kAdvHdr)),
          SizedBox(width: 40),
        ]),
      ),
      const Divider(height: 1, color: Color(0xFFE5E7EB)),
      Expanded(
        child: ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) => _buildRow(rows[i], i),
        ),
      ),
    ]);
  }

  Widget _buildRow(Map item, int index) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy');
    final amount = (item['amount'] ?? 0).toDouble();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openForm(item),
        hoverColor: const Color(0xFFF9FAFB),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
          child: Row(children: [
            SizedBox(
              width: 28,
              child: Text('${index + 1}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ),
            const SizedBox(width: 10),
            _avatar(item['employee'], index, size: 32),
            const SizedBox(width: 10),
            Expanded(
                flex: 3,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(item['employee']?['name'] ?? '—',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
                      overflow: TextOverflow.ellipsis),
                  if ((item['employee']?['empCode'] ?? '').toString().isNotEmpty)
                    Text(item['employee']?['empCode'] ?? '',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                ])),
            Expanded(
                flex: 2,
                child: Text(item['branch']?['name'] ?? '—',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF374151)))),
            Expanded(
                flex: 2,
                child: Text('₹${fmt.format(amount)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _accent))),
            Expanded(
                flex: 2,
                child: Text(
                    item['date'] != null
                        ? dateFmt.format(DateTime.parse(item['date']))
                        : '—',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)))),
            Expanded(
                flex: 2,
                child: Text(item['remarks'] ?? '—',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    overflow: TextOverflow.ellipsis)),
            _actionMenu(item),
          ]),
        ),
      ),
    );
  }

  // ── Mobile list ───────────────────────────────────────────────────────────────

  Widget _buildMobileList(List rows) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _mobileCard(rows[i], i),
    );
  }

  Widget _mobileCard(Map item, int index) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy');
    final amount = (item['amount'] ?? 0).toDouble();
    return InkWell(
      onTap: () => _openForm(item),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ],
        ),
        child: Row(children: [
          _avatar(item['employee'], index, size: 40),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item['employee']?['name'] ?? '—',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF111827))),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.store_outlined,
                      size: 11, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 3),
                  Text(item['branch']?['name'] ?? '—',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ]),
                if ((item['remarks'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item['remarks'],
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                      overflow: TextOverflow.ellipsis),
                ],
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${fmt.format(amount)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15, color: _accent)),
            const SizedBox(height: 3),
            Text(
                item['date'] != null
                    ? dateFmt.format(DateTime.parse(item['date']))
                    : '—',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ]),
          const SizedBox(width: 4),
          _actionMenu(item),
        ]),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _avatar(dynamic emp, int index, {double size = 32}) {
    const bgs = [
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFFDC2626),
      Color(0xFF2563EB),
    ];
    final bg = bgs[index % bgs.length];

    if (emp != null) {
      final photo = emp['photo'] as String?;
      if (photo != null && photo.isNotEmpty) {
        try {
          final bytes = base64Decode(photo);
          return GestureDetector(
            onTap: () => _viewPhoto(emp),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.28),
              child: Image.memory(bytes,
                  width: size, height: size, fit: BoxFit.cover),
            ),
          );
        } catch (_) {}
      }
    }

    final name = emp?['name'] as String? ?? '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Center(
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.42)),
      ),
    );
  }

  Widget _actionMenu(Map item) => SizedBox(
        width: 40,
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded,
              size: 18, color: Color(0xFF9CA3AF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 3,
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 15, color: Color(0xFF374151)),
                  SizedBox(width: 8),
                  Text('Edit', style: TextStyle(fontSize: 13)),
                ])),
            PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 15, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Text('Delete',
                      style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                ])),
          ],
          onSelected: (v) {
            if (v == 'edit') _openForm(item);
            if (v == 'delete') _delete(item['_id']);
          },
        ),
      );

  // ── Empty state ───────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    final hasFilter = _search.isNotEmpty || _activeFilterCount > 0;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.account_balance_wallet_outlined,
              size: 28, color: _accent),
        ),
        const SizedBox(height: 14),
        Text(hasFilter ? 'No results found' : 'No advance records yet',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(
            hasFilter
                ? 'Try adjusting your search or filters.'
                : 'Add your first advance to get started.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        if (hasFilter) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _search = '';
              _fromDate = null;
              _toDate = null;
              _filterBranchId = null;
              _filterEmployeeId = null;
            }),
            child:
                const Text('Clear filters', style: TextStyle(color: _accent)),
          ),
        ] else ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openForm,
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add Advance', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Constants ──────────────────────────────────────────────────────────────────

const _kAdvHdr = TextStyle(
    fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);

// ── Form Panel ─────────────────────────────────────────────────────────────────

class AdvanceFormPanel extends StatefulWidget {
  final Map? item;
  final VoidCallback onSaved;
  const AdvanceFormPanel({super.key, this.item, required this.onSaved});
  @override
  State<AdvanceFormPanel> createState() => _AdvanceFormPanelState();
}

class _AdvanceFormPanelState extends State<AdvanceFormPanel> {
  final _formKey = GlobalKey<FormState>();
  List _users = [], _branches = [];
  String? _employeeId, _branchId;
  final _amountCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _primary = Color(0xFF1B3A27);
  static const _accent = Color(0xFF7C3AED);
  static const _gradEnd = Color(0xFF5B21B6);

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.item != null) {
      final e = widget.item!;
      _employeeId = e['employee']?['_id'];
      _branchId = e['branch']?['_id'];
      _amountCtrl.text = e['amount'] != null ? e['amount'].toString() : '';
      _remarksCtrl.text = e['remarks'] ?? '';
      if (e['date'] != null) _date = DateTime.parse(e['date']);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    final results = await Future.wait(
        [ApiService.get('/employees'), ApiService.get('/branches')]);
    if (mounted) {
      setState(() {
        _users = results[0]['data'] ?? [];
        _branches = results[1]['data'] ?? [];
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'employee': _employeeId,
      'branch': _branchId,
      'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
      'date': _date.toIso8601String(),
      'remarks': _remarksCtrl.text.trim(),
    };
    final res = widget.item == null
        ? await ApiService.post('/advances', body)
        : await ApiService.put('/advances/${widget.item!['_id']}', body);
    if (mounted) {
      showSnack(context,
          res['success'] == true ? 'Saved successfully!' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) {
        Navigator.pop(context);
        widget.onSaved();
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  InputDecoration _dec(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: _accent),
        labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFF7F9F8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _accent, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item == null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 10),
      Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(height: 2),
      // Header card
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primary, Color(0xFF1E6F5C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(isNew ? 'Add Advance' : 'Edit Advance',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                    isNew
                        ? 'Record advance payment to employee'
                        : 'Update advance details',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
              ])),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white70, size: 16),
            ),
          ),
        ]),
      ),
      // Form
      Expanded(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Form(
              key: _formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _employeeId,
                      decoration:
                          _dec('Employee', Icons.badge_outlined),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1A1A2E)),
                      borderRadius: BorderRadius.circular(10),
                      isExpanded: true,
                      hint: const Text('Select Employee'),
                      items: _users.map<DropdownMenuItem<String>>((emp) {
                        final active = emp['isActive'] ?? true;
                        final name = emp['name'] as String? ?? '';
                        final code = emp['empCode'] as String? ?? '';
                        final label = code.isNotEmpty ? '$name ($code)' : name;
                        return DropdownMenuItem(
                          value: emp['_id'] as String,
                          child: Text(active ? label : '$label – Inactive',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: active ? null : Colors.grey)),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _employeeId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _branchId,
                      decoration: _dec('Branch', Icons.store_outlined),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1A1A2E)),
                      borderRadius: BorderRadius.circular(10),
                      isExpanded: true,
                      items: _branches
                          .map<DropdownMenuItem<String>>((b) =>
                              DropdownMenuItem(
                                  value: b['_id'] as String,
                                  child: Text(b['name'] as String)))
                          .toList(),
                      onChanged: (v) => setState(() => _branchId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                      ],
                      decoration:
                          _dec('Amount (₹)', Icons.currency_rupee_rounded),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    DatePickerField(
                        label: 'Date',
                        value: _date,
                        onChanged: (d) => setState(() => _date = d)),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _remarksCtrl,
                      maxLines: 2,
                      decoration: _dec('Remarks', Icons.notes_outlined,
                          hint: 'Optional'),
                    ),
                    const SizedBox(height: 24),
                    // Cancel + Save row — matches branch screen style
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFDDE3E0)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _saving
                                ? null
                                : const LinearGradient(
                                    colors: [Color(0xFF3B0764), _gradEnd],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                            color: _saving ? Colors.grey.shade300 : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _saving
                                ? const ButtonLoader()
                                : Text(isNew ? 'Save Advance' : 'Save Changes',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                  ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
