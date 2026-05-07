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
  String _search = '';
  final _searchCtrl = TextEditingController();

  static const _primary = Color(0xFF111827);

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/attendance');
    if (mounted) setState(() { _items = res['data'] ?? []; _loading = false; });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/attendance/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  void _openForm([Map? item]) {
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
            child: AttendanceFormPanel(item: item, onSaved: _load),
          ),
        ),
      ),
      transitionBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'present':  return Colors.green;
      case 'absent':   return Colors.red;
      case 'halfday':  return Colors.orange;
      default:         return Colors.blue;
    }
  }

  List get _filtered {
    if (_search.isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items.where((i) =>
      (i['employee']?['name'] ?? '').toString().toLowerCase().contains(q) ||
      (i['branch']?['name'] ?? '').toString().toLowerCase().contains(q) ||
      (i['status'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final rows = _filtered;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Attendance',
              subtitle: 'Track daily attendance records for your workforce',
              onRefresh: _load,
              onSearchChanged: (v) => setState(() => _search = v),
              searchHint: 'Search attendance...',
              onAdd: _openForm,
              addLabel: 'Mark Attendance',
            ),
            _buildToolbar(isMobile),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Expanded(
              child: _loading
                  ? const AppLoader()
                  : rows.isEmpty
                      ? const EmptyState(message: 'No attendance records', icon: Icons.how_to_reg)
                      : isMobile
                          ? _buildMobileList(rows)
                          : _buildTable(rows),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildToolbar(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
      child: Row(children: [
        if (isMobile) ...[
          Expanded(
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(7),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  prefixIcon: Icon(Icons.search_rounded, size: 16, color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(top: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
          child: Text('${_filtered.length} rows',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ),
        if (isMobile) ...[
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _openForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Icon(Icons.add_rounded, size: 16),
          ),
        ],
      ]),
    );
  }

  Widget _buildTable(List rows) {
    return Column(children: [
      Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: const Row(children: [
          SizedBox(width: 28, child: Text('#', style: _kAttHdr)),
          SizedBox(width: 12),
          Expanded(flex: 3, child: Text('Employee', style: _kAttHdr)),
          Expanded(flex: 2, child: Text('Branch', style: _kAttHdr)),
          Expanded(flex: 2, child: Text('Date', style: _kAttHdr)),
          Expanded(flex: 2, child: Text('In / Out', style: _kAttHdr)),
          SizedBox(width: 90, child: Text('Status', style: _kAttHdr, textAlign: TextAlign.center)),
          SizedBox(width: 40),
        ]),
      ),
      const Divider(height: 1, color: Color(0xFFE5E7EB)),
      Expanded(
        child: ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) => _buildRow(rows[i], i),
        ),
      ),
    ]);
  }

  Widget _buildRow(Map item, int index) {
    final date = item['date'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
        : '—';
    final status = item['status'] ?? '';
    final inT = item['inTime'] ?? '—';
    final outT = item['outTime'] ?? '—';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openForm(item),
        hoverColor: const Color(0xFFF9FAFB),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
          child: Row(children: [
            SizedBox(width: 28, child: Text('${index + 1}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _statusColor(status).withOpacity(0.12),
                child: Icon(Icons.person, size: 14, color: _statusColor(status)),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(item['employee']?['name'] ?? '—',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
                  overflow: TextOverflow.ellipsis)),
            ])),
            Expanded(flex: 2, child: Text(item['branch']?['name'] ?? '—',
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                overflow: TextOverflow.ellipsis)),
            Expanded(flex: 2, child: Text(date,
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
            Expanded(flex: 2, child: Text('$inT – $outT',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                overflow: TextOverflow.ellipsis)),
            SizedBox(width: 90, child: Center(child: _statusBadge(status))),
            _actionMenu(item),
          ]),
        ),
      ),
    );
  }

  Widget _buildMobileList(List rows) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _mobileCard(rows[i]),
    );
  }

  Widget _mobileCard(Map item) {
    final date = item['date'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
        : '—';
    final status = item['status'] ?? '';
    return InkWell(
      onTap: () => _openForm(item),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: _statusColor(status).withOpacity(0.12),
            child: Icon(Icons.person, color: _statusColor(status)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['employee']?['name'] ?? '—',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text('${item['branch']?['name'] ?? '—'}  ·  $date',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ])),
          const SizedBox(width: 8),
          _statusBadge(status),
          _actionMenu(item),
        ]),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final c = _statusColor(status);
    final label = status.isEmpty ? '—'
        : status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c)),
    );
  }

  Widget _actionMenu(Map item) {
    return SizedBox(
      width: 40,
      child: PopupMenuButton(
        icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF9CA3AF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 3,
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Row(children: [
            Icon(Icons.edit_outlined, size: 15, color: Color(0xFF374151)),
            SizedBox(width: 8), Text('Edit', style: TextStyle(fontSize: 13)),
          ])),
          PopupMenuItem(value: 'delete', child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFDC2626)),
            SizedBox(width: 8), Text('Delete', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
          ])),
        ],
        onSelected: (val) {
          if (val == 'edit') _openForm(item);
          if (val == 'delete') _delete(item['_id']);
        },
      ),
    );
  }
}

const _kAttHdr = TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);

// ── Attendance Form Panel ─────────────────────────────────────────────────────

class AttendanceFormPanel extends StatefulWidget {
  final Map? item;
  final VoidCallback onSaved;
  const AttendanceFormPanel({super.key, this.item, required this.onSaved});
  @override
  State<AttendanceFormPanel> createState() => _AttendanceFormPanelState();
}

class _AttendanceFormPanelState extends State<AttendanceFormPanel> {
  final _formKey = GlobalKey<FormState>();
  List _users = [], _branches = [];
  String? _employeeId, _branchId, _status = 'present';
  final _inCtrl = TextEditingController();
  final _outCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _primary = Color(0xFF1B3A27);
  static const _accent = Color(0xFF2E7D52);

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.item != null) {
      final e = widget.item!;
      _employeeId = e['employee']?['_id'];
      _branchId = e['branch']?['_id'];
      _status = e['status'] ?? 'present';
      _inCtrl.text = e['inTime'] ?? '';
      _outCtrl.text = e['outTime'] ?? '';
      _remarksCtrl.text = e['remarks'] ?? '';
      if (e['date'] != null) _date = DateTime.parse(e['date']);
    }
  }

  @override
  void dispose() {
    _inCtrl.dispose(); _outCtrl.dispose(); _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    final results = await Future.wait([ApiService.get('/users'), ApiService.get('/branches')]);
    if (mounted) setState(() {
      _users = results[0]['data'] ?? [];
      _branches = results[1]['data'] ?? [];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'employee': _employeeId, 'branch': _branchId, 'status': _status,
      'date': _date.toIso8601String(),
      'inTime': _inCtrl.text.trim(), 'outTime': _outCtrl.text.trim(),
      'remarks': _remarksCtrl.text.trim(),
    };
    final res = widget.item == null
        ? await ApiService.post('/attendance', body)
        : await ApiService.put('/attendance/${widget.item!['_id']}', body);
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Saved successfully!' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) { Navigator.pop(context); widget.onSaved(); }
    }
    if (mounted) setState(() => _saving = false);
  }

  InputDecoration _dec(String label, IconData icon, {String? hint}) => InputDecoration(
    labelText: label, hintText: hint,
    prefixIcon: Icon(icon, size: 18, color: _accent),
    labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
    filled: true, fillColor: const Color(0xFFF7F9F8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item == null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 10),
      Container(width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 2),
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_primary, Color(0xFF1E6F5C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isNew ? 'Mark Attendance' : 'Edit Attendance',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(isNew ? 'Fill in the attendance details' : 'Update attendance information',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.close, color: Colors.white70, size: 16),
            ),
          ),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<String>(
                initialValue: _employeeId,
                decoration: _dec('Employee', Icons.person_outline_rounded),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                borderRadius: BorderRadius.circular(10),
                items: _users.map<DropdownMenuItem<String>>((u) =>
                    DropdownMenuItem(value: u['_id'] as String, child: Text(u['name'] as String))).toList(),
                onChanged: (v) => setState(() => _employeeId = v),
                validator: (v) => v == null ? 'Required' : null,
                isExpanded: true,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _branchId,
                decoration: _dec('Branch', Icons.store_outlined),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                borderRadius: BorderRadius.circular(10),
                items: _branches.map<DropdownMenuItem<String>>((b) =>
                    DropdownMenuItem(value: b['_id'] as String, child: Text(b['name'] as String))).toList(),
                onChanged: (v) => setState(() => _branchId = v),
                validator: (v) => v == null ? 'Required' : null,
                isExpanded: true,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: _dec('Status', Icons.check_circle_outline_rounded),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                borderRadius: BorderRadius.circular(10),
                items: const [
                  DropdownMenuItem(value: 'present', child: Text('Present')),
                  DropdownMenuItem(value: 'absent',  child: Text('Absent')),
                  DropdownMenuItem(value: 'halfday', child: Text('Half Day')),
                  DropdownMenuItem(value: 'leave',   child: Text('Leave')),
                ],
                onChanged: (v) => setState(() => _status = v),
                isExpanded: true,
              ),
              const SizedBox(height: 14),
              DatePickerField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextFormField(controller: _inCtrl, decoration: _dec('In Time', Icons.login_rounded, hint: '09:00'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _outCtrl, decoration: _dec('Out Time', Icons.logout_rounded, hint: '17:00'))),
              ]),
              const SizedBox(height: 14),
              TextFormField(controller: _remarksCtrl, maxLines: 2,
                  decoration: _dec('Remarks', Icons.notes_rounded, hint: 'Optional...')),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFDDE3E0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 14)),
                )),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _saving ? null : const LinearGradient(colors: [_primary, Color(0xFF1E6F5C)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                    color: _saving ? Colors.grey.shade300 : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const ButtonLoader()
                        : Text(isNew ? 'Mark Attendance' : 'Save Changes',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                )),
              ]),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    ]);
  }
}
