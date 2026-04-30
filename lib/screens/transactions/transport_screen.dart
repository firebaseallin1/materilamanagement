import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

// ════════════════════════════════════════════════
// TRANSPORT SCREEN
// ════════════════════════════════════════════════
class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});
  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  List _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/transport');
    if (mounted) setState(() { _items = res['data'] ?? []; _loading = false; });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/transport/$id');
    if (mounted) { showSnack(context, res['success'] == true ? 'Deleted' : res['message'], error: res['success'] != true); if (res['success'] == true) _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const TransportFormScreen())); _load(); },
        icon: const Icon(Icons.add), label: const Text('Add Transport'),
      ),
      body: Column(children: [
        ScreenHeader(
          title: 'Transport',
          subtitle: 'Manage vehicle transport and delivery records',
          onRefresh: _load,
        ),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyState(message: 'No transport records', icon: Icons.local_shipping)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      final date = item['date'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date'])) : '—';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.teal.shade50, child: Icon(Icons.local_shipping, color: Colors.teal.shade700)),
                          title: Text('${item['vehicleNo']} · ${item['driverName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${item['fromLocation']?['name'] ?? '—'} → ${item['toLocation']?['name'] ?? '—'}\n$date'),
                          isThreeLine: true,
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (item['cost'] != null) Text('₹${item['cost']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                            PopupMenuButton(
                              itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red)))],
                              onSelected: (v) async { if (v == 'edit') { await Navigator.push(context, MaterialPageRoute(builder: (_) => TransportFormScreen(item: item))); _load(); } else _delete(item['_id']); },
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
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
    final [lRes, mRes] = await Future.wait([ApiService.get('/locations'), ApiService.get('/materials')]);
    if (mounted) setState(() { _locations = lRes['data'] ?? []; _materials = mRes['data'] ?? []; });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = { 'vehicleNo': _vehicleCtrl.text, 'driverName': _driverCtrl.text, 'fromLocation': _fromLoc, 'toLocation': _toLoc, 'material': _materialId, 'quantity': double.tryParse(_qtyCtrl.text), 'distance': double.tryParse(_distCtrl.text), 'cost': double.tryParse(_costCtrl.text), 'date': _date.toIso8601String(), 'remarks': _remarksCtrl.text };
    final res = widget.item == null ? await ApiService.post('/transport', body) : await ApiService.put('/transport/${widget.item!['_id']}', body);
    if (mounted) { showSnack(context, res['success'] == true ? 'Saved!' : res['message'], error: res['success'] != true); if (res['success'] == true) Navigator.pop(context); }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'Add Transport' : 'Edit Transport')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: _vehicleCtrl, decoration: const InputDecoration(labelText: 'Vehicle No'), validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 16),
          TextFormField(controller: _driverCtrl, decoration: const InputDecoration(labelText: 'Driver Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 16),
          AppDropdown<String>(label: 'From Location', value: _fromLoc, items: _locations.map<DropdownMenuItem<String>>((l) => DropdownMenuItem(value: l['_id'], child: Text(l['name']))).toList(), onChanged: (v) => setState(() => _fromLoc = v), validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 16),
          AppDropdown<String>(label: 'To Location', value: _toLoc, items: _locations.map<DropdownMenuItem<String>>((l) => DropdownMenuItem(value: l['_id'], child: Text(l['name']))).toList(), onChanged: (v) => setState(() => _toLoc = v), validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 16),
          AppDropdown<String>(label: 'Material (Optional)', value: _materialId, items: _materials.map<DropdownMenuItem<String>>((m) => DropdownMenuItem(value: m['_id'], child: Text(m['name']))).toList(), onChanged: (v) => setState(() => _materialId = v)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextFormField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'))),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _distCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Distance (km)'))),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost (₹)'))),
          ]),
          const SizedBox(height: 16),
          DatePickerField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 16),
          TextFormField(controller: _remarksCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Remarks')),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save')),
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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/measurements');
    if (mounted) setState(() { _items = res['data'] ?? []; _loading = false; });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/measurements/$id');
    if (mounted) { showSnack(context, res['success'] == true ? 'Deleted' : res['message'], error: res['success'] != true); if (res['success'] == true) _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Measurements'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const MeasurementFormScreen())); _load(); },
        icon: const Icon(Icons.add), label: const Text('Add Measurement'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyState(message: 'No measurements', icon: Icons.straighten)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      final date = item['date'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date'])) : '—';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.indigo.shade50, child: Icon(Icons.straighten, color: Colors.indigo.shade700)),
                          title: Text(item['material']?['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${item['branch']?['name'] ?? '—'} · $date\nQty: ${item['quantity']} ${item['unit'] ?? ''}'),
                          isThreeLine: true,
                          trailing: PopupMenuButton(
                            itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red)))],
                            onSelected: (v) async { if (v == 'edit') { await Navigator.push(context, MaterialPageRoute(builder: (_) => MeasurementFormScreen(item: item))); _load(); } else _delete(item['_id']); },
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
    final [bRes, mRes] = await Future.wait([ApiService.get('/branches'), ApiService.get('/materials')]);
    if (mounted) setState(() { _branches = bRes['data'] ?? []; _materials = mRes['data'] ?? []; });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = { 'branch': _branchId, 'material': _materialId, 'length': double.tryParse(_lenCtrl.text), 'breadth': double.tryParse(_breCtrl.text), 'height': double.tryParse(_heiCtrl.text), 'quantity': double.tryParse(_qtyCtrl.text) ?? 0, 'unit': _unit, 'date': _date.toIso8601String(), 'description': _descCtrl.text };
    final res = widget.item == null ? await ApiService.post('/measurements', body) : await ApiService.put('/measurements/${widget.item!['_id']}', body);
    if (mounted) { showSnack(context, res['success'] == true ? 'Saved!' : res['message'], error: res['success'] != true); if (res['success'] == true) Navigator.pop(context); }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'Add Measurement' : 'Edit Measurement')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppDropdown<String>(label: 'Branch', value: _branchId, items: _branches.map<DropdownMenuItem<String>>((b) => DropdownMenuItem(value: b['_id'], child: Text(b['name']))).toList(), onChanged: (v) => setState(() => _branchId = v), validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 16),
          AppDropdown<String>(label: 'Material', value: _materialId, items: _materials.map<DropdownMenuItem<String>>((m) => DropdownMenuItem(value: m['_id'], child: Text(m['name']))).toList(), onChanged: (v) => setState(() => _materialId = v), validator: (v) => v == null ? 'Required' : null),
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
            Expanded(child: AppDropdown<String>(label: 'Unit', value: _unit, items: const [DropdownMenuItem(value: 'sqft', child: Text('sq ft')), DropdownMenuItem(value: 'sqm', child: Text('sq m')), DropdownMenuItem(value: 'rft', child: Text('rft')), DropdownMenuItem(value: 'cum', child: Text('cu m')), DropdownMenuItem(value: 'nos', child: Text('nos'))], onChanged: (v) => setState(() => _unit = v))),
          ]),
          const SizedBox(height: 16),
          DatePickerField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 16),
          TextFormField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save')),
        ]),
      ),
    );
  }
}
