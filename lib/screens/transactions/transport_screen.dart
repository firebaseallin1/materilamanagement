import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

const _kTrpHdr = TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);
const _trpPrimary = Color(0xFF111827);
const _trpTeal = Color(0xFF0D9488);

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

  @override
  void initState() { super.initState(); _load(); }

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
    if (mounted) setState(() { _items = all; _loading = false; });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/transport/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'], error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  List get _filtered {
    if (_search.isEmpty) return _items;
    final q = _search.toLowerCase().trim();
    return _items.where((item) {
      final isStockMove = item['recordType'] == 'stock_move';
      final vehicle = (isStockMove ? item['vehicleName'] : item['vehicleNo'])?.toString().toLowerCase() ?? '';
      final driver = (item['driverName'] ?? '').toString().toLowerCase();
      final material = (item['material'] as Map?)?['name']?.toString().toLowerCase() ?? '';
      return vehicle.contains(q) || driver.contains(q) || material.contains(q);
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
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 700;
      return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: _trpTeal,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Transport', style: TextStyle(color: Colors.white)),
        ),
        body: Column(children: [
          ScreenHeader(
            title: 'Transport',
            subtitle: 'Deliveries & Stock Moves',
            onRefresh: _load,
            onSearchChanged: (v) => setState(() => _search = v),
            searchHint: 'Search vehicle, driver, material…',
          ),
          if (!isMobile) _buildTableHeader(),
          Expanded(
            child: _loading
                ? const AppLoader()
                : _filtered.isEmpty
                    ? const EmptyState(message: 'No matching records', icon: Icons.local_shipping)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: isMobile ? _buildMobileList() : _buildDesktopList(),
                      ),
          ),
        ]),
      );
    });
  }

  Widget _buildTableHeader() {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(children: [
        SizedBox(width: 40, child: Text('#', style: _kTrpHdr)),
        SizedBox(width: 88, child: Text('TYPE', style: _kTrpHdr)),
        Expanded(flex: 2, child: Text('VEHICLE / DRIVER', style: _kTrpHdr)),
        Expanded(flex: 3, child: Text('ROUTE', style: _kTrpHdr)),
        Expanded(flex: 2, child: Text('MATERIAL', style: _kTrpHdr)),
        SizedBox(width: 68, child: Text('COST', style: _kTrpHdr, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('DATE', style: _kTrpHdr)),
        SizedBox(width: 48),
      ]),
    );
  }

  Widget _buildDesktopList() {
    final list = _filtered;
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final item = list[i];
        final isStockMove = item['recordType'] == 'stock_move';
        final vehicleNo = isStockMove ? (item['vehicleName'] ?? '—') : (item['vehicleNo'] ?? '—');
        final driver = item['driverName'] ?? '—';
        final route = isStockMove
            ? '${item['fromBranch']?['name'] ?? '—'} → ${item['toBranch']?['name'] ?? '—'}'
            : '${item['fromLocation']?['name'] ?? '—'} → ${item['toLocation']?['name'] ?? '—'}';
        final material = item['material']?['name'] ?? '—';
        final cost = item['cost'];
        final date = item['date'] != null
            ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(item['date']) ?? DateTime.now())
            : '—';
        return InkWell(
          onTap: isStockMove ? null : () => _openForm(item),
          hoverColor: const Color(0xFFF0FDF4),
          child: Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(children: [
              SizedBox(width: 40, child: Text('${i + 1}', style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))),
              SizedBox(width: 88, child: _typeBadge(isStockMove)),
              Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(vehicleNo.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _trpPrimary)),
                Text(driver.toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ])),
              Expanded(flex: 3, child: Text(route, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), overflow: TextOverflow.ellipsis)),
              Expanded(flex: 2, child: Text(material.toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), overflow: TextOverflow.ellipsis)),
              SizedBox(width: 68, child: Text(cost != null ? '₹$cost' : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _trpTeal), textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text(date, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),
              isStockMove ? const SizedBox(width: 48) : _actionMenu(item),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildMobileList() {
    final list = _filtered;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final item = list[i];
        final isStockMove = item['recordType'] == 'stock_move';
        final accentColor = isStockMove ? const Color(0xFF6A1B9A) : _trpTeal;
        final vehicleNo = isStockMove ? (item['vehicleName'] ?? '—') : (item['vehicleNo'] ?? '—');
        final driver = item['driverName'] ?? '—';
        final route = isStockMove
            ? '${item['fromBranch']?['name'] ?? '—'} → ${item['toBranch']?['name'] ?? '—'}'
            : '${item['fromLocation']?['name'] ?? '—'} → ${item['toLocation']?['name'] ?? '—'}';
        final cost = item['cost'];
        final date = item['date'] != null
            ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(item['date']) ?? DateTime.now())
            : '—';
        final material = item['material']?['name'];
        final qty = item['quantity'];
        final distance = item['distance'];
        final remarks = (item['remarks'] ?? '').toString();
        final transportName = item['transportName'];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEEE)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                backgroundColor: isStockMove ? const Color(0xFFF3E5F5) : const Color(0xFFE0F2FE),
                child: Icon(Icons.local_shipping, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      [vehicleNo.toString(), driver.toString()].where((s) => s != '—' && s.isNotEmpty).join('  ·  '),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A1A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (cost != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Text('₹$cost', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: accentColor)),
                    ),
                ]),
                const SizedBox(height: 4),
                if (transportName != null && transportName.toString().isNotEmpty) ...[
                  Text(transportName.toString(), style: TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                ],
                Row(children: [
                  Icon(Icons.route_outlined, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(child: Text(route, style: const TextStyle(fontSize: 12, color: Color(0xFF424242)), overflow: TextOverflow.ellipsis)),
                ]),
                if (material != null && material.toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.inventory_2_outlined, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      qty != null ? '$material  ·  $qty units' : material.toString(),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                    ),
                  ]),
                ],
                const SizedBox(height: 4),
                Row(children: [
                  if (distance != null) ...[
                    Icon(Icons.straighten, size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text('${distance}km', style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                    const SizedBox(width: 10),
                  ],
                  Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(date, style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                ]),
                if (remarks.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(remarks, style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (isStockMove) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Stock Move', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6A1B9A))),
                  ),
                ],
              ])),
              if (!isStockMove) _actionMenu(item),
            ]),
          ),
        );
      },
    );
  }

  Widget _typeBadge(bool isStockMove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isStockMove ? const Color(0xFFF3E5F5) : const Color(0xFFCCFBF1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isStockMove ? 'Stock Move' : 'Delivery',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isStockMove ? const Color(0xFF6A1B9A) : _trpTeal),
      ),
    );
  }

  Widget _actionMenu(Map item) {
    return PopupMenuButton<String>(
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
    );
  }
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

  @override
  void dispose() {
    _vehicleCtrl.dispose(); _driverCtrl.dispose();
    _qtyCtrl.dispose(); _distCtrl.dispose();
    _costCtrl.dispose(); _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    final [lRes, mRes] = await Future.wait([ApiService.get('/locations'), ApiService.get('/materials')]);
    if (mounted) setState(() { _locations = lRes['data'] ?? []; _materials = mRes['data'] ?? []; });
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
      'remarks': _remarksCtrl.text,
    };
    final res = widget.item == null
        ? await ApiService.post('/transport', body)
        : await ApiService.put('/transport/${widget.item!['_id']}', body);
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Saved!' : res['message'], error: res['success'] != true);
      if (res['success'] == true) widget.onSaved();
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return Column(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1B3A27), Color(0xFF1E6F5C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 18, left: 20, right: 8),
        child: Row(children: [
          const Icon(Icons.local_shipping_outlined, color: Colors.white70, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(isEdit ? 'Edit Transport' : 'New Transport', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600))),
          IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
      Expanded(child: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
            controller: _vehicleCtrl,
            decoration: const InputDecoration(labelText: 'Vehicle No', border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _driverCtrl,
            decoration: const InputDecoration(labelText: 'Driver Name', border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          AppDropdown<String>(
            label: 'From Location',
            value: _fromLoc,
            items: _locations.map<DropdownMenuItem<String>>((l) => DropdownMenuItem(value: l['_id'], child: Text(l['name']))).toList(),
            onChanged: (v) => setState(() => _fromLoc = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          AppDropdown<String>(
            label: 'To Location',
            value: _toLoc,
            items: _locations.map<DropdownMenuItem<String>>((l) => DropdownMenuItem(value: l['_id'], child: Text(l['name']))).toList(),
            onChanged: (v) => setState(() => _toLoc = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          AppDropdown<String>(
            label: 'Material (Optional)',
            value: _materialId,
            items: _materials.map<DropdownMenuItem<String>>((m) => DropdownMenuItem(value: m['_id'], child: Text(m['name']))).toList(),
            onChanged: (v) => setState(() => _materialId = v),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextFormField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextFormField(controller: _distCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Distance (km)', border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextFormField(controller: _costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost (₹)', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 16),
          DatePickerField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _remarksCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D52),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const ButtonLoader()
                  : Text(isEdit ? 'Update Transport' : 'Save Transport'),
            ),
          ),
        ]),
      )),
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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/measurements');
    if (mounted) setState(() { _items = res['data'] ?? []; _loading = false; });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/measurements/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'], error: res['success'] != true);
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
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const MeasurementFormScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Measurement'),
      ),
      body: _loading
          ? const AppLoader()
          : _items.isEmpty
              ? const EmptyState(message: 'No measurements', icon: Icons.straighten)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      final date = item['date'] != null
                          ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
                          : '—';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: Colors.indigo.shade50,
                              child: Icon(Icons.straighten, color: Colors.indigo.shade700)),
                          title: Text(item['material']?['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${item['branch']?['name'] ?? '—'} · $date\nQty: ${item['quantity']} ${item['unit'] ?? ''}'),
                          isThreeLine: true,
                          trailing: PopupMenuButton(
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
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => MeasurementFormScreen(item: item)));
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
    _lenCtrl.dispose(); _breCtrl.dispose(); _heiCtrl.dispose();
    _qtyCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    final [bRes, mRes] = await Future.wait([ApiService.get('/branches'), ApiService.get('/materials')]);
    if (mounted) setState(() { _branches = bRes['data'] ?? []; _materials = mRes['data'] ?? []; });
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
      showSnack(context, res['success'] == true ? 'Saved!' : res['message'], error: res['success'] != true);
      if (res['success'] == true) Navigator.pop(context);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'Add Measurement' : 'Edit Measurement')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppDropdown<String>(
              label: 'Branch',
              value: _branchId,
              items: _branches.map<DropdownMenuItem<String>>((b) => DropdownMenuItem(value: b['_id'], child: Text(b['name']))).toList(),
              onChanged: (v) => setState(() => _branchId = v),
              validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 16),
          AppDropdown<String>(
              label: 'Material',
              value: _materialId,
              items: _materials.map<DropdownMenuItem<String>>((m) => DropdownMenuItem(value: m['_id'], child: Text(m['name']))).toList(),
              onChanged: (v) => setState(() => _materialId = v),
              validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextFormField(controller: _lenCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Length'))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _breCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Breadth'))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _heiCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height'))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextFormField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'), validator: (v) => v!.isEmpty ? 'Required' : null)),
            const SizedBox(width: 12),
            Expanded(child: AppDropdown<String>(
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
          DatePickerField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 16),
          TextFormField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 24),
          ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const ButtonLoader()
                  : const Text('Save')),
        ]),
      ),
    );
  }
}
