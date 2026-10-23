import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

const _ueGreen = Color(0xFF16A34A);
const _ueOrange = Color(0xFFEA580C);
const _ueBorder = Color(0xFFE5E7EB);

String _ueAmt(num v) => NumberFormat('#,##,##0.00', 'en_IN').format(v);

// Same as attendance screen: dates are stored as UTC days
String _datePart(String iso) => iso.length >= 10 ? iso.substring(0, 10) : iso;

class UserExpenseScreen extends StatefulWidget {
  const UserExpenseScreen({super.key});
  @override
  State<UserExpenseScreen> createState() => _UserExpenseScreenState();
}

class _UserExpenseScreenState extends State<UserExpenseScreen> {
  bool _loading = true;
  String _search = '';
  late DateTime _from, _to;

  // Admin can view any user's expenses
  List _users = [];
  String? _userId;

  List _expenses = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0);
    if (context.read<AuthService>().isAdmin) _loadUsers();
    _load();
  }

  Future<void> _loadUsers() async {
    final res = await ApiService.get('/users');
    if (mounted) setState(() => _users = res['data'] ?? []);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fmt = DateFormat('yyyy-MM-dd');
    final params = {'from': fmt.format(_from), 'to': fmt.format(_to)};
    if (_userId != null) params['user'] = _userId!;
    final res = await ApiService.get('/user-expenses', params: params);
    if (!mounted) return;
    if (res['success'] != true) {
      showSnack(context, res['message'] ?? 'Failed to load', error: true);
    }
    setState(() {
      _expenses = res['data'] ?? [];
      _loading = false;
    });
  }

  List get _filtered {
    final q = _search.toLowerCase();
    if (q.isEmpty) return _expenses;
    return _expenses
        .where((e) =>
            (e['category'] ?? '').toString().toLowerCase().contains(q) ||
            (e['description'] ?? '').toString().toLowerCase().contains(q) ||
            (e['branch']?['name'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF2E7D52))),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
    _load();
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/user-expenses/$id');
    if (!mounted) return;
    showSnack(context, res['success'] == true ? 'Deleted' : res['message'],
        error: res['success'] != true);
    if (res['success'] == true) _load();
  }

  void _openForm([Map? item]) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'user-expense-form',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final sw = MediaQuery.of(ctx).size.width;
        final pw = sw > 900 ? sw * 0.38 : sw * 0.92;
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
                child: UserExpenseFormPanel(
                  item: item,
                  userId: _userId,
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<AuthService>().isAdmin;
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final rows = _filtered;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ScreenHeader(
            title: 'User Expense',
            subtitle: 'Expenses paid by you',
            onRefresh: _load,
            onSearchChanged: (v) => setState(() => _search = v),
            searchHint: 'Search category...',
            onAdd: () => _openForm(),
            addLabel: 'Add Expense',
          ),
          _buildToolbar(isMobile, isAdmin),
          const Divider(height: 1, color: _ueBorder),
          Expanded(
            child: _loading
                ? const AppLoader()
                : rows.isEmpty
                    ? const EmptyState(
                        message: 'No expenses in this period',
                        icon: Icons.receipt_long_outlined)
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _expenseCard(rows[i]),
                      ),
          ),
        ]);
      }),
    );
  }

  // ── Toolbar: user picker (admin) + date range ──────────────────────────────

  Widget _buildToolbar(bool isMobile, bool isAdmin) {
    final fmt = DateFormat('dd MMM yyyy');
    Widget dateBox(String label, DateTime d, bool isFrom) => InkWell(
          onTap: () => _pickDate(isFrom),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDDE3E0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: Color(0xFF2E7D52)),
              const SizedBox(width: 6),
              Text('$label  ',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              Text(fmt.format(d),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
            ]),
          ),
        );

    final userPicker = isAdmin
        ? DropdownButtonFormField<String?>(
            initialValue: _userId,
            isExpanded: true,
            borderRadius: BorderRadius.circular(8),
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  size: 15, color: Color(0xFF2E7D52)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
            ),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('My expenses')),
              ..._users.map((u) => DropdownMenuItem<String?>(
                  value: u['_id'] as String,
                  child: Text('${u['name'] ?? ''} (${u['userId'] ?? ''})',
                      overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) {
              setState(() => _userId = v);
              _load();
            },
          )
        : null;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(children: [
          if (userPicker != null) ...[userPicker, const SizedBox(height: 8)],
          Row(children: [
            Expanded(child: dateBox('From', _from, true)),
            const SizedBox(width: 8),
            Expanded(child: dateBox('To', _to, false)),
          ]),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(children: [
        if (userPicker != null) ...[
          SizedBox(width: 260, child: userPicker),
          const SizedBox(width: 10),
        ],
        dateBox('From', _from, true),
        const SizedBox(width: 10),
        dateBox('To', _to, false),
      ]),
    );
  }

  // ── Expense card ───────────────────────────────────────────────────────────

  Widget _expenseCard(Map e) {
    final date = e['date'] != null
        ? DateFormat('dd MMM yyyy')
            .format(DateTime.parse(_datePart(e['date'] as String)))
        : '—';
    final desc = (e['description'] as String? ?? '').trim();
    final mode = (e['paymentMode'] as String? ?? 'cash').toUpperCase();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _ueBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: _ueOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.receipt_long_rounded,
              size: 18, color: _ueOrange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e['category'] ?? '—',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(
                [
                  if (e['branch']?['name'] != null) e['branch']['name'],
                  date,
                  mode,
                ].join('  ·  '),
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            if (desc.isNotEmpty)
              Text(desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ]),
        ),
        Text('₹${_ueAmt((e['amount'] ?? 0) as num)}',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: _ueGreen)),
        SizedBox(
          width: 40,
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded,
                size: 18, color: Color(0xFF9CA3AF)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                  value: 'delete',
                  child:
                      Text('Delete', style: TextStyle(color: Color(0xFFDC2626)))),
            ],
            onSelected: (v) {
              if (v == 'edit') _openForm(e);
              if (v == 'delete') _delete(e['_id']);
            },
          ),
        ),
      ]),
    );
  }
}

// ── Slide-in form ─────────────────────────────────────────────────────────────

class UserExpenseFormPanel extends StatefulWidget {
  final Map? item;
  final String? userId; // admin adding for another user
  final VoidCallback onSaved;
  const UserExpenseFormPanel(
      {super.key, this.item, this.userId, required this.onSaved});
  @override
  State<UserExpenseFormPanel> createState() => _UserExpenseFormPanelState();
}

class _UserExpenseFormPanelState extends State<UserExpenseFormPanel> {
  final _formKey = GlobalKey<FormState>();
  List _branches = [], _categories = [];
  String? _branchId, _category;
  String _mode = 'cash';
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _accent = Color(0xFF2E7D52);

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    final e = widget.item;
    if (e != null) {
      _branchId = e['branch']?['_id'];
      _category = e['category'];
      _mode = e['paymentMode'] ?? 'cash';
      _amountCtrl.text = '${e['amount'] ?? ''}';
      _descCtrl.text = e['description'] ?? '';
      if (e['date'] != null) {
        _date = DateTime.parse(_datePart(e['date'] as String));
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    final results = await Future.wait([
      ApiService.get('/branches', params: {'isActive': 'true', 'limit': '1000'}),
      ApiService.get('/expense-categories',
          params: {'isActive': 'true', 'limit': '1000'}),
    ]);
    if (!mounted) return;
    setState(() {
      _branches = results[0]['data'] ?? [];
      _categories = results[1]['data'] ?? [];
      final names = _categories.map((c) => c['name']).toList();
      if (_category != null && !names.contains(_category)) _category = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'branch': _branchId,
      'category': _category,
      'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'paymentMode': _mode,
      'description': _descCtrl.text.trim(),
      if (widget.item == null && widget.userId != null) 'user': widget.userId,
    };
    final res = widget.item == null
        ? await ApiService.post('/user-expenses', body)
        : await ApiService.put('/user-expenses/${widget.item!['_id']}', body);
    if (!mounted) return;
    showSnack(context, res['success'] == true ? 'Saved!' : res['message'],
        error: res['success'] != true);
    setState(() => _saving = false);
    if (res['success'] == true) widget.onSaved();
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: _accent),
        labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
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
      );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final today = DateTime.now();
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1B5E37), Color(0xFF1E6F5C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEdit ? 'Edit Expense' : 'Add Expense',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Text('Expense paid by you — added to your credit',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
          ),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(children: [
              DropdownButtonFormField<String>(
                key: ValueKey('cat_${_categories.length}'),
                initialValue: _category,
                isExpanded: true,
                borderRadius: BorderRadius.circular(10),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                decoration:
                    _dec('Expense Category', Icons.category_outlined),
                items: _categories
                    .map<DropdownMenuItem<String>>((c) => DropdownMenuItem(
                        value: c['name'] as String,
                        child: Text(c['name'] as String)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('br_${_branches.length}'),
                initialValue: _branchId,
                isExpanded: true,
                borderRadius: BorderRadius.circular(10),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                decoration: _dec('Branch', Icons.store_outlined),
                items: _branches
                    .map<DropdownMenuItem<String>>((b) => DropdownMenuItem(
                        value: b['_id'] as String,
                        child: Text(b['name'] as String)))
                    .toList(),
                onChanged: (v) => setState(() => _branchId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                ],
                decoration: _dec('Amount (₹)', Icons.currency_rupee_rounded),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  return n == null || n <= 0 ? 'Enter a valid amount' : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _mode,
                borderRadius: BorderRadius.circular(10),
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                decoration: _dec('Payment Mode', Icons.payments_outlined),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                ],
                onChanged: (v) => setState(() => _mode = v ?? 'cash'),
              ),
              const SizedBox(height: 12),
              DatePickerField(
                label: 'Date',
                value: _date,
                lastDate: DateTime(today.year, today.month, today.day),
                onChanged: (d) => setState(() => _date = d),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: _dec('Description', Icons.notes_rounded),
              ),
              const SizedBox(height: 24),
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
                      : Text(isEdit ? 'Update Expense' : 'Save Expense',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
