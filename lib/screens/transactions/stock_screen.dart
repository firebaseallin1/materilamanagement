import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/material_movement_list.dart';
import '../../widgets/screen_header.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List _items = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/stock');
    if (mounted) setState(() { _items = res['data'] ?? []; _loading = false; });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/stock/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'], error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty ? _items : _items.where((i) =>
      (i['material']?['name'] ?? '').toLowerCase().contains(_search.toLowerCase()) ||
      (i['branch']?['name'] ?? '').toLowerCase().contains(_search.toLowerCase())).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const StockFormScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Stock'),
      ),
      body: Column(children: [
        ScreenHeader(
          title: 'Material Stock',
          subtitle: 'Monitor inventory levels and stock movements',
          onRefresh: _load,
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search by material or branch...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const EmptyState(message: 'No stock entries', icon: Icons.inventory_2)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        child: MaterialMovementList(
                          items: filtered,
                          onEdit: (item) async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => StockFormScreen(item: item)));
                            _load();
                          },
                          onDelete: (item) => _delete(item['_id']),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}


class StockFormScreen extends StatefulWidget {
  final Map? item;
  const StockFormScreen({super.key, this.item});
  @override
  State<StockFormScreen> createState() => _StockFormScreenState();
}

class _StockFormScreenState extends State<StockFormScreen> {
  final _formKey = GlobalKey<FormState>();
  List _materials = [], _branches = [];
  String? _materialId, _branchId, _type = 'in';
  final _qtyCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.item != null) {
      final e = widget.item!;
      _materialId = e['material']?['_id'];
      _branchId = e['branch']?['_id'];
      _type = e['type'];
      _qtyCtrl.text = '${e['quantity'] ?? ''}';
      _remarksCtrl.text = e['remarks'] ?? '';
      if (e['date'] != null) _date = DateTime.parse(e['date']);
    }
  }

  Future<void> _loadDropdowns() async {
    final [mRes, bRes] = await Future.wait([
      ApiService.get('/materials'),
      ApiService.get('/branches'),
    ]);
    if (mounted) setState(() {
      _materials = mRes['data'] ?? [];
      _branches = bRes['data'] ?? [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'material': _materialId,
      'branch': _branchId,
      'type': _type,
      'quantity': double.tryParse(_qtyCtrl.text) ?? 0,
      'date': _date.toIso8601String(),
      'remarks': _remarksCtrl.text,
    };
    final res = widget.item == null
        ? await ApiService.post('/stock', body)
        : await ApiService.put('/stock/${widget.item!['_id']}', body);
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Saved!' : res['message'], error: res['success'] != true);
      if (res['success'] == true) Navigator.pop(context);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'Add Stock' : 'Edit Stock')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppDropdown<String>(
              label: 'Material',
              value: _materialId,
              items: _materials.map<DropdownMenuItem<String>>((m) =>
                DropdownMenuItem(value: m['_id'], child: Text(m['name']))).toList(),
              onChanged: (v) => setState(() => _materialId = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            AppDropdown<String>(
              label: 'Branch',
              value: _branchId,
              items: _branches.map<DropdownMenuItem<String>>((b) =>
                DropdownMenuItem(value: b['_id'], child: Text(b['name']))).toList(),
              onChanged: (v) => setState(() => _branchId = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            AppDropdown<String>(
              label: 'Type',
              value: _type,
              items: const [
                DropdownMenuItem(value: 'in', child: Text('Stock In')),
                DropdownMenuItem(value: 'out', child: Text('Stock Out')),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DatePickerField(
              label: 'Date',
              value: _date,
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _remarksCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Remarks'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
