import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/payments');
    if (mounted) setState(() { _items = res['data'] ?? []; _loading = false; });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/payments/$id');
    if (mounted) { showSnack(context, res['success'] == true ? 'Deleted' : res['message'], error: res['success'] != true); if (res['success'] == true) _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentFormScreen())); _load(); },
        icon: const Icon(Icons.add), label: const Text('Add Payment'),
      ),
      body: Column(children: [
        ScreenHeader(
          title: 'Payments',
          subtitle: 'Record and monitor financial payment transactions',
          onRefresh: _load,
        ),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyState(message: 'No payments', icon: Icons.payment)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      final isReceived = item['type'] == 'received';
                      final date = item['date'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date'])) : '—';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isReceived ? Colors.green.shade50 : Colors.red.shade50,
                            child: Icon(isReceived ? Icons.arrow_downward : Icons.arrow_upward, color: isReceived ? Colors.green : Colors.red),
                          ),
                          title: Text(item['partyName'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${item['paymentMode']?.toUpperCase()} · $date\n${item['branch']?['name'] ?? ''}'),
                          isThreeLine: true,
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('₹${item['amount']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isReceived ? Colors.green : Colors.red)),
                              StatusBadge(label: item['type'] ?? '', color: isReceived ? Colors.green : Colors.red),
                            ]),
                            PopupMenuButton(
                              itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red)))],
                              onSelected: (v) async {
                                if (v == 'edit') { await Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentFormScreen(item: item))); _load(); }
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

class PaymentFormScreen extends StatefulWidget {
  final Map? item;
  const PaymentFormScreen({super.key, this.item});
  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  List _branches = [];
  String? _branchId, _mode = 'cash', _type = 'received';
  final _partyCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    if (widget.item != null) {
      final e = widget.item!;
      _branchId = e['branch']?['_id'];
      _mode = e['paymentMode'];
      _type = e['type'];
      _partyCtrl.text = e['partyName'] ?? '';
      _amountCtrl.text = '${e['amount'] ?? ''}';
      _refCtrl.text = e['referenceNo'] ?? '';
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
    final body = { 'branch': _branchId, 'partyName': _partyCtrl.text, 'amount': double.tryParse(_amountCtrl.text) ?? 0, 'paymentMode': _mode, 'type': _type, 'date': _date.toIso8601String(), 'referenceNo': _refCtrl.text, 'description': _descCtrl.text };
    final res = widget.item == null ? await ApiService.post('/payments', body) : await ApiService.put('/payments/${widget.item!['_id']}', body);
    if (mounted) { showSnack(context, res['success'] == true ? 'Saved!' : res['message'], error: res['success'] != true); if (res['success'] == true) Navigator.pop(context); }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'Add Payment' : 'Edit Payment')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppDropdown<String>(label: 'Branch', value: _branchId, items: _branches.map<DropdownMenuItem<String>>((b) => DropdownMenuItem(value: b['_id'], child: Text(b['name']))).toList(), onChanged: (v) => setState(() => _branchId = v), validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 16),
          TextFormField(controller: _partyCtrl, decoration: const InputDecoration(labelText: 'Party Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 16),
          TextFormField(controller: _amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ '), validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: AppDropdown<String>(label: 'Payment Mode', value: _mode, items: const [DropdownMenuItem(value: 'cash', child: Text('Cash')), DropdownMenuItem(value: 'cheque', child: Text('Cheque')), DropdownMenuItem(value: 'online', child: Text('Online')), DropdownMenuItem(value: 'upi', child: Text('UPI'))], onChanged: (v) => setState(() => _mode = v))),
            const SizedBox(width: 12),
            Expanded(child: AppDropdown<String>(label: 'Type', value: _type, items: const [DropdownMenuItem(value: 'received', child: Text('Received')), DropdownMenuItem(value: 'paid', child: Text('Paid'))], onChanged: (v) => setState(() => _type = v))),
          ]),
          const SizedBox(height: 16),
          DatePickerField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 16),
          TextFormField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'Reference No')),
          const SizedBox(height: 16),
          TextFormField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save')),
        ]),
      ),
    );
  }
}
