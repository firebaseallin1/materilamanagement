import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List _items = [];
  List _branches = [];
  List _employees = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  // Filters
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _filterBranchId;
  String? _filterEmployeeId;

  static const _primary = Color(0xFF111827);
  static const _green = Color(0xFF16A34A);

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _weekSunday() {
    final now = DateTime.now();
    final daysFromSun = now.weekday % 7; // Sun=7→0, Mon=1→1, …, Sat=6→6
    return DateTime(now.year, now.month, now.day - daysFromSun);
  }

  @override
  void initState() {
    super.initState();
    final sunday = _weekSunday();
    _fromDate = sunday;
    _toDate = sunday.add(const Duration(days: 6));
    _loadDropdownData();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdownData() async {
    final auth = context.read<AuthService>();
    if (auth.isAdmin) {
      final results = await Future.wait([
        ApiService.get('/branches',
            params: {'isActive': 'true', 'limit': '1000'}),
        ApiService.get('/employees',
            params: {'isActive': 'true', 'limit': '1000'}),
      ]);
      if (mounted) {
        setState(() {
          _branches = results[0]['data'] ?? [];
          _employees = List.from(results[1]['data'] ?? []);
        });
      }
    } else {
      final results = await Future.wait([
        ApiService.get('/branches',
            params: {'isActive': 'true', 'limit': '1000'}),
        ApiService.get('/auth/me'),
      ]);
      if (mounted) {
        setState(() {
          _branches = results[0]['data'] ?? [];
          final me = results[1];
          if (me['success'] == true) {
            final emps = me['data']?['employees'];
            _employees =
                emps is List ? List.from(emps.where((e) => e != null)) : [];
          }
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final params = <String, String>{};
    if (_fromDate != null) params['from'] = _fmtDate(_fromDate!);
    if (_toDate != null) params['to'] = _fmtDate(_toDate!);
    if (_filterBranchId != null) params['branch'] = _filterBranchId!;
    if (_filterEmployeeId != null) params['employee'] = _filterEmployeeId!;
    final res = await ApiService.get('/attendance', params: params);
    if (mounted)
      setState(() {
        _items = res['data'] ?? [];
        _loading = false;
      });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/attendance/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  void _openForm([Map? item]) {
    final sw = MediaQuery.of(context).size.width;
    final panelWidth = sw > 900 ? sw * 0.38 : sw * 0.92;
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
            width: panelWidth,
            height: MediaQuery.of(ctx).size.height,
            child: AttendanceFormPanel(item: item, onSaved: _load),
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

  // ── Computed ───────────────────────────────────────────────────────────────

  List get _filtered {
    final auth = context.read<AuthService>();
    final linkedIds = auth.isAdmin ? <String>[] : auth.linkedEmployeeIds;
    var list = _items.where((i) {
      if (!auth.isAdmin && linkedIds.isNotEmpty) {
        final empId = i['employee'] is Map
            ? i['employee']['_id']?.toString()
            : i['employee']?.toString();
        if (!linkedIds.contains(empId)) return false;
      }
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return (i['employee']?['name'] ?? '')
          .toString()
          .toLowerCase()
          .contains(q);
    }).toList();
    return list;
  }

  int get _activeFilterCount {
    int c = 0;
    if (_fromDate != null || _toDate != null) c++;
    if (_filterBranchId != null) c++;
    if (_filterEmployeeId != null) c++;
    return c;
  }

  ({double amount, double presentHrs, double otHrs}) get _totals {
    double amount = 0, presentHrs = 0, otHrs = 0;
    for (final item in _filtered) {
      final p = item['isPresent'] == true ? 8.0 : 0.0;
      final ot = (item['otHours'] ?? 0).toDouble();
      final rate = (item['hourRate'] ?? 0).toDouble();
      presentHrs += p;
      otHrs += ot;
      amount += (p + ot) * rate;
    }
    return (amount: amount, presentHrs: presentHrs, otHrs: otHrs);
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_fromDate ?? now) : (_toDate ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF16A34A)),
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

  // ── Photo viewer ───────────────────────────────────────────────────────────

  void _viewPhoto(Map employee) {
    final photo = employee['photo'] as String?;
    if (photo == null || photo.isEmpty) return;
    late final List<int> bytes;
    try {
      bytes = base64Decode(photo);
    } catch (_) {
      return;
    }
    final name = employee['name'] as String? ?? '';
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
              Text(name,
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

  Widget _employeeAvatar(Map item, {double size = 30}) {
    final emp = item['employee'];
    if (emp == null) return _initialsAvatar('?', size: size);
    final photo = emp['photo'] as String?;
    final name = emp['name'] as String? ?? '';
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
    return _initialsAvatar(name, size: size);
  }

  Widget _initialsAvatar(String name, {double size = 30}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.42),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final rows = _filtered;
        final t = _totals;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ScreenHeader(
            title: 'Attendance',
            subtitle: 'Track daily attendance records for your workforce',
            onRefresh: _load,
            onSearchChanged: (v) => setState(() => _search = v),
            searchHint: 'Search by name...',
            onAdd: _openForm,
            addLabel: 'Mark Attendance',
          ),
          _buildToolbar(isMobile),
          // Totals strip
          if (!_loading && rows.isNotEmpty) _buildTotalsStrip(rows.length, t),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: _loading
                ? const AppLoader()
                : rows.isEmpty
                    ? const EmptyState(
                        message: 'No attendance records',
                        icon: Icons.how_to_reg)
                    : isMobile
                        ? _buildMobileList(rows)
                        : _buildTable(rows),
          ),
        ]);
      }),
    );
  }

  // ── Totals strip ───────────────────────────────────────────────────────────

  Widget _buildTotalsStrip(
      int count, ({double amount, double presentHrs, double otHrs}) t) {
    final fmt = NumberFormat('#,##0.00');
    return Container(
      color: const Color(0xFFF0FDF4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      child: Row(children: [
        _totalChip(Icons.people_outline_rounded, '$count records',
            const Color(0xFF374151), const Color(0xFFE5E7EB)),
        const SizedBox(width: 10),
        _totalChip(
            Icons.access_time_rounded,
            '${t.presentHrs % 1 == 0 ? t.presentHrs.toInt() : t.presentHrs}h present',
            const Color(0xFF166534),
            const Color(0xFFBBF7D0)),
        if (t.otHrs > 0) ...[
          const SizedBox(width: 10),
          _totalChip(
              Icons.more_time_rounded,
              'OT ${t.otHrs % 1 == 0 ? t.otHrs.toInt() : t.otHrs}h',
              const Color(0xFF5B21B6),
              const Color(0xFFEDE9FE)),
        ],
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.currency_rupee_rounded,
                size: 13, color: Colors.white),
            Text(fmt.format(t.amount),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ),
      ]),
    );
  }

  Widget _totalChip(IconData icon, String label, Color color, Color bg) =>
      Container(
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

  // ── Toolbar ────────────────────────────────────────────────────────────────

  Widget _buildToolbar(bool isMobile) {
    final fmt = DateFormat('dd MMM yyyy');
    final hasFilter = _activeFilterCount > 0;

    final filters = Row(children: [
      // Employee dropdown
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
              ..._employees.map((e) {
                final active = e['isActive'] ?? true;
                final name = e['name'] as String? ?? '';
                final code = e['empCode'] as String?;
                final label =
                    code != null && code.isNotEmpty ? '$name ($code)' : name;
                return DropdownMenuItem(
                  value: e['_id'] as String,
                  child: Text(active ? label : '$label (Inactive)',
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
        ),
      ),
      const SizedBox(width: 8),
      // Branch dropdown
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
        ),
      ),
      const SizedBox(width: 8),
      // From date
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
            : null,
      ),
      const SizedBox(width: 8),
      // To date
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
            : null,
      ),
      if (hasFilter) ...[
        const SizedBox(width: 8),
        InkWell(
          onTap: () {
            setState(() {
              _fromDate = null;
              _toDate = null;
              _filterBranchId = null;
              _filterEmployeeId = null;
            });
            _load();
          },
          borderRadius: BorderRadius.circular(7),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              border: Border.all(color: const Color(0xFFFCA5A5)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.close_rounded, size: 13, color: Color(0xFFDC2626)),
              SizedBox(width: 4),
              Text('Clear',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ],
      const SizedBox(width: 12),
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
    ]);

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal, child: filters),
    );
  }

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
          color: active ? const Color(0xFFF0FDF4) : Colors.white,
          border: Border.all(
              color:
                  active ? const Color(0xFF86EFAC) : const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_rounded,
              size: 13,
              color:
                  active ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF)),
          const SizedBox(width: 6),
          Text(
            active ? fmt.format(date) : label,
            style: TextStyle(
              fontSize: 12,
              color: active ? const Color(0xFF166534) : const Color(0xFF6B7280),
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (active && onClear != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded,
                  size: 13, color: Color(0xFF16A34A)),
            ),
          ] else ...[
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                size: 15, color: Color(0xFF9CA3AF)),
          ],
        ]),
      ),
    );
  }

  // ── Desktop table ──────────────────────────────────────────────────────────

  Widget _buildTable(List rows) {
    return Column(children: [
      Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: const Row(children: [
          SizedBox(width: 28, child: Text('#', style: _kAttHdr)),
          SizedBox(width: 12),
          Expanded(flex: 3, child: Text('Employee', style: _kAttHdr)),
          Expanded(flex: 2, child: Text('Branch', style: _kAttHdr)),
          Expanded(flex: 2, child: Text('Date', style: _kAttHdr)),
          SizedBox(
              width: 60,
              child: Text('Hrs', style: _kAttHdr, textAlign: TextAlign.center)),
          SizedBox(
              width: 60,
              child:
                  Text('OT Hrs', style: _kAttHdr, textAlign: TextAlign.center)),
          SizedBox(
              width: 70,
              child: Text('Rate/Hr',
                  style: _kAttHdr, textAlign: TextAlign.center)),
          SizedBox(
              width: 88,
              child:
                  Text('Total', style: _kAttHdr, textAlign: TextAlign.right)),
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
    final date = item['date'] != null
        ? DateFormat('dd MMM yyyy')
            .format(DateTime.parse(item['date']).toLocal())
        : '—';
    final isPresent = item['isPresent'] == true;
    final presentHrs = isPresent ? 8 : 0;
    final otHours = (item['otHours'] ?? 0).toDouble();
    final hourRate = (item['hourRate'] ?? 0).toDouble();
    final total = (presentHrs + otHours) * hourRate;
    final fmt = NumberFormat('#,##0.00');

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
        child: Row(children: [
          SizedBox(
              width: 28,
              child: Text('${index + 1}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))),
          const SizedBox(width: 12),
          Expanded(
              flex: 3,
              child: Row(children: [
                _employeeAvatar(item),
                const SizedBox(width: 8),
                Flexible(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item['employee']?['name'] ?? '—',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111827)),
                          overflow: TextOverflow.ellipsis),
                      Text(isPresent ? 'Present' : 'Absent',
                          style: TextStyle(
                              fontSize: 11,
                              color: isPresent
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626))),
                    ])),
              ])),
          Expanded(
              flex: 2,
              child: Text(item['branch']?['name'] ?? '—',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                  overflow: TextOverflow.ellipsis)),
          Expanded(
              flex: 2,
              child: Text(date,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
          SizedBox(
              width: 60,
              child: Center(child: _hrsBadge('${presentHrs}h', isPresent))),
          SizedBox(
              width: 60,
              child: Center(
                child: Text(
                    otHours > 0
                        ? '${otHours % 1 == 0 ? otHours.toInt() : otHours}h'
                        : '—',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            otHours > 0 ? FontWeight.w600 : FontWeight.normal,
                        color: otHours > 0
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF9CA3AF))),
              )),
          SizedBox(
              width: 70,
              child: Center(
                child: Text(hourRate > 0 ? '₹${fmt.format(hourRate)}' : '—',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF374151))),
              )),
          SizedBox(
              width: 88,
              child: Text(
                total > 0 ? '₹${fmt.format(total)}' : '—',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: total > 0 ? FontWeight.w600 : FontWeight.normal,
                    color: total > 0
                        ? const Color(0xFF111827)
                        : const Color(0xFF9CA3AF)),
              )),
          _actionMenu(item),
        ]),
      ),
    );
  }

  // ── Mobile list ────────────────────────────────────────────────────────────

  Widget _buildMobileList(List rows) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _mobileCard(rows[i]),
    );
  }

  Widget _mobileCard(Map item) {
    final date = item['date'] != null
        ? DateFormat('dd MMM yyyy')
            .format(DateTime.parse(item['date']).toLocal())
        : '—';
    final isPresent = item['isPresent'] == true;
    final presentHrs = isPresent ? 8 : 0;
    final otHours = (item['otHours'] ?? 0).toDouble();
    final hourRate = (item['hourRate'] ?? 0).toDouble();
    final total = (presentHrs + otHours) * hourRate;
    final fmt = NumberFormat('#,##0.00');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        _employeeAvatar(item, size: 42),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['employee']?['name'] ?? '—',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827))),
          const SizedBox(height: 2),
          Text('${item['branch']?['name'] ?? '—'}  ·  $date',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Row(children: [
            _hrsBadge('${presentHrs}h', isPresent),
            if (otHours > 0) ...[
              const SizedBox(width: 6),
              _otBadge(otHours),
            ],
          ]),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(total > 0 ? '₹${fmt.format(total)}' : '—',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          if (hourRate > 0)
            Text('₹${fmt.format(hourRate)}/hr',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ]),
        _actionMenu(item),
      ]),
    );
  }

  // ── Shared badges ──────────────────────────────────────────────────────────

  Widget _hrsBadge(String label, bool present) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: present ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: present
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626))),
      );

  Widget _otBadge(double hrs) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(20)),
        child: Text('OT ${hrs % 1 == 0 ? hrs.toInt() : hrs}h',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7C3AED))),
      );

  Widget _actionMenu(Map item) {
    if (!context.read<AuthService>().isAdmin) return const SizedBox.shrink();
    return SizedBox(
      width: 40,
      child: PopupMenuButton(
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
        onSelected: (val) {
          if (val == 'edit') _openForm(item);
          if (val == 'delete') _delete(item['_id']);
        },
      ),
    );
  }
}

const _kAttHdr = TextStyle(
    fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);

// ── Attendance Form Panel ─────────────────────────────────────────────────────

class AttendanceFormPanel extends StatefulWidget {
  final Map? item;
  final VoidCallback onSaved;
  const AttendanceFormPanel({super.key, this.item, required this.onSaved});
  @override
  State<AttendanceFormPanel> createState() => _AttendanceFormPanelState();
}

class _AttendanceFormPanelState extends State<AttendanceFormPanel> {
  final _formKey = GlobalKey<FormState>();
  List _employees = [], _branches = [];
  String? _employeeId, _branchId;
  final _remarksCtrl = TextEditingController();
  final _otHoursCtrl = TextEditingController();
  final _hourRateCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _isPresent = true;
  bool _otEnabled = false;

  static const _primary = Color(0xFF1B3A27);
  static const _accent = Color(0xFF2E7D52);

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.item != null) {
      final e = widget.item!;
      _employeeId = e['employee']?['_id'];
      _branchId = e['branch']?['_id'];
      _isPresent = e['isPresent'] ?? false;
      _otEnabled = e['otEnabled'] ?? false;
      _otHoursCtrl.text = e['otHours'] != null && e['otHours'] != 0
          ? e['otHours'].toString()
          : '';
      _hourRateCtrl.text = e['hourRate'] != null && e['hourRate'] != 0
          ? e['hourRate'].toString()
          : '';
      _remarksCtrl.text = e['remarks'] ?? '';
      if (e['date'] != null) _date = DateTime.parse(e['date']).toLocal();
    }
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    _otHoursCtrl.dispose();
    _hourRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    final auth = context.read<AuthService>();
    if (!mounted) return;

    if (auth.isAdmin) {
      final results = await Future.wait([
        ApiService.get('/employees',
            params: {'isActive': 'true', 'limit': '1000'}),
        ApiService.get('/branches'),
      ]);
      if (!mounted) return;
      final allEmps = List.from(results[0]['data'] ?? []);
      setState(() {
        _employees = allEmps;
        _branches = results[1]['data'] ?? [];
      });
      return;
    }

    // Non-admin: get linked employees directly from /auth/me
    final results = await Future.wait([
      ApiService.get('/auth/me'),
      ApiService.get('/branches'),
    ]);
    if (!mounted) return;

    final me = results[0];
    List filtered = [];
    if (me['success'] == true) {
      final emps = me['data']?['employees'];
      if (emps is List) {
        filtered = emps.where((e) => e != null).toList();
      }
    }

    setState(() {
      _employees = filtered;
      _branches = results[1]['data'] ?? [];
      // Auto-select & fill rate when only one linked employee
      if (!auth.isAdmin && filtered.length == 1 && _employeeId == null) {
        _employeeId = filtered[0]['_id'] as String?;
        final rate = filtered[0]['hourRate'];
        if (rate != null && rate != 0 && _hourRateCtrl.text.isEmpty) {
          _hourRateCtrl.text = rate.toString();
        }
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'employee': _employeeId,
      'branch': _branchId,
      'date': _date.toIso8601String(),
      'isPresent': _isPresent,
      'otEnabled': _otEnabled,
      'otHours':
          _otEnabled ? (double.tryParse(_otHoursCtrl.text.trim()) ?? 0) : 0,
      'hourRate': double.tryParse(_hourRateCtrl.text.trim()) ?? 0,
      'remarks': _remarksCtrl.text.trim(),
    };
    final res = widget.item == null
        ? await ApiService.post('/attendance', body)
        : await ApiService.put('/attendance/${widget.item!['_id']}', body);
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

  Widget _switchRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color activeColor = _accent,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: value
              ? Color.lerp(const Color(0xFFF7F9F8), activeColor, 0.06)
              : const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: value
                  ? activeColor.withValues(alpha: 0.4)
                  : const Color(0xFFDDE3E0)),
        ),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: value ? activeColor : const Color(0xFF374151))),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7280))),
              ])),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeColor,
            activeTrackColor: activeColor.withValues(alpha: 0.25),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item == null;
    final presentHrs = _isPresent ? 8 : 0;
    final otHrs =
        _otEnabled ? (double.tryParse(_otHoursCtrl.text.trim()) ?? 0) : 0.0;
    final rate = double.tryParse(_hourRateCtrl.text.trim()) ?? 0.0;
    final total = (presentHrs + otHrs) * rate;
    final fmt = NumberFormat('#,##0.00');

    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 10),
      Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 2),
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_primary, Color(0xFF1E6F5C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.how_to_reg_rounded,
                  color: Colors.white, size: 20)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(isNew ? 'Mark Attendance' : 'Edit Attendance',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                    isNew
                        ? 'Fill in the attendance details'
                        : 'Update attendance information',
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
                    borderRadius: BorderRadius.circular(8)),
                child:
                    const Icon(Icons.close, color: Colors.white70, size: 16)),
          ),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Form(
            key: _formKey,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<String>(
                initialValue: _employeeId,
                decoration: _dec('Employee', Icons.person_outline_rounded),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                borderRadius: BorderRadius.circular(10),
                items: _employees.map<DropdownMenuItem<String>>((e) {
                  final active = e['isActive'] ?? true;
                  final name = e['name'] as String? ?? '';
                  final code = e['empCode'] as String?;
                  final label =
                      code != null && code.isNotEmpty ? '$name ($code)' : name;
                  return DropdownMenuItem(
                    value: e['_id'] as String,
                    child: Text(active ? label : '$label (Inactive)',
                        style: TextStyle(color: active ? null : Colors.grey)),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() => _employeeId = v);
                  if (v != null) {
                    final emp = _employees.firstWhere((e) => e['_id'] == v,
                        orElse: () => <String, dynamic>{});
                    final rate = emp['hourRate'];
                    if (rate != null && rate != 0) {
                      _hourRateCtrl.text = rate.toString();
                    }
                  }
                },
                validator: (v) => v == null ? 'Required' : null,
                isExpanded: true,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _branchId,
                decoration: _dec('Branch', Icons.store_outlined),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                borderRadius: BorderRadius.circular(10),
                items: _branches
                    .map<DropdownMenuItem<String>>((b) => DropdownMenuItem(
                        value: b['_id'] as String,
                        child: Text(b['name'] as String)))
                    .toList(),
                onChanged: (v) => setState(() => _branchId = v),
                validator: (v) => v == null ? 'Required' : null,
                isExpanded: true,
              ),
              const SizedBox(height: 14),
              Builder(builder: (ctx) {
                final isAdmin = ctx.read<AuthService>().isAdmin;
                final today = DateTime.now();
                final todayOnly = DateTime(today.year, today.month, today.day);
                return DatePickerField(
                  label: 'Date',
                  value: _date,
                  onChanged: (d) => setState(() => _date = d),
                  firstDate: isAdmin ? DateTime(2020) : todayOnly,
                  lastDate: todayOnly,
                );
              }),
              const SizedBox(height: 14),
              _switchRow(
                label: 'Present',
                subtitle: _isPresent ? '8 regular hours' : 'Marked as absent',
                value: _isPresent,
                onChanged: (v) => setState(() => _isPresent = v),
                activeColor: const Color(0xFF16A34A),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _hourRateCtrl,
                readOnly: true,
                style: const TextStyle(color: Color(0xFF6B7280)),
                decoration:
                    _dec('Rate per Hour (₹)', Icons.currency_rupee_rounded)
                        .copyWith(
                  fillColor: const Color(0xFFF3F4F6),
                ),
              ),
              const SizedBox(height: 14),
              _switchRow(
                label: 'Overtime (OT)',
                subtitle: _otEnabled ? 'Enter OT hours below' : 'No overtime',
                value: _otEnabled,
                onChanged: (v) {
                  setState(() {
                    _otEnabled = v;
                    if (!v) _otHoursCtrl.clear();
                  });
                },
                activeColor: const Color(0xFF7C3AED),
              ),
              if (_otEnabled) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _otHoursCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  decoration:
                      _dec('OT Hours', Icons.more_time_rounded, hint: 'e.g. 2'),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (!_otEnabled) return null;
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Enter valid OT hours';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                  controller: _remarksCtrl,
                  maxLines: 2,
                  decoration: _dec('Remarks', Icons.notes_rounded,
                      hint: 'Optional...')),
              const SizedBox(height: 16),
              if (rate > 0)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(children: [
                    _summaryRow(
                        'Regular hours',
                        '${presentHrs}h × ₹${fmt.format(rate)}',
                        '₹${fmt.format(presentHrs * rate)}'),
                    if (_otEnabled && otHrs > 0) ...[
                      const SizedBox(height: 6),
                      _summaryRow(
                          'OT hours',
                          '${otHrs % 1 == 0 ? otHrs.toInt() : otHrs}h × ₹${fmt.format(rate)}',
                          '₹${fmt.format(otHrs * rate)}'),
                    ],
                    const Divider(height: 16, color: Color(0xFFBBF7D0)),
                    Row(children: [
                      const Text('Total',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF166534))),
                      const Spacer(),
                      Text('₹${fmt.format(total)}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF166534))),
                    ]),
                  ]),
                ),
              const SizedBox(height: 24),
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
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                )),
                const SizedBox(width: 12),
                Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _saving
                            ? null
                            : const LinearGradient(
                                colors: [_primary, Color(0xFF1E6F5C)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight),
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
                            : Text(isNew ? 'Mark Attendance' : 'Save Changes',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                      ),
                    )),
              ]),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _summaryRow(String label, String detail, String value) =>
      Row(children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
        const SizedBox(width: 6),
        Text(detail,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF166534))),
      ]);
}
