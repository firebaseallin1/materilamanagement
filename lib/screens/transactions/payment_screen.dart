import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

const _kPayHdr = TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);
const _payPrimary = Color(0xFF111827);
const _payGreen = Color(0xFF16A34A);
const _payRed = Color(0xFFDC2626);

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List _items = [];
  bool _loading = true;
  String _search = '';

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
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'], error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  List get _filtered {
    if (_search.isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items.where((e) =>
      (e['partyName'] ?? '').toLowerCase().contains(q) ||
      (e['branch']?['name'] ?? '').toLowerCase().contains(q) ||
      (e['paymentMode'] ?? '').toLowerCase().contains(q),
    ).toList();
  }

  void _openForm([Map? item]) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'payment-form',
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
                child: PaymentFormPanel(
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
          backgroundColor: _payGreen,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Payment', style: TextStyle(color: Colors.white)),
        ),
        body: Column(children: [
          ScreenHeader(
            title: 'Payments',
            subtitle: 'Record and monitor financial payment transactions',
            onRefresh: _load,
            onSearchChanged: (v) => setState(() => _search = v),
            searchHint: 'Search party, branch…',
          ),
          if (!isMobile) _buildTableHeader(),
          Expanded(
            child: _loading
                ? const AppLoader()
                : _filtered.isEmpty
                    ? const EmptyState(message: 'No payments', icon: Icons.payment)
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
        SizedBox(width: 40, child: Text('#', style: _kPayHdr)),
        Expanded(flex: 2, child: Text('PARTY NAME', style: _kPayHdr)),
        Expanded(flex: 2, child: Text('BRANCH', style: _kPayHdr)),
        SizedBox(width: 80, child: Text('TYPE', style: _kPayHdr)),
        Expanded(flex: 1, child: Text('MODE', style: _kPayHdr)),
        Expanded(flex: 1, child: Text('AMOUNT', style: _kPayHdr, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('DATE', style: _kPayHdr)),
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
        final isReceived = item['type'] == 'received';
        final date = item['date'] != null
            ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
            : '—';
        final amtColor = isReceived ? _payGreen : _payRed;
        return InkWell(
          onTap: () => _openForm(item),
          hoverColor: const Color(0xFFF0FDF4),
          child: Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              SizedBox(width: 40, child: Text('${i + 1}', style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))),
              Expanded(flex: 2, child: Text(item['partyName'] ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _payPrimary))),
              Expanded(flex: 2, child: Text(item['branch']?['name'] ?? '—', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),
              SizedBox(width: 80, child: _typeBadge(item['type'] ?? '')),
              Expanded(flex: 1, child: Text((item['paymentMode'] ?? '—').toString().toUpperCase(), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
              Expanded(flex: 1, child: Text('₹${item['amount']}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: amtColor), textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text(date, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),
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
        final isReceived = item['type'] == 'received';
        final date = item['date'] != null
            ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))
            : '—';
        final amtColor = isReceived ? _payGreen : _payRed;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isReceived ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              child: Icon(isReceived ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 18, color: amtColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(item['partyName'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _payPrimary))),
                Text('₹${item['amount']}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: amtColor)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                _typeBadge(item['type'] ?? ''),
                const SizedBox(width: 8),
                Text((item['paymentMode'] ?? '—').toString().toUpperCase(), style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                const SizedBox(width: 6),
                Text('·  $date', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ]),
              const SizedBox(height: 2),
              Text(item['branch']?['name'] ?? '—', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ])),
            _actionMenu(item),
          ]),
        );
      },
    );
  }

  Widget _typeBadge(String type) {
    final isReceived = type == 'received';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isReceived ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isReceived ? 'Received' : 'Paid',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isReceived ? _payGreen : _payRed),
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
class PaymentFormPanel extends StatefulWidget {
  final Map? item;
  final VoidCallback onSaved;
  const PaymentFormPanel({super.key, this.item, required this.onSaved});
  @override
  State<PaymentFormPanel> createState() => _PaymentFormPanelState();
}

class _PaymentFormPanelState extends State<PaymentFormPanel> {
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
      _mode = e['paymentMode'] ?? 'cash';
      _type = e['type'] ?? 'received';
      _partyCtrl.text = e['partyName'] ?? '';
      _amountCtrl.text = '${e['amount'] ?? ''}';
      _refCtrl.text = e['referenceNo'] ?? '';
      _descCtrl.text = e['description'] ?? '';
      if (e['date'] != null) _date = DateTime.parse(e['date']);
    }
  }

  @override
  void dispose() {
    _partyCtrl.dispose(); _amountCtrl.dispose();
    _refCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches');
    if (mounted) setState(() => _branches = res['data'] ?? []);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'branch': _branchId,
      'partyName': _partyCtrl.text,
      'amount': double.tryParse(_amountCtrl.text) ?? 0,
      'paymentMode': _mode,
      'type': _type,
      'date': _date.toIso8601String(),
      'referenceNo': _refCtrl.text,
      'description': _descCtrl.text,
    };
    final res = widget.item == null
        ? await ApiService.post('/payments', body)
        : await ApiService.put('/payments/${widget.item!['_id']}', body);
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
          const Icon(Icons.payment_outlined, color: Colors.white70, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(isEdit ? 'Edit Payment' : 'New Payment', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600))),
          IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
      Expanded(child: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
            controller: _partyCtrl,
            decoration: const InputDecoration(labelText: 'Party Name', border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? 'Required' : null,
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
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              value: _mode,
              decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                DropdownMenuItem(value: 'online', child: Text('Online')),
                DropdownMenuItem(value: 'upi', child: Text('UPI')),
              ],
              onChanged: (v) => setState(() => _mode = v),
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'received', child: Text('Received')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
              ],
              onChanged: (v) => setState(() => _type = v),
            )),
          ]),
          const SizedBox(height: 16),
          DatePickerField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _refCtrl,
            decoration: const InputDecoration(labelText: 'Reference No', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descCtrl,
            maxLines: 2,
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
                  ? const ButtonLoader()
                  : Text(isEdit ? 'Update Payment' : 'Save Payment'),
            ),
          ),
        ]),
      )),
    ]);
  }
}
