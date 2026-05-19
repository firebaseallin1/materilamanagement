import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

class OutstandingScreen extends StatefulWidget {
  const OutstandingScreen({super.key});
  @override
  State<OutstandingScreen> createState() => _OutstandingScreenState();
}

class _OutstandingScreenState extends State<OutstandingScreen> {
  List _items = [];
  List _branches = [];
  bool _loading = true;
  String _search = '';
  String? _filterBranchId;
  String? _error;

  static const _red  = Color(0xFFDC2626);
  static const _safe = Color(0xFF16A34A);

  List get _filtered {
    final q = _search.toLowerCase();
    return _items.where((e) {
      final name  = (e['name']  ?? '').toString().toLowerCase();
      final code  = (e['empCode'] ?? '').toString().toLowerCase();
      final desig = (e['designation'] ?? '').toString().toLowerCase();
      final matchSearch = q.isEmpty || name.contains(q) || code.contains(q) || desig.contains(q);
      final matchBranch = _filterBranchId == null ||
          (e['branch'] is Map && e['branch']['_id'] == _filterBranchId);
      return matchSearch && matchBranch;
    }).toList();
  }

  double get _grandAdvance =>
      _filtered.fold(0.0, (s, e) => s + ((e['totalAdvance'] ?? 0) as num).toDouble());
  double get _grandPaid =>
      _filtered.fold(0.0, (s, e) => s + ((e['totalPaid'] ?? 0) as num).toDouble());
  double get _grandOutstanding =>
      _filtered.fold(0.0, (s, e) => s + ((e['outstandingBalance'] ?? 0) as num).toDouble());

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _load();
  }

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches');
    if (mounted) setState(() => _branches = res['data'] ?? []);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final params = <String, String>{};
    if (_filterBranchId != null) params['branch'] = _filterBranchId!;
    if (_search.isNotEmpty) params['search'] = _search;
    final res = await ApiService.get('/outstanding', params: params);
    if (mounted) {
      setState(() {
        if (res['success'] == true) {
          _items = res['data'] ?? [];
        } else {
          final msg = (res['message'] ?? '').toString().toLowerCase();
          if (msg.contains('not found') || msg.contains('no data')) {
            _items = [];
          } else {
            _error = res['message'] ?? 'Something went wrong';
          }
        }
        _loading = false;
      });
    }
  }

  void _openPay(Map emp) {
    final sw = MediaQuery.of(context).size.width;
    final panelWidth = sw > 900 ? sw * 0.36 : sw * 0.92;
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
            child: _PayFormPanel(employee: emp, branches: _branches, onSaved: _load),
          ),
        ),
      ),
      transitionBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<AuthService>().isAdmin;
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 800;
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(children: [
          ScreenHeader(
            title: 'Outstanding',
            subtitle: isAdmin
                ? 'Advance outstanding for all employees'
                : 'Outstanding for your employees',
            onRefresh: _load,
            onSearchChanged: (v) => setState(() { _search = v; _load(); }),
            searchHint: 'Search employee...',
          ),
          _buildToolbar(isDesktop),
          if (!_loading && _filtered.isNotEmpty) _buildSummaryStrip(),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: _loading
                ? const AppLoader(message: 'Loading outstanding...')
                : _error != null
                    ? _buildError()
                    : _filtered.isEmpty
                        ? _buildEmpty()
                        : isDesktop
                            ? _buildTable()
                            : _buildMobileList(),
          ),
        ]),
      );
    });
  }

  Widget _buildToolbar(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 12, vertical: 10),
      child: Row(children: [
        Container(
          height: 34,
          constraints: const BoxConstraints(minWidth: 130, maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _filterBranchId,
              hint: const Text('All Branches', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              isDense: true,
              isExpanded: true,
              icon: const Icon(Icons.expand_more_rounded, size: 15, color: Color(0xFF6B7280)),
              style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
              borderRadius: BorderRadius.circular(8),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Branches')),
                ..._branches.map((b) => DropdownMenuItem(
                  value: b['_id'] as String,
                  child: Text(b['name'] as String? ?? '', overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (v) => setState(() { _filterBranchId = v; _load(); }),
            ),
          ),
        ),
        if (_filterBranchId != null) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() { _filterBranchId = null; _load(); }),
            child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9CA3AF)),
          ),
        ],
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
          child: Text('${_filtered.length} employees',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ),
      ]),
    );
  }

  Widget _buildSummaryStrip() {
    final fmt = NumberFormat('#,##0.00');
    final hasOutstanding = _grandOutstanding > 0;
    return Container(
      color: hasOutstanding ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
        // Advance
        _summaryChip('Advance', _grandAdvance, const Color(0xFF2563EB), fmt),
        const SizedBox(width: 10),
        // Paid
        _summaryChip('Paid', _grandPaid, _safe, fmt),
        const SizedBox(width: 10),
        // Outstanding
        _summaryChip('Pending', _grandOutstanding, hasOutstanding ? _red : _safe, fmt),
      ]),
    );
  }

  Widget _summaryChip(String label, double value, Color color, NumberFormat fmt) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.currency_rupee_rounded, size: 11, color: color),
            Expanded(
              child: Text(fmt.format(value),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildTable() {
    final fmt = NumberFormat('#,##0.00');
    final rows = _filtered;
    return Column(children: [
      Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: const Row(children: [
          SizedBox(width: 28, child: Text('#', style: _kHdr)),
          SizedBox(width: 10),
          Expanded(flex: 4, child: Text('Employee', style: _kHdr)),
          Expanded(flex: 3, child: Text('Branch', style: _kHdr)),
          Expanded(flex: 2, child: Text('Advances', style: _kHdr, textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text('Total Advance', style: _kHdr, textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('Total Paid', style: _kHdr, textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('Pending', style: _kHdr, textAlign: TextAlign.right)),
          SizedBox(width: 72),
        ]),
      ),
      const Divider(height: 1, color: Color(0xFFE5E7EB)),
      Expanded(
        child: ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final emp = rows[i];
            final balance  = ((emp['outstandingBalance'] ?? 0) as num).toDouble();
            final total    = ((emp['totalAdvance'] ?? 0) as num).toDouble();
            final paid     = ((emp['totalPaid'] ?? 0) as num).toDouble();
            final count    = (emp['advanceCount'] ?? 0) as int;
            final hasBalance = balance > 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
              child: Row(children: [
                SizedBox(width: 28,
                    child: Text('${i + 1}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))),
                const SizedBox(width: 10),
                Expanded(flex: 4, child: Row(children: [
                  _EmpAvatar(name: emp['name'] ?? '', index: i, photo: emp['photo'] as String?),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(emp['name'] ?? '—',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: Color(0xFF111827)),
                        overflow: TextOverflow.ellipsis),
                    if ((emp['empCode'] ?? '').toString().isNotEmpty)
                      Text(emp['empCode'],
                          style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                    Text(emp['designation'] ?? '',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        overflow: TextOverflow.ellipsis),
                  ])),
                ])),
                Expanded(flex: 3, child: Text(
                    emp['branch'] is Map ? (emp['branch']['name'] ?? '—') : '—',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                    overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: count > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$count',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: count > 0 ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                      )),
                ))),
                Expanded(flex: 3, child: Text('₹${fmt.format(total)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF374151)))),
                Expanded(flex: 3, child: Text('₹${fmt.format(paid)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF059669)))),
                Expanded(flex: 3, child: Text('₹${fmt.format(balance)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: hasBalance ? _red : _safe,
                    ))),
                SizedBox(
                  width: 72,
                  child: hasBalance
                      ? TextButton(
                          onPressed: () => _openPay(emp),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFF0FDF4),
                            foregroundColor: _safe,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        )
                      : const SizedBox.shrink(),
                ),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildMobileList() {
    final fmt = NumberFormat('#,##0.00');
    final rows = _filtered;
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final emp = rows[i];
        final balance  = ((emp['outstandingBalance'] ?? 0) as num).toDouble();
        final total    = ((emp['totalAdvance'] ?? 0) as num).toDouble();
        final paid     = ((emp['totalPaid'] ?? 0) as num).toDouble();
        final count    = (emp['advanceCount'] ?? 0) as int;
        final hasBalance = balance > 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _EmpAvatar(name: emp['name'] ?? '', index: i, photo: emp['photo'] as String?),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(emp['name'] ?? '—',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: Color(0xFF111827))),
                if ((emp['empCode'] ?? '').toString().isNotEmpty)
                  Text(emp['empCode'],
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                Text(emp['designation'] ?? '',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                if (emp['branch'] is Map && (emp['branch']['name'] ?? '').isNotEmpty)
                  Row(children: [
                    const Icon(Icons.store_outlined, size: 11, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 3),
                    Text(emp['branch']['name'],
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${fmt.format(balance)}',
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: hasBalance ? _red : _safe,
                    )),
                Text(hasBalance ? 'Pending' : 'Cleared',
                    style: TextStyle(fontSize: 10, color: hasBalance ? _red : _safe)),
              ]),
            ]),
            const SizedBox(height: 10),
            // Stats row
            Row(children: [
              _mobileStatChip('$count advance${count == 1 ? '' : 's'}', const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              _mobileStatChip('Advance ₹${fmt.format(total)}', const Color(0xFF6B7280)),
              const SizedBox(width: 8),
              _mobileStatChip('Paid ₹${fmt.format(paid)}', _safe),
            ]),
            if (hasBalance) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openPay(emp),
                  icon: const Icon(Icons.payments_outlined, size: 15),
                  label: const Text('Record Payment', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _safe,
                    side: const BorderSide(color: Color(0xFF16A34A)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ]),
        );
      },
    );
  }

  Widget _mobileStatChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, color: color)),
  );

  Widget _buildError() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: Color(0xFF374151), fontSize: 14)),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
    ]),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 64, height: 64,
        decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.account_balance_outlined, size: 28, color: Color(0xFF9CA3AF))),
      const SizedBox(height: 14),
      const Text('No outstanding records',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
      const SizedBox(height: 4),
      const Text('Add employees and record advances to track outstanding.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
    ]),
  );
}

// ─── Pay Form Panel ───────────────────────────────────────────────────────────

class _PayFormPanel extends StatefulWidget {
  final Map employee;
  final List branches;
  final VoidCallback onSaved;
  const _PayFormPanel({
    required this.employee,
    required this.branches,
    required this.onSaved,
  });

  @override
  State<_PayFormPanel> createState() => _PayFormPanelState();
}

class _PayFormPanelState extends State<_PayFormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  String _paymentMode = 'cash';
  String? _branchId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _primary = Color(0xFF1B3A27);
  static const _accent  = Color(0xFF16A34A);
  static const _gradient2 = Color(0xFF1E6F5C);

  @override
  void initState() {
    super.initState();
    final b = widget.employee['branch'];
    _branchId = b is Map ? b['_id'] as String? : (b is String ? b : null);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  double get _outstanding =>
      ((widget.employee['outstandingBalance'] ?? 0) as num).toDouble();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final body = <String, dynamic>{
      'employee': widget.employee['_id'],
      'branch': _branchId,
      'partyName': widget.employee['name'],
      'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
      'paymentMode': _paymentMode,
      'date': _date.toIso8601String(),
      'type': 'paid',
      'referenceNo': _referenceCtrl.text.trim(),
      'description': _remarksCtrl.text.trim(),
    };

    final res = await ApiService.post('/payments', body);
    if (mounted) {
      setState(() => _saving = false);
      showSnack(context,
          res['success'] == true ? 'Payment recorded successfully!' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) {
        Navigator.pop(context);
        widget.onSaved();
      }
    }
  }

  InputDecoration _dec(String label, IconData icon, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, size: 18, color: _accent),
    labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
    filled: true,
    fillColor: const Color(0xFFF7F9F8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDE3E0))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accent, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final empName = widget.employee['name'] ?? '';
    final empCode = (widget.employee['empCode'] ?? '').toString();

    return Column(children: [
      // Drag handle
      const SizedBox(height: 10),
      Container(
        width: 36, height: 4,
        decoration: BoxDecoration(
            color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(height: 2),

      // Header card
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_primary, _gradient2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.payments_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Record Payment',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                empCode.isNotEmpty ? '$empName ($empCode)' : empName,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.close, color: Colors.white70, size: 16),
            ),
          ),
        ]),
      ),

      // Outstanding badge
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet_outlined,
                size: 16, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            const Text('Pending Balance',
                style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            const Spacer(),
            Text('₹${fmt.format(_outstanding)}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626))),
          ]),
        ),
      ),

      // Form
      Expanded(
        child: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), children: [

            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec('Payment Amount', Icons.currency_rupee_rounded,
                  hint: 'e.g. 5000'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Amount is required';
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'Enter a valid amount';
                if (n > _outstanding) return 'Cannot exceed pending balance';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Payment mode
            DropdownButtonFormField<String>(
              value: _paymentMode,
              decoration: _dec('Payment Mode', Icons.credit_card_outlined),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
              borderRadius: BorderRadius.circular(10),
              items: const [
                DropdownMenuItem(value: 'cash',   child: Text('Cash')),
                DropdownMenuItem(value: 'online', child: Text('Online Transfer')),
                DropdownMenuItem(value: 'upi',    child: Text('UPI')),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
              ],
              onChanged: (v) => setState(() => _paymentMode = v!),
            ),
            const SizedBox(height: 14),

            // Date
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: _dec('Payment Date', Icons.calendar_today_outlined),
                child: Text(
                  DateFormat('dd MMM yyyy').format(_date),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Branch
            DropdownButtonFormField<String>(
              value: _branchId,
              decoration: _dec('Branch', Icons.store_outlined),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
              borderRadius: BorderRadius.circular(10),
              hint: const Text('Select Branch'),
              isExpanded: true,
              items: widget.branches.map<DropdownMenuItem<String>>((b) =>
                DropdownMenuItem(
                    value: b['_id'] as String,
                    child: Text(b['name'] ?? ''))).toList(),
              onChanged: (v) => setState(() => _branchId = v),
              validator: (v) => v == null ? 'Branch is required' : null,
            ),
            const SizedBox(height: 14),

            // Reference
            TextFormField(
              controller: _referenceCtrl,
              decoration: _dec('Reference / Transaction No', Icons.tag_rounded,
                  hint: 'Optional'),
            ),
            const SizedBox(height: 14),

            // Remarks
            TextFormField(
              controller: _remarksCtrl,
              maxLines: 2,
              decoration: _dec('Remarks', Icons.notes_rounded, hint: 'Optional'),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFDDE3E0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _saving
                        ? null
                        : const LinearGradient(
                            colors: [_primary, _gradient2],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight),
                    color: _saving ? Colors.grey.shade300 : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const ButtonLoader()
                        : const Text('Record Payment',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    ]);
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _EmpAvatar extends StatelessWidget {
  final String name;
  final int index;
  final String? photo;
  const _EmpAvatar({required this.name, required this.index, this.photo});

  static const _colors = [
    Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFF059669),
    Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF0891B2),
  ];

  @override
  Widget build(BuildContext context) {
    if (photo != null && photo!.isNotEmpty) {
      try {
        final bytes = base64Decode(photo!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(bytes, width: 38, height: 38, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    final color = _colors[index % _colors.length];
    final init = name.trim().isEmpty ? '?' :
        (name.trim().split(RegExp(r'\s+')).length >= 2
            ? '${name.trim().split(RegExp(r'\s+'))[0][0]}${name.trim().split(RegExp(r'\s+'))[1][0]}'.toUpperCase()
            : name.trim().substring(0, name.trim().length.clamp(0, 2)).toUpperCase());
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: Text(init,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
    );
  }
}

const _kHdr = TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);
