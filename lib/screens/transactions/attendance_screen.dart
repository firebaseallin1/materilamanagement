import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/attendance');
    if (mounted) setState(() { _items = res['data'] ?? []; _loading = false; });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/attendance/$id');
    if (mounted) { showSnack(context, res['success'] == true ? 'Deleted' : res['message'], error: res['success'] != true); if (res['success'] == true) _load(); }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'absent': return Colors.red;
      case 'halfday': return Colors.orange;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceFormScreen())); _load(); },
        icon: const Icon(Icons.add), label: const Text('Mark Attendance'),
      ),
      body: Column(children: [
        ScreenHeader(
          title: 'Attendance',
          subtitle: 'Track daily attendance records for your workforce',
          onRefresh: _load,
        ),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyState(message: 'No attendance records', icon: Icons.how_to_reg)
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
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(item['status']).withOpacity(0.12),
                            child: Icon(Icons.person, color: _statusColor(item['status'])),
                          ),
                          title: Text(item['employee']?['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${item['branch']?['name'] ?? '—'} · $date'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            StatusBadge(label: item['status'] ?? '', color: _statusColor(item['status'] ?? '')),
                            PopupMenuButton(
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                              onSelected: (v) async {
                                if (v == 'edit') { await Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceFormScreen(item: item))); _load(); }
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

class AttendanceFormScreen extends StatefulWidget {
  final Map? item;
  const AttendanceFormScreen({super.key, this.item});
  @override
  State<AttendanceFormScreen> createState() => _AttendanceFormScreenState();
}

class _AttendanceFormScreenState extends State<AttendanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  List _users = [], _branches = [];
  String? _employeeId, _branchId, _status = 'present';
  final _inCtrl = TextEditingController();
  final _outCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.item != null) {
      final e = widget.item!;
      _employeeId = e['employee']?['_id'];
      _branchId = e['branch']?['_id'];
      _status = e['status'];
      _inCtrl.text = e['inTime'] ?? '';
      _outCtrl.text = e['outTime'] ?? '';
      _remarksCtrl.text = e['remarks'] ?? '';
      if (e['date'] != null) _date = DateTime.parse(e['date']);
    }
  }

  Future<void> _loadDropdowns() async {
    final [uRes, bRes] = await Future.wait([ApiService.get('/users'), ApiService.get('/branches')]);
    if (mounted) setState(() { _users = uRes['data'] ?? []; _branches = bRes['data'] ?? []; });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = { 'employee': _employeeId, 'branch': _branchId, 'status': _status, 'date': _date.toIso8601String(), 'inTime': _inCtrl.text, 'outTime': _outCtrl.text, 'remarks': _remarksCtrl.text };
    final res = widget.item == null ? await ApiService.post('/attendance', body) : await ApiService.put('/attendance/${widget.item!['_id']}', body);
    if (mounted) { showSnack(context, res['success'] == true ? 'Saved!' : res['message'], error: res['success'] != true); if (res['success'] == true) Navigator.pop(context); }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'Mark Attendance' : 'Edit Attendance')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppDropdown<String>(label: 'Employee', value: _employeeId, items: _users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem(value: u['_id'], child: Text(u['name']))).toList(), onChanged: (v) => setState(() => _employeeId = v), validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 16),
          AppDropdown<String>(label: 'Branch', value: _branchId, items: _branches.map<DropdownMenuItem<String>>((b) => DropdownMenuItem(value: b['_id'], child: Text(b['name']))).toList(), onChanged: (v) => setState(() => _branchId = v), validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 16),
          AppDropdown<String>(label: 'Status', value: _status, items: const [
            DropdownMenuItem(value: 'present', child: Text('Present')),
            DropdownMenuItem(value: 'absent', child: Text('Absent')),
            DropdownMenuItem(value: 'halfday', child: Text('Half Day')),
            DropdownMenuItem(value: 'leave', child: Text('Leave')),
          ], onChanged: (v) => setState(() => _status = v)),
          const SizedBox(height: 16),
          DatePickerField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextFormField(controller: _inCtrl, decoration: const InputDecoration(labelText: 'In Time', hintText: '09:00'))),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _outCtrl, decoration: const InputDecoration(labelText: 'Out Time', hintText: '17:00'))),
          ]),
          const SizedBox(height: 16),
          TextFormField(controller: _remarksCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Remarks')),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save')),
        ]),
      ),
    );
  }
}
