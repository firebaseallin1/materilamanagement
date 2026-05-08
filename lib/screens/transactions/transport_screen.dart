import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

const _trpTeal = Color(0xFF0D9488);
const _trpPurple = Color(0xFF6A1B9A);

// ════════════════════════════════════════════════
// TRANSPORT SCREEN  (Deliveries + Stock Moves combined)
// ════════════════════════════════════════════════
class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});
  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  List _items = [];
  bool _loading = true;
  String _search = '';

  // Filters
  String? _typeFilter; // null = all | 'delivery' | 'stock_move'
  String? _selTransport;
  String? _selMaterial;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.get('/transport'),
      ApiService.get('/stock/history?transactionType=stock_move'),
    ]);
    final deliveries = (results[0]['data'] as List? ?? []).map((e) {
      e['recordType'] = 'delivery';
      return e;
    }).toList();
    final stockMoves = (results[1]['data'] as List? ?? [])
        .where((r) =>
            (r['vehicleName'] ?? '').toString().isNotEmpty ||
            (r['driverName'] ?? '').toString().isNotEmpty)
        .map((e) {
      e['recordType'] = 'stock_move';
      return e;
    }).toList();
    final all = [...deliveries, ...stockMoves];
    all.sort((a, b) {
      final d1 = DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
      final d2 = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
      return d2.compareTo(d1);
    });
    if (mounted)
      setState(() {
        _items = all;
        _loading = false;
      });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/transport/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  void _clearFilters() => setState(() {
        _typeFilter = null;
        _selTransport = null;
        _selMaterial = null;
        _fromDate = null;
        _toDate = null;
      });

  int get _activeFilters => [
        _typeFilter,
        _selTransport,
        _selMaterial,
        _fromDate,
        _toDate
      ].where((e) => e != null).length;

  List get _filtered {
    final q = _search.toLowerCase().trim();
    return _items.where((item) {
      final isStockMove = item['recordType'] == 'stock_move';
      final vehicle = (isStockMove ? item['vehicleName'] : item['vehicleNo'])
              ?.toString()
              .toLowerCase() ??
          '';
      final driver = (item['driverName'] ?? '').toString().toLowerCase();
      final material =
          (item['material'] as Map?)?['name']?.toString().toLowerCase() ?? '';

      final raw = DateTime.tryParse(item['date']?.toString() ?? '');
      final itemDate = raw != null
          ? DateTime(raw.toLocal().year, raw.toLocal().month, raw.toLocal().day)
          : null;

      final transportName =
          (item['transportName'] ?? '').toString().toLowerCase();

      final matchesSearch = q.isEmpty ||
          vehicle.contains(q) ||
          driver.contains(q) ||
          material.contains(q) ||
          transportName.contains(q);

      final matchesType = _typeFilter == null ||
          (isStockMove
              ? _typeFilter == 'stock_move'
              : _typeFilter == 'delivery');

      final matchesTransport = _selTransport == null ||
          transportName == _selTransport!.toLowerCase();

      final matchesMaterial =
          _selMaterial == null || material == _selMaterial!.toLowerCase();

      final matchesFrom = _fromDate == null ||
          (itemDate != null && !itemDate.isBefore(_fromDate!));
      final matchesTo =
          _toDate == null || (itemDate != null && !itemDate.isAfter(_toDate!));

      return matchesSearch &&
          matchesType &&
          matchesTransport &&
          matchesMaterial &&
          matchesFrom &&
          matchesTo;
    }).toList();
  }

  void _openForm([Map? item]) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'transport-form',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final sw = MediaQuery.of(ctx).size.width;
        final pw = sw > 900 ? sw * 0.40 : sw * 0.92;
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
                child: TransportFormPanel(
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 700;
      final results = _filtered;
      return Scaffold(
        body: Column(children: [
          ScreenHeader(
            title: 'Transport',
            subtitle: 'Deliveries & Stock Moves',
            onRefresh: _load,
            onSearchChanged: (v) => setState(() => _search = v),
            searchHint: 'Search vehicle, driver, material…',
            onAdd: () => _openForm(),
            addLabel: 'Add Transport',
          ),
          _buildFilterBar(
              results.length,
              results.fold<double>(
                  0, (s, e) => s + (e['cost'] as num? ?? 0).toDouble())),
          Expanded(
            child: _loading
                ? const AppLoader()
                : results.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: EmptyState(
                            message: _activeFilters > 0
                                ? 'No results for current filters'
                                : 'No transport records',
                            icon: Icons.local_shipping_outlined,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: isMobile
                            ? _buildMobileList(results)
                            : _buildDesktopList(results),
                      ),
          ),
        ]),
      );
    });
  }

  // ── Filter Bar ──────────────────────────────────────────────────────────────

  Widget _buildFilterBar(int count, double totalCost) {
    final hasFilters = _activeFilters > 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: _trpTeal, borderRadius: BorderRadius.circular(10)),
                child: Text('$_activeFilters',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('$count record${count != 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B))),
            ),
            if (totalCost > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 202, 5, 5)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color.fromARGB(255, 99, 3, 3)
                          .withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.currency_rupee_rounded,
                      size: 10, color: _trpTeal),
                  Text(
                    _trpFmtAmount(totalCost, symbol: false),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _trpTeal),
                  ),
                ]),
              ),
            ],
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
                      border: Border.all(color: const Color(0xFFFECACA))),
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

        // Type chips
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _typeChip(null, 'All', Icons.layers_outlined),
              const SizedBox(width: 6),
              _typeChip('delivery', 'Delivery', Icons.local_shipping_outlined),
              const SizedBox(width: 6),
              _typeChip('stock_move', 'Stock Move', Icons.swap_horiz_rounded),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Dropdowns + date row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(children: [
            _filterDropdown(
              icon: Icons.business_outlined,
              hint: 'Transport',
              value: _selTransport,
              items: _getTransports(),
              onChanged: (v) => setState(() => _selTransport = v),
            ),
            const SizedBox(width: 8),
            _filterDropdown(
              icon: Icons.inventory_2_outlined,
              hint: 'Material',
              value: _selMaterial,
              items: _getMaterials(),
              onChanged: (v) => setState(() => _selMaterial = v),
            ),
            const SizedBox(width: 8),
            _datePill('From', _fromDate, (d) => setState(() => _fromDate = d),
                () => setState(() => _fromDate = null)),
            const SizedBox(width: 8),
            _datePill('To', _toDate, (d) => setState(() => _toDate = d),
                () => setState(() => _toDate = null)),
          ]),
        ),
      ]),
    );
  }

  Widget _typeChip(String? type, String label, IconData icon) {
    final selected = _typeFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _typeFilter = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _trpTeal : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? _trpTeal : const Color(0xFFE2E8F0), width: 1.2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 12,
              color: selected ? Colors.white : const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF475569))),
        ]),
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
              colorScheme: const ColorScheme.light(primary: _trpTeal),
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
          color: active ? const Color(0xFFCCFBF1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active
                  ? _trpTeal.withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
              width: 1.2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined,
              size: 13, color: active ? _trpTeal : const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Text(
            active
                ? '$label: ${DateFormat('dd MMM yyyy').format(value)}'
                : label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? _trpTeal : const Color(0xFF94A3B8)),
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
        color: active ? const Color(0xFFCCFBF1) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: active
                ? _trpTeal.withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0),
            width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: active ? _trpTeal : const Color(0xFF94A3B8)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          hint: Row(children: [
            Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(hint,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ]),
          selectedItemBuilder: (_) => [
            Row(children: [
              Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(hint,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ]),
            ...items.map((e) => Row(children: [
                  Icon(icon, size: 13, color: _trpTeal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(e,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _trpTeal),
                        overflow: TextOverflow.ellipsis),
                  ),
                ])),
          ],
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('All $hint',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
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

  List<String> _getTransports() => _items
      .map((e) => e['transportName']?.toString() ?? '')
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<String> _getMaterials() => _items
      .map((e) => (e['material'] as Map?)?['name']?.toString() ?? '')
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  // ── Desktop Table ───────────────────────────────────────────────────────────

  Widget _buildDesktopList(List list) {
    const hdr = TextStyle(
        fontSize: 10,
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8);

    return Column(children: [
      Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
        child: const Row(children: [
          SizedBox(width: 32, child: Text('#', style: hdr)),
          SizedBox(width: 112, child: Text('TYPE', style: hdr)),
          Expanded(flex: 3, child: Text('VEHICLE / DRIVER', style: hdr)),
          Expanded(flex: 4, child: Text('ROUTE', style: hdr)),
          Expanded(flex: 3, child: Text('MATERIAL', style: hdr)),
          SizedBox(
              width: 90,
              child: Text('COST', style: hdr, textAlign: TextAlign.center)),
          SizedBox(width: 110, child: Text('DATE', style: hdr)),
          SizedBox(width: 36),
        ]),
      ),
      const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final item = list[i];
            final isStockMove = item['recordType'] == 'stock_move';
            final accent = isStockMove ? _trpPurple : _trpTeal;
            final vehicleNo = isStockMove
                ? (item['vehicleName'] ?? '—')
                : (item['vehicleNo'] ?? '—');
            final driver = (item['driverName'] ?? '—').toString();
            final from = isStockMove
                ? (item['fromBranch']?['name'] ?? '—')
                : (item['fromLocation']?['name'] ?? '—');
            final to = isStockMove
                ? (item['toBranch']?['name'] ?? '—')
                : (item['toLocation']?['name'] ?? '—');
            final material = (item['material']?['name'] ?? '—').toString();
            final qty = item['quantity'];
            final cost = item['cost'];
            final dateStr = item['date'] as String?;

            return InkWell(
              onTap: isStockMove ? null : () => _openForm(item),
              borderRadius: BorderRadius.circular(10),
              hoverColor: accent.withValues(alpha: 0.04),
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
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Accent strip
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: accent,
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
                        // TYPE
                        SizedBox(
                          width: 112,
                          child: Center(child: _typeBadge(isStockMove)),
                        ),
                        // VEHICLE / DRIVER
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Icon(Icons.directions_car_outlined,
                                        size: 14, color: accent),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(vehicleNo.toString(),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E293B)),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ]),
                                if (driver != '—') ...[
                                  const SizedBox(height: 2),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 36),
                                    child: Text(driver,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF94A3B8)),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // ROUTE
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 4),
                            child: Row(children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 13, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(from.toString(),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151)),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('→',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: accent)),
                                ),
                              ),
                              Flexible(
                                child: Text(to.toString(),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151)),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          ),
                        ),
                        // MATERIAL
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(material,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151)),
                                    overflow: TextOverflow.ellipsis),
                                if (qty != null)
                                  Text('Qty: $qty',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                        ),
                        // COST
                        SizedBox(
                          width: 90,
                          child: Center(
                            child: cost != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _trpTeal.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              _trpTeal.withValues(alpha: 0.2)),
                                    ),
                                    child: Text(_trpFmtAmount(cost is num ? cost : null),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _trpTeal)),
                                  )
                                : const Text('—',
                                    style: TextStyle(
                                        color: Color(0xFFE2E8F0),
                                        fontSize: 16)),
                          ),
                        ),
                        // DATE
                        SizedBox(
                          width: 110,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _trpFmtShort(dateStr),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151)),
                                ),
                                Text(
                                  _trpFmtYear(dateStr),
                                  style: const TextStyle(
                                      fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // ACTIONS
                        SizedBox(
                          width: 36,
                          child: Center(
                            child: isStockMove
                                ? const SizedBox.shrink()
                                : _actionMenu(item),
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

  // ── Mobile Cards ────────────────────────────────────────────────────────────

  Widget _buildMobileList(List list) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final item = list[i];
        final isStockMove = item['recordType'] == 'stock_move';
        final accent = isStockMove ? _trpPurple : _trpTeal;
        final vehicleNo = isStockMove
            ? (item['vehicleName'] ?? '—').toString()
            : (item['vehicleNo'] ?? '—').toString();
        final driver = (item['driverName'] ?? '').toString();
        final from = isStockMove
            ? (item['fromBranch']?['name'] ?? '—').toString()
            : (item['fromLocation']?['name'] ?? '—').toString();
        final to = isStockMove
            ? (item['toBranch']?['name'] ?? '—').toString()
            : (item['toLocation']?['name'] ?? '—').toString();
        final cost = item['cost'];
        final distance = item['distance'];
        final material = item['material']?['name']?.toString();
        final qty = item['quantity'];
        final remarks = (item['remarks'] ?? '').toString();
        final transportName = item['transportName']?.toString() ?? '';
        final dateStr = item['date'] as String?;

        return Container(
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
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Accent strip
              Container(width: 4, color: accent),

              // Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1 — type badge · date · menu
                      Row(children: [
                        _typeBadge(isStockMove),
                        const Spacer(),
                        const Icon(Icons.calendar_today_outlined,
                            size: 10, color: Color(0xFFB0BEC5)),
                        const SizedBox(width: 4),
                        Text(
                          dateStr != null
                              ? DateFormat('dd MMM yyyy').format(
                                  DateTime.tryParse(dateStr)?.toLocal() ??
                                      DateTime.now())
                              : '—',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 4),
                        if (!isStockMove) _actionMenu(item),
                      ]),

                      const SizedBox(height: 10),

                      // Row 2 — vehicle icon · vehicle / driver · cost
                      Row(children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.local_shipping_outlined,
                              size: 20, color: accent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(vehicleNo,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B)),
                                  overflow: TextOverflow.ellipsis),
                              if (driver.isNotEmpty)
                                Text(driver,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        if (cost != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _trpTeal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _trpTeal.withValues(alpha: 0.2)),
                            ),
                            child: Text(_trpFmtAmount(cost is num ? cost : null),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _trpTeal)),
                          ),
                        ],
                      ]),

                      const SizedBox(height: 8),

                      // Row 3 — route
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE8ECF0)),
                        ),
                        child: Row(children: [
                          Icon(Icons.route_outlined,
                              size: 13, color: accent.withValues(alpha: 0.7)),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('→',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: accent)),
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
                        ]),
                      ),

                      // Row 4 — transport name
                      if (transportName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.business_outlined,
                              size: 12, color: accent.withValues(alpha: 0.7)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(transportName,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: accent),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ],

                      // Row 5 — material + distance
                      if (material != null || distance != null) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          if (material != null) ...[
                            const Icon(Icons.inventory_2_outlined,
                                size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                  qty != null ? '$material · $qty' : material,
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                          if (distance != null) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.straighten,
                                size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text('${distance}km',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ]),
                      ],

                      // Row 6 — remarks
                      if (remarks.isNotEmpty) ...[
                        const SizedBox(height: 5),
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
        );
      },
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _typeBadge(bool isStockMove) {
    final color = isStockMove ? _trpPurple : _trpTeal;
    final bg = isStockMove ? const Color(0xFFF3E5F5) : const Color(0xFFCCFBF1);
    final icon =
        isStockMove ? Icons.swap_horiz_rounded : Icons.local_shipping_outlined;
    final label = isStockMove ? 'Stock Move' : 'Delivery';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _actionMenu(Map item) {
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
          if (v == 'edit') _openForm(item);
          if (v == 'delete') _delete(item['_id']);
        },
      ),
    );
  }
}

String _trpFmtAmount(num? v, {bool symbol = true}) {
  if (v == null) return '—';
  final fmt = NumberFormat('#,##,###.##', 'en_IN');
  return symbol ? '₹${fmt.format(v)}' : fmt.format(v);
}

String _trpFmtShort(String? d) {
  if (d == null) return '—';
  final dt = DateTime.tryParse(d);
  if (dt == null) return '—';
  return DateFormat('dd MMM').format(dt.toLocal());
}

String _trpFmtYear(String? d) {
  if (d == null) return '';
  final dt = DateTime.tryParse(d);
  if (dt == null) return '';
  return DateFormat('yyyy').format(dt.toLocal());
}

// ── Slide-in Form Panel ───────────────────────────────────────────────────────
class TransportFormPanel extends StatefulWidget {
  final Map? item;
  final VoidCallback onSaved;
  const TransportFormPanel({super.key, this.item, required this.onSaved});
  @override
  State<TransportFormPanel> createState() => _TransportFormPanelState();
}

class _TransportFormPanelState extends State<TransportFormPanel> {
  final _formKey = GlobalKey<FormState>();
  List _locations = [], _materials = [];
  String? _fromLoc, _toLoc, _materialId;
  final _transportNameCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _driverCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _distCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.item != null) {
      final e = widget.item!;
      _fromLoc = e['fromLocation']?['_id'];
      _toLoc = e['toLocation']?['_id'];
      _materialId = e['material']?['_id'];
      _transportNameCtrl.text = e['transportName'] ?? '';
      _vehicleCtrl.text = e['vehicleNo'] ?? '';
      _driverCtrl.text = e['driverName'] ?? '';
      _qtyCtrl.text = '${e['quantity'] ?? ''}';
      _distCtrl.text = '${e['distance'] ?? ''}';
      _costCtrl.text = '${e['cost'] ?? ''}';
      _remarksCtrl.text = e['remarks'] ?? '';
      if (e['date'] != null) _date = DateTime.parse(e['date']);
    }
  }

  @override
  void dispose() {
    _transportNameCtrl.dispose();
    _vehicleCtrl.dispose();
    _driverCtrl.dispose();
    _qtyCtrl.dispose();
    _distCtrl.dispose();
    _costCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    final [lRes, mRes] = await Future.wait(
        [ApiService.get('/locations'), ApiService.get('/materials')]);
    if (mounted)
      setState(() {
        _locations = lRes['data'] ?? [];
        _materials = mRes['data'] ?? [];
      });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'transportName': _transportNameCtrl.text.trim(),
      'vehicleNo': _vehicleCtrl.text.trim(),
      'driverName': _driverCtrl.text.trim(),
      'fromLocation': _fromLoc,
      'toLocation': _toLoc,
      'material': _materialId,
      'quantity': double.tryParse(_qtyCtrl.text),
      'distance': double.tryParse(_distCtrl.text),
      'cost': double.tryParse(_costCtrl.text),
      'date': _date.toIso8601String(),
      'remarks': _remarksCtrl.text,
    };
    final res = widget.item == null
        ? await ApiService.post('/transport', body)
        : await ApiService.put('/transport/${widget.item!['_id']}', body);
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Saved!' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) widget.onSaved();
    }
    if (mounted) setState(() => _saving = false);
  }

  static const _primary = Color(0xFF1B3A27);
  static const _accent = Color(0xFF2E7D52);

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

  Widget _sectionLabel(String text, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 13, color: _accent),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151))),
          const SizedBox(width: 8),
          const Expanded(
              child: Divider(thickness: 1, color: Color(0xFFE5E7EB))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return Column(children: [
      // ── Drag handle ──────────────────────────────────────────────────────
      const SizedBox(height: 10),
      Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(height: 2),

      // ── Gradient header card ─────────────────────────────────────────────
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
            child: const Icon(Icons.local_shipping_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEdit ? 'Edit Transport' : 'New Transport',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                isEdit
                    ? 'Update the transport entry below'
                    : 'Fill in the transport details below',
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white70, size: 16),
            ),
          ),
        ]),
      ),

      // ── Form body ────────────────────────────────────────────────────────
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Form(
            key: _formKey,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Transport / Vehicle ─────────────────────────────────────
              _sectionLabel(
                  'Transport & Vehicle', Icons.local_shipping_outlined),
              TextFormField(
                controller: _transportNameCtrl,
                decoration: _dec('Transport Name', Icons.business_outlined,
                    hint: 'e.g. KPS Transport'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _vehicleCtrl,
                    decoration:
                        _dec('Vehicle No', Icons.directions_car_outlined),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _driverCtrl,
                    decoration:
                        _dec('Driver Name', Icons.person_outline_rounded),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // ── Route ───────────────────────────────────────────────────
              _sectionLabel('Route', Icons.alt_route_outlined),
              DropdownButtonFormField<String>(
                key: ValueKey('from_$_fromLoc'),
                initialValue: _fromLoc,
                decoration: _dec('From Location', Icons.location_on_outlined),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                borderRadius: BorderRadius.circular(10),
                isExpanded: true,
                items: _locations
                    .map<DropdownMenuItem<String>>((l) => DropdownMenuItem(
                        value: l['_id'], child: Text(l['name'])))
                    .toList(),
                onChanged: (v) => setState(() => _fromLoc = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('to_$_toLoc'),
                initialValue: _toLoc,
                decoration:
                    _dec('To Location', Icons.location_searching_outlined),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                borderRadius: BorderRadius.circular(10),
                isExpanded: true,
                items: _locations
                    .map<DropdownMenuItem<String>>((l) => DropdownMenuItem(
                        value: l['_id'], child: Text(l['name'])))
                    .toList(),
                onChanged: (v) => setState(() => _toLoc = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // ── Material ─────────────────────────────────────────────────
              _sectionLabel('Material (Optional)', Icons.inventory_2_outlined),
              DropdownButtonFormField<String>(
                key: ValueKey('mat_$_materialId'),
                initialValue: _materialId,
                decoration: _dec('Material', Icons.widgets_outlined),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                borderRadius: BorderRadius.circular(10),
                isExpanded: true,
                items: _materials
                    .map<DropdownMenuItem<String>>((m) => DropdownMenuItem(
                        value: m['_id'], child: Text(m['name'])))
                    .toList(),
                onChanged: (v) => setState(() => _materialId = v),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        _dec('Quantity', Icons.format_list_numbered_rounded),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _distCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Distance (km)', Icons.route_outlined),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Cost (₹)', Icons.currency_rupee_rounded),
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // ── Date & Remarks ───────────────────────────────────────────
              _sectionLabel('Date & Remarks', Icons.calendar_today_outlined),
              DatePickerField(
                  label: 'Date',
                  value: _date,
                  onChanged: (d) => setState(() => _date = d)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarksCtrl,
                maxLines: 2,
                decoration: _dec('Remarks', Icons.notes_rounded),
              ),
              const SizedBox(height: 28),

              // ── Save button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const ButtonLoader()
                      : Text(
                          isEdit ? 'Update Transport' : 'Save Transport',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
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

// ════════════════════════════════════════════════
// MEASUREMENT SCREEN
// ════════════════════════════════════════════════
class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key});
  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  List _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/measurements');
    if (mounted)
      setState(() {
        _items = res['data'] ?? [];
        _loading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Measurements'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MeasurementFormScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Measurement'),
      ),
      body: _loading
          ? const AppLoader()
          : _items.isEmpty
              ? const EmptyState(
                  message: 'No measurements', icon: Icons.straighten)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      final date = item['date'] != null
                          ? DateFormat('dd MMM yyyy')
                              .format(DateTime.parse(item['date']))
                          : '—';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: Colors.indigo.shade50,
                              child: Icon(Icons.straighten,
                                  color: Colors.indigo.shade700)),
                          title: Text(item['material']?['name'] ?? '—',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${item['branch']?['name'] ?? '—'} · $date\nQty: ${item['quantity']} ${item['unit'] ?? ''}'),
                          isThreeLine: true,
                          trailing: PopupMenuButton(
                            icon: const Icon(Icons.more_horiz_rounded,
                                size: 18, color: Color(0xFF9CA3AF)),
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
                                    Text('Edit',
                                        style: TextStyle(fontSize: 13)),
                                  ])),
                              PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [
                                    Icon(Icons.delete_outline_rounded,
                                        size: 15, color: Color(0xFFDC2626)),
                                    SizedBox(width: 8),
                                    Text('Delete',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFFDC2626))),
                                  ])),
                            ],
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            MeasurementFormScreen(item: item)));
                                _load();
                              } else {
                                _delete(item['_id']);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class MeasurementFormScreen extends StatefulWidget {
  final Map? item;
  const MeasurementFormScreen({super.key, this.item});
  @override
  State<MeasurementFormScreen> createState() => _MeasurementFormScreenState();
}

class _MeasurementFormScreenState extends State<MeasurementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  List _branches = [], _materials = [];
  String? _branchId, _materialId, _unit = 'sqft';
  final _lenCtrl = TextEditingController();
  final _breCtrl = TextEditingController();
  final _heiCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.item != null) {
      final e = widget.item!;
      _branchId = e['branch']?['_id'];
      _materialId = e['material']?['_id'];
      _unit = e['unit'] ?? 'sqft';
      _lenCtrl.text = '${e['length'] ?? ''}';
      _breCtrl.text = '${e['breadth'] ?? ''}';
      _heiCtrl.text = '${e['height'] ?? ''}';
      _qtyCtrl.text = '${e['quantity'] ?? ''}';
      _descCtrl.text = e['description'] ?? '';
      if (e['date'] != null) _date = DateTime.parse(e['date']);
    }
  }

  @override
  void dispose() {
    _lenCtrl.dispose();
    _breCtrl.dispose();
    _heiCtrl.dispose();
    _qtyCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    final [bRes, mRes] = await Future.wait(
        [ApiService.get('/branches'), ApiService.get('/materials')]);
    if (mounted)
      setState(() {
        _branches = bRes['data'] ?? [];
        _materials = mRes['data'] ?? [];
      });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'branch': _branchId,
      'material': _materialId,
      'length': double.tryParse(_lenCtrl.text),
      'breadth': double.tryParse(_breCtrl.text),
      'height': double.tryParse(_heiCtrl.text),
      'quantity': double.tryParse(_qtyCtrl.text) ?? 0,
      'unit': _unit,
      'date': _date.toIso8601String(),
      'description': _descCtrl.text,
    };
    final res = widget.item == null
        ? await ApiService.post('/measurements', body)
        : await ApiService.put('/measurements/${widget.item!['_id']}', body);
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Saved!' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) Navigator.pop(context);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.item == null ? 'Add Measurement' : 'Edit Measurement')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppDropdown<String>(
              label: 'Branch',
              value: _branchId,
              items: _branches
                  .map<DropdownMenuItem<String>>((b) =>
                      DropdownMenuItem(value: b['_id'], child: Text(b['name'])))
                  .toList(),
              onChanged: (v) => setState(() => _branchId = v),
              validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 16),
          AppDropdown<String>(
              label: 'Material',
              value: _materialId,
              items: _materials
                  .map<DropdownMenuItem<String>>((m) =>
                      DropdownMenuItem(value: m['_id'], child: Text(m['name'])))
                  .toList(),
              onChanged: (v) => setState(() => _materialId = v),
              validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: TextFormField(
                    controller: _lenCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Length'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextFormField(
                    controller: _breCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Breadth'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextFormField(
                    controller: _heiCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height'))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    validator: (v) => v!.isEmpty ? 'Required' : null)),
            const SizedBox(width: 12),
            Expanded(
                child: AppDropdown<String>(
                    label: 'Unit',
                    value: _unit,
                    items: const [
                      DropdownMenuItem(value: 'sqft', child: Text('sq ft')),
                      DropdownMenuItem(value: 'sqm', child: Text('sq m')),
                      DropdownMenuItem(value: 'rft', child: Text('rft')),
                      DropdownMenuItem(value: 'cum', child: Text('cu m')),
                      DropdownMenuItem(value: 'nos', child: Text('nos')),
                    ],
                    onChanged: (v) => setState(() => _unit = v))),
          ]),
          const SizedBox(height: 16),
          DatePickerField(
              label: 'Date',
              value: _date,
              onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 16),
          TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 24),
          ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const ButtonLoader() : const Text('Save')),
        ]),
      ),
    );
  }
}
