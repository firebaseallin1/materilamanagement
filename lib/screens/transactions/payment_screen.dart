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
    final res = await ApiService.get('/branches');
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
    if (mounted) setState(() { _items = res['data'] ?? []; _loading = false; });
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
      _filterBranch != null || _filterParty != null ||
      _filterFrom != null || _filterTo != null;

  void _clearFilters() => setState(() {
        _filterBranch = null;
        _filterParty = null;
        _filterFrom = null;
        _filterTo = null;
      });

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_filterFrom ?? now)
        : (_filterTo ?? _filterFrom ?? now);
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

  List get _incoming => _filtered.where((e) => e['type'] == 'received').toList();
  List get _outgoing => _filtered.where((e) => e['type'] == 'paid').toList();

  double get _totalReceived =>
      _incoming.fold(0.0, (s, e) => s + (double.tryParse('${e['amount']}') ?? 0));
  double get _totalPaid =>
      _outgoing.fold(0.0, (s, e) => s + (double.tryParse('${e['amount']}') ?? 0));
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
                  onSaved: () { Navigator.of(ctx).pop(); _load(); },
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
      _summaryTileWidget('Received', '₹${fmt.format(_totalReceived)}', _payGreen, Icons.arrow_downward_rounded),
      _summaryTileWidget('Paid Out', '₹${fmt.format(_totalPaid)}', _payRed, Icons.arrow_upward_rounded),
      _summaryTileWidget('Net', '₹${fmt.format(net.abs())}',
          net >= 0 ? _payGreen : _payRed,
          net >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded),
      _summaryTileWidget('Pending', '₹${fmt.format(_totalPending)}', _payAmber, Icons.schedule_rounded),
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

  Widget _summaryTileWidget(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 7),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
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
                  child: Text(b['name'] ?? '', overflow: TextOverflow.ellipsis)))
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
            Expanded(child: _tabBtn(0, 'Incoming', Icons.arrow_downward_rounded, _payGreen, _incoming.length)),
            const SizedBox(width: 8),
            Expanded(child: _tabBtn(1, 'Outgoing', Icons.arrow_upward_rounded, _payRed, _outgoing.length)),
          ]),
          const SizedBox(height: 8),
          // Row 2: branch + party
          Row(children: [
            Expanded(child: branchDrop()),
            const SizedBox(width: 8),
            Expanded(child: partyDrop()),
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
          _tabBtn(0, 'Incoming', Icons.arrow_downward_rounded, _payGreen, _incoming.length),
          const SizedBox(width: 8),
          _tabBtn(1, 'Outgoing', Icons.arrow_upward_rounded, _payRed, _outgoing.length),
          Container(height: 24, width: 1, color: const Color(0xFFE5E7EB),
              margin: const EdgeInsets.symmetric(horizontal: 12)),
          SizedBox(width: 150, child: branchDrop()),
          const SizedBox(width: 8),
          SizedBox(width: 150, child: partyDrop()),
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
        color: active ? activeColor.withValues(alpha: 0.07) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? activeColor : const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(children: [
            Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
            const SizedBox(width: 5),
            Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          ]),
          icon: Icon(Icons.expand_more_rounded, size: 16,
              color: active ? activeColor : const Color(0xFF9CA3AF)),
          isExpanded: true,
          style: TextStyle(fontSize: 12,
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
          border: Border.all(color: active ? activeColor : const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Icon(icon, size: 13, color: active ? activeColor : const Color(0xFF9CA3AF)),
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

  Widget _tabBtn(int index, String label, IconData icon, Color color, int count) {
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _payGreen)),
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
      Color(0xFF16A34A), Color(0xFF0891B2),
      Color(0xFF7C3AED), Color(0xFF0369A1),
      Color(0xFF0D9488), Color(0xFF6366F1),
    ];
    final strip = strips[index % strips.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: strip),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: _payGreen.withValues(alpha: 0.1),
                    child: const Icon(Icons.arrow_downward_rounded,
                        size: 15, color: _payGreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        children:
            sortedKeys.map((k) => _buildWeekGroup(k, weeks[k]!)).toList(),
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
    final totalDue = items.fold(0.0,
        (s, e) => s + (double.tryParse('${e['totalDue'] ?? e['amount']}') ?? 0));
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _payRed)),
            if (pending > 0)
              Text('₹${fmt.format(pending)} pending',
                  style: const TextStyle(fontSize: 10, color: _payAmber)),
          ]),
        ]),
      ),
      ...items.asMap().entries
          .map((e) => _buildOutgoingCard(e.value, e.key, sunday)),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildOutgoingCard(Map item, int index, DateTime weekSunday) {
    final category = item['category'] ?? 'expense';
    final catColor = _categoryColor(category);
    final catIcon = _categoryIcon(category);
    final date = item['date'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
        : '—';
    final fmt = NumberFormat('#,##0.##');
    final totalDue =
        double.tryParse('${item['totalDue'] ?? item['amount']}') ?? 0;
    final paid = double.tryParse('${item['amount']}') ?? 0;
    final pending = totalDue > paid ? totalDue - paid : 0.0;
    final hasPending = pending > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: hasPending
                ? const Color(0xFFFBBF24).withValues(alpha: 0.5)
                : const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(children: [
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
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['partyName'] ?? '—',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: _payPrimary)),
                        const SizedBox(height: 3),
                        Row(children: [
                          _catBadge(category),
                          const SizedBox(width: 6),
                          Text(item['branch']?['name'] ?? '—',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF9CA3AF))),
                        ]),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (totalDue > 0 && totalDue != paid) ...[
                        Text('Due ₹${fmt.format(totalDue)}',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF9CA3AF))),
                        const SizedBox(height: 1),
                      ],
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
                const Icon(Icons.schedule_rounded,
                    size: 12, color: _payAmber),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'labor': return _payPurple;
      case 'transport': return _payBlue;
      default: return _payOrange;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'labor': return Icons.people_outline_rounded;
      case 'transport': return Icons.local_shipping_outlined;
      default: return Icons.receipt_long_outlined;
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
                  style:
                      TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
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
  List _branches = [];
  String? _branchId, _mode = 'cash', _category = 'expense';
  late String _type;
  final _partyCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _totalDueCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

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

  @override
  void initState() {
    super.initState();
    _type = widget.defaultType;
    _loadBranches();
    if (widget.item != null) {
      final e = widget.item!;
      _branchId = e['branch']?['_id'];
      _mode = e['paymentMode'] ?? 'cash';
      _type = e['type'] ?? widget.defaultType;
      _category = e['category'] ?? 'expense';
      _partyCtrl.text = e['partyName'] ?? '';
      _amountCtrl.text = '${e['amount'] ?? ''}';
      _totalDueCtrl.text = '${e['totalDue'] ?? e['amount'] ?? ''}';
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
    _refCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches');
    if (mounted) setState(() => _branches = res['data'] ?? []);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
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
        labelStyle:
            const TextStyle(color: Color(0xFF374151), fontSize: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: _primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

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
          const Icon(Icons.payment_outlined,
              color: Colors.white70, size: 22),
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
                  child: _typeBtn('paid', 'Outgoing',
                      Icons.arrow_upward_rounded, _payRed)),
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
                  .map<DropdownMenuItem<String>>((b) =>
                      DropdownMenuItem(value: b['_id'], child: Text(b['name'])))
                  .toList(),
              onChanged: (v) => setState(() => _branchId = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            // Total Due (outgoing only)
            if (isOutgoing) ...[
              TextFormField(
                controller: _totalDueCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    _dec('Total Due (₹)', hint: 'Full amount owed'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec(
                  isOutgoing ? 'Paying Now (₹)' : 'Amount (₹)'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onChanged: (_) => setState(() {}),
            ),
            // Pending preview
            if (isOutgoing && _pendingAmt > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFBBF24)
                          .withValues(alpha: 0.5)),
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
                                  fontSize: 11,
                                  color: Color(0xFF92400E))),
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
                  backgroundColor: isOutgoing ? _payRed : _payGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const ButtonLoader()
                    : Text(_isEdit
                        ? 'Update Payment'
                        : (isOutgoing ? 'Record Payment' : 'Record Income')),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _typeBtn(String value, String label, IconData icon, Color color) {
    final active = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.1)
              : const Color(0xFFF9FAFB),
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
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.w400,
                  color:
                      active ? color : const Color(0xFF6B7280))),
        ]),
      ),
    );
  }

  Widget _catBtn(
      String value, String label, IconData icon, Color color) {
    final active = _category == value;
    return GestureDetector(
      onTap: () => setState(() => _category = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.1)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? color : const Color(0xFFE5E7EB),
              width: active ? 1.5 : 1),
        ),
        child: Column(children: [
          Icon(icon,
              size: 16,
              color: active ? color : const Color(0xFF9CA3AF)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.w400,
                  color:
                      active ? color : const Color(0xFF6B7280))),
        ]),
      ),
    );
  }
}
