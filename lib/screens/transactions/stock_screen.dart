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

    if (_loading) return const Center(child: CircularProgressIndicator());
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
    const hdr = TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);
    return Column(children: [
      Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: const Row(children: [
          SizedBox(width: 40, child: Text('#', style: hdr)),
          Expanded(flex: 3, child: Text('MATERIAL', style: hdr)),
          SizedBox(width: 60, child: Text('CODE', style: hdr)),
          SizedBox(width: 50, child: Text('UNIT', style: hdr)),
          SizedBox(width: 80, child: Text('STORED', style: hdr, textAlign: TextAlign.right)),
          SizedBox(width: 80, child: Text('MOVED', style: hdr, textAlign: TextAlign.right)),
          SizedBox(width: 95, child: Text('BALANCE', style: hdr, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text('UTILIZED', style: hdr)),
        ]),
      ),
      Expanded(child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (_, i) {
          final item     = filtered[i];
          final name     = (item['material']?['name'] ?? '—') as String;
          final code     = (item['material']?['code'] ?? '—') as String;
          final unit     = (item['material']?['unit'] ?? 'pcs') as String;
          final balance  = (item['balance']  as num? ?? 0).toDouble();
          final stored   = (item['stored']   as num? ?? 0).toDouble();
          final moved    = (item['moved']    as num? ?? 0).toDouble();
          final totalIn  = (item['totalIn']  as num? ?? 0).toDouble();
          final totalOut = (item['totalOut'] as num? ?? 0).toDouble();
          final ratio    = totalIn > 0 ? (totalOut / totalIn).clamp(0.0, 1.0) : 0.0;
          final lowStock = balance >= 0 && ratio > 0.85;
          return InkWell(
            hoverColor: const Color(0xFFF0FDF4),
            child: Container(
              decoration: BoxDecoration(
                border: const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                color: lowStock ? const Color(0xFFFFF8F8) : Colors.white,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(children: [
                SizedBox(width: 40, child: Text('${i + 1}', style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))),
                Expanded(flex: 3, child: Row(children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(7)),
                    child: Icon(_matIcon(name), size: 15, color: const Color(0xFF2E7D52)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)), overflow: TextOverflow.ellipsis)),
                ])),
                SizedBox(width: 60, child: Text(code, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))),
                SizedBox(width: 50, child: Text(unit, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                SizedBox(width: 80, child: Text('+${_fmt(stored)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF2E7D32)), textAlign: TextAlign.right)),
                SizedBox(width: 80, child: Text(_fmt(moved), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6A1B9A)), textAlign: TextAlign.right)),
                SizedBox(width: 95, child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: balance > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_fmt(balance), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: balance > 0 ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F))),
                  ),
                )),
                Expanded(flex: 2, child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE8F5E9),
                        valueColor: AlwaysStoppedAnimation<Color>(ratio > 0.85 ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32)),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text('${(ratio * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
                      if (lowStock) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.warning_amber_rounded, size: 11, color: Color(0xFFD32F2F)),
                        const SizedBox(width: 2),
                        const Text('Low', style: TextStyle(fontSize: 10, color: Color(0xFFD32F2F))),
                      ],
                    ]),
                  ]),
                )),
              ]),
            ),
          );
        },
      )),
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
    final stored  = (item['stored']  as num? ?? 0).toDouble();
    final moved   = (item['moved']   as num? ?? 0).toDouble();
    final totalIn = (item['totalIn'] as num? ?? 0).toDouble();
    final totalOut= (item['totalOut']as num? ?? 0).toDouble();
    final ratio = totalIn > 0 ? (totalOut / totalIn).clamp(0.0, 1.0) : 0.0;
    final lowStock = balance >= 0 && ratio > 0.85;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: lowStock
                ? const Color(0xFFFFCDD2)
                : const Color(0xFFEEEEEE)),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
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
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF9E9E9E)),
                ),
                if (lowStock) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.warning_amber_rounded,
                      size: 12, color: Color(0xFFD32F2F)),
                  const SizedBox(width: 2),
                  const Text('Low stock',
                      style: TextStyle(
                          fontSize: 10, color: Color(0xFFD32F2F))),
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
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: color),
            ),
            const SizedBox(height: 1),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: Color(0xFF757575))),
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

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (filtered.isEmpty) {
      return const EmptyState(
          message: 'No warehouse data',
          icon: Icons.warehouse_outlined);
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
    final totalIn = (widget.data['totalIn'] as num? ?? 0).toDouble();
    final totalOut = (widget.data['totalOut'] as num? ?? 0).toDouble();
    final totalBalance = (widget.data['totalBalance'] as num? ?? 0).toDouble();

    const colLabel = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: Color(0xFF9E9E9E),
      letterSpacing: 0.8,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warehouse_outlined,
                        size: 22, color: Color(0xFF1565C0)),
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
                                color: Color(0xFF1A1A1A))),
                        Text(
                          '${materials.length} material${materials.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9E9E9E)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _fmt(totalBalance),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF1565C0)),
                      ),
                      const Text('balance',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF9E9E9E))),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF9E9E9E),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                _MiniStat('Total In', totalIn, const Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                _MiniStat('Total Out', totalOut, const Color(0xFFF57C00)),
              ]),
            ),
            Container(
              color: const Color(0xFFF9FAFB),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(children: [
                Expanded(child: Text('MATERIAL', style: colLabel)),
                SizedBox(width: 64, child: Text('IN', style: colLabel)),
                SizedBox(width: 64, child: Text('OUT', style: colLabel)),
                SizedBox(width: 80, child: Text('BALANCE', style: colLabel)),
              ]),
            ),
            ...materials.asMap().entries.map((entry) {
              final idx = entry.key;
              final m = entry.value as Map;
              final mName = (m['material']?['name'] ?? '—') as String;
              final mUnit = (m['material']?['unit'] ?? '') as String;
              final mIn = (m['in'] as num? ?? 0).toDouble();
              final mOut = (m['out'] as num? ?? 0).toDouble();
              final mBal = (m['balance'] as num? ?? 0).toDouble();

              return Column(children: [
                if (idx > 0)
                  Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey.shade100),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF1A1A1A))),
                          Text(mUnit,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF9E9E9E))),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text('+${_fmt(mIn)}',
                          style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text('-${_fmt(mOut)}',
                          style: const TextStyle(
                              color: Color(0xFFF57C00),
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                    SizedBox(
                      width: 80,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: mBal > 0
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
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

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Text(_fmt(value),
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: color)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF757575))),
        ]),
      ),
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
      showSnack(context,
          res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.search.toLowerCase();
    final filtered = q.isEmpty
        ? _items
        : _items.where((i) {
            final mat =
                (i['material']?['name'] ?? '').toString().toLowerCase();
            final b1 =
                (i['branch']?['name'] ?? '').toString().toLowerCase();
            final b2 =
                (i['fromBranch']?['name'] ?? '').toString().toLowerCase();
            final b3 =
                (i['toBranch']?['name'] ?? '').toString().toLowerCase();
            return mat.contains(q) ||
                b1.contains(q) ||
                b2.contains(q) ||
                b3.contains(q);
          }).toList();

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (filtered.isEmpty) {
      return const EmptyState(
          message: 'No stock movements', icon: Icons.swap_vert);
    }

    return LayoutBuilder(builder: (_, constraints) {
      final isMobile = constraints.maxWidth < 700;
      return RefreshIndicator(
        onRefresh: _load,
        child: isMobile
            ? ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _HistoryCard(
                  item: filtered[i],
                  onEdit: () => _openStockForm(context, item: filtered[i], onSaved: _load),
                  onDelete: () => _delete(filtered[i]['_id']),
                ),
              )
            : _buildDesktopTable(filtered),
      );
    });
  }

  Widget _buildDesktopTable(List filtered) {
    const hdr = TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);
    return Column(children: [
      Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: const Row(children: [
          SizedBox(width: 40, child: Text('#', style: hdr)),
          SizedBox(width: 100, child: Text('TYPE', style: hdr)),
          Expanded(flex: 2, child: Text('MATERIAL', style: hdr)),
          Expanded(flex: 3, child: Text('BRANCH / ROUTE', style: hdr)),
          SizedBox(width: 90, child: Text('QUANTITY', style: hdr, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text('DATE', style: hdr)),
          SizedBox(width: 48),
        ]),
      ),
      Expanded(child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filtered.length,
        itemBuilder: (_, i) {
          final item    = filtered[i];
          final txType  = item['transactionType'] as String? ?? '';
          final ledType = item['type'] as String? ?? 'in';
          final matName = (item['material']?['name'] ?? '—') as String;
          final matUnit = (item['material']?['unit'] ?? '') as String;
          final qty     = (item['quantity'] as num? ?? 0).toDouble();
          final isMove  = txType == 'stock_move';
          final from    = (item['fromBranch']?['name'] ?? '') as String;
          final to      = (item['toBranch']?['name']   ?? '') as String;
          final branch  = (item['branch']?['name']     ?? '—') as String;
          final branchLine = isMove ? '$from  →  $to' : branch;
          final cfg = _txConfig(txType, ledType);
          return InkWell(
            onTap: () => _openStockForm(context, item: item, onSaved: _load),
            hoverColor: const Color(0xFFF0FDF4),
            child: Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(children: [
                SizedBox(width: 40, child: Text('${i + 1}', style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))),
                SizedBox(width: 100, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: cfg.labelBg, borderRadius: BorderRadius.circular(10)),
                  child: Text(cfg.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cfg.labelColor), overflow: TextOverflow.ellipsis),
                )),
                Expanded(flex: 2, child: Text(matName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827)), overflow: TextOverflow.ellipsis)),
                Expanded(flex: 3, child: Text(branchLine, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), overflow: TextOverflow.ellipsis)),
                SizedBox(width: 90, child: Text('${cfg.qtyPrefix}${_fmt(qty)} $matUnit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cfg.badgeColor), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_fmtDate(item['date'] as String?), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF9CA3AF)),
                  padding: EdgeInsets.zero,
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
                    if (v == 'edit') _openStockForm(context, item: item, onSaved: _load);
                    if (v == 'delete') _delete(item['_id']);
                  },
                ),
              ]),
            ),
          );
        },
      )),
    ]);
  }
}

// ── History Card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final Map item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _HistoryCard(
      {required this.item,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final txType     = item['transactionType'] as String? ?? '';
    final ledgerType = item['type']            as String? ?? 'in';
    final matName    = (item['material']?['name'] ?? '—') as String;
    final matUnit    = (item['material']?['unit'] ?? '')  as String;
    final qty        = (item['quantity'] as num? ?? 0).toDouble();
    final remarks    = (item['remarks'] ?? '') as String;
    final dateStr    = item['date'] as String?;

    final isMove  = txType == 'stock_move';
    final cfg     = _txConfig(txType, ledgerType);

    final fromBranch    = (item['fromBranch']?['name']   ?? '') as String;
    final toBranch      = (item['toBranch']?['name']     ?? '') as String;
    final branch        = (item['branch']?['name']       ?? '—') as String;
    final branchLine    = isMove ? '$fromBranch  →  $toBranch' : branch;

    final vehicleName   = (item['vehicleName']   ?? '') as String;
    final driverName    = (item['driverName']    ?? '') as String;
    final transportName = (item['transportName'] ?? '') as String;
    final distance      = item['distance'] as num?;
    final cost          = item['cost']     as num?;

    final transportLine = [
      if (transportName.isNotEmpty) transportName,
      if (vehicleName.isNotEmpty)   vehicleName,
      if (driverName.isNotEmpty)    driverName,
    ].join(' · ');
    final distCost = [
      if (distance != null) '${distance}km',
      if (cost != null)     '₹$cost',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cfg.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(cfg.icon, size: 20, color: cfg.iconColor),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          matName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF1A1A1A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Qty badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cfg.badgeBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${cfg.qtyPrefix}${_fmt(qty)} $matUnit',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: cfg.badgeColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cfg.labelBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(cfg.label,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: cfg.labelColor)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        branchLine,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF424242)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  if (transportLine.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.local_shipping_outlined,
                          size: 12, color: Color(0xFF6A1B9A)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          transportLine,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF6A1B9A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ],
                  if (distCost.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.route_outlined,
                          size: 12, color: Color(0xFF9E9E9E)),
                      const SizedBox(width: 4),
                      Text(distCost,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9E9E9E))),
                    ]),
                  ],
                  if (remarks.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      remarks,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9E9E9E)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _fmtDate(dateStr),
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9E9E9E)),
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded,
                  size: 18, color: Color(0xFF9CA3AF)),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 3,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined,
                        size: 15, color: Color(0xFF374151)),
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
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFFDC2626))),
                  ]),
                ),
              ],
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
            ),
          ],
        ),
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

IconData _matIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('steel') || n.contains('metal') || n.contains('iron') ||
      n.contains('re-bar') || n.contains('re bar')) {
    return Icons.grid_4x4;
  }
  if (n.contains('wood') || n.contains('lumber') || n.contains('timber') ||
      n.contains('ply')) {
    return Icons.layers_outlined;
  }
  if (n.contains('cement') || n.contains('concrete') ||
      n.contains('mortar') || n.contains('sand')) {
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
        borderRadius:
            const BorderRadius.horizontal(left: Radius.circular(20)),
        child: SizedBox(
          width: panelWidth,
          height: MediaQuery.of(ctx).size.height,
          child: StockFormPanel(item: item, onSaved: onSaved),
        ),
      ),
    ),
    transitionBuilder: (_, a, __, child) => SlideTransition(
      position: Tween<Offset>(
              begin: const Offset(1, 0), end: Offset.zero)
          .animate(a),
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
  bool _isEditingMove = false; // lock branches/material when editing a stock_move

  // STORE STOCK
  String? _branchId;

  // STOCK MOVE
  String? _fromBranchId;
  String? _toBranchId;

  // Common
  String? _materialId;
  final _qtyCtrl           = TextEditingController();
  final _remarksCtrl       = TextEditingController();
  final _transportNameCtrl = TextEditingController();
  final _driverNameCtrl    = TextEditingController();
  final _vehicleNameCtrl   = TextEditingController();
  final _distanceCtrl      = TextEditingController();
  final _costCtrl          = TextEditingController();
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
      _materialId       = e['material']?['_id'] as String?;
      _qtyCtrl.text     = '${e['quantity'] ?? ''}';
      _remarksCtrl.text = (e['remarks'] ?? '') as String;
      if (e['date'] != null) {
        _date = DateTime.tryParse(e['date'].toString()) ?? DateTime.now();
      }
      if (_txType == 'store') {
        _branchId = e['branch']?['_id'] as String?;
      } else {
        _isEditingMove        = true;
        _fromBranchId         = e['fromBranch']?['_id'] as String?;
        _toBranchId           = e['toBranch']?['_id']   as String?;
        _transportNameCtrl.text = (e['transportName'] ?? '') as String;
        _driverNameCtrl.text    = (e['driverName']    ?? '') as String;
        _vehicleNameCtrl.text   = (e['vehicleName']   ?? '') as String;
        _distanceCtrl.text      = e['distance'] != null ? '${e['distance']}' : '';
        _costCtrl.text          = e['cost']     != null ? '${e['cost']}'     : '';
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
    if (_txType != 'stock_move' || _materialId == null || _fromBranchId == null) {
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
        if (_transportNameCtrl.text.trim().isNotEmpty)
          'transportName': _transportNameCtrl.text.trim(),
        if (_driverNameCtrl.text.trim().isNotEmpty)
          'driverName': _driverNameCtrl.text.trim(),
        if (_vehicleNameCtrl.text.trim().isNotEmpty)
          'vehicleName': _vehicleNameCtrl.text.trim(),
        if (_distanceCtrl.text.trim().isNotEmpty)
          'distance': double.tryParse(_distanceCtrl.text.trim()),
        if (_costCtrl.text.trim().isNotEmpty)
          'cost': double.tryParse(_costCtrl.text.trim()),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
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
                child: const Icon(Icons.close,
                    color: Colors.white70, size: 16),
              ),
            ),
          ]),
        ),
        // Form body
        Expanded(
          child: _loadingData
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF2E7D52)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Transaction type selector ──────────────────────
                        const Text('Transaction Type',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey)),
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
                            decoration:
                                _dec('Branch', Icons.store_outlined),
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF1A1A2E)),
                            borderRadius: BorderRadius.circular(10),
                            items: _branches
                                .map<DropdownMenuItem<String>>((b) =>
                                    DropdownMenuItem(
                                        value: b['_id'] as String,
                                        child: Text(b['name'] as String)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _branchId = v),
                            validator: (v) => v == null
                                ? 'Please select a branch'
                                : null,
                            isExpanded: true,
                          ),
                        ],

                        // ── STOCK MOVE: from + to branch + transport ───────
                        if (_txType == 'stock_move') ...[
                          DropdownButtonFormField<String>(
                            key: ValueKey('from_$_fromBranchId'),
                            initialValue: _fromBranchId,
                            decoration: _dec(
                                'From Branch', Icons.store_outlined),
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
                            decoration: _dec(
                                'To Branch', Icons.store_mall_directory_outlined),
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
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF)))
                              else if (_availableQty == null)
                                const Text(
                                    'Select material & source branch to see stock',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF)))
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
                              border: Border.all(color: const Color(0xFFCE93D8)),
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
                          decoration:
                              _dec('Material', Icons.widgets_outlined),
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
                          decoration: _dec('Quantity',
                              Icons.numbers_rounded,
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
                              border: Border.all(
                                  color: const Color(0xFFDDE3E0)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 18, color: Color(0xFF2E7D52)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('Date',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey)),
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
                          decoration: _dec(
                              'Remarks', Icons.notes_rounded,
                              hint: 'Optional notes...'),
                        ),
                        const SizedBox(height: 24),

                        // ── Buttons ────────────────────────────────────────
                        Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                side: const BorderSide(
                                    color: Color(0xFFDDE3E0)),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
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
                                        colors: [
                                          _primary,
                                          Color(0xFF1E6F5C)
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                color: _saving
                                    ? const Color(0xFFD1D5DB)
                                    : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ElevatedButton(
                                onPressed: _saving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : Text(
                                        isNew
                                            ? 'Add Stock'
                                            : 'Save Changes',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.w600)),
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
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
