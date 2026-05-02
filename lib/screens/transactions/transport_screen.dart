import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

// ════════════════════════════════════════════════
// TRANSPORT SCREEN  (2 tabs: Deliveries + Stock Moves)
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

    if (mounted) {
      setState(() {
        _items = all;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items.where((item) {
      final Map<String, dynamic> data = item as Map<String, dynamic>;

      final bool isStockMove = data['recordType']?.toString() == 'stock_move';

      final vehicle = (isStockMove ? data['vehicleName'] : data['vehicleNo'])
              ?.toString()
              .toLowerCase() ??
          '';

      final driver = data['driverName']?.toString().toLowerCase() ?? '';

      // final from = (isStockMove
      //             ? (data['fromBranch'] as Map?)?['name']
      //             : (data['fromLocation'] as Map?)?['name'])
      //         ?.toString()
      //         .toLowerCase() ??
      //     '';

      // final to = (isStockMove
      //             ? (data['toBranch'] as Map?)?['name']
      //             : (data['toLocation'] as Map?)?['name'])
      //         ?.toString()
      //         .toLowerCase() ??
      '';

      final material =
          (data['material'] as Map?)?['name']?.toString().toLowerCase() ?? '';

      final query = _search.toLowerCase().trim();

      return vehicle.contains(query) ||
          driver.contains(query) ||
          // from.contains(query) ||
          // to.contains(query) ||
          material.contains(query);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TransportFormScreen(),
            ),
          );

          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text("Add Transport"),
      ),
      body: Column(
        children: [
          ScreenHeader(
            title: "Transport",
            subtitle: "Deliveries & Stock Moves",
            onRefresh: _load,
            onSearchChanged: (v) => setState(() => _search = v),
            searchHint: 'Search...',
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : filteredItems.isEmpty
                    ? const EmptyState(
                        message: "No matching records",
                        icon: Icons.local_shipping,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredItems.length,
                          itemBuilder: (_, i) {
                            final item = filteredItems[i];

                            final isStockMove =
                                item['recordType'] == 'stock_move';
                            return _TransportCard(
                              leading: CircleAvatar(
                                backgroundColor: isStockMove
                                    ? Colors.purple.shade50
                                    : Colors.teal.shade50,
                                child: Icon(
                                  Icons.local_shipping,
                                  color:
                                      isStockMove ? Colors.purple : Colors.teal,
                                ),
                              ),
                              vehicleNo: isStockMove
                                  ? item['vehicleName'] ?? '—'
                                  : item['vehicleNo'] ?? '—',
                              driverName: item['driverName'] ?? '—',
                              transportName: item['transportName'],
                              route: isStockMove
                                  ? '${item['fromBranch']?['name']} → ${item['toBranch']?['name']}'
                                  : '${item['fromLocation']?['name']} → ${item['toLocation']?['name']}',
                              materialName: item['material']?['name'],
                              qty: item['quantity'],
                              distance: item['distance'],
                              cost: item['cost'],
                              date: DateFormat(
                                "dd MMM yyyy",
                              ).format(
                                DateTime.parse(
                                  item['date'],
                                ),
                              ),
                              remarks: item['remarks'] ?? '',
                              isStockMove: isStockMove,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1 · Deliveries (existing Transport records) ───────────────────────────

class _DeliveriesTab extends StatefulWidget {
  final VoidCallback onReload;
  const _DeliveriesTab({super.key, required this.onReload});
  @override
  State<_DeliveriesTab> createState() => _DeliveriesTabState();
}

class _DeliveriesTabState extends State<_DeliveriesTab> {
  List _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/transport');
    if (mounted)
      setState(() {
        _items = res['data'] ?? [];
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return const EmptyState(
          message: 'No delivery records', icon: Icons.local_shipping_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = _items[i];
          final date = item['date'] != null
              ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
              : '—';
          return _TransportCard(
            leading: CircleAvatar(
                backgroundColor: Colors.teal.shade50,
                child: Icon(Icons.local_shipping, color: Colors.teal.shade700)),
            vehicleNo: item['vehicleNo'] ?? '—',
            driverName: item['driverName'] ?? '—',
            route:
                '${item['fromLocation']?['name'] ?? '—'}  →  ${item['toLocation']?['name'] ?? '—'}',
            materialName: item['material']?['name'],
            qty: item['quantity'] as num?,
            distance: item['distance'] as num?,
            cost: item['cost'] as num?,
            date: date,
            remarks: item['remarks'] ?? '',
            onEdit: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => TransportFormScreen(item: item)));
              _load();
            },
            onDelete: () => _delete(item['_id']),
          );
        },
      ),
    );
  }
}

// ── Tab 2 · Stock Moves (transport data from stock moves) ─────────────────────

class _StockMovesTab extends StatefulWidget {
  const _StockMovesTab({super.key});
  @override
  State<_StockMovesTab> createState() => _StockMovesTabState();
}

class _StockMovesTabState extends State<_StockMovesTab> {
  List _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res =
        await ApiService.get('/stock/history?transactionType=stock_move');
    if (mounted) {
      final all = (res['data'] as List? ?? []);
      // Only show records that have at least one transport detail filled
      final withTransport = all
          .where((r) =>
              (r['vehicleName'] ?? '').toString().isNotEmpty ||
              (r['driverName'] ?? '').toString().isNotEmpty ||
              (r['transportName'] ?? '').toString().isNotEmpty)
          .toList();
      setState(() {
        _items = withTransport;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return const EmptyState(
          message: 'No stock move transport records',
          icon: Icons.swap_horiz_rounded);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = _items[i];
          final date = item['date'] != null
              ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
              : '—';
          final fromB = (item['fromBranch']?['name'] ?? '—') as String;
          final toB = (item['toBranch']?['name'] ?? '—') as String;
          return _TransportCard(
            leading: CircleAvatar(
                backgroundColor: const Color(0xFFF3E5F5),
                child: const Icon(Icons.local_shipping_outlined,
                    color: Color(0xFF6A1B9A))),
            vehicleNo: (item['vehicleName'] ?? '—') as String,
            driverName: (item['driverName'] ?? '—') as String,
            transportName: (item['transportName'] ?? '') as String,
            route: '$fromB  →  $toB',
            materialName: item['material']?['name'] as String?,
            qty: item['quantity'] as num?,
            distance: item['distance'] as num?,
            cost: item['cost'] as num?,
            date: date,
            remarks: (item['remarks'] ?? '') as String,
            isStockMove: true,
          );
        },
      ),
    );
  }
}

// ── Shared transport card ─────────────────────────────────────────────────────

class _TransportCard extends StatelessWidget {
  final Widget leading;
  final String vehicleNo;
  final String driverName;
  final String? transportName;
  final String route;
  final String? materialName;
  final num? qty;
  final num? distance;
  final num? cost;
  final String date;
  final String remarks;
  final bool isStockMove;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TransportCard({
    required this.leading,
    required this.vehicleNo,
    required this.driverName,
    this.transportName,
    required this.route,
    this.materialName,
    this.qty,
    this.distance,
    this.cost,
    required this.date,
    required this.remarks,
    this.isStockMove = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor =
        isStockMove ? const Color(0xFF6A1B9A) : Colors.teal.shade700;

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
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Vehicle · Driver row
              Row(children: [
                Expanded(
                  child: Text(
                    [vehicleNo, driverName]
                        .where((s) => s != '—' && s.isNotEmpty)
                        .join('  ·  '),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A1A1A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (cost != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('₹$cost',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: accentColor)),
                  ),
              ]),
              const SizedBox(height: 4),
              // Transport company name (stock moves only)
              if (transportName != null && transportName!.isNotEmpty) ...[
                Text(transportName!,
                    style: TextStyle(
                        fontSize: 12,
                        color: accentColor,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
              ],
              // Route
              Row(children: [
                Icon(Icons.route_outlined,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(route,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF424242)),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 4),
              // Material + qty
              if (materialName != null && materialName!.isNotEmpty)
                Row(children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    qty != null
                        ? '$materialName  ·  $qty units'
                        : materialName!,
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                  ),
                ]),
              const SizedBox(height: 4),
              // Distance · Date
              Row(children: [
                if (distance != null) ...[
                  Icon(Icons.straighten, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('${distance}km',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9E9E9E))),
                  const SizedBox(width: 10),
                ],
                Icon(Icons.calendar_today_outlined,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(date,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9E9E9E))),
              ]),
              if (remarks.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(remarks,
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
              // Stock Move badge
              if (isStockMove) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Stock Move',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6A1B9A))),
                ),
              ],
            ]),
          ),
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  size: 18, color: Color(0xFFBDBDBD)),
              padding: EdgeInsets.zero,
              itemBuilder: (_) => [
                if (onEdit != null)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (onDelete != null)
                  const PopupMenuItem(
                      value: 'delete',
                      child:
                          Text('Delete', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (v) {
                if (v == 'edit')
                  onEdit?.call();
                else
                  onDelete?.call();
              },
            ),
        ]),
      ),
    );
  }
}

class TransportFormScreen extends StatefulWidget {
  final Map? item;
  const TransportFormScreen({super.key, this.item});
  @override
  State<TransportFormScreen> createState() => _TransportFormScreenState();
}

class _TransportFormScreenState extends State<TransportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  List _locations = [], _materials = [];
  String? _fromLoc, _toLoc, _materialId;
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
      _vehicleCtrl.text = e['vehicleNo'] ?? '';
      _driverCtrl.text = e['driverName'] ?? '';
      _qtyCtrl.text = '${e['quantity'] ?? ''}';
      _distCtrl.text = '${e['distance'] ?? ''}';
      _costCtrl.text = '${e['cost'] ?? ''}';
      _remarksCtrl.text = e['remarks'] ?? '';
      if (e['date'] != null) _date = DateTime.parse(e['date']);
    }
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
      'vehicleNo': _vehicleCtrl.text,
      'driverName': _driverCtrl.text,
      'fromLocation': _fromLoc,
      'toLocation': _toLoc,
      'material': _materialId,
      'quantity': double.tryParse(_qtyCtrl.text),
      'distance': double.tryParse(_distCtrl.text),
      'cost': double.tryParse(_costCtrl.text),
      'date': _date.toIso8601String(),
      'remarks': _remarksCtrl.text
    };
    final res = widget.item == null
        ? await ApiService.post('/transport', body)
        : await ApiService.put('/transport/${widget.item!['_id']}', body);
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
          title:
              Text(widget.item == null ? 'Add Transport' : 'Edit Transport')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
              controller: _vehicleCtrl,
              decoration: const InputDecoration(labelText: 'Vehicle No'),
              validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 16),
          TextFormField(
              controller: _driverCtrl,
              decoration: const InputDecoration(labelText: 'Driver Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 16),
          AppDropdown<String>(
              label: 'From Location',
              value: _fromLoc,
              items: _locations
                  .map<DropdownMenuItem<String>>((l) =>
                      DropdownMenuItem(value: l['_id'], child: Text(l['name'])))
                  .toList(),
              onChanged: (v) => setState(() => _fromLoc = v),
              validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 16),
          AppDropdown<String>(
              label: 'To Location',
              value: _toLoc,
              items: _locations
                  .map<DropdownMenuItem<String>>((l) =>
                      DropdownMenuItem(value: l['_id'], child: Text(l['name'])))
                  .toList(),
              onChanged: (v) => setState(() => _toLoc = v),
              validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 16),
          AppDropdown<String>(
              label: 'Material (Optional)',
              value: _materialId,
              items: _materials
                  .map<DropdownMenuItem<String>>((m) =>
                      DropdownMenuItem(value: m['_id'], child: Text(m['name'])))
                  .toList(),
              onChanged: (v) => setState(() => _materialId = v)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'))),
            const SizedBox(width: 12),
            Expanded(
                child: TextFormField(
                    controller: _distCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Distance (km)'))),
            const SizedBox(width: 12),
            Expanded(
                child: TextFormField(
                    controller: _costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cost (₹)'))),
          ]),
          const SizedBox(height: 16),
          DatePickerField(
              label: 'Date',
              value: _date,
              onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 16),
          TextFormField(
              controller: _remarksCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Remarks')),
          const SizedBox(height: 24),
          ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save')),
        ]),
      ),
    );
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
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load)
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
          ? const Center(child: CircularProgressIndicator())
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
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete',
                                      style: TextStyle(color: Colors.red)))
                            ],
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            MeasurementFormScreen(item: item)));
                                _load();
                              } else
                                _delete(item['_id']);
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
      'description': _descCtrl.text
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
                      DropdownMenuItem(value: 'nos', child: Text('nos'))
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
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save')),
        ]),
      ),
    );
  }
}
