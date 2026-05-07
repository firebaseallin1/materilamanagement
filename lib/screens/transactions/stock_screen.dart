import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

// ── Shell ─────────────────────────────────────────────────────────────────────

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String _search = '';
  int _refresh = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _refresh++);

  void _goAdd() => _openStockForm(context, onSaved: _reload);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: 'Material Stock',
            subtitle: 'Store · Stock In · Stock Out',
            onRefresh: _reload,
            onSearchChanged: (v) => setState(() => _search = v),
            searchHint: 'Search...',
            onAdd: _goAdd,
            addLabel: 'Add Stock',
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: const Color(0xFF2E7D52),
              unselectedLabelColor: const Color(0xFF9E9E9E),
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              indicatorColor: const Color(0xFF2E7D52),
              indicatorWeight: 2.5,
              tabs: const [
                Tab(text: 'Total Stock'),
                Tab(text: 'By Warehouse'),
                Tab(text: 'Movements'),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _TotalStockTab(
                    key: ValueKey('total-$_refresh'), search: _search),
                _WarehouseTab(
                    key: ValueKey('warehouse-$_refresh'), search: _search),
                _MovementsTab(
                    key: ValueKey('movements-$_refresh'),
                    search: _search,
                    onReload: _reload),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1 · Total Stock ───────────────────────────────────────────────────────

class _TotalStockTab extends StatefulWidget {
  final String search;
  const _TotalStockTab({super.key, required this.search});
  @override
  State<_TotalStockTab> createState() => _TotalStockTabState();
}

class _TotalStockTabState extends State<_TotalStockTab> {
  List _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/stock/summary');
    if (mounted) {
      setState(() {
        _items = res['data'] ?? [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.search.toLowerCase();
    final filtered = q.isEmpty
        ? _items
        : _items
            .where((i) => (i['material']?['name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(q))
            .toList();

    if (_loading) return const AppLoader();
    if (filtered.isEmpty) {
      return const EmptyState(
          message: 'No stock data', icon: Icons.inventory_2_outlined);
    }

    return LayoutBuilder(builder: (_, constraints) {
      final isMobile = constraints.maxWidth < 700;
      return RefreshIndicator(
        onRefresh: _load,
        child: isMobile
            ? ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _TotalStockCard(item: filtered[i]),
              )
            : _buildDesktopTable(filtered),
      );
    });
  }

  Widget _buildDesktopTable(List filtered) {
    const hdrStyle = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF94A3B8),
        letterSpacing: 0.7);

    Widget colHdr(String label, Color dot) => SizedBox(
          width: 108,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(label, style: hdrStyle),
          ]),
        );

    Widget chip(String val, Color fg, Color bg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(val,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
        );

    return Column(children: [
      // ── Header ──────────────────────────────────────────────────────────────
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          border:
              Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 11, 24, 11),
        child: Row(children: [
          const SizedBox(width: 32, child: Text('#', style: hdrStyle)),
          const Expanded(flex: 4, child: Text('MATERIAL', style: hdrStyle)),
          colHdr('STORED', const Color(0xFF059669)),
          colHdr('MOVED', const Color(0xFF7C3AED)),
          colHdr('BALANCE', const Color(0xFF2563EB)),
          const Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.only(left: 20),
                child: Text('UTILIZED', style: hdrStyle),
              )),
        ]),
      ),

      // ── Rows ────────────────────────────────────────────────────────────────
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final item = filtered[i];
            final name = (item['material']?['name'] ?? '—') as String;
            final code = (item['material']?['code'] ?? '—') as String;
            final unit = (item['material']?['unit'] ?? 'pcs') as String;
            final balance = (item['balance'] as num? ?? 0).toDouble();
            final stored = (item['stored'] as num? ?? 0).toDouble();
            final moved = (item['moved'] as num? ?? 0).toDouble();
            final ratio = stored > 0 ? (moved / stored).clamp(0.0, 1.0) : 0.0;
            final lowStock = balance >= 0 && ratio > 0.85;

            final statusColor = ratio > 0.85
                ? const Color(0xFFEF4444)
                : ratio > 0.55
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981);

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 5,
                      offset: const Offset(0, 1))
                ],
              ),
              child: IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status strip
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12)),
                        ),
                      ),
                      // Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Row(children: [
                            // Index
                            SizedBox(
                              width: 28,
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFCBD5E1))),
                            ),
                            // Material info
                            Expanded(
                                flex: 4,
                                child: Row(children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: statusColor.withValues(
                                              alpha: 0.2)),
                                    ),
                                    child: Icon(_matIcon(name),
                                        size: 18, color: statusColor),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1E293B)),
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text('$code · $unit',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF94A3B8))),
                                    ],
                                  )),
                                ])),
                            // STORED chip
                            SizedBox(
                                width: 108,
                                child: Center(
                                    child: chip(
                                        '+${_fmt(stored)}',
                                        const Color(0xFF059669),
                                        const Color(0xFFECFDF5)))),
                            // MOVED chip
                            SizedBox(
                              width: 108,
                              child: Center(
                                child: moved > 0
                                    ? chip(_fmt(moved), const Color(0xFF7C3AED),
                                        const Color(0xFFF5F3FF))
                                    : const Text('—',
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFFCBD5E1))),
                              ),
                            ),
                            // BALANCE badge
                            SizedBox(
                              width: 108,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: balance > 0
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (balance > 0
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFFEF4444))
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: Text(
                                    '${_fmt(balance)} $unit',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            // UTILIZED bar
                            Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${(ratio * 100).toStringAsFixed(0)}%',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: statusColor),
                                          ),
                                          if (lowStock)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFEF2F2),
                                                  borderRadius:
                                                      BorderRadius.circular(5)),
                                              child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                        Icons
                                                            .warning_amber_rounded,
                                                        size: 10,
                                                        color:
                                                            Color(0xFFEF4444)),
                                                    SizedBox(width: 3),
                                                    Text('Low',
                                                        style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Color(
                                                                0xFFEF4444))),
                                                  ]),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: ratio,
                                          minHeight: 7,
                                          backgroundColor:
                                              const Color(0xFFF1F5F9),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  statusColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ]),
                        ),
                      ),
                    ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _TotalStockCard extends StatelessWidget {
  final Map item;
  const _TotalStockCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = (item['material']?['name'] ?? '—') as String;
    final code = (item['material']?['code'] ?? '') as String;
    final unit = (item['material']?['unit'] ?? 'pcs') as String;
    final balance = (item['balance'] as num? ?? 0).toDouble();
    final stored = (item['stored'] as num? ?? 0).toDouble();
    final moved = (item['moved'] as num? ?? 0).toDouble();
    final ratio = stored > 0 ? (moved / stored).clamp(0.0, 1.0) : 0.0;
    final lowStock = balance >= 0 && ratio > 0.85;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                lowStock ? const Color(0xFFFFCDD2) : const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_matIcon(name),
                      size: 22, color: const Color(0xFF2E7D52)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF1A1A1A))),
                      Text(
                        code.isNotEmpty
                            ? 'Code: $code  ·  Unit: $unit'
                            : 'Unit: $unit',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9E9E9E)),
                      ),
                    ],
                  ),
                ),
                // Balance badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: balance > 0
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_fmt(balance)} $unit',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: balance > 0
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFD32F2F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Breakdown: Stored | Moved | Balance
            Row(
              children: [
                _StatPill(
                  label: 'Stored',
                  value: stored,
                  color: const Color(0xFF2E7D32),
                  icon: Icons.add_box_outlined,
                ),
                const SizedBox(width: 6),
                _StatPill(
                  label: 'Moved',
                  value: moved,
                  color: const Color(0xFF6A1B9A),
                  icon: Icons.local_shipping_outlined,
                ),
                const SizedBox(width: 6),
                _StatPill(
                  label: 'Balance',
                  value: balance,
                  color: const Color(0xFF1565C0),
                  icon: Icons.account_balance_outlined,
                  highlight: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Utilization bar (issued vs total-in)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: const Color(0xFFE8F5E9),
                valueColor: AlwaysStoppedAnimation<Color>(
                  ratio > 0.85
                      ? const Color(0xFFD32F2F)
                      : const Color(0xFF2E7D32),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  '${(ratio * 100).toStringAsFixed(0)}% utilized',
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
                ),
                if (lowStock) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.warning_amber_rounded,
                      size: 12, color: Color(0xFFD32F2F)),
                  const SizedBox(width: 2),
                  const Text('Low stock',
                      style: TextStyle(fontSize: 10, color: Color(0xFFD32F2F))),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData? icon;
  final bool highlight;
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight
              ? color.withValues(alpha: 0.12)
              : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: highlight
              ? Border.all(color: color.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(height: 3),
            ],
            Text(
              _fmt(value),
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14, color: color),
            ),
            const SizedBox(height: 1),
            Text(label,
                style: const TextStyle(fontSize: 9, color: Color(0xFF757575))),
          ],
        ),
      ),
    );
  }
}

// ── Tab 2 · By Warehouse ──────────────────────────────────────────────────────

class _WarehouseTab extends StatefulWidget {
  final String search;
  const _WarehouseTab({super.key, required this.search});
  @override
  State<_WarehouseTab> createState() => _WarehouseTabState();
}

class _WarehouseTabState extends State<_WarehouseTab> {
  List _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/stock/branch-wise');
    if (mounted) {
      setState(() {
        _items = res['data'] ?? [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.search.toLowerCase();
    final filtered = q.isEmpty
        ? _items
        : _items.where((b) {
            if ((b['branch']?['name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(q)) {
              return true;
            }
            return (b['materials'] as List? ?? []).any((m) =>
                (m['material']?['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(q));
          }).toList();

    if (_loading) return const AppLoader();
    if (filtered.isEmpty) {
      return const EmptyState(
          message: 'No warehouse data', icon: Icons.warehouse_outlined);
    }

    return LayoutBuilder(builder: (_, constraints) {
      final maxCardWidth = constraints.maxWidth < 700 ? double.infinity : 860.0;
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          itemBuilder: (_, i) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxCardWidth),
              child: _WarehouseCard(data: filtered[i]),
            ),
          ),
        ),
      );
    });
  }
}

class _WarehouseCard extends StatefulWidget {
  final Map data;
  const _WarehouseCard({required this.data});
  @override
  State<_WarehouseCard> createState() => _WarehouseCardState();
}

class _WarehouseCardState extends State<_WarehouseCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final branchName = (widget.data['branch']?['name'] ?? '—') as String;
    final materials = (widget.data['materials'] as List? ?? []);
    final totalStored = (widget.data['totalStored'] as num? ?? 0).toDouble();
    final totalMoveIn = (widget.data['totalMoveIn'] as num? ?? 0).toDouble();
    final totalMoveOut = (widget.data['totalMoveOut'] as num? ?? 0).toDouble();
    final totalBalance = (widget.data['totalBalance'] as num? ?? 0).toDouble();
    final hasStore = totalStored > 0;

    const colLabel = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9E9E9E),
        letterSpacing: 0.8);

    Widget balBadge(double v, {double fontSize = 13}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: v > 0 ? const Color(0xFF2563EB) : const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: (v > 0
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFEF4444))
                      .withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Text(_fmt(v),
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Branch header ──────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: const Icon(Icons.warehouse_rounded,
                      size: 22, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(branchName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF1E293B))),
                        Text(
                          '${materials.length} material${materials.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ]),
                ),
                // Quick stats
                Row(children: [
                  if (hasStore) ...[
                    _HeaderStat('Stored', totalStored, const Color(0xFF059669)),
                    const SizedBox(width: 10),
                    _HeaderStat('In', totalMoveIn, const Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    _HeaderStat('Out', totalMoveOut, const Color(0xFF7C3AED)),
                    const SizedBox(width: 12),
                  ] else ...[
                    _HeaderStat('In', totalMoveIn, const Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    _HeaderStat('Out', totalMoveOut, const Color(0xFF7C3AED)),
                    const SizedBox(width: 12),
                  ],
                  balBadge(totalBalance, fontSize: 12),
                ]),
                const SizedBox(width: 8),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF94A3B8),
                  size: 22,
                ),
              ]),
            ),
          ),

          if (_expanded) ...[
            // ── Column headers ───────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                const Expanded(child: Text('MATERIAL', style: colLabel)),
                if (hasStore)
                  const SizedBox(
                      width: 72,
                      child: Text('STORED',
                          style: colLabel, textAlign: TextAlign.center)),
                const SizedBox(
                    width: 72,
                    child: Text('IN',
                        style: colLabel, textAlign: TextAlign.center)),
                const SizedBox(
                    width: 72,
                    child: Text('OUT',
                        style: colLabel, textAlign: TextAlign.center)),
                const SizedBox(
                    width: 88,
                    child: Text('BALANCE',
                        style: colLabel, textAlign: TextAlign.center)),
              ]),
            ),

            // ── Material rows ────────────────────────────────────────────────
            ...materials.asMap().entries.map((entry) {
              final idx = entry.key;
              final m = entry.value as Map;
              final mName = (m['material']?['name'] ?? '—') as String;
              final mUnit = (m['material']?['unit'] ?? '') as String;
              final mStore = (m['stored'] as num? ?? 0).toDouble();
              final mIn = (m['moveIn'] as num? ?? 0).toDouble();
              final mOut = (m['moveOut'] as num? ?? 0).toDouble();
              final mBal = (m['balance'] as num? ?? 0).toDouble();

              Widget numCell(String val, Color color, {bool plus = false}) =>
                  SizedBox(
                    width: 72,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${plus ? '+' : ''}$val',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );

              return Column(children: [
                if (idx > 0)
                  const Divider(
                      height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF1E293B))),
                            if (mUnit.isNotEmpty)
                              Text(mUnit,
                                  style: const TextStyle(
                                      fontSize: 10, color: Color(0xFF94A3B8))),
                          ]),
                    ),
                    if (hasStore)
                      numCell(_fmt(mStore), const Color(0xFF059669),
                          plus: true),
                    numCell(_fmt(mIn), const Color(0xFF2563EB), plus: true),
                    numCell(_fmt(mOut), const Color(0xFF7C3AED)),
                    SizedBox(
                      width: 88,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: mBal > 0
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _fmt(mBal),
                            style: TextStyle(
                              color: mBal > 0
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFD32F2F),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    )
                  ]),
                ),
              ]);
            }),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _HeaderStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _fmt(value),
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}

// ── Tab 3 · Movements ─────────────────────────────────────────────────────────

class _MovementsTab extends StatefulWidget {
  final String search;
  final VoidCallback onReload;
  const _MovementsTab(
      {super.key, required this.search, required this.onReload});
  @override
  State<_MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<_MovementsTab> {
  List _items = [];
  bool _loading = true;

  // Filters
  String? _selMaterial;
  String? _selRoute;
  String? _selTransport;
  String? _selType; // null=all | 'store' | 'stock_move' | 'out' | 'in'
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/stock/history');
    if (mounted) {
      setState(() {
        _items = res['data'] ?? [];
        _loading = false;
      });
    }
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/stock/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  void _clearFilters() => setState(() {
        _selMaterial = null;
        _selRoute = null;
        _selTransport = null;
        _selType = null;
        _fromDate = null;
        _toDate = null;
      });

  int get _activeFilterCount => [
        _selMaterial,
        _selRoute,
        _selTransport,
        _selType,
        _fromDate,
        _toDate,
      ].where((e) => e != null).length;

  List<Map> get _filtered {
    final q = widget.search.toLowerCase();
    return _items.where((item) {
      final mat = (item['material']?['name'] ?? '').toString().toLowerCase();
      final branch = (item['branch']?['name'] ?? '').toString().toLowerCase();
      final from = (item['fromBranch']?['name'] ?? '').toString();
      final to = (item['toBranch']?['name'] ?? '').toString();
      final txType = (item['transactionType'] ?? '').toString();
      final ledType = (item['type'] ?? 'in').toString();
      final transport = (item['transportName'] ?? '').toString().toLowerCase();
      final routeLabel =
          from.isNotEmpty || to.isNotEmpty ? '$from → $to' : branch;
      final raw = DateTime.tryParse(item['date']?.toString() ?? '');
      final itemDate = raw != null
          ? DateTime(raw.toLocal().year, raw.toLocal().month, raw.toLocal().day)
          : null;

      final matchesSearch = q.isEmpty ||
          mat.contains(q) ||
          routeLabel.toLowerCase().contains(q) ||
          transport.contains(q);

      final matchesMaterial =
          _selMaterial == null || mat == _selMaterial!.toLowerCase();

      final matchesRoute = _selRoute == null ||
          routeLabel.toLowerCase() == _selRoute!.toLowerCase();

      final matchesTransport = _selTransport == null ||
          transport.contains(_selTransport!.toLowerCase());

      final matchesType = _selType == null ||
          (_selType == 'store' && txType == 'store') ||
          (_selType == 'stock_move' && txType == 'stock_move') ||
          (_selType == 'out' && txType != 'stock_move' && ledType == 'out') ||
          (_selType == 'in' && txType != 'stock_move' && ledType == 'in');

      final matchesFrom = _fromDate == null ||
          (itemDate != null && !itemDate.isBefore(_fromDate!));
      final matchesTo = _toDate == null ||
          (itemDate != null && !itemDate.isAfter(_toDate!));

      return matchesSearch &&
          matchesMaterial &&
          matchesRoute &&
          matchesTransport &&
          matchesType &&
          matchesFrom &&
          matchesTo;
    }).cast<Map>().toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoader();

    final results = _filtered;

    return LayoutBuilder(builder: (_, constraints) {
      final isMobile = constraints.maxWidth < 700;
      return Column(
        children: [
          _buildFilterBar(results.length),
          Expanded(
            child: results.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: EmptyState(
                        message: _activeFilterCount > 0
                            ? 'No results for current filters'
                            : 'No stock movements',
                        icon: Icons.swap_vert,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: isMobile
                        ? ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            itemCount: results.length,
                            itemBuilder: (_, i) => _HistoryCard(
                              item: results[i],
                              onEdit: () => _openStockForm(context,
                                  item: results[i], onSaved: _load),
                              onDelete: () => _delete(results[i]['_id']),
                            ),
                          )
                        : _buildDesktopTable(results),
                  ),
          ),
        ],
      );
    });
  }

  // ── Filter Bar ──────────────────────────────────────────────────────────────

  static const _green = Color(0xFF2E7D52);
  static const _greenLight = Color(0xFFE8F5E9);

  Widget _buildFilterBar(int resultCount) {
    final hasFilters = _activeFilterCount > 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE8ECF0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(children: [
              const Icon(Icons.filter_list_rounded,
                  size: 15, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              const Text('Filters',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569))),
              if (hasFilters) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('$_activeFilterCount',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ],
              const Spacer(),
              // Result count
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12)),
                child: Text('$resultCount record${resultCount != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B))),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: _clearFilters,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: const Color(0xFFFECACA))),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.close_rounded,
                          size: 11, color: Color(0xFFDC2626)),
                      SizedBox(width: 4),
                      Text('Clear all',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626))),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 8),

          // ── Type quick-filter chips ────────────────────────────────────────
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _typeChip(null, 'All', Icons.layers_outlined),
                const SizedBox(width: 6),
                _typeChip('store', 'Store', Icons.add_box_outlined),
                const SizedBox(width: 6),
                _typeChip('stock_move', 'Move',
                    Icons.local_shipping_outlined),
                const SizedBox(width: 6),
                _typeChip('in', 'Received', Icons.add_circle_outline),
                const SizedBox(width: 6),
                _typeChip('out', 'Issued', Icons.remove_circle_outline),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Dropdown + date row ────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              _filterDropdown(
                icon: Icons.category_outlined,
                hint: 'Material',
                value: _selMaterial,
                items: _getMaterials(),
                onChanged: (v) => setState(() => _selMaterial = v),
              ),
              const SizedBox(width: 8),
              _filterDropdown(
                icon: Icons.alt_route_outlined,
                hint: 'Route',
                value: _selRoute,
                items: _getRoutes(),
                onChanged: (v) => setState(() => _selRoute = v),
              ),
              const SizedBox(width: 8),
              _filterDropdown(
                icon: Icons.local_shipping_outlined,
                hint: 'Transport',
                value: _selTransport,
                items: _getTransports(),
                onChanged: (v) => setState(() => _selTransport = v),
              ),
              const SizedBox(width: 8),
              _datePill(
                  'From',
                  _fromDate,
                  (d) => setState(() => _fromDate = d),
                  () => setState(() => _fromDate = null)),
              const SizedBox(width: 8),
              _datePill(
                  'To',
                  _toDate,
                  (d) => setState(() => _toDate = d),
                  () => setState(() => _toDate = null)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String? type, String label, IconData icon) {
    final selected = _selType == type;
    return GestureDetector(
      onTap: () => setState(() => _selType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _green : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? _green : const Color(0xFFE2E8F0), width: 1.2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 12, color: selected ? Colors.white : const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      selected ? Colors.white : const Color(0xFF475569))),
        ]),
      ),
    );
  }

  Widget _filterDropdown({
    required IconData icon,
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final active = value != null;
    return Container(
      width: 160,
      height: 36,
      decoration: BoxDecoration(
        color: active ? _greenLight : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: active ? _green.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
            width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active ? _green : const Color(0xFF94A3B8)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          hint: Row(children: [
            Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(hint,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF94A3B8))),
          ]),
          selectedItemBuilder: (_) => [
            // index 0 → null selected (show plain hint)
            Row(children: [
              Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(hint,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8))),
            ]),
            // index 1..n → each real item selected
            ...items.map((e) => Row(children: [
                  Icon(icon, size: 13, color: _green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(e,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _green),
                        overflow: TextOverflow.ellipsis),
                  ),
                ])),
          ],
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('All $hint',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8))),
            ),
            ...items.map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _datePill(String label, DateTime? value, Function(DateTime) onPick,
      VoidCallback onClear) {
    final active = value != null;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDate: value ?? DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: _green),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? _greenLight : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active
                  ? _green.withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
              width: 1.2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined,
              size: 13, color: active ? _green : const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Text(
            active ? '$label: ${_fmtDate(value.toIso8601String())}' : label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? _green : const Color(0xFF94A3B8)),
          ),
          if (active) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded,
                  size: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ]),
      ),
    );
  }

  List<String> _getMaterials() => _items
      .map((e) => e['material']?['name']?.toString())
      .whereType<String>()
      .toSet()
      .toList()
    ..sort();

  List<String> _getRoutes() => _items
      .where((e) =>
          (e['fromBranch']?['name'] ?? '').toString().isNotEmpty &&
          (e['toBranch']?['name'] ?? '').toString().isNotEmpty)
      .map((e) =>
          '${e['fromBranch']['name']} → ${e['toBranch']['name']}')
      .toSet()
      .toList()
    ..sort();

  List<String> _getTransports() => _items
      .map((e) => e['transportName']?.toString() ?? '')
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  Widget _buildDesktopTable(List filtered) {
    const hdr = TextStyle(
        fontSize: 10,
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8);
    return Column(children: [
      // ── Header ──────────────────────────────────────────────────────────────
      Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
        child: const Row(children: [
          SizedBox(width: 32, child: Text('#', style: hdr)),
          SizedBox(width: 120, child: Text('TYPE', style: hdr)),
          Expanded(flex: 3, child: Text('MATERIAL', style: hdr)),
          Expanded(flex: 4, child: Text('BRANCH / ROUTE', style: hdr)),
          Expanded(flex: 3, child: Text('TRANSPORT', style: hdr)),
          SizedBox(width: 110, child: Text('QTY', style: hdr, textAlign: TextAlign.center)),
          SizedBox(width: 100, child: Text('DATE', style: hdr)),
          SizedBox(width: 36),
        ]),
      ),
      const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

      // ── Rows ────────────────────────────────────────────────────────────────
      Expanded(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final item = filtered[i];
            final txType = (item['transactionType'] ?? '') as String;
            final ledType = (item['type'] ?? 'in') as String;
            final matName = (item['material']?['name'] ?? '—') as String;
            final matUnit = (item['material']?['unit'] ?? '') as String;
            final qty = (item['quantity'] as num? ?? 0).toDouble();
            final isMove = txType == 'stock_move';
            final from = (item['fromBranch']?['name'] ?? '') as String;
            final to = (item['toBranch']?['name'] ?? '') as String;
            final branch = (item['branch']?['name'] ?? '—') as String;
            final cfg = _txConfig(txType, ledType);
            final transportName = (item['transportName'] ?? '') as String;
            final vehicleName = (item['vehicleName'] ?? '') as String;
            final driverName = (item['driverName'] ?? '') as String;
            final distance = item['distance'] as num?;
            final cost = item['cost'] as num?;

            return InkWell(
              onTap: () => _openStockForm(context, item: item, onSaved: _load),
              borderRadius: BorderRadius.circular(10),
              hoverColor: cfg.iconBg.withValues(alpha: 0.4),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.025),
                        blurRadius: 4,
                        offset: const Offset(0, 1)),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // Colored left strip
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: cfg.iconColor,
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            bottomLeft: Radius.circular(10)),
                      ),
                    ),
                    // Index
                    SizedBox(
                      width: 32,
                      child: Center(
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    // TYPE badge
                    SizedBox(
                      width: 120,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: cfg.labelBg,
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(cfg.icon, size: 10, color: cfg.labelColor),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(cfg.label,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: cfg.labelColor),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                        ),
                      ),
                    ),
                    // MATERIAL
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: cfg.iconBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(cfg.icon, size: 15, color: cfg.iconColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(matName,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B)),
                                    overflow: TextOverflow.ellipsis),
                                if (matUnit.isNotEmpty)
                                  Text(matUnit,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                    // BRANCH / ROUTE
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        child: isMove
                            ? _RouteWidget(from: from, to: to)
                            : Row(children: [
                                const Icon(Icons.warehouse_outlined,
                                    size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(branch,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF374151)),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ]),
                      ),
                    ),
                    // TRANSPORT
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        child: _TransportSummaryCell(
                          name: transportName,
                          vehicle: vehicleName,
                          driver: driverName,
                          distance: distance,
                          cost: cost,
                        ),
                      ),
                    ),
                    // QTY
                    SizedBox(
                      width: 110,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: cfg.badgeBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: cfg.badgeColor.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            '${cfg.qtyPrefix}${_fmt(qty)} $matUnit',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: cfg.badgeColor),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    // DATE
                    SizedBox(
                      width: 100,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _fmtDateShort(item['date'] as String?),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151)),
                            ),
                            Text(
                              _fmtYear(item['date'] as String?),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ACTIONS
                    SizedBox(
                      width: 36,
                      child: Center(
                        child: _ActionMenu(
                          onEdit: () =>
                              _openStockForm(context, item: item, onSaved: _load),
                          onDelete: () => _delete(item['_id']),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ── History Card (mobile) ─────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final Map item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _HistoryCard(
      {required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final txType = (item['transactionType'] ?? '') as String;
    final ledgerType = (item['type'] ?? 'in') as String;
    final matName = (item['material']?['name'] ?? '—') as String;
    final matUnit = (item['material']?['unit'] ?? '') as String;
    final qty = (item['quantity'] as num? ?? 0).toDouble();
    final remarks = (item['remarks'] ?? '') as String;
    final dateStr = item['date'] as String?;
    final isMove = txType == 'stock_move';
    final cfg = _txConfig(txType, ledgerType);

    final fromBranch = (item['fromBranch']?['name'] ?? '') as String;
    final toBranch = (item['toBranch']?['name'] ?? '') as String;
    final branch = (item['branch']?['name'] ?? '—') as String;
    final transportName = (item['transportName'] ?? '') as String;
    final vehicleName = (item['vehicleName'] ?? '') as String;
    final driverName = (item['driverName'] ?? '') as String;
    final distance = item['distance'] as num?;
    final cost = item['cost'] as num?;
    final hasTransport = transportName.isNotEmpty ||
        vehicleName.isNotEmpty ||
        driverName.isNotEmpty ||
        distance != null ||
        cost != null;

    return GestureDetector(
      onTap: () => _openStockForm(context, item: item,
          onSaved: () {}), // parent handles reload via onEdit
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEF2F6)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ── Accent strip ──────────────────────────────────────────────
            Container(width: 4, color: cfg.iconColor),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1 — type badge · date · menu
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: cfg.labelBg,
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(cfg.icon, size: 10, color: cfg.labelColor),
                          const SizedBox(width: 4),
                          Text(cfg.label,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: cfg.labelColor)),
                        ]),
                      ),
                      const Spacer(),
                      const Icon(Icons.calendar_today_outlined,
                          size: 10, color: Color(0xFFB0BEC5)),
                      const SizedBox(width: 4),
                      Text(_fmtDate(dateStr),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8))),
                      const SizedBox(width: 4),
                      _ActionMenu(onEdit: onEdit, onDelete: onDelete),
                    ]),

                    const SizedBox(height: 10),

                    // Row 2 — icon · name · qty
                    Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cfg.iconBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(cfg.icon, size: 19, color: cfg.iconColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(matName,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B)),
                                overflow: TextOverflow.ellipsis),
                            if (matUnit.isNotEmpty)
                              Text(matUnit,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: cfg.badgeBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: cfg.badgeColor.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          '${cfg.qtyPrefix}${_fmt(qty)} $matUnit',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: cfg.badgeColor),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 8),

                    // Row 3 — route / branch
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE8ECF0)),
                      ),
                      child: isMove
                          ? _RouteWidget(from: fromBranch, to: toBranch)
                          : Row(children: [
                              const Icon(Icons.warehouse_outlined,
                                  size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(branch,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155)),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                    ),

                    // Row 4 — transport (if any)
                    if (hasTransport) ...[
                      const SizedBox(height: 6),
                      _TransportSummaryCell(
                        name: transportName,
                        vehicle: vehicleName,
                        driver: driverName,
                        distance: distance,
                        cost: cost,
                        inCard: true,
                      ),
                    ],

                    // Row 5 — remarks (if any)
                    if (remarks.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.notes_rounded,
                            size: 12, color: Color(0xFFB0BEC5)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(remarks,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9E9E9E),
                                  fontStyle: FontStyle.italic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _RouteWidget extends StatelessWidget {
  final String from;
  final String to;
  const _RouteWidget({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.warehouse_outlined, size: 13, color: Color(0xFF64748B)),
      const SizedBox(width: 6),
      Flexible(
        child: Text(from,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155)),
            overflow: TextOverflow.ellipsis),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('→',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7C3AED))),
        ),
      ),
      Flexible(
        child: Text(to,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155)),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

class _TransportSummaryCell extends StatelessWidget {
  final String name;
  final String vehicle;
  final String driver;
  final num? distance;
  final num? cost;
  final bool inCard;
  const _TransportSummaryCell({
    required this.name,
    required this.vehicle,
    required this.driver,
    this.distance,
    this.cost,
    this.inCard = false,
  });

  static const _purple = Color(0xFF6A1B9A);
  static const _purpleBg = Color(0xFFF5F0FF);
  static const _purpleBorder = Color(0xFFDDD6FE);

  @override
  Widget build(BuildContext context) {
    final hasAny = name.isNotEmpty ||
        vehicle.isNotEmpty ||
        driver.isNotEmpty ||
        distance != null ||
        cost != null;
    if (!hasAny) {
      return const Text('—',
          style: TextStyle(fontSize: 14, color: Color(0xFFE2E8F0)));
    }

    // ── Card mode: transport-screen style ──────────────────────────────────
    if (inCard) {
      // headline = vehicle no. or transport name (whichever is more prominent)
      final headline = vehicle.isNotEmpty ? vehicle : name;
      final subParts = <String>[
        if (name.isNotEmpty && vehicle.isNotEmpty) name,
        if (driver.isNotEmpty) driver,
      ];

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _purpleBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _purpleBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: icon + headline + cost badge
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.local_shipping_outlined,
                    size: 17, color: _purple),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis),
                    if (subParts.isNotEmpty)
                      Text(subParts.join(' · '),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (cost != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: _purple.withValues(alpha: 0.25)),
                  ),
                  child: Text('₹$cost',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _purple)),
                ),
              ],
            ]),

            // Row 2: distance + driver (if not already in subtitle)
            if (distance != null || (driver.isNotEmpty && subParts.isEmpty)) ...[
              const SizedBox(height: 7),
              Wrap(spacing: 12, runSpacing: 4, children: [
                if (driver.isNotEmpty && subParts.isEmpty)
                  _infoChip(Icons.person_outline_rounded, driver,
                      const Color(0xFF0369A1)),
                if (distance != null)
                  _infoChip(Icons.route_outlined, '${distance}km',
                      const Color(0xFF374151)),
              ]),
            ],
          ],
        ),
      );
    }

    // ── Table / inline mode: compact chips row ─────────────────────────────
    return Row(children: [
      const Icon(Icons.local_shipping_outlined,
          size: 12, color: _purple),
      const SizedBox(width: 5),
      Expanded(
        child: Wrap(spacing: 6, runSpacing: 3, children: [
          if (name.isNotEmpty)
            _infoChip(Icons.business_outlined, name, _purple),
          if (vehicle.isNotEmpty)
            _infoChip(Icons.directions_car_outlined, vehicle,
                const Color(0xFF0369A1)),
          if (driver.isNotEmpty)
            _infoChip(Icons.person_outline_rounded, driver,
                const Color(0xFF0369A1)),
          if (distance != null)
            _infoChip(Icons.route_outlined, '${distance}km',
                const Color(0xFF374151)),
          if (cost != null)
            _infoChip(Icons.currency_rupee_rounded, '₹$cost',
                const Color(0xFF374151)),
        ]),
      ),
    ]);
  }

  Widget _infoChip(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w500, color: color)),
        ],
      );
}

class _ActionMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ActionMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded,
            size: 16, color: Color(0xFFB0BEC5)),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 3,
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 15, color: Color(0xFF374151)),
              SizedBox(width: 8),
              Text('Edit', style: TextStyle(fontSize: 13)),
            ]),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline_rounded,
                  size: 15, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Delete',
                  style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
            ]),
          ),
        ],
        onSelected: (v) {
          if (v == 'edit') onEdit();
          if (v == 'delete') onDelete();
        },
      ),
    );
  }
}

// ── History card config ───────────────────────────────────────────────────────

class _TxConfig {
  final String label;
  final String qtyPrefix;
  final Color labelColor, labelBg;
  final Color badgeColor, badgeBg;
  final Color iconColor, iconBg;
  final IconData icon;
  const _TxConfig({
    required this.label,
    required this.qtyPrefix,
    required this.labelColor,
    required this.labelBg,
    required this.badgeColor,
    required this.badgeBg,
    required this.iconColor,
    required this.iconBg,
    required this.icon,
  });
}

_TxConfig _txConfig(String txType, String ledgerType) {
  switch (txType) {
    case 'store':
      return const _TxConfig(
        label: 'Store Stock',
        qtyPrefix: '+',
        labelColor: Color(0xFF2E7D32),
        labelBg: Color(0xFFE8F5E9),
        badgeColor: Color(0xFF2E7D32),
        badgeBg: Color(0xFFE8F5E9),
        iconColor: Color(0xFF2E7D32),
        iconBg: Color(0xFFE8F5E9),
        icon: Icons.add_box_outlined,
      );
    case 'stock_move':
      return const _TxConfig(
        label: 'Stock Move',
        qtyPrefix: '↕ ',
        labelColor: Color(0xFF6A1B9A),
        labelBg: Color(0xFFF3E5F5),
        badgeColor: Color(0xFF6A1B9A),
        badgeBg: Color(0xFFF3E5F5),
        iconColor: Color(0xFF6A1B9A),
        iconBg: Color(0xFFF3E5F5),
        icon: Icons.local_shipping_outlined,
      );
    default:
      // Legacy records: use ledger type
      if (ledgerType == 'out') {
        return const _TxConfig(
          label: 'Issued',
          qtyPrefix: '− ',
          labelColor: Color(0xFFF57C00),
          labelBg: Color(0xFFFFF3E0),
          badgeColor: Color(0xFFF57C00),
          badgeBg: Color(0xFFFFF3E0),
          iconColor: Color(0xFFF57C00),
          iconBg: Color(0xFFFFF3E0),
          icon: Icons.remove_circle_outline,
        );
      }
      return const _TxConfig(
        label: 'Received',
        qtyPrefix: '+ ',
        labelColor: Color(0xFF2E7D32),
        labelBg: Color(0xFFE8F5E9),
        badgeColor: Color(0xFF2E7D32),
        badgeBg: Color(0xFFE8F5E9),
        iconColor: Color(0xFF2E7D32),
        iconBg: Color(0xFFE8F5E9),
        icon: Icons.add_circle_outline,
      );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmt(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

String _fmtDate(String? d) {
  if (d == null) return '—';
  final dt = DateTime.tryParse(d);
  if (dt == null) return '—';
  return DateFormat('dd MMM yyyy').format(dt.toLocal());
}

String _fmtDateShort(String? d) {
  if (d == null) return '—';
  final dt = DateTime.tryParse(d);
  if (dt == null) return '—';
  return DateFormat('dd MMM').format(dt.toLocal());
}

String _fmtYear(String? d) {
  if (d == null) return '';
  final dt = DateTime.tryParse(d);
  if (dt == null) return '';
  return DateFormat('yyyy').format(dt.toLocal());
}

IconData _matIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('steel') ||
      n.contains('metal') ||
      n.contains('iron') ||
      n.contains('re-bar') ||
      n.contains('re bar')) {
    return Icons.grid_4x4;
  }
  if (n.contains('wood') ||
      n.contains('lumber') ||
      n.contains('timber') ||
      n.contains('ply')) {
    return Icons.layers_outlined;
  }
  if (n.contains('cement') ||
      n.contains('concrete') ||
      n.contains('mortar') ||
      n.contains('sand')) {
    return Icons.blur_on;
  }
  if (n.contains('pipe') || n.contains('pvc') || n.contains('tube')) {
    return Icons.plumbing;
  }
  if (n.contains('wire') || n.contains('cable') || n.contains('copper')) {
    return Icons.electrical_services;
  }
  if (n.contains('paint') || n.contains('coat') || n.contains('primer')) {
    return Icons.format_paint;
  }
  if (n.contains('brick') || n.contains('tile') || n.contains('block')) {
    return Icons.view_quilt;
  }
  if (n.contains('glass') || n.contains('window')) return Icons.window;
  return Icons.inventory_2_outlined;
}

// ── Open stock form (slide-in panel) ─────────────────────────────────────────

void _openStockForm(BuildContext context,
    {Map? item, required VoidCallback onSaved}) {
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
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
        child: SizedBox(
          width: panelWidth,
          height: MediaQuery.of(ctx).size.height,
          child: StockFormPanel(item: item, onSaved: onSaved),
        ),
      ),
    ),
    transitionBuilder: (_, a, __, child) => SlideTransition(
      position:
          Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(a),
      child: child,
    ),
  );
}

// ── Stock Form Panel ──────────────────────────────────────────────────────────

class StockFormPanel extends StatefulWidget {
  final Map? item;
  final VoidCallback onSaved;
  const StockFormPanel({super.key, this.item, required this.onSaved});
  @override
  State<StockFormPanel> createState() => _StockFormPanelState();
}

class _StockFormPanelState extends State<StockFormPanel> {
  final _formKey = GlobalKey<FormState>();

  List _materials = [], _branches = [];

  // Transaction type: 'store' | 'stock_move'
  String _txType = 'store';
  bool _isEditingMove =
      false; // lock branches/material when editing a stock_move

  // STORE STOCK
  String? _branchId;

  // STOCK MOVE
  String? _fromBranchId;
  String? _toBranchId;

  // Common
  String? _materialId;
  final _qtyCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _transportNameCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _vehicleNameCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  bool _saving = false, _loadingData = true;
  double? _availableQty;
  bool _loadingBalance = false;

  static const _primary = Color(0xFF1B3A27);
  static const _accent = Color(0xFF2E7D52);

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.item != null) {
      final e = widget.item!;
      final tt = (e['transactionType'] as String?) ?? 'store';
      _txType = tt == 'stock_move' ? 'stock_move' : 'store';
      _materialId = e['material']?['_id'] as String?;
      _qtyCtrl.text = '${e['quantity'] ?? ''}';
      _remarksCtrl.text = (e['remarks'] ?? '') as String;
      if (e['date'] != null) {
        _date = DateTime.tryParse(e['date'].toString()) ?? DateTime.now();
      }
      if (_txType == 'store') {
        _branchId = e['branch']?['_id'] as String?;
      } else {
        _isEditingMove = true;
        _fromBranchId = e['fromBranch']?['_id'] as String?;
        _toBranchId = e['toBranch']?['_id'] as String?;
        _transportNameCtrl.text = (e['transportName'] ?? '') as String;
        _driverNameCtrl.text = (e['driverName'] ?? '') as String;
        _vehicleNameCtrl.text = (e['vehicleName'] ?? '') as String;
        _distanceCtrl.text = e['distance'] != null ? '${e['distance']}' : '';
        _costCtrl.text = e['cost'] != null ? '${e['cost']}' : '';
      }
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _remarksCtrl.dispose();
    _transportNameCtrl.dispose();
    _driverNameCtrl.dispose();
    _vehicleNameCtrl.dispose();
    _distanceCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    final results = await Future.wait([
      ApiService.get('/materials'),
      ApiService.get('/branches'),
    ]);
    if (!mounted) return;
    setState(() {
      _materials = results[0]['data'] ?? [];
      _branches = results[1]['data'] ?? [];
      _loadingData = false;
    });
    if (widget.item == null && _txType == 'store') {
      _autoSelectVilankuruchi();
    }
    if (_txType != 'store') _fetchBalance();
  }

  void _autoSelectVilankuruchi() {
    final matches = _branches.where((b) =>
        (b['name'] as String? ?? '').toLowerCase().contains('vilankuruchi'));
    if (matches.isNotEmpty && mounted) {
      setState(() => _branchId = matches.first['_id'] as String);
    }
  }

  void _onTypeChange(String newType) {
    if (_isEditingMove) return; // lock type when editing a transfer
    setState(() {
      _txType = newType;
      _availableQty = null;
    });
    if (newType == 'store') {
      _autoSelectVilankuruchi();
    } else {
      _fetchBalance();
    }
  }

  Future<void> _fetchBalance() async {
    if (_txType != 'stock_move' ||
        _materialId == null ||
        _fromBranchId == null) {
      setState(() => _availableQty = null);
      return;
    }
    setState(() => _loadingBalance = true);
    final res = await ApiService.get(
        '/stock/balance?material=$_materialId&branch=$_fromBranchId');
    if (!mounted) return;
    double balance = ((res['balance'] as num?) ?? 0).toDouble();
    // Add back original qty when editing a transfer
    if (_isEditingMove && widget.item != null) {
      balance += ((widget.item!['quantity'] as num?) ?? 0).toDouble();
    }
    setState(() {
      _availableQty = balance;
      _loadingBalance = false;
    });
    _formKey.currentState?.validate();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final Map<String, dynamic> body;

    if (_txType == 'store') {
      body = {
        'transactionType': 'store',
        'material': _materialId,
        'branch': _branchId,
        'quantity': qty,
        'date': _date.toIso8601String(),
        'remarks': _remarksCtrl.text.trim(),
      };
    } else {
      body = {
        'transactionType': 'stock_move',
        'material': _materialId,
        'fromBranch': _fromBranchId,
        'toBranch': _toBranchId,
        'quantity': qty,
        'date': _date.toIso8601String(),
        'remarks': _remarksCtrl.text.trim(),
        'transportName': _transportNameCtrl.text.trim(),
        'driverName': _driverNameCtrl.text.trim(),
        'vehicleName': _vehicleNameCtrl.text.trim(),
        'distance': _distanceCtrl.text.trim().isNotEmpty
            ? double.tryParse(_distanceCtrl.text.trim())
            : null,
        'cost': _costCtrl.text.trim().isNotEmpty
            ? double.tryParse(_costCtrl.text.trim())
            : null,
      };
    }

    final res = widget.item == null
        ? await ApiService.post('/stock', body)
        : await ApiService.put('/stock/${widget.item!['_id']}', body);

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

  InputDecoration _dec(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: _accent),
      labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFFF7F9F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDE3E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDE3E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 2),
        // Gradient header
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
              child: const Icon(Icons.inventory_2_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isNew ? 'Add Stock' : 'Edit Stock',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      isNew
                          ? 'Choose a transaction type below'
                          : 'Update the stock entry below',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close, color: Colors.white70, size: 16),
              ),
            ),
          ]),
        ),
        // Form body
        Expanded(
          child: _loadingData
              ? const AppLoader()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Transaction type selector ──────────────────────
                        const Text('Transaction Type',
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(children: [
                          _TxTypeBtn(
                            label: 'Store Stock',
                            icon: Icons.add_box_outlined,
                            selected: _txType == 'store',
                            color: const Color(0xFF2E7D32),
                            disabled: _isEditingMove,
                            onTap: () => _onTypeChange('store'),
                          ),
                          const SizedBox(width: 8),
                          _TxTypeBtn(
                            label: 'Stock Move',
                            icon: Icons.local_shipping_outlined,
                            selected: _txType == 'stock_move',
                            color: const Color(0xFF6A1B9A),
                            disabled: _isEditingMove && _txType != 'stock_move',
                            onTap: () => _onTypeChange('stock_move'),
                          ),
                        ]),
                        const SizedBox(height: 18),

                        // ── STORE STOCK: single branch ─────────────────────
                        if (_txType == 'store') ...[
                          DropdownButtonFormField<String>(
                            key: ValueKey('branch_$_branchId'),
                            initialValue: _branchId,
                            decoration: _dec('Branch', Icons.store_outlined),
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF1A1A2E)),
                            borderRadius: BorderRadius.circular(10),
                            items: _branches
                                .map<DropdownMenuItem<String>>((b) =>
                                    DropdownMenuItem(
                                        value: b['_id'] as String,
                                        child: Text(b['name'] as String)))
                                .toList(),
                            onChanged: (v) => setState(() => _branchId = v),
                            validator: (v) =>
                                v == null ? 'Please select a branch' : null,
                            isExpanded: true,
                          ),
                        ],

                        // ── STOCK MOVE: from + to branch + transport ───────
                        if (_txType == 'stock_move') ...[
                          DropdownButtonFormField<String>(
                            key: ValueKey('from_$_fromBranchId'),
                            initialValue: _fromBranchId,
                            decoration:
                                _dec('From Branch', Icons.store_outlined),
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF1A1A2E)),
                            borderRadius: BorderRadius.circular(10),
                            items: _branches
                                .map<DropdownMenuItem<String>>((b) =>
                                    DropdownMenuItem(
                                        value: b['_id'] as String,
                                        child: Text(b['name'] as String)))
                                .toList(),
                            onChanged: _isEditingMove
                                ? null
                                : (v) {
                                    setState(() => _fromBranchId = v);
                                    _fetchBalance();
                                  },
                            validator: (v) => v == null
                                ? 'Please select source branch'
                                : null,
                            isExpanded: true,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            key: ValueKey('to_$_toBranchId'),
                            initialValue: _toBranchId,
                            decoration: _dec('To Branch',
                                Icons.store_mall_directory_outlined),
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF1A1A2E)),
                            borderRadius: BorderRadius.circular(10),
                            items: _branches
                                .map<DropdownMenuItem<String>>((b) =>
                                    DropdownMenuItem(
                                        value: b['_id'] as String,
                                        child: Text(b['name'] as String)))
                                .toList(),
                            onChanged: _isEditingMove
                                ? null
                                : (v) => setState(() => _toBranchId = v),
                            validator: (v) {
                              if (v == null) {
                                return 'Please select destination branch';
                              }
                              if (v == _fromBranchId) {
                                return 'Source and destination must differ';
                              }
                              return null;
                            },
                            isExpanded: true,
                          ),
                          const SizedBox(height: 14),
                          // Available stock banner
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _loadingBalance
                                  ? const Color(0xFFF3F4F6)
                                  : (_availableQty != null &&
                                          _availableQty! <= 0)
                                      ? const Color(0xFFFFEBEE)
                                      : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _loadingBalance
                                    ? const Color(0xFFE5E7EB)
                                    : (_availableQty != null &&
                                            _availableQty! <= 0)
                                        ? const Color(0xFFFFCDD2)
                                        : const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: Row(children: [
                              Icon(
                                _loadingBalance
                                    ? Icons.hourglass_empty_rounded
                                    : (_availableQty != null &&
                                            _availableQty! <= 0)
                                        ? Icons.warning_amber_rounded
                                        : Icons.inventory_2_outlined,
                                size: 16,
                                color: _loadingBalance
                                    ? const Color(0xFF9CA3AF)
                                    : (_availableQty != null &&
                                            _availableQty! <= 0)
                                        ? const Color(0xFFD32F2F)
                                        : const Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 8),
                              if (_loadingBalance)
                                const Text('Checking available stock…',
                                    style: TextStyle(
                                        fontSize: 12, color: Color(0xFF9CA3AF)))
                              else if (_availableQty == null)
                                const Text(
                                    'Select material & source branch to see stock',
                                    style: TextStyle(
                                        fontSize: 12, color: Color(0xFF9CA3AF)))
                              else if (_availableQty! <= 0)
                                const Text(
                                    'No stock available in source branch',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFD32F2F),
                                        fontWeight: FontWeight.w500))
                              else
                                Text(
                                  'Available: ${_fmt(_availableQty!)} units',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.w600),
                                ),
                            ]),
                          ),
                          const SizedBox(height: 14),
                          // ── Transport Details ──────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E5F5),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFCE93D8)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(children: [
                                  Icon(Icons.local_shipping_outlined,
                                      size: 14, color: Color(0xFF6A1B9A)),
                                  SizedBox(width: 6),
                                  Text('Transport Details',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF6A1B9A))),
                                  SizedBox(width: 4),
                                  Text('(optional)',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9E9E9E))),
                                ]),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _transportNameCtrl,
                                  decoration: _dec('Transport Name',
                                      Icons.business_outlined),
                                ),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _vehicleNameCtrl,
                                      decoration: _dec('Vehicle No.',
                                          Icons.directions_car_outlined),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _driverNameCtrl,
                                      decoration: _dec('Driver Name',
                                          Icons.person_outline_rounded),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _distanceCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: _dec('Distance (km)',
                                          Icons.route_outlined),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _costCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: _dec('Cost (₹)',
                                          Icons.currency_rupee_rounded),
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // ── Material ───────────────────────────────────────
                        DropdownButtonFormField<String>(
                          key: ValueKey('mat_$_materialId'),
                          initialValue: _materialId,
                          decoration: _dec('Material', Icons.widgets_outlined),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF1A1A2E)),
                          borderRadius: BorderRadius.circular(10),
                          items: _materials
                              .map<DropdownMenuItem<String>>((m) =>
                                  DropdownMenuItem(
                                      value: m['_id'] as String,
                                      child: Text(m['name'] as String)))
                              .toList(),
                          onChanged: _isEditingMove
                              ? null
                              : (v) {
                                  setState(() => _materialId = v);
                                  _fetchBalance();
                                },
                          validator: (v) =>
                              v == null ? 'Please select a material' : null,
                          isExpanded: true,
                        ),
                        const SizedBox(height: 14),

                        // ── Quantity ───────────────────────────────────────
                        TextFormField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _dec('Quantity', Icons.numbers_rounded,
                              hint: 'e.g. 100'),
                          onChanged: (_) {
                            if (_txType == 'stock_move') {
                              _formKey.currentState?.validate();
                            }
                          },
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Quantity is required';
                            }
                            final qty = double.tryParse(v.trim());
                            if (qty == null || qty <= 0) {
                              return 'Enter a valid quantity';
                            }
                            if (_txType == 'stock_move' &&
                                _availableQty != null) {
                              if (_availableQty! <= 0) {
                                return 'No stock available in source branch';
                              }
                              if (qty > _availableQty!) {
                                return 'Only ${_fmt(_availableQty!)} units available';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // ── Date ───────────────────────────────────────────
                        GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => _date = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F9F8),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFDDE3E0)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 18, color: Color(0xFF2E7D52)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Date',
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.grey)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_date.day.toString().padLeft(2, '0')} / '
                                      '${_date.month.toString().padLeft(2, '0')} / '
                                      '${_date.year}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF1A1A2E)),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded,
                                  color: Color(0xFF9CA3AF)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Remarks ────────────────────────────────────────
                        TextFormField(
                          controller: _remarksCtrl,
                          maxLines: 3,
                          decoration: _dec('Remarks', Icons.notes_rounded,
                              hint: 'Optional notes...'),
                        ),
                        const SizedBox(height: 24),

                        // ── Buttons ────────────────────────────────────────
                        Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side:
                                    const BorderSide(color: Color(0xFFDDE3E0)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Cancel',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 14)),
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
                                        colors: [_primary, Color(0xFF1E6F5C)],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                color: _saving ? const Color(0xFFD1D5DB) : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ElevatedButton(
                                onPressed: _saving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: _saving
                                    ? const ButtonLoader()
                                    : Text(isNew ? 'Add Stock' : 'Save Changes',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Transaction type button ───────────────────────────────────────────────────

class _TxTypeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool disabled;
  final Color color;
  final VoidCallback onTap;

  const _TxTypeBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? color : const Color(0xFFF7F9F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : const Color(0xFFDDE3E0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? Colors.white
                      : disabled
                          ? const Color(0xFFCCCCCC)
                          : const Color(0xFF6B7280)),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : disabled
                          ? const Color(0xFFCCCCCC)
                          : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
