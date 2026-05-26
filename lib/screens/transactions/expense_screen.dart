import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

const _expPrimary = Color(0xFF111827);
const _expGreen = Color(0xFF16A34A);
const _expAccent = Color(0xFFEA580C);

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});
  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List _items = [];
  bool _loading = true;
  String _search = '';
  int _tabIndex = 0; // 0=All, 1=This Month, 2=This Year
  String _sortBy = 'date_desc';
  String? _filterCategory;
  String? _filterBranch;
  DateTime? _filterFrom;
  DateTime? _filterTo;

  final _searchCtrl = TextEditingController();

  List get _filtered {
    final q = _search.toLowerCase();
    final now = DateTime.now();
    var list = _items.where((e) {
      final matchSearch = q.isEmpty ||
          (e['category'] ?? '').toLowerCase().contains(q) ||
          (e['branch']?['name'] ?? '').toLowerCase().contains(q) ||
          (e['description'] ?? '').toLowerCase().contains(q);
      final date = DateTime.tryParse(e['date'] ?? '');
      final matchTab = _tabIndex == 0 ||
          (_tabIndex == 1 && date != null && date.month == now.month && date.year == now.year) ||
          (_tabIndex == 2 && date != null && date.year == now.year);
      final matchCat = _filterCategory == null || e['category'] == _filterCategory;
      final matchBranch = _filterBranch == null || e['branch']?['_id'] == _filterBranch;
      final d = date != null ? DateTime(date.year, date.month, date.day) : null;
      final from = _filterFrom != null
          ? DateTime(_filterFrom!.year, _filterFrom!.month, _filterFrom!.day)
          : null;
      final to = _filterTo != null
          ? DateTime(_filterTo!.year, _filterTo!.month, _filterTo!.day)
          : null;
      final matchDate = (from == null || (d != null && !d.isBefore(from))) &&
          (to == null || (d != null && !d.isAfter(to)));
      return matchSearch && matchTab && matchCat && matchBranch && matchDate;
    }).toList();

    list.sort((a, b) {
      switch (_sortBy) {
        case 'date_asc':
          return (DateTime.tryParse(a['date'] ?? '') ?? DateTime(0))
              .compareTo(DateTime.tryParse(b['date'] ?? '') ?? DateTime(0));
        case 'amount_desc':
          return ((b['amount'] ?? 0) as num).compareTo((a['amount'] ?? 0) as num);
        case 'amount_asc':
          return ((a['amount'] ?? 0) as num).compareTo((b['amount'] ?? 0) as num);
        default:
          return (DateTime.tryParse(b['date'] ?? '') ?? DateTime(0))
              .compareTo(DateTime.tryParse(a['date'] ?? '') ?? DateTime(0));
      }
    });
    return list;
  }

  int get _activeFilterCount =>
      [_filterCategory, _filterBranch].where((e) => e != null).length +
      (_filterFrom != null ? 1 : 0) +
      (_filterTo != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/expenses');
    if (mounted) setState(() { _items = res['data'] ?? []; _loading = false; });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/expenses/$id');
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
      barrierLabel: 'expense-form',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final sw = MediaQuery.of(ctx).size.width;
        final pw = sw > 900 ? sw * 0.38 : sw * 0.92;
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
                child: ExpenseFormPanel(
                  item: item,
                  onSaved: () { Navigator.of(ctx).pop(); _load(); },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Sort menu ────────────────────────────────────────────────────────────────

  void _showSortMenu(BuildContext anchorCtx) {
    const items = {
      'date_desc': 'Newest First',
      'date_asc': 'Oldest First',
      'amount_desc': 'Highest Amount',
      'amount_asc': 'Lowest Amount',
    };
    showMenu<String>(
      context: anchorCtx,
      position: _buttonPosition(anchorCtx),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 4,
      items: items.entries.map((e) {
        final active = _sortBy == e.key;
        return PopupMenuItem<String>(
          value: e.key,
          child: Row(children: [
            Icon(
              active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: active ? _expGreen : const Color(0xFFD1D5DB),
            ),
            const SizedBox(width: 10),
            Text(e.value,
                style: TextStyle(
                    fontSize: 13,
                    color: active ? _expGreen : const Color(0xFF374151),
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ]),
        );
      }).toList(),
    ).then((val) { if (val != null) setState(() => _sortBy = val); });
  }

  // ── Inline filter helpers ────────────────────────────────────────────────────

  List<String> get _allCategories => (_items
        .map((e) => e['category']?.toString() ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort());

  List<Map> get _allBranches {
    final seen = <String>{};
    final result = <Map>[];
    for (final item in _items) {
      final id = item['branch']?['_id'];
      if (id != null && seen.add(id as String)) result.add(item['branch'] as Map);
    }
    return result;
  }

  Future<void> _pickFilterDate(bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom ? (_filterFrom ?? now) : (_filterTo ?? now);
    final first = isFrom ? DateTime(2020) : (_filterFrom ?? DateTime(2020));
    final last = isFrom ? (_filterTo ?? DateTime(2100)) : DateTime(2100);
    final safe = initial.isBefore(first) ? first : initial.isAfter(last) ? last : initial;
    final picked = await showDatePicker(
      context: context,
      initialDate: safe,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF2E7D52)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) { _filterFrom = picked; } else { _filterTo = picked; }
      });
    }
  }

  void _clearAllFilters() => setState(() {
        _filterCategory = null;
        _filterBranch = null;
        _filterFrom = null;
        _filterTo = null;
      });

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final rows = _filtered;
        final total = rows.fold<num>(0, (s, i) => s + (i['amount'] ?? 0));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Expenses',
              subtitle: 'Track and manage operational expenses',
              onRefresh: _load,
              onSearchChanged: (v) => setState(() => _search = v),
              searchHint: 'Search category, branch…',
              onAdd: () => _openForm(),
              addLabel: 'Add Expense',
            ),
            _buildTabBar(isMobile),
            _buildToolbar(isMobile, rows.length, total),
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
          ],
        );
      }),
    );
  }

  // ── Tab bar ──────────────────────────────────────────────────────────────────

  Widget _buildTabBar(bool isMobile) {
    const tabs = ['All', 'This Month', 'This Year'];
    const tabsFull = ['All Expenses', 'This Month', 'This Year'];
    if (isMobile) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Row(children: List.generate(tabs.length, (i) {
          final active = _tabIndex == i;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _tabIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: active ? _expAccent.withValues(alpha: 0.1) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: active ? _expAccent : const Color(0xFFE5E7EB)),
              ),
              child: Center(child: Text(tabs[i],
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? _expAccent : const Color(0xFF6B7280)))),
            ),
          ));
        })),
      );
    }
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
      child: Row(children: List.generate(tabsFull.length, (i) {
        final active = _tabIndex == i;
        return GestureDetector(
          onTap: () => setState(() => _tabIndex = i),
          child: Container(
            margin: const EdgeInsets.only(right: 24),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                color: active ? _expAccent : Colors.transparent, width: 2)),
            ),
            child: Text(tabsFull[i],
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? _expAccent : const Color(0xFF6B7280))),
          ),
        );
      })),
    );
  }

  // ── Toolbar ──────────────────────────────────────────────────────────────────

  Widget _buildToolbar(bool isMobile, int count, num total) {
    final cats = _allCategories;
    final branches = _allBranches;
    final fmt = DateFormat('dd MMM yyyy');
    const green = Color(0xFF2E7D52);

    InputDecoration dropDec(String hint, IconData icon) => InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 15, color: green),
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: green, width: 1.5)),
        );

    Widget dateTile(String placeholder, DateTime? date, bool isFrom) =>
        GestureDetector(
          onTap: () => _pickFilterDate(isFrom),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: date != null ? green : const Color(0xFFDDE3E0)),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_outlined,
                  size: 13,
                  color: date != null ? green : const Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  date != null ? fmt.format(date) : placeholder,
                  style: TextStyle(
                      fontSize: 12,
                      color: date != null
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF)),
                ),
              ),
              if (date != null)
                GestureDetector(
                  onTap: () => setState(
                      () => isFrom ? _filterFrom = null : _filterTo = null),
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: Color(0xFF9CA3AF)),
                ),
            ]),
          ),
        );

    Widget totalChip() => Row(mainAxisSize: MainAxisSize.min, children: [
          if (total > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _expAccent.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.currency_rupee_rounded,
                    size: 11, color: _expAccent),
                Text(_fmtAmount(total),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _expAccent)),
              ]),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6)),
            child: Text('$count rows',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),
        ]);

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    hintStyle:
                        TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 16, color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(top: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            totalChip(),
            const SizedBox(width: 8),
            _addBtn(),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _filterCategory,
                decoration: dropDec('All Categories', Icons.category_outlined),
                isExpanded: true,
                borderRadius: BorderRadius.circular(8),
                style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
                items: [
                  const DropdownMenuItem(
                      value: null,
                      child: Text('All Categories',
                          style: TextStyle(color: Color(0xFF9CA3AF)))),
                  ...cats.map(
                      (c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => setState(() => _filterCategory = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _filterBranch,
                decoration: dropDec('All Branches', Icons.store_outlined),
                isExpanded: true,
                borderRadius: BorderRadius.circular(8),
                style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
                items: [
                  const DropdownMenuItem(
                      value: null,
                      child: Text('All Branches',
                          style: TextStyle(color: Color(0xFF9CA3AF)))),
                  ...branches.map((b) => DropdownMenuItem(
                      value: b['_id'] as String,
                      child: Text(b['name'] as String))),
                ],
                onChanged: (v) => setState(() => _filterBranch = v),
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
                onTap: _clearAllFilters,
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
        Builder(builder: (ctx) => _sortBtn(ctx)),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _filterCategory,
            decoration: dropDec('All Categories', Icons.category_outlined),
            isExpanded: true,
            borderRadius: BorderRadius.circular(8),
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('All Categories',
                      style: TextStyle(color: Color(0xFF9CA3AF)))),
              ...cats.map((c) => DropdownMenuItem(value: c, child: Text(c))),
            ],
            onChanged: (v) => setState(() => _filterCategory = v),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _filterBranch,
            decoration: dropDec('All Branches', Icons.store_outlined),
            isExpanded: true,
            borderRadius: BorderRadius.circular(8),
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('All Branches',
                      style: TextStyle(color: Color(0xFF9CA3AF)))),
              ...branches.map((b) => DropdownMenuItem(
                  value: b['_id'] as String,
                  child: Text(b['name'] as String))),
            ],
            onChanged: (v) => setState(() => _filterBranch = v),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: dateTile('From date', _filterFrom, true)),
        const SizedBox(width: 10),
        Expanded(child: dateTile('To date', _filterTo, false)),
        if (_activeFilterCount > 0) ...[
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: _clearAllFilters,
            icon: const Icon(Icons.close_rounded, size: 13),
            label: const Text('Clear', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ],
        const SizedBox(width: 10),
        totalChip(),
      ]),
    );
  }



  Widget _sortBtn(BuildContext ctx) {
    const labels = {
      'date_desc': 'Newest First',
      'date_asc': 'Oldest First',
      'amount_desc': 'Highest Amount',
      'amount_asc': 'Lowest Amount',
    };
    final sorted = _sortBy != 'date_desc';
    return _toolbarSurface(
      onTap: () => _showSortMenu(ctx),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.swap_vert_rounded,
            size: 14, color: sorted ? _expGreen : const Color(0xFF6B7280)),
        const SizedBox(width: 6),
        Text(labels[_sortBy] ?? 'Sort',
            style: TextStyle(
                fontSize: 13,
                color: sorted ? _expGreen : const Color(0xFF374151),
                fontWeight: sorted ? FontWeight.w500 : FontWeight.w400)),
      ]),
    );
  }

  Widget _toolbarSurface({required VoidCallback onTap, required Widget child}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(7),
          color: Colors.white,
        ),
        child: child,
      ),
    );
  }

  RelativeRect _buttonPosition(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    return RelativeRect.fromLTRB(
        offset.dx, offset.dy + box.size.height + 4, offset.dx + box.size.width, 0);
  }

  Widget _addBtn() => ElevatedButton(
        onPressed: () => _openForm(),
        style: ElevatedButton.styleFrom(
          backgroundColor: _expPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Icon(Icons.add_rounded, size: 16),
      );

  // ── Card color palette ────────────────────────────────────────────────────────

  Color _cardColor(int i) {
    const palette = [
      Color(0xFFEA580C), Color(0xFFDB2777), Color(0xFF9333EA),
      Color(0xFF2563EB), Color(0xFF0D9488), Color(0xFF16A34A),
      Color(0xFFD97706), Color(0xFF0891B2),
    ];
    return palette[i % palette.length];
  }

  // ── Desktop table ─────────────────────────────────────────────────────────────

  Widget _buildTable(List rows) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: rows.length,
      itemBuilder: (_, i) => _buildCard(rows[i], i),
    );
  }

  Widget _buildCard(Map item, int index) {
    final date = item['date'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']).toLocal())
        : '—';
    final color = _cardColor(index);
    final cat = (item['category'] as String? ?? '—');
    final initial = cat.isNotEmpty ? cat[0].toUpperCase() : '₹';
    final desc = (item['description'] as String? ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: null,
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0xFFF0FDF4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: color),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(children: [
                          // Avatar
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(initial,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: color)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Category + Branch + Description
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(cat,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827))),
                                const SizedBox(height: 3),
                                Row(children: [
                                  const Icon(Icons.store_outlined,
                                      size: 11, color: Color(0xFF9CA3AF)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                        item['branch']?['name'] ?? '—',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280)),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ]),
                                if (desc.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(desc,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Amount + Date
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '₹${_fmtAmount(item['amount'] is num ? item['amount'] : 0)}',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A)),
                              ),
                              const SizedBox(height: 5),
                              Row(children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 11, color: Color(0xFF9CA3AF)),
                                const SizedBox(width: 3),
                                Text(date,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF))),
                              ]),
                            ],
                          ),
                          const SizedBox(width: 4),
                          _actionMenu(item),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Mobile list ───────────────────────────────────────────────────────────────

  Widget _buildMobileList(List list) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (_, i) => _mobileCard(list[i], i),
    );
  }

  Widget _mobileCard(Map item, int index) {
    final date = item['date'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']).toLocal())
        : '—';
    final color = _cardColor(index);
    final cat = (item['category'] as String? ?? '—');
    final initial = cat.isNotEmpty ? cat[0].toUpperCase() : '₹';
    final desc = (item['description'] as String? ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: color),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(initial,
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: color)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(cat,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111827))),
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    const Icon(Icons.store_outlined,
                                        size: 11, color: Color(0xFF9CA3AF)),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                          item['branch']?['name'] ?? '—',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF6B7280)),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ]),
                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(desc,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '₹${_fmtAmount(item['amount'] is num ? item['amount'] : 0)}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF16A34A)),
                                ),
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.calendar_today_outlined,
                                      size: 10, color: Color(0xFF9CA3AF)),
                                  const SizedBox(width: 3),
                                  Text(date,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF))),
                                ]),
                              ],
                            ),
                            _actionMenu(item),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionMenu(Map item) {
    if (!context.read<AuthService>().isAdmin) return const SizedBox.shrink();
    return SizedBox(
      width: 40,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF9CA3AF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 3,
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Row(children: [
            Icon(Icons.edit_outlined, size: 15, color: Color(0xFF374151)),
            SizedBox(width: 8),
            Text('Edit', style: TextStyle(fontSize: 13)),
          ])),
          PopupMenuItem(value: 'delete', child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
          ])),
        ],
        onSelected: (v) {
          if (v == 'edit') _openForm(item);
          if (v == 'delete') _delete(item['_id']);
        },
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    final hasFilter =
        _search.isNotEmpty || _activeFilterCount > 0 || _tabIndex != 0;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.receipt_long_outlined, size: 28, color: _expAccent),
        ),
        const SizedBox(height: 14),
        Text(hasFilter ? 'No results found' : 'No expenses yet',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(
          hasFilter
              ? 'Try adjusting your search or filters.'
              : 'Add your first expense to get started.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        if (hasFilter) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _search = '';
              _searchCtrl.clear();
              _filterCategory = null;
              _filterBranch = null;
              _filterFrom = null;
              _filterTo = null;
              _tabIndex = 0;
            }),
            child: const Text('Clear filters', style: TextStyle(color: _expAccent)),
          ),
        ] else ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add Expense', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _expPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Amount formatter ──────────────────────────────────────────────────────────

String _fmtAmount(num v) => NumberFormat('#,##,###.##', 'en_IN').format(v);


// ── Slide-in Form Panel ───────────────────────────────────────────────────────
class ExpenseFormPanel extends StatefulWidget {
  final Map? item;
  final VoidCallback onSaved;
  const ExpenseFormPanel({super.key, this.item, required this.onSaved});
  @override
  State<ExpenseFormPanel> createState() => _ExpenseFormPanelState();
}

class _ExpenseFormPanelState extends State<ExpenseFormPanel> {
  final _formKey = GlobalKey<FormState>();
  List _branches = [];
  List _expCategories = [];
  String? _branchId, _category;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _formPrimary = Color(0xFF1B5E37);
  static const _formAccent = Color(0xFF2E7D52);
  static const _formGradient2 = Color(0xFF1E6F5C);

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.item != null) {
      final e = widget.item!;
      _branchId = e['branch']?['_id'];
      _category = e['category'];
      _amountCtrl.text = '${e['amount'] ?? ''}';
      _descCtrl.text = e['description'] ?? '';
      if (e['date'] != null) _date = DateTime.parse(e['date']).toLocal();
    }
  }

  @override
  void dispose() { _amountCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _loadDropdowns() async {
    final results = await Future.wait([
      ApiService.get('/branches'),
      ApiService.get('/expense-categories'),
    ]);
    if (mounted) {
      setState(() {
        _branches = results[0]['data'] ?? [];
        _expCategories = results[1]['data'] ?? [];
        if (_category != null) {
          final names = _expCategories.map((c) => c['name'] as String).toList();
          if (!names.contains(_category)) _category = null;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'branch': _branchId,
      'category': _category,
      'amount': double.tryParse(_amountCtrl.text) ?? 0,
      'date': _date.toIso8601String(),
      'description': _descCtrl.text,
    };
    final res = widget.item == null
        ? await ApiService.post('/expenses', body)
        : await ApiService.put('/expenses/${widget.item!['_id']}', body);
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Saved!' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) widget.onSaved();
    }
    if (mounted) setState(() => _saving = false);
  }

  InputDecoration _dec(String label, IconData icon, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: _formAccent),
        labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _formAccent, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      );

  Widget _sectionLabel(String text, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 13, color: _formAccent),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
          const SizedBox(width: 8),
          const Expanded(child: Divider(thickness: 1, color: Color(0xFFE5E7EB))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return Column(children: [
      const SizedBox(height: 10),
      Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
            color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(height: 2),
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_formPrimary, _formGradient2],
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
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEdit ? 'Edit Expense' : 'New Expense',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                isEdit ? 'Update the expense entry below' : 'Fill in the expense details below',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ]),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.close, color: Colors.white70, size: 16),
            ),
          ),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('Category & Branch', Icons.category_outlined),
              DropdownButtonFormField<String>(
                key: ValueKey('cat_$_category'),
                initialValue: _category,
                decoration: _dec('Expense Category', Icons.receipt_long_outlined),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                borderRadius: BorderRadius.circular(10),
                isExpanded: true,
                items: _expCategories
                    .map<DropdownMenuItem<String>>((c) => DropdownMenuItem(
                        value: c['name'] as String, child: Text(c['name'] as String)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('branch_$_branchId'),
                initialValue: _branchId,
                decoration: _dec('Branch', Icons.store_outlined),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                borderRadius: BorderRadius.circular(10),
                isExpanded: true,
                items: _branches
                    .map<DropdownMenuItem<String>>((b) => DropdownMenuItem(
                        value: b['_id'] as String, child: Text(b['name'] as String)))
                    .toList(),
                onChanged: (v) => setState(() => _branchId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              _sectionLabel('Amount & Date', Icons.currency_rupee_rounded),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: _dec('Amount (₹)', Icons.currency_rupee_rounded),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DatePickerField(
                  label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d)),
              const SizedBox(height: 20),
              _sectionLabel('Description', Icons.notes_rounded),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: _dec('Description', Icons.notes_rounded),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _formAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const ButtonLoader()
                      : Text(
                          isEdit ? 'Update Expense' : 'Save Expense',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
