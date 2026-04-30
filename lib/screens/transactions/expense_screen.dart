import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});
  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/expenses');
    if (mounted) setState(() { _items = res['data'] ?? []; _loading = false; });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/expenses/$id');
    if (mounted) { showSnack(context, res['success'] == true ? 'Deleted' : res['message'], error: res['success'] != true); if (res['success'] == true) _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<num>(0, (s, i) => s + (i['amount'] ?? 0));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseFormScreen())); _load(); },
        icon: const Icon(Icons.add), label: const Text('Add Expense'),
      ),
      body: Column(children: [
        ScreenHeader(
          title: 'Expenses',
          subtitle: 'Track and manage operational expenses',
          onRefresh: _load,
        ),
        Container(
          color: Colors.orange.shade700,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('Total: ₹${total.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyState(message: 'No expenses', icon: Icons.receipt_long)
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
                          leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: Icon(Icons.receipt_long, color: Colors.orange.shade700)),
                          title: Text(item['category'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${item['branch']?['name'] ?? '—'} · $date\n${item['description'] ?? ''}'),
                          isThreeLine: true,
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('₹${item['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
                            PopupMenuButton(
                              itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red)))],
                              onSelected: (v) async {
                                if (v == 'edit') { await Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseFormScreen(item: item))); _load(); }
                                else _delete(item['_id']);
                              },
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

class ExpenseFormScreen extends StatefulWidget {
  final Map? item;
  const ExpenseFormScreen({super.key, this.item});
  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  List _branches = [];
  String? _branchId;
  final _categoryCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const categories = ['Labour', 'Material', 'Transport', 'Food', 'Fuel', 'Maintenance', 'Miscellaneous'];

  @override
  void initState() {
    super.initState();
    _loadBranches();
    if (widget.item != null) {
      final e = widget.item!;
      _branchId = e['branch']?['_id'];
      _categoryCtrl.text = e['category'] ?? '';
      _amountCtrl.text = '${e['amount'] ?? ''}';
      _descCtrl.text = e['description'] ?? '';
      if (e['date'] != null) _date = DateTime.parse(e['date']);
    }
  }

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches');
    if (mounted) setState(() => _branches = res['data'] ?? []);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = { 'branch': _branchId, 'category': _categoryCtrl.text, 'amount': double.tryParse(_amountCtrl.text) ?? 0, 'date': _date.toIso8601String(), 'description': _descCtrl.text };
    final res = widget.item == null ? await ApiService.post('/expenses', body) : await ApiService.put('/expenses/${widget.item!['_id']}', body);
    if (mounted) { showSnack(context, res['success'] == true ? 'Saved!' : res['message'], error: res['success'] != true); if (res['success'] == true) Navigator.pop(context); }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'Add Expense' : 'Edit Expense')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppDropdown<String>(label: 'Branch', value: _branchId, items: _branches.map<DropdownMenuItem<String>>((b) => DropdownMenuItem(value: b['_id'], child: Text(b['name']))).toList(), onChanged: (v) => setState(() => _branchId = v), validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: categories.contains(_categoryCtrl.text) ? _categoryCtrl.text : null,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => _categoryCtrl.text = v ?? '',
            validator: (_) => _categoryCtrl.text.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(controller: _amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ '), validator: (v) => v!.isEmpty ? 'Required' : null),
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
