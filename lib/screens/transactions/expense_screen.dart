import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

const _kExpHdr = TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);
const _expPrimary = Color(0xFF111827);
const _expAccent = Color(0xFFEA580C);

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});
  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List _items = [];
  bool _loading = true;
  String _search = '';

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
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'], error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  List get _filtered {
    if (_search.isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items.where((e) =>
      (e['category'] ?? '').toLowerCase().contains(q) ||
      (e['branch']?['name'] ?? '').toLowerCase().contains(q) ||
      (e['description'] ?? '').toLowerCase().contains(q),
    ).toList();
  }

  void _openForm([Map? item]) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'expense-form',
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
                child: ExpenseFormPanel(
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
    final total = _items.fold<num>(0, (s, i) => s + (i['amount'] ?? 0));
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 700;
      return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: _expAccent,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Expense', style: TextStyle(color: Colors.white)),
        ),
        body: Column(children: [
          ScreenHeader(
            title: 'Expenses',
            subtitle: 'Track and manage operational expenses',
            onRefresh: _load,
            onSearchChanged: (v) => setState(() => _search = v),
            searchHint: 'Search category, branch…',
          ),
          Container(
            color: _expAccent,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('Total: ₹${total.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          if (!isMobile) _buildTableHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const EmptyState(message: 'No expenses', icon: Icons.receipt_long)
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
        SizedBox(width: 40, child: Text('#', style: _kExpHdr)),
        Expanded(flex: 2, child: Text('CATEGORY', style: _kExpHdr)),
        Expanded(flex: 2, child: Text('BRANCH', style: _kExpHdr)),
        Expanded(flex: 1, child: Text('AMOUNT', style: _kExpHdr, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('DATE', style: _kExpHdr)),
        Expanded(flex: 3, child: Text('DESCRIPTION', style: _kExpHdr)),
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
        final date = item['date'] != null
            ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
            : '—';
        return InkWell(
          onTap: () => _openForm(item),
          hoverColor: const Color(0xFFFFF7ED),
          child: Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              SizedBox(width: 40, child: Text('${i + 1}', style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))),
              Expanded(flex: 2, child: _catBadge(item['category'] ?? '—')),
              Expanded(flex: 2, child: Text(item['branch']?['name'] ?? '—', style: const TextStyle(fontSize: 13, color: _expPrimary))),
              Expanded(flex: 1, child: Text('₹${item['amount']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _expAccent), textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text(date, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),
              Expanded(flex: 3, child: Text(item['description'] ?? '—', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              _actionMenu(item),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildMobileList() {
    final list = _filtered;
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = list[i];
        final date = item['date'] != null
            ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
            : '—';
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFFFF7ED),
              child: Icon(Icons.receipt_long, size: 18, color: _expAccent),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _catBadge(item['category'] ?? '—'),
                const Spacer(),
                Text('₹${item['amount']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _expAccent)),
              ]),
              const SizedBox(height: 4),
              Text('${item['branch']?['name'] ?? '—'}  ·  $date', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              if ((item['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(item['description'], style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ])),
            _actionMenu(item),
          ]),
        );
      },
    );
  }

  Widget _catBadge(String cat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
      child: Text(cat, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _expAccent)),
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
class ExpenseFormPanel extends StatefulWidget {
  final Map? item;
  final VoidCallback onSaved;
  const ExpenseFormPanel({super.key, this.item, required this.onSaved});
  @override
  State<ExpenseFormPanel> createState() => _ExpenseFormPanelState();
}

class _ExpenseFormPanelState extends State<ExpenseFormPanel> {
  final _formKey = GlobalKey<FormState>();
  List _branches = [];
  String? _branchId, _category;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _categories = [
    'Labour', 'Material', 'Transport', 'Food', 'Fuel', 'Maintenance', 'Miscellaneous',
  ];

  @override
  void initState() {
    super.initState();
    _loadBranches();
    if (widget.item != null) {
      final e = widget.item!;
      _branchId = e['branch']?['_id'];
      _category = _categories.contains(e['category']) ? e['category'] : null;
      _amountCtrl.text = '${e['amount'] ?? ''}';
      _descCtrl.text = e['description'] ?? '';
      if (e['date'] != null) _date = DateTime.parse(e['date']);
    }
  }

  @override
  void dispose() { _amountCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches');
    if (mounted) setState(() => _branches = res['data'] ?? []);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'branch': _branchId,
      'category': _category,
      'amount': double.tryParse(_amountCtrl.text) ?? 0,
      'date': _date.toIso8601String(),
      'description': _descCtrl.text,
    };
    final res = widget.item == null
        ? await ApiService.post('/expenses', body)
        : await ApiService.put('/expenses/${widget.item!['_id']}', body);
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
          const Icon(Icons.receipt_long_outlined, color: Colors.white70, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(isEdit ? 'Edit Expense' : 'New Expense', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600))),
          IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
      Expanded(child: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          AppDropdown<String>(
            label: 'Branch',
            value: _branchId,
            items: _branches.map<DropdownMenuItem<String>>((b) => DropdownMenuItem(value: b['_id'], child: Text(b['name']))).toList(),
            onChanged: (v) => setState(() => _branchId = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ ', border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          DatePickerField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
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
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'Update Expense' : 'Save Expense'),
            ),
          ),
        ]),
      )),
    ]);
  }
}
