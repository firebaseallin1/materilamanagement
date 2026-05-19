import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

const _payGreen = Color(0xFF16A34A);
const _payRed = Color(0xFFDC2626);
const _payBlue = Color(0xFF2563EB);
const _payPurple = Color(0xFF9333EA);
const _payOrange = Color(0xFFEA580C);
const _payAmber = Color(0xFFD97706);
const _payPrimary = Color(0xFF111827);

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  List _items = [];
  List _branches = [];
  bool _loading = true;
  String _search = '';
  String? _filterBranch;
  String? _filterParty;
  String? _filterCategory;
  DateTime? _filterFrom;
  DateTime? _filterTo;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
    _load();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches',
        params: {'limit': '1000', 'isActive': 'true'});
    if (mounted) setState(() => _branches = res['data'] ?? []);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/payments');
    if (mounted)
      setState(() {
        _items = res['data'] ?? [];
        _loading = false;
      });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/payments/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  List<String> get _allPartyNames {
    final names = _items
        .map((e) => (e['partyName'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  List get _filtered {
    return _items.where((e) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final match = (e['partyName'] ?? '').toLowerCase().contains(q) ||
            (e['branch']?['name'] ?? '').toLowerCase().contains(q) ||
            (e['category'] ?? '').toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_filterBranch != null && e['branch']?['_id'] != _filterBranch) return false;
      if (_filterParty != null && e['partyName'] != _filterParty) return false;
      if (_filterCategory != null && (e['category'] ?? 'other') != _filterCategory) return false;
      if (_filterFrom != null || _filterTo != null) {
        if (e['date'] == null) return false;
        final d = DateTime.parse(e['date']).toLocal();
        final day = DateTime(d.year, d.month, d.day);
        if (_filterFrom != null && day.isBefore(_filterFrom!)) return false;
        if (_filterTo != null && day.isAfter(_filterTo!)) return false;
      }
      return true;
    }).toList();
  }

  bool get _hasFilters =>
      _filterBranch != null ||
      _filterParty != null ||
      _filterCategory != null ||
      _filterFrom != null ||
      _filterTo != null;

  void _clearFilters() => setState(() {
        _filterBranch = null;
        _filterParty = null;
        _filterCategory = null;
        _filterFrom = null;
        _filterTo = null;
      });

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final initial =
        isFrom ? (_filterFrom ?? now) : (_filterTo ?? _filterFrom ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1B5E37),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _filterFrom = DateTime(picked.year, picked.month, picked.day);
      } else {
        _filterTo = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  List get _incoming =>
      _filtered.where((e) => e['type'] == 'received').toList();
  List get _outgoing => _filtered.where((e) => e['type'] == 'paid').toList();

  double get _totalReceived => _incoming.fold(
      0.0, (s, e) => s + (double.tryParse('${e['amount']}') ?? 0));
  double get _totalPaid => _outgoing.fold(
      0.0, (s, e) => s + (double.tryParse('${e['amount']}') ?? 0));
  double get _totalPending => _outgoing.fold(0.0, (s, e) {
        final due = double.tryParse('${e['totalDue'] ?? e['amount']}') ?? 0;
        final paid = double.tryParse('${e['amount']}') ?? 0;
        return s + (due > paid ? due - paid : 0);
      });

  void _openForm([Map? item]) {
    final defaultType = _tab.index == 0 ? 'received' : 'paid';
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'payment-form',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final sw = MediaQuery.of(ctx).size.width;
        final pw = sw > 900 ? sw * 0.40 : sw * 0.95;
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              elevation: 16,
              child: SizedBox(
                width: pw,
                height: double.infinity,
                child: PaymentFormPanel(
                  item: item,
                  defaultType: defaultType,
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

  @override
  Widget build(BuildContext context) {
    final net = _totalReceived - _totalPaid;
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 700;
      return Scaffold(
        body: Column(children: [
          ScreenHeader(
            title: 'Payments',
            subtitle: 'Track incoming income and outgoing expenses',
            onRefresh: _load,
            onSearchChanged: (v) => setState(() => _search = v),
            searchHint: 'Search by name…',
            onAdd: _openForm,
            addLabel: _tab.index == 0 ? 'Add Income' : 'Add Payment',
          ),
          _buildSummary(net, isMobile),
          _buildToolbar(isMobile),
          Expanded(
            child: _loading
                ? const AppLoader()
                : TabBarView(
                    controller: _tab,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildIncomingTab(),
                      _buildOutgoingTab(),
                    ],
                  ),
          ),
        ]),
      );
    });
  }

  Widget _buildSummary(double net, bool isMobile) {
    final fmt = NumberFormat('#,##0.##');
    final tiles = [
      _summaryTileWidget('Received', '₹${fmt.format(_totalReceived)}',
          _payGreen, Icons.arrow_downward_rounded),
      _summaryTileWidget('Paid Out', '₹${fmt.format(_totalPaid)}', _payRed,
          Icons.arrow_upward_rounded),
      _summaryTileWidget(
          'Net',
          '₹${fmt.format(net.abs())}',
          net >= 0 ? _payGreen : _payRed,
          net >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded),
      _summaryTileWidget('Pending', '₹${fmt.format(_totalPending)}', _payAmber,
          Icons.schedule_rounded),
    ];
    if (isMobile) {
      return Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: Column(children: [
          Row(children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 6),
            Expanded(child: tiles[1]),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: 6),
            Expanded(child: tiles[3]),
          ]),
        ]),
      );
    }
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Expanded(child: tiles[0]),
        const SizedBox(width: 8),
        Expanded(child: tiles[1]),
        const SizedBox(width: 8),
        Expanded(child: tiles[2]),
        const SizedBox(width: 8),
        Expanded(child: tiles[3]),
      ]),
    );
  }

  Widget _summaryTileWidget(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 7),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
              overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  Widget _buildToolbar(bool isMobile) {
    final fmt = DateFormat('d MMM');
    final activeColor = _tab.index == 0 ? _payGreen : _payRed;

    Widget branchDrop() => _filterDropdown(
          icon: Icons.store_outlined,
          hint: 'All Branches',
          clearLabel: 'All Branches',
          value: _filterBranch,
          items: _branches
              .map<DropdownMenuItem<String>>((b) => DropdownMenuItem(
                  value: b['_id'],
                  child:
                      Text(b['name'] ?? '', overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => _filterBranch = v),
          activeColor: activeColor,
        );

    Widget partyDrop() => _filterDropdown(
          icon: Icons.person_outline_rounded,
          hint: 'All Parties',
          clearLabel: 'All Parties',
          value: _filterParty,
          items: _allPartyNames
              .map<DropdownMenuItem<String>>((name) => DropdownMenuItem(
                  value: name,
                  child: Text(name, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => _filterParty = v),
          activeColor: activeColor,
        );

    Widget categoryDrop() => _filterDropdown(
          icon: Icons.label_outline_rounded,
          hint: 'All Categories',
          clearLabel: 'All Categories',
          value: _filterCategory,
          items: const [
            DropdownMenuItem(value: 'labor', child: Text('Labor')),
            DropdownMenuItem(value: 'transport', child: Text('Transport')),
            DropdownMenuItem(value: 'expense', child: Text('Expense')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (v) => setState(() => _filterCategory = v),
          activeColor: activeColor,
        );

    Widget fromTile() => _dateTile(
          label: _filterFrom != null ? fmt.format(_filterFrom!) : 'From Date',
          icon: Icons.calendar_today_outlined,
          active: _filterFrom != null,
          activeColor: activeColor,
          onTap: () => _pickDate(true),
        );

    Widget toTile() => _dateTile(
          label: _filterTo != null ? fmt.format(_filterTo!) : 'To Date',
          icon: Icons.calendar_month_outlined,
          active: _filterTo != null,
          activeColor: activeColor,
          onTap: () => _pickDate(false),
        );

    Widget clearBtn() => GestureDetector(
          onTap: _clearFilters,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _payRed.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.close_rounded, size: 13, color: _payRed),
              SizedBox(width: 4),
              Text('Clear',
                  style: TextStyle(
                      fontSize: 11,
                      color: _payRed,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        );

    if (isMobile) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Row 1: tab buttons
          Row(children: [
            Expanded(
                child: _tabBtn(0, 'Incoming', Icons.arrow_downward_rounded,
                    _payGreen, _incoming.length)),
            const SizedBox(width: 8),
            Expanded(
                child: _tabBtn(1, 'Outgoing', Icons.arrow_upward_rounded,
                    _payRed, _outgoing.length)),
          ]),
          const SizedBox(height: 8),
          // Row 2: branch + party + category
          Row(children: [
            Expanded(child: branchDrop()),
            const SizedBox(width: 8),
            Expanded(child: partyDrop()),
            const SizedBox(width: 8),
            Expanded(child: categoryDrop()),
          ]),
          const SizedBox(height: 8),
          // Row 3: from + to + clear
          Row(children: [
            Expanded(child: fromTile()),
            const SizedBox(width: 8),
            Expanded(child: toTile()),
            if (_hasFilters) ...[
              const SizedBox(width: 8),
              clearBtn(),
            ],
          ]),
        ]),
      );
    }

    // Desktop: scrollable single row
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _tabBtn(0, 'Incoming', Icons.arrow_downward_rounded, _payGreen,
              _incoming.length),
          const SizedBox(width: 8),
          _tabBtn(1, 'Outgoing', Icons.arrow_upward_rounded, _payRed,
              _outgoing.length),
          Container(
              height: 24,
              width: 1,
              color: const Color(0xFFE5E7EB),
              margin: const EdgeInsets.symmetric(horizontal: 12)),
          SizedBox(width: 150, child: branchDrop()),
          const SizedBox(width: 8),
          SizedBox(width: 150, child: partyDrop()),
          const SizedBox(width: 8),
          SizedBox(width: 130, child: categoryDrop()),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: fromTile()),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: toTile()),
          if (_hasFilters) ...[
            const SizedBox(width: 8),
            clearBtn(),
          ],
        ]),
      ),
    );
  }

  Widget _filterDropdown({
    required IconData icon,
    required String hint,
    required String clearLabel,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required Color activeColor,
  }) {
    final active = value != null;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active
            ? activeColor.withValues(alpha: 0.07)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: active ? activeColor : const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(children: [
            Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
            const SizedBox(width: 5),
            Text(hint,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          ]),
          icon: Icon(Icons.expand_more_rounded,
              size: 16, color: active ? activeColor : const Color(0xFF9CA3AF)),
          isExpanded: true,
          style: TextStyle(
              fontSize: 12,
              color: active ? activeColor : _payPrimary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(clearLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required IconData icon,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: active ? activeColor : const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Icon(icon,
              size: 13, color: active ? activeColor : const Color(0xFF9CA3AF)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: active ? activeColor : const Color(0xFF9CA3AF),
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ),
        ]),
      ),
    );
  }

  Widget _tabBtn(
      int index, String label, IconData icon, Color color, int count) {
    final active = _tab.index == index;
    return GestureDetector(
      onTap: () => _tab.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: active ? color : const Color(0xFF9CA3AF)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? color : const Color(0xFF6B7280))),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                color: active ? color : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10)),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : const Color(0xFF6B7280))),
          ),
        ]),
      ),
    );
  }

  // ── Incoming Tab ─────────────────────────────────────────────────────────────

  Widget _buildIncomingTab() {
    if (_incoming.isEmpty) {
      return const EmptyState(
          message: 'No incoming payments', icon: Icons.arrow_downward_rounded);
    }
    final Map<String, List> groups = {};
    for (final item in _incoming) {
      final branch = item['branch']?['name'] ?? 'Unknown Branch';
      groups.putIfAbsent(branch, () => []).add(item);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: groups.entries
            .map((e) => _buildBranchGroup(e.key, e.value))
            .toList(),
      ),
    );
  }

  Widget _buildBranchGroup(String branch, List items) {
    final total =
        items.fold(0.0, (s, e) => s + (double.tryParse('${e['amount']}') ?? 0));
    final fmt = NumberFormat('#,##0.##');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E37), Color(0xFF1E6F5C)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.store_outlined, size: 12, color: Colors.white70),
              const SizedBox(width: 5),
              Text(branch,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ]),
          ),
          const SizedBox(width: 8),
          Text('${items.length} payment${items.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          const Spacer(),
          Text('₹${fmt.format(total)}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _payGreen)),
        ]),
      ),
      ...items.asMap().entries.map((e) => _buildIncomingCard(e.value, e.key)),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildIncomingCard(Map item, int index) {
    final date = item['date'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
        : '—';
    final fmt = NumberFormat('#,##0.##');
    final amount = double.tryParse('${item['amount']}') ?? 0;
    const strips = [
      Color(0xFF16A34A),
      Color(0xFF0891B2),
      Color(0xFF7C3AED),
      Color(0xFF0369A1),
      Color(0xFF0D9488),
      Color(0xFF6366F1),
    ];
    final strip = strips[index % strips.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: strip),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: _payGreen.withValues(alpha: 0.1),
                    child: const Icon(Icons.arrow_downward_rounded,
                        size: 15, color: _payGreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['partyName'] ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _payPrimary)),
                          const SizedBox(height: 3),
                          Row(children: [
                            _modeBadge(item['paymentMode'] ?? ''),
                            if (item['referenceNo'] != null &&
                                item['referenceNo'] != '') ...[
                              const SizedBox(width: 6),
                              Text('Ref: ${item['referenceNo']}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Color(0xFF9CA3AF))),
                            ],
                          ]),
                        ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₹${fmt.format(amount)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _payGreen)),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 10, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 3),
                      Text(date,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF9CA3AF))),
                    ]),
                  ]),
                  const SizedBox(width: 4),
                  _actionMenu(item),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Outgoing Tab ─────────────────────────────────────────────────────────────

  Widget _buildOutgoingTab() {
    if (_outgoing.isEmpty) {
      return const EmptyState(
          message: 'No outgoing payments', icon: Icons.arrow_upward_rounded);
    }
    final Map<String, List> weeks = {};
    for (final item in _outgoing) {
      final key = _weekKey(item['date'] as String?);
      weeks.putIfAbsent(key, () => []).add(item);
    }
    final sortedKeys = weeks.keys.toList()..sort((a, b) => b.compareTo(a));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: sortedKeys.map((k) => _buildWeekGroup(k, weeks[k]!)).toList(),
      ),
    );
  }

  String _weekKey(String? dateStr) {
    if (dateStr == null) return '1970-01-05';
    final d = DateTime.parse(dateStr);
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  bool _isCurrentWeek(String weekKey) {
    final now = DateTime.now();
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    return weekKey == DateFormat('yyyy-MM-dd').format(thisMonday);
  }

  DateTime _weekSunday(String weekKey) =>
      DateTime.parse(weekKey).add(const Duration(days: 6));

  Widget _buildWeekGroup(String weekKey, List items) {
    final sunday = _weekSunday(weekKey);
    final monday = DateTime.parse(weekKey);
    final isCurrent = _isCurrentWeek(weekKey);
    final fmt = NumberFormat('#,##0.##');
    final totalDue = items.fold(
        0.0,
        (s, e) =>
            s + (double.tryParse('${e['totalDue'] ?? e['amount']}') ?? 0));
    final totalPaid =
        items.fold(0.0, (s, e) => s + (double.tryParse('${e['amount']}') ?? 0));
    final pending = totalDue - totalPaid;
    final weekLabel = isCurrent
        ? 'This Week'
        : '${DateFormat('d MMM').format(monday)} – ${DateFormat('d MMM').format(sunday)}';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 8, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFFFEF3C7) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isCurrent
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Icon(
              isCurrent
                  ? Icons.calendar_today_rounded
                  : Icons.calendar_month_outlined,
              size: 13,
              color: isCurrent ? _payAmber : const Color(0xFF9CA3AF)),
          const SizedBox(width: 6),
          Text(weekLabel,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isCurrent ? _payAmber : const Color(0xFF374151))),
          if (isCurrent) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: _payAmber, borderRadius: BorderRadius.circular(8)),
              child: const Text('CURRENT',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ],
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${fmt.format(totalPaid)} paid',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _payRed)),
            if (pending > 0)
              Text('₹${fmt.format(pending)} pending',
                  style: const TextStyle(fontSize: 10, color: _payAmber)),
          ]),
        ]),
      ),
      ..._buildWeekCards(items, sunday),
      const SizedBox(height: 8),
    ]);
  }

  List<Widget> _buildWeekCards(List items, DateTime weekSunday) {
    // Group labor payments by employee; keep transport/expense as individual cards
    final Map<String, List> laborGroups = {};
    final List nonLaborItems = [];

    for (final item in items) {
      final cat = (item['category'] ?? 'expense') as String;
      if (cat == 'labor') {
        final key = item['employee']?['_id']?.toString() ??
            (item['partyName'] ?? 'unknown').toString();
        laborGroups.putIfAbsent(key, () => []).add(item);
      } else {
        nonLaborItems.add(item);
      }
    }

    final cards = <Widget>[];
    for (final group in laborGroups.values) {
      if (group.length == 1) {
        cards.add(_buildOutgoingCard(group[0] as Map, 0, weekSunday));
      } else {
        cards.add(_buildGroupedLaborCard(group, weekSunday));
      }
    }
    for (int i = 0; i < nonLaborItems.length; i++) {
      cards.add(_buildOutgoingCard(nonLaborItems[i] as Map, i, weekSunday));
    }
    return cards;
  }

  Widget _buildGroupedLaborCard(List payments, DateTime weekSunday) {
    final fmt  = NumberFormat('#,##0.##');
    final dfmt = DateFormat('d MMM');

    // Sort by date ascending so sub-entries are chronological
    final sorted = List.of(payments)
      ..sort((a, b) {
        final da = a['date'] != null ? DateTime.parse(a['date'] as String) : DateTime(0);
        final db = b['date'] != null ? DateTime.parse(b['date'] as String) : DateTime(0);
        return da.compareTo(db);
      });

    final first = sorted.first as Map;

    // Aggregate totals
    double totalPaid     = 0;
    double totalEarnings = 0;
    double totalAdv      = 0;
    int    totalDays     = 0;
    for (final p in sorted) {
      totalPaid     += ((p['amount']           ?? 0) as num).toDouble();
      totalEarnings += ((p['earnings']          ?? 0) as num).toDouble();
      totalAdv      += ((p['advanceAdjustment'] ?? 0) as num).toDouble();
      totalDays     += ((p['presentDays']       ?? 0) as num).toInt();
    }

    // Period: min(periodFrom) → max(periodTo)
    DateTime? minFrom, maxTo;
    for (final p in sorted) {
      if (p['periodFrom'] != null) {
        final d = DateTime.parse(p['periodFrom'] as String);
        if (minFrom == null || d.isBefore(minFrom)) minFrom = d;
      }
      if (p['periodTo'] != null) {
        final d = DateTime.parse(p['periodTo'] as String);
        if (maxTo == null || d.isAfter(maxTo)) maxTo = d;
      }
    }
    final periodLabel = (minFrom != null && maxTo != null)
        ? '${dfmt.format(minFrom)} – ${dfmt.format(maxTo)}'
        : null;

    // Outstanding from the most recent payment entry
    final last = sorted.last as Map;
    final prevOutstanding = ((first['previousOutstanding'] ?? 0) as num).toDouble();
    final weekOutstanding = ((last['thisWeekOutstanding']  ?? 0) as num).toDouble();

    const catColor = _payPurple;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: weekOutstanding > 0
                ? const Color(0xFFFBBF24).withValues(alpha: 0.5)
                : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(children: [
          // ── Header ─────────────────────────────────────────────────────
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 4, color: catColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: catColor.withValues(alpha: 0.1),
                      child: const Icon(Icons.people_outline_rounded,
                          size: 15, color: catColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(first['partyName'] ?? '—',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: _payPrimary)),
                            const SizedBox(height: 3),
                            Row(children: [
                              _catBadge('labor'),
                              const SizedBox(width: 4),
                              _modeBadge(first['paymentMode'] ?? ''),
                              if (periodLabel != null) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: catColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(periodLabel,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: catColor)),
                                ),
                              ],
                            ]),
                          ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₹${fmt.format(totalPaid)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _payRed)),
                      Text('${sorted.length} payments',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF9CA3AF))),
                    ]),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Attendance summary ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              border: Border(
                  top: BorderSide(color: catColor.withValues(alpha: 0.15))),
            ),
            child: Column(children: [
              Row(children: [
                _attCell(Icons.calendar_month_outlined,
                    '${totalDays}d worked', const Color(0xFF2563EB)),
                const SizedBox(width: 12),
                _attCell(Icons.payments_outlined,
                    'Earned ₹${fmt.format(totalEarnings)}',
                    const Color(0xFF059669)),
                if (totalAdv > 0) ...[
                  const SizedBox(width: 12),
                  _attCell(Icons.remove_circle_outline,
                      'Adv -₹${fmt.format(totalAdv)}', _payRed),
                ],
              ]),
              if (prevOutstanding > 0 || weekOutstanding > 0) ...[
                const SizedBox(height: 6),
                const Divider(height: 1, color: Color(0xFFDDD6FE)),
                const SizedBox(height: 6),
                Row(children: [
                  if (prevOutstanding > 0) ...[
                    _attCell(Icons.history_rounded,
                        'Prev ₹${fmt.format(prevOutstanding)}', _payAmber),
                    const SizedBox(width: 12),
                  ],
                  if (weekOutstanding > 0)
                    _attCell(Icons.pending_actions_rounded,
                        'Outstanding ₹${fmt.format(weekOutstanding)}', _payRed),
                ]),
              ],
            ]),
          ),

          // ── Individual payment sub-entries ──────────────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              children: sorted.asMap().entries.map((e) {
                final idx = e.key;
                final p   = e.value as Map;
                final pd  = p['date'] != null
                    ? DateFormat('dd MMM yyyy').format(DateTime.parse(p['date'] as String))
                    : '—';
                final amt = ((p['amount'] ?? 0) as num).toDouble();
                return Container(
                  decoration: BoxDecoration(
                    border: idx < sorted.length - 1
                        ? const Border(
                            bottom: BorderSide(color: Color(0xFFF3F4F6)))
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.5),
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(pd,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280))),
                    if ((p['presentDays'] ?? 0) > 0) ...[
                      const SizedBox(width: 8),
                      Text('${p['presentDays']}d',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w500)),
                    ],
                    const Spacer(),
                    Text('₹${fmt.format(amt)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: _payRed)),
                    const SizedBox(width: 4),
                    _actionMenu(p),
                  ]),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildOutgoingCard(Map item, int index, DateTime weekSunday) {
    final category = item['category'] ?? 'expense';
    final catColor = _categoryColor(category);
    final catIcon = _categoryIcon(category);
    final payDate = item['date'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
        : '—';
    final fmt = NumberFormat('#,##0.##');
    final paid = double.tryParse('${item['amount']}') ?? 0;

    // Labor-specific fields
    final isLabor = category == 'labor';
    final hasPeriod = isLabor && item['periodFrom'] != null && item['periodTo'] != null;
    final periodFrom = hasPeriod ? DateTime.parse(item['periodFrom'] as String) : null;
    final periodTo   = hasPeriod ? DateTime.parse(item['periodTo']   as String) : null;
    final dfmt = DateFormat('d MMM');
    final periodLabel = hasPeriod
        ? '${dfmt.format(periodFrom!)} – ${dfmt.format(periodTo!)}'
        : null;
    final earnings           = ((item['earnings']           ?? 0) as num).toDouble();
    final presentDays        = ((item['presentDays']        ?? 0) as num).toInt();
    final prevOutstanding    = ((item['previousOutstanding'] ?? 0) as num).toDouble();
    final weekOutstanding    = ((item['thisWeekOutstanding'] ?? 0) as num).toDouble();
    final advAdj             = ((item['advanceAdjustment']  ?? 0) as num).toDouble();

    // Non-labor pending (legacy totalDue field)
    final totalDue  = double.tryParse('${item['totalDue'] ?? item['amount']}') ?? 0;
    final pending   = !isLabor && totalDue > paid ? totalDue - paid : 0.0;
    final hasPending = pending > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: (hasPending || (isLabor && weekOutstanding > 0))
                ? const Color(0xFFFBBF24).withValues(alpha: 0.5)
                : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(children: [
          // ── Header row ────────────────────────────────────────────────────
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 4, color: catColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: catColor.withValues(alpha: 0.1),
                      child: Icon(catIcon, size: 15, color: catColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['partyName'] ?? '—',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: _payPrimary)),
                            const SizedBox(height: 3),
                            Row(children: [
                              _catBadge(category),
                              const SizedBox(width: 4),
                              _modeBadge(item['paymentMode'] ?? ''),
                              if (periodLabel != null) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: _payPurple.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(periodLabel,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: _payPurple)),
                                ),
                              ] else ...[
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                      item['employee']?['name'] != null
                                          ? item['employee']['name']
                                          : (item['branch']?['name'] ?? '—'),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF))),
                                ),
                              ],
                            ]),
                          ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₹${fmt.format(paid)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _payRed)),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 10, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 3),
                        Text(payDate,
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF9CA3AF))),
                      ]),
                    ]),
                    const SizedBox(width: 4),
                    _actionMenu(item),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Labor attendance breakdown ────────────────────────────────────
          if (isLabor && hasPeriod) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                border: Border(
                    top: BorderSide(
                        color: _payPurple.withValues(alpha: 0.15))),
              ),
              child: Column(children: [
                // Days + Earnings row
                Row(children: [
                  _attCell(Icons.calendar_month_outlined,
                      '${presentDays}d worked', const Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  _attCell(Icons.payments_outlined,
                      'Earned ₹${fmt.format(earnings)}', const Color(0xFF059669)),
                  if (advAdj > 0) ...[
                    const SizedBox(width: 12),
                    _attCell(Icons.remove_circle_outline,
                        'Adv -₹${fmt.format(advAdj)}', _payRed),
                  ],
                ]),
                if (prevOutstanding > 0 || weekOutstanding > 0) ...[
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: Color(0xFFDDD6FE)),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (prevOutstanding > 0) ...[
                      _attCell(Icons.history_rounded,
                          'Prev ₹${fmt.format(prevOutstanding)}', _payAmber),
                      const SizedBox(width: 12),
                    ],
                    if (weekOutstanding > 0)
                      _attCell(Icons.pending_actions_rounded,
                          'Outstanding ₹${fmt.format(weekOutstanding)}',
                          _payRed),
                  ]),
                ],
              ]),
            ),
          ],

          // ── Non-labor pending footer ───────────────────────────────────────
          if (hasPending)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                border: Border(
                    top: BorderSide(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.4))),
              ),
              child: Row(children: [
                const Icon(Icons.schedule_rounded, size: 12, color: _payAmber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '₹${fmt.format(pending)} pending · Due ${DateFormat('d MMM yyyy').format(weekSunday)}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: _payAmber,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                GestureDetector(
                  onTap: () => _openForm(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: _payAmber,
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('Pay Now',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _attCell(IconData icon, String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: color)),
    ]);
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'labor':
        return _payPurple;
      case 'transport':
        return _payBlue;
      default:
        return _payOrange;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'labor':
        return Icons.people_outline_rounded;
      case 'transport':
        return Icons.local_shipping_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Widget _catBadge(String cat) {
    final color = _categoryColor(cat);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(cat[0].toUpperCase() + cat.substring(1),
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _modeBadge(String mode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(6)),
      child: Text(mode.toUpperCase(),
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: _payGreen)),
    );
  }

  Widget _actionMenu(Map item) {
    return PopupMenuButton<String>(
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
    );
  }
}

// ── Slide-in Form Panel ───────────────────────────────────────────────────────
class PaymentFormPanel extends StatefulWidget {
  final Map? item;
  final String defaultType;
  final VoidCallback onSaved;
  const PaymentFormPanel(
      {super.key, this.item, required this.defaultType, required this.onSaved});
  @override
  State<PaymentFormPanel> createState() => _PaymentFormPanelState();
}

class _PaymentFormPanelState extends State<PaymentFormPanel> {
  static const _primary = Color(0xFF1B3A27);
  static const _gradient2 = Color(0xFF1E6F5C);

  final _formKey = GlobalKey<FormState>();
  List _branches = [], _employees = [];
  String? _branchId, _mode = 'cash', _category = 'expense';
  String? _employeeId;
  late String _type;
  final _partyCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _totalDueCtrl = TextEditingController();
  final _advanceAdjCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  // Employee balance (single employee)
  double _outstandingBalance = 0;
  double _advanceBalance = 0;
  bool _balanceLoading = false;

  // Labour payment state
  List _laborEmps = [];
  bool _laborLoading = false;
  late DateTime _laborFrom;
  late DateTime _laborTo;
  final Set<String> _selectedEmpIds = {};
  final Map<String, double> _advDeduction = {};
  final _payableCtrl = TextEditingController();

  // Transport payment state
  List _transportItems = [];
  bool _transportLoading = false;
  late DateTime _transportFrom;
  late DateTime _transportTo;
  final Set<String> _selectedVehicles = {};
  final _transportPayableCtrl = TextEditingController();

  double get _pendingAmt {
    final due = double.tryParse(_totalDueCtrl.text) ?? 0;
    final paying = double.tryParse(_amountCtrl.text) ?? 0;
    return due > paying ? due - paying : 0;
  }

  DateTime get _nextSunday {
    final now = DateTime.now();
    final days = (7 - now.weekday) % 7;
    return days == 0
        ? now.add(const Duration(days: 7))
        : now.add(Duration(days: days));
  }

  bool get _isEdit =>
      widget.item != null &&
      widget.item!.containsKey('_id') &&
      widget.item!['_id'] != null;

  static DateTime _weekSunday() {
    final now = DateTime.now();
    final daysFromSun = now.weekday % 7; // Mon=1..Sat=6, Sun=0
    return DateTime(now.year, now.month, now.day - daysFromSun);
  }

  @override
  void initState() {
    super.initState();
    _type = widget.defaultType;
    // Default date ranges = current week Sun→Sat
    final sunday = _weekSunday();
    _laborFrom = sunday;
    _laborTo = sunday.add(const Duration(days: 6));
    _transportFrom = sunday;
    _transportTo = sunday.add(const Duration(days: 6));
    _loadDropdowns();
    if (widget.item != null) {
      final e = widget.item!;
      _branchId = e['branch']?['_id'];
      final emp = e['employee'];
      if (emp is Map) {
        _employeeId = emp['_id'] as String?;
      } else if (emp is String && emp.isNotEmpty) {
        _employeeId = emp;
      }
      _mode = e['paymentMode'] ?? 'cash';
      _type = e['type'] ?? widget.defaultType;
      _category = e['category'] ?? 'expense';
      _partyCtrl.text = e['partyName'] ?? '';
      _amountCtrl.text = '${e['amount'] ?? ''}';
      _totalDueCtrl.text = '${e['totalDue'] ?? e['amount'] ?? ''}';
      _advanceAdjCtrl.text =
          e['advanceAdjustment'] != null && e['advanceAdjustment'] != 0
              ? '${e['advanceAdjustment']}'
              : '';
      _refCtrl.text = e['referenceNo'] ?? '';
      _descCtrl.text = e['description'] ?? '';
      if (e['date'] != null) _date = DateTime.parse(e['date']);
    }
  }

  @override
  void dispose() {
    _partyCtrl.dispose();
    _amountCtrl.dispose();
    _totalDueCtrl.dispose();
    _advanceAdjCtrl.dispose();
    _refCtrl.dispose();
    _descCtrl.dispose();
    _payableCtrl.dispose();
    _transportPayableCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    final results = await Future.wait([
      ApiService.get('/branches', params: {'limit': '1000', 'isActive': 'true'}),
      ApiService.get('/employees', params: {'limit': '1000'}),
    ]);
    if (mounted) {
      setState(() {
        _branches = results[0]['data'] ?? [];
        _employees = results[1]['data'] ?? [];
      });
      if (_employeeId != null) _fetchBalance(_employeeId!);
    }
  }

  Future<void> _fetchBalance(String empId) async {
    setState(() => _balanceLoading = true);
    final res =
        await ApiService.get('/advances/balance', params: {'employee': empId});
    if (mounted) {
      setState(() {
        _outstandingBalance = (res['outstandingBalance'] ?? 0).toDouble();
        _advanceBalance = (res['advanceBalance'] ?? 0).toDouble();
        _balanceLoading = false;
      });
    }
  }

  void _onEmployeeChanged(String? empId) {
    setState(() {
      _employeeId = empId;
      _outstandingBalance = 0;
      _advanceBalance = 0;
      if (empId != null) {
        final emp =
            _employees.firstWhere((u) => u['_id'] == empId, orElse: () => {});
        if (emp.isNotEmpty && _partyCtrl.text.isEmpty) {
          _partyCtrl.text = emp['name'] ?? '';
        }
        _fetchBalance(empId);
      }
    });
  }

  // ── Labour helpers ────────────────────────────────────────────────────────

  bool get _isLaborMode => _type == 'paid' && _category == 'labor';

  double get _laborTotalEarnings => _laborEmps
      .where((e) => _selectedEmpIds.contains(e['_id'].toString()))
      .fold(0.0, (s, e) => s + ((e['earnings'] ?? 0) as num).toDouble());

  // Per-employee advance deduction (manual override or default 0)
  double get _laborTotalDeductions => _laborEmps
      .where((e) => _selectedEmpIds.contains(e['_id'].toString()))
      .fold(0.0, (s, e) {
    final id = e['_id'].toString();
    return s + (_advDeduction[id] ?? 0.0);
  });

  // Sum of unpaid wages carried over from all previous periods
  double get _laborPrevOutstanding => _laborEmps
      .where((e) => _selectedEmpIds.contains(e['_id'].toString()))
      .fold(0.0, (s, e) => s + ((e['previousOutstanding'] ?? 0) as num).toDouble());

  // This week's outstanding = (prev outstanding + this week earnings) − amount paid now
  double get _laborThisWeekOutstanding {
    final payable = double.tryParse(_payableCtrl.text) ?? _laborTotalEarnings;
    return (_laborPrevOutstanding + _laborTotalEarnings - payable)
        .clamp(0.0, double.infinity);
  }

  void _syncPayable() {
    _payableCtrl.text = _laborTotalEarnings.toStringAsFixed(2);
  }

  // ── Transport payment getters ─────────────────────────────────────────────
  bool get _isTransportMode => _type == 'paid' && _category == 'transport';

  double get _transportTotalCost => _transportItems
      .where((t) => _selectedVehicles.contains(t['vehicleNo'].toString()))
      .fold(0.0, (s, t) => s + ((t['currentCost'] ?? 0) as num).toDouble());

  double get _transportPrevOutstanding => _transportItems
      .where((t) => _selectedVehicles.contains(t['vehicleNo'].toString()))
      .fold(0.0, (s, t) => s + ((t['previousOutstanding'] ?? 0) as num).toDouble());

  double get _transportThisWeekOutstanding {
    final payable = double.tryParse(_transportPayableCtrl.text) ?? _transportTotalCost;
    return (_transportPrevOutstanding + _transportTotalCost - payable)
        .clamp(0.0, double.infinity);
  }

  void _syncTransportPayable() {
    _transportPayableCtrl.text = _transportTotalCost.toStringAsFixed(2);
  }

  Future<void> _loadTransportRecords({bool autoAdvanced = false}) async {
    setState(() {
      _transportLoading = true;
      _transportItems = [];
      _selectedVehicles.clear();
    });
    final params = <String, String>{
      if (_branchId != null) 'branch': _branchId!,
      'from': _transportFrom.toIso8601String(),
      'to': DateTime(_transportTo.year, _transportTo.month, _transportTo.day, 23, 59, 59)
          .toIso8601String(),
    };
    final res = await ApiService.get('/transport/payment-summary', params: params);
    if (!mounted) return;

    final list = (res['data'] as List? ?? []).toList();

    // Auto-advance to next unpaid period when backend suggests one
    if (list.isEmpty && !autoAdvanced && res['nextPeriodFrom'] != null) {
      final nextFrom =
          DateTime.parse(res['nextPeriodFrom'] as String).toLocal();
      final nextFrom0 =
          DateTime(nextFrom.year, nextFrom.month, nextFrom.day);
      setState(() {
        _transportFrom = nextFrom0;
        _transportTo = nextFrom0.add(const Duration(days: 6));
        _transportLoading = false;
      });
      _loadTransportRecords(autoAdvanced: true);
      return;
    }

    setState(() {
      _transportItems = list;
      _transportLoading = false;
      _selectedVehicles.addAll(list.map((t) => t['vehicleNo'].toString()));
    });
    _syncTransportPayable();
  }

  Future<void> _pickTransportDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _transportFrom : _transportTo,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _payBlue)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _transportFrom = picked;
      } else {
        _transportTo = picked;
      }
    });
  }

  Future<void> _loadLaborEmployees({bool autoAdvanced = false}) async {
    setState(() {
      _laborLoading = true;
      _laborEmps = [];
      _selectedEmpIds.clear();
    });
    final params = <String, String>{
      if (_branchId != null) 'branch': _branchId!,
      'from': _laborFrom.toIso8601String(),
      'to': DateTime(_laborTo.year, _laborTo.month, _laborTo.day, 23, 59, 59)
          .toIso8601String(),
    };
    final res = await ApiService.get('/attendance/summary', params: params);
    if (!mounted) return;

    final list = (res['data'] as List? ?? [])
        .where((e) => (e['presentDays'] ?? 0) > 0 || (e['earnings'] ?? 0) > 0)
        .toList();

    // When empty and the backend knows a later unpaid period exists,
    // auto-advance the date pickers to that period and reload once.
    if (list.isEmpty && !autoAdvanced && res['nextPeriodFrom'] != null) {
      final nextFrom =
          DateTime.parse(res['nextPeriodFrom'] as String).toLocal();
      final nextFrom0 =
          DateTime(nextFrom.year, nextFrom.month, nextFrom.day);
      setState(() {
        _laborFrom = nextFrom0;
        _laborTo = nextFrom0.add(const Duration(days: 6));
        _laborLoading = false;
      });
      _loadLaborEmployees(autoAdvanced: true);
      return;
    }

    setState(() {
      _laborEmps = list;
      _laborLoading = false;
      _selectedEmpIds.addAll(list.map((e) => e['_id'].toString()));
    });
    _syncPayable();
  }

  Future<void> _pickLaborDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _laborFrom : _laborTo,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1B5E37))),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom)
        _laborFrom = picked;
      else
        _laborTo = picked;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // ── Labour batch payment ──────────────────────────────────────────────────
    if (_isLaborMode) {
      final selected = _laborEmps
          .where((e) => _selectedEmpIds.contains(e['_id'].toString()))
          .toList();
      if (selected.isEmpty) {
        showSnack(context, 'Select at least one employee', error: true);
        setState(() => _saving = false);
        return;
      }
      final totalPayable =
          double.tryParse(_payableCtrl.text) ?? _laborTotalEarnings;
      final totalNet = selected.fold(0.0, (s, e) {
        final id = e['_id'].toString();
        final earnings = ((e['earnings'] ?? 0) as num).toDouble();
        final deduction = _advDeduction[id] ?? 0.0;
        return s + (earnings - deduction).clamp(0.0, double.infinity);
      });
      int ok = 0;
      String? errMsg;
      for (final emp in selected) {
        final id = emp['_id'].toString();
        final earnings = ((emp['earnings'] ?? 0) as num).toDouble();
        final deduction = _advDeduction[id] ?? 0.0;
        final net = (earnings - deduction).clamp(0.0, double.infinity);
        final prevOutstanding =
            ((emp['previousOutstanding'] ?? 0) as num).toDouble();
        final perEmpPayable = totalNet > 0
            ? (net / totalNet * totalPayable).clamp(0.0, net + prevOutstanding)
            : net;
        final outstanding = double.parse(
            (prevOutstanding + net - perEmpPayable)
                .clamp(0.0, double.infinity)
                .toStringAsFixed(2));
        final body = <String, dynamic>{
          'employee': emp['_id'],
          'branch': _branchId ?? emp['branch']?['_id'],
          'partyName': emp['name'],
          'amount': double.parse(perEmpPayable.toStringAsFixed(2)),
          'paymentMode': _mode,
          'type': 'paid',
          'category': 'labor',
          'date': _date.toIso8601String(),
          'referenceNo': _refCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'advanceAdjustment': deduction,
          'periodFrom': _laborFrom.toIso8601String(),
          'periodTo': _laborTo.toIso8601String(),
          'earnings': earnings,
          'presentDays': (emp['presentDays'] ?? 0) as num,
          'previousOutstanding': prevOutstanding,
          'thisWeekOutstanding': outstanding,
        };
        final res = await ApiService.post('/payments', body);
        if (res['success'] == true)
          ok++;
        else
          errMsg ??= res['message'];
      }
      if (mounted) {
        setState(() => _saving = false);
        if (ok > 0) {
          showSnack(context,
              'Payment recorded for $ok employee${ok == 1 ? '' : 's'}');
          widget.onSaved();
        } else {
          showSnack(context, errMsg ?? 'Save failed', error: true);
        }
      }
      return;
    }

    // ── Transport batch payment ───────────────────────────────────────────────
    if (_isTransportMode) {
      final selected = _transportItems
          .where((t) => _selectedVehicles.contains(t['vehicleNo'].toString()))
          .toList();
      if (selected.isEmpty) {
        showSnack(context, 'Select at least one vehicle', error: true);
        setState(() => _saving = false);
        return;
      }
      final totalPayable =
          double.tryParse(_transportPayableCtrl.text) ?? _transportTotalCost;
      final totalCost = _transportTotalCost;
      int ok = 0;
      String? errMsg;
      for (final item in selected) {
        final vehicleCost = ((item['currentCost'] ?? 0) as num).toDouble();
        final prevOutstanding =
            ((item['previousOutstanding'] ?? 0) as num).toDouble();
        final perVehiclePayable = totalCost > 0
            ? (vehicleCost / totalCost * totalPayable)
                .clamp(0.0, vehicleCost + prevOutstanding)
            : vehicleCost;
        final outstanding = double.parse(
            (prevOutstanding + vehicleCost - perVehiclePayable)
                .clamp(0.0, double.infinity)
                .toStringAsFixed(2));
        final body = <String, dynamic>{
          'partyName': '${item['vehicleNo']} - ${item['driverName']}',
          'branch': _branchId,
          'amount': double.parse(perVehiclePayable.toStringAsFixed(2)),
          'paymentMode': _mode,
          'type': 'paid',
          'category': 'transport',
          'date': _date.toIso8601String(),
          'referenceNo': _refCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'vehicleNo': item['vehicleNo'].toString(),
          'periodFrom': _transportFrom.toIso8601String(),
          'periodTo': _transportTo.toIso8601String(),
          'previousOutstanding': prevOutstanding,
          'thisWeekOutstanding': outstanding,
        };
        final res = await ApiService.post('/payments', body);
        if (res['success'] == true) {
          ok++;
        } else {
          errMsg ??= res['message'];
        }
      }
      if (mounted) {
        setState(() => _saving = false);
        if (ok > 0) {
          showSnack(context,
              'Payment recorded for $ok vehicle${ok == 1 ? '' : 's'}');
          widget.onSaved();
        } else {
          showSnack(context, errMsg ?? 'Save failed', error: true);
        }
      }
      return;
    }

    // ── Regular payment ───────────────────────────────────────────────────────
    final isOutgoing = _type == 'paid';
    final body = {
      'branch': _branchId,
      'partyName': _partyCtrl.text,
      'amount': double.tryParse(_amountCtrl.text) ?? 0,
      'paymentMode': _mode,
      'type': _type,
      if (isOutgoing) 'category': _category,
      if (isOutgoing)
        'totalDue': double.tryParse(_totalDueCtrl.text) ??
            double.tryParse(_amountCtrl.text) ??
            0,
      'date': _date.toIso8601String(),
      'referenceNo': _refCtrl.text,
      'description': _descCtrl.text,
      if (_employeeId != null) 'employee': _employeeId,
      'advanceAdjustment': double.tryParse(_advanceAdjCtrl.text) ?? 0,
    };
    final res = _isEdit
        ? await ApiService.put('/payments/${widget.item!['_id']}', body)
        : await ApiService.post('/payments', body);
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Saved!' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) widget.onSaved();
    }
    if (mounted) setState(() => _saving = false);
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Color(0xFF374151), fontSize: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _balanceCard(
      String label, double amount, IconData icon, Color color, Color bg) {
    final fmt = NumberFormat('#,##0.00');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text('₹${fmt.format(amount)}',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoing = _type == 'paid';
    return Column(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [_primary, _gradient2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 18,
            left: 20,
            right: 8),
        child: Row(children: [
          const Icon(Icons.payment_outlined, color: Colors.white70, size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_isEdit ? 'Edit Payment' : 'New Payment',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600))),
          IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
      Expanded(
        child: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            // Type toggle
            Row(children: [
              Expanded(
                  child: _typeBtn('received', 'Incoming',
                      Icons.arrow_downward_rounded, _payGreen)),
              const SizedBox(width: 10),
              Expanded(
                  child: _typeBtn(
                      'paid', 'Outgoing', Icons.arrow_upward_rounded, _payRed)),
            ]),
            const SizedBox(height: 16),
            // Category (outgoing only)
            if (isOutgoing) ...[
              Row(children: [
                Expanded(
                    child: _catBtn('labor', 'Labor',
                        Icons.people_outline_rounded, _payPurple)),
                const SizedBox(width: 8),
                Expanded(
                    child: _catBtn('transport', 'Transport',
                        Icons.local_shipping_outlined, _payBlue)),
                const SizedBox(width: 8),
                Expanded(
                    child: _catBtn('expense', 'Expense',
                        Icons.receipt_long_outlined, _payOrange)),
              ]),
              const SizedBox(height: 16),
            ],
            // ── Labour / Transport mode (batch only — not for editing) ────────
            if (_isLaborMode && !_isEdit) ...[
              _buildLaborSection(),
            ] else if (_isTransportMode && !_isEdit) ...[
              _buildTransportSection(),
            ] else ...[
              // Employee selector (optional)
              AppDropdown<String>(
                label: 'Employee (optional)',
                value: _employeeId,
                items: _employees.map<DropdownMenuItem<String>>((u) {
                  final active = u['isActive'] ?? true;
                  final name = u['name'] as String? ?? '';
                  final code = u['empCode'] as String? ?? '';
                  final label = code.isNotEmpty ? '$name ($code)' : name;
                  return DropdownMenuItem(
                    value: u['_id'] as String,
                    child: Text(active ? label : '$label (Inactive)',
                        style: TextStyle(color: active ? null : Colors.grey)),
                  );
                }).toList(),
                onChanged: _onEmployeeChanged,
              ),
              if (_employeeId != null) ...[
                const SizedBox(height: 10),
                _balanceLoading
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))))
                    : Row(children: [
                        Expanded(
                            child: _balanceCard(
                                'Outstanding',
                                _outstandingBalance,
                                Icons.account_balance_outlined,
                                const Color(0xFF0369A1),
                                const Color(0xFFE0F2FE))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _balanceCard(
                                'Advance',
                                _advanceBalance,
                                Icons.account_balance_wallet_outlined,
                                const Color(0xFF7C3AED),
                                const Color(0xFFF5F3FF))),
                      ]),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _partyCtrl,
                decoration: _dec('Party Name',
                    hint: isOutgoing ? 'Laborer / vendor name' : 'Sender name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              AppDropdown<String>(
                label: 'Branch',
                value: _branchId,
                items: _branches
                    .map<DropdownMenuItem<String>>((b) => DropdownMenuItem(
                        value: b['_id'], child: Text(b['name'])))
                    .toList(),
                onChanged: (v) => setState(() => _branchId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              if (isOutgoing) ...[
                TextFormField(
                  controller: _totalDueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Total Due (₹)', hint: 'Full amount owed'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: _dec(isOutgoing ? 'Paying Now (₹)' : 'Amount (₹)'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                onChanged: (_) => setState(() {}),
              ),
              if (_employeeId != null) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _advanceAdjCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Advance Adjustment (₹)',
                      hint: 'Amount to deduct from advance balance'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
            // Pending preview
            if (isOutgoing && _pendingAmt > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: _payAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '₹${NumberFormat('#,##0.##').format(_pendingAmt)} will remain pending',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _payAmber)),
                          Text(
                              'Due on ${DateFormat('d MMM yyyy').format(_nextSunday)} (next Sunday)',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF92400E))),
                        ]),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              decoration: _dec('Payment Mode'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                DropdownMenuItem(value: 'online', child: Text('Online')),
                DropdownMenuItem(value: 'upi', child: Text('UPI')),
              ],
              onChanged: (v) => setState(() => _mode = v),
            ),
            const SizedBox(height: 14),
            DatePickerField(
                label: 'Date',
                value: _date,
                onChanged: (d) => setState(() => _date = d)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _refCtrl,
              decoration: _dec('Reference No', hint: 'Optional'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: _dec('Notes', hint: 'Optional notes'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLaborMode
                      ? _payPurple
                      : (_isTransportMode
                          ? _payBlue
                          : (isOutgoing ? _payRed : _payGreen)),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const ButtonLoader()
                    : Text(_isLaborMode
                        ? 'Record Payment for ${_selectedEmpIds.length} Employee${_selectedEmpIds.length == 1 ? '' : 's'}'
                        : (_isTransportMode
                            ? 'Record Payment for ${_selectedVehicles.length} Vehicle${_selectedVehicles.length == 1 ? '' : 's'}'
                            : (_isEdit
                                ? 'Update Payment'
                                : (isOutgoing ? 'Record Payment' : 'Record Income')))),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  // ── Labour section ──────────────────────────────────────────────────────────

  Widget _buildLaborSection() {
    final fmt = NumberFormat('#,##0.00');
    final dfmt = DateFormat('dd MMM yyyy');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Branch
      AppDropdown<String>(
        label: 'Branch',
        value: _branchId,
        items: [
          const DropdownMenuItem<String>(
              value: null, child: Text('All Branches')),
          ..._branches.map<DropdownMenuItem<String>>((b) =>
              DropdownMenuItem(value: b['_id'], child: Text(b['name']))),
        ],
        onChanged: (v) {
          setState(() {
            _branchId = v;
            _laborEmps = [];
            _selectedEmpIds.clear();
          });
        },
      ),
      const SizedBox(height: 12),

      // Date range + Load button
      Row(children: [
        Expanded(child: _datePicker(
          label: dfmt.format(_laborFrom),
          active: true,
          onTap: () => _pickLaborDate(isFrom: true),
        )),
        const SizedBox(width: 8),
        Expanded(child: _datePicker(
          label: dfmt.format(_laborTo),
          active: true,
          onTap: () => _pickLaborDate(isFrom: false),
        )),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _laborLoading ? null : _loadLaborEmployees,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _payPurple,
              borderRadius: BorderRadius.circular(10),
            ),
            child: _laborLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Row(children: [
                    Icon(Icons.search_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Load',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ]),
          ),
        ),
      ]),
      const SizedBox(height: 12),

      // Employee list
      if (_laborEmps.isEmpty && !_laborLoading)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Text('Select a branch and load employees',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
        )
      else ...[
        // Select-all header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _selectedEmpIds.length == _laborEmps.length &&
                    _laborEmps.isNotEmpty,
                tristate: _selectedEmpIds.isNotEmpty &&
                    _selectedEmpIds.length < _laborEmps.length,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedEmpIds
                          .addAll(_laborEmps.map((e) => e['_id'].toString()));
                    } else {
                      _selectedEmpIds.clear();
                    }
                  });
                  _syncPayable();
                },
                activeColor: _payPurple,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('Employee',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151)))),
            const SizedBox(width: 4),
            const SizedBox(
                width: 46,
                child: Text('Days',
                    style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    textAlign: TextAlign.center)),
            const SizedBox(
                width: 48,
                child: Text('Earnings',
                    style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    textAlign: TextAlign.right)),
            const SizedBox(
                width: 48,
                child: Text('Advance',
                    style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    textAlign: TextAlign.right)),
            const SizedBox(
                width: 50,
                child: Text('Net Pay',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right)),
          ]),
        ),
        // Employee rows
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(10)),
          ),
          child: Column(
            children: _laborEmps.asMap().entries.map((entry) {
              final i = entry.key;
              final emp = entry.value;
              final id = emp['_id'].toString();
              final selected = _selectedEmpIds.contains(id);
              final earnings = ((emp['earnings'] ?? 0) as num).toDouble();
              final deduction = _advDeduction[id] ?? 0.0;
              final net = (earnings - deduction).clamp(0.0, double.infinity);
              final photo = emp['photo'] as String?;
              return Container(
                decoration: BoxDecoration(
                  color: selected
                      ? _payPurple.withValues(alpha: 0.03)
                      : Colors.white,
                  border: i < _laborEmps.length - 1
                      ? const Border(
                          bottom: BorderSide(color: Color(0xFFF3F4F6)))
                      : null,
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedEmpIds.remove(id);
                      } else {
                        _selectedEmpIds.add(id);
                      }
                    });
                    _syncPayable();
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: selected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedEmpIds.add(id);
                              } else {
                                _selectedEmpIds.remove(id);
                              }
                            });
                            _syncPayable();
                          },
                          activeColor: _payPurple,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Avatar
                      _laborAvatar(emp['name'] ?? '', i, photo),
                      const SizedBox(width: 8),
                      // Name + code
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(emp['name'] ?? '—',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827)),
                                overflow: TextOverflow.ellipsis),
                            if ((emp['empCode'] ?? '').toString().isNotEmpty)
                              Text(emp['empCode'],
                                  style: const TextStyle(
                                      fontSize: 10, color: Color(0xFF9CA3AF))),
                          ])),
                      const SizedBox(width: 4),
                      // Days present + OT
                      SizedBox(
                          width: 46,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text('${emp['presentDays'] ?? 0}d',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2563EB))),
                                if ((emp['otHours'] ?? 0) > 0)
                                  Text(
                                      '${(emp['otHours'] as num).toStringAsFixed(1)}h OT',
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF9CA3AF))),
                              ])),
                      // Earnings
                      SizedBox(
                          width: 48,
                          child: Text('₹${fmt.format(earnings)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF374151)))),
                      // Advance deduction (editable)
                      SizedBox(
                          width: 48,
                          child: GestureDetector(
                            onTap: () => _editAdvDeduction(emp, deduction),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: deduction > 0
                                    ? const Color(0xFFFEF2F2)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('₹${fmt.format(deduction)}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: deduction > 0
                                        ? _payRed
                                        : const Color(0xFF9CA3AF),
                                  )),
                            ),
                          )),
                      // Net pay
                      SizedBox(
                          width: 50,
                          child: Text('₹${fmt.format(net)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: net > 0
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF9CA3AF),
                              ))),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Summary bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _payPurple.withValues(alpha: 0.25)),
          ),
          child: Column(children: [
            _summaryRow('Last Week Outstanding',
                '₹${fmt.format(_laborPrevOutstanding)}', _payRed),
            const SizedBox(height: 6),
            _summaryRow('This Week Earnings',
                '₹${fmt.format(_laborTotalEarnings)}', const Color(0xFF059669)),
            const SizedBox(height: 8),
            // Payable Amount — editable
            Row(children: [
              const Expanded(
                child: Text('Payable Amount',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151))),
              ),
              SizedBox(
                width: 120,
                child: TextFormField(
                  controller: _payableCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _payPurple),
                  decoration: InputDecoration(
                    prefixText: '₹',
                    prefixStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _payPurple),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                          color: _payPurple.withValues(alpha: 0.4)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide: BorderSide(color: _payPurple),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            const Divider(height: 16, color: Color(0xFFDDD6FE)),
            _summaryRow('This Week Outstanding',
                '₹${fmt.format(_laborThisWeekOutstanding)}',
                const Color(0xFFF59E0B),
                bold: true),
          ]),
        ),
      ],
    ]);
  }

  // ── Transport section ──────────────────────────────────────────────────────

  Widget _buildTransportSection() {
    final fmt = NumberFormat('#,##0.00');
    final dfmt = DateFormat('dd MMM yyyy');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Branch
      AppDropdown<String>(
        label: 'Branch',
        value: _branchId,
        items: [
          const DropdownMenuItem<String>(
              value: null, child: Text('All Branches')),
          ..._branches.map<DropdownMenuItem<String>>((b) =>
              DropdownMenuItem(value: b['_id'], child: Text(b['name']))),
        ],
        onChanged: (v) => setState(() {
          _branchId = v;
          _transportItems = [];
          _selectedVehicles.clear();
        }),
      ),
      const SizedBox(height: 12),

      // Date range + Load button
      Row(children: [
        Expanded(
          child: _transportDatePicker(
            label: dfmt.format(_transportFrom),
            onTap: () => _pickTransportDate(isFrom: true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _transportDatePicker(
            label: dfmt.format(_transportTo),
            onTap: () => _pickTransportDate(isFrom: false),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _transportLoading ? null : _loadTransportRecords,
            icon: _transportLoading
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh, size: 16),
            label: const Text('Load'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _payBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),

      if (_transportItems.isEmpty && !_transportLoading) ...[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Center(
            child: Text('Select date range and tap Load',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          ),
        ),
      ] else if (_transportLoading) ...[
        const Center(
            child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator())),
      ] else ...[
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _selectedVehicles.length == _transportItems.length &&
                    _transportItems.isNotEmpty,
                tristate: _selectedVehicles.isNotEmpty &&
                    _selectedVehicles.length < _transportItems.length,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedVehicles.addAll(
                          _transportItems.map((t) => t['vehicleNo'].toString()));
                    } else {
                      _selectedVehicles.clear();
                    }
                  });
                  _syncTransportPayable();
                },
                activeColor: _payBlue,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('Vehicle / Driver',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151)))),
            const SizedBox(
                width: 44,
                child: Text('Trips',
                    style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    textAlign: TextAlign.center)),
            const SizedBox(
                width: 72,
                child: Text('This Week',
                    style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    textAlign: TextAlign.right)),
            const SizedBox(
                width: 72,
                child: Text('Outstanding',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right)),
          ]),
        ),
        // Rows
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(10)),
          ),
          child: Column(
            children: _transportItems.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final vehicle = item['vehicleNo'].toString();
              final selected = _selectedVehicles.contains(vehicle);
              final cost = ((item['currentCost'] ?? 0) as num).toDouble();
              final prevOut = ((item['previousOutstanding'] ?? 0) as num).toDouble();
              return Container(
                decoration: BoxDecoration(
                  color: selected
                      ? _payBlue.withValues(alpha: 0.03)
                      : Colors.white,
                  border: i < _transportItems.length - 1
                      ? const Border(
                          bottom: BorderSide(color: Color(0xFFF3F4F6)))
                      : null,
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedVehicles.remove(vehicle);
                      } else {
                        _selectedVehicles.add(vehicle);
                      }
                    });
                    _syncTransportPayable();
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: selected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedVehicles.add(vehicle);
                              } else {
                                _selectedVehicles.remove(vehicle);
                              }
                            });
                            _syncTransportPayable();
                          },
                          activeColor: _payBlue,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Icon
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _payBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_shipping_outlined,
                            size: 15, color: _payBlue),
                      ),
                      const SizedBox(width: 8),
                      // Vehicle + driver
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(vehicle,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827)),
                                  overflow: TextOverflow.ellipsis),
                              Text(item['driverName'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF6B7280))),
                            ]),
                      ),
                      // Trips
                      SizedBox(
                          width: 44,
                          child: Text('${item['trips'] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB)))),
                      // This week cost
                      SizedBox(
                          width: 72,
                          child: Text('₹${fmt.format(cost)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF374151)))),
                      // Previous outstanding
                      SizedBox(
                          width: 72,
                          child: Text(
                              prevOut > 0 ? '₹${fmt.format(prevOut)}' : '—',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: prevOut > 0
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: prevOut > 0
                                      ? _payRed
                                      : const Color(0xFF9CA3AF)))),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Summary bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _payBlue.withValues(alpha: 0.25)),
          ),
          child: Column(children: [
            _summaryRow('Last Week Outstanding',
                '₹${fmt.format(_transportPrevOutstanding)}', _payRed),
            const SizedBox(height: 6),
            _summaryRow('This Week Cost',
                '₹${fmt.format(_transportTotalCost)}', const Color(0xFF059669)),
            const SizedBox(height: 8),
            Row(children: [
              const Expanded(
                child: Text('Payable Amount',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151))),
              ),
              SizedBox(
                width: 120,
                child: TextFormField(
                  controller: _transportPayableCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _payBlue),
                  decoration: InputDecoration(
                    prefixText: '₹',
                    prefixStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _payBlue),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          BorderSide(color: _payBlue.withValues(alpha: 0.4)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide: BorderSide(color: _payBlue),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            const Divider(height: 16, color: Color(0xFFBFDBFE)),
            _summaryRow('This Week Outstanding',
                '₹${fmt.format(_transportThisWeekOutstanding)}',
                const Color(0xFFF59E0B),
                bold: true),
          ]),
        ),
      ],
    ]);
  }

  Widget _transportDatePicker({required String label, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _payBlue.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _payBlue),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 13, color: _payBlue),
            const SizedBox(width: 6),
            Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _payBlue))),
          ]),
        ),
      );

  Widget _datePicker(
          {required String label,
          required bool active,
          required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? _payPurple.withValues(alpha: 0.07) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? _payPurple : const Color(0xFFDDE3E0)),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined,
                size: 13, color: active ? _payPurple : const Color(0xFF9CA3AF)),
            const SizedBox(width: 6),
            Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? _payPurple : const Color(0xFF9CA3AF),
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ))),
          ]),
        ),
      );

  Widget _laborAvatar(String name, int index, String? photo) {
    const colors = [
      Color(0xFF7C3AED),
      Color(0xFF2563EB),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFFDC2626),
      Color(0xFF0891B2)
    ];
    if (photo != null && photo.isNotEmpty) {
      try {
        final bytes = base64Decode(photo);
        return ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.memory(bytes, width: 28, height: 28, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    final color = colors[index % colors.length];
    final init = name.trim().isEmpty
        ? '?'
        : (name.trim().split(RegExp(r'\s+')).length >= 2
            ? '${name.trim().split(RegExp(r'\s+'))[0][0]}${name.trim().split(RegExp(r'\s+'))[1][0]}'
                .toUpperCase()
            : name
                .trim()
                .substring(0, name.trim().length.clamp(0, 2))
                .toUpperCase());
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Center(
          child: Text(init,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 10))),
    );
  }

  Widget _summaryRow(String label, String value, Color color,
          {bool bold = false}) =>
      Row(children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 14 : 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color)),
      ]);

  void _editAdvDeduction(Map emp, double current) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Advance Deduction\n${emp['name']}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: '₹ ',
            border: OutlineInputBorder(),
            labelText: 'Deduction amount',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim()) ?? 0;
              setState(() => _advDeduction[emp['_id'].toString()] = v);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _payPurple),
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _typeBtn(String value, String label, IconData icon, Color color) {
    final active = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:
              active ? color.withValues(alpha: 0.1) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? color : const Color(0xFFE5E7EB),
              width: active ? 1.5 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: active ? color : const Color(0xFF9CA3AF)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? color : const Color(0xFF6B7280))),
        ]),
      ),
    );
  }

  Widget _catBtn(String value, String label, IconData icon, Color color) {
    final active = _category == value;
    return GestureDetector(
      onTap: () => setState(() => _category = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color:
              active ? color.withValues(alpha: 0.1) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? color : const Color(0xFFE5E7EB),
              width: active ? 1.5 : 1),
        ),
        child: Column(children: [
          Icon(icon, size: 16, color: active ? color : const Color(0xFF9CA3AF)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? color : const Color(0xFF6B7280))),
        ]),
      ),
    );
  }
}
