import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/screen_header.dart';

const _aGreen  = Color(0xFF16A34A);
const _aRed    = Color(0xFFDC2626);
const _aPrimary = Color(0xFF1B3A27);
const _aBg     = Color(0xFFF4F6F8);
const _aBorder = Color(0xFFE5E7EB);

// ── Ledger entry ──────────────────────────────────────────────────────────────

class _LedgerEntry {
  final DateTime date;
  final String   description;
  final String   party;
  final String   mode;
  final String   category;
  final double   credit; // money IN
  final double   debit;  // money OUT
  double         balance = 0;

  _LedgerEntry({
    required this.date, required this.description,
    required this.party, required this.mode,
    required this.category,
    required this.credit, required this.debit,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AccountReportScreen extends StatelessWidget {
  const AccountReportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _aBg,
    body: Column(children: [
      ScreenHeader(title: 'Account Report', subtitle: 'Ledger by account type'),
      const Expanded(child: _AccountView()),
    ]),
  );
}

class _AccountView extends StatefulWidget {
  const _AccountView();
  @override
  State<_AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<_AccountView> {
  List _payments = [], _expenses = [], _advances = [], _branches = [];
  bool _loading = false;
  late DateTime _from, _to;
  String? _branchId;
  String _accountType = 'all'; // all | cash | cheque | online | upi
  final _searchCtrl = TextEditingController();
  String _search = '';

  static String _iso(DateTime d, {bool end = false}) => end
      ? DateTime(d.year, d.month, d.day, 23, 59, 59).toIso8601String()
      : d.toIso8601String();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to   = DateTime(now.year, now.month + 1, 0);
    _loadBranches();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches', params: {'isActive': 'true', 'limit': '1000'});
    if (mounted) setState(() => _branches = res['data'] ?? []);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final params = <String, String>{
      'from': _iso(_from), 'to': _iso(_to, end: true), 'limit': '5000',
    };
    if (_branchId != null) params['branch'] = _branchId!;
    final results = await Future.wait([
      ApiService.get('/payments', params: params),
      ApiService.get('/expenses', params: params),
      ApiService.get('/advances', params: params),
    ]);
    if (!mounted) return;
    setState(() {
      _payments = results[0]['data'] ?? [];
      _expenses = results[1]['data'] ?? [];
      _advances = results[2]['data'] ?? [];
      _loading  = false;
    });
  }

  // ── Build ledger entries ──────────────────────────────────────────────────

  List<_LedgerEntry> get _entries {
    final list = <_LedgerEntry>[];

    for (final p in _payments) {
      final mode = (p['paymentMode'] as String? ?? 'cash').toLowerCase();
      if (_accountType != 'all' && mode != _accountType) continue;
      final isCredit = (p['type'] as String? ?? '') == 'received';
      final amt = (p['amount'] as num?)?.toDouble() ?? 0;
      final cat = _catLabel(p['category'] as String? ?? 'other');
      list.add(_LedgerEntry(
        date: DateTime.parse(p['date'] as String),
        description: cat,
        party: p['partyName'] as String? ?? '—',
        mode: mode,
        category: cat,
        credit: isCredit ? amt : 0,
        debit:  isCredit ? 0 : amt,
      ));
    }

    // Expenses → cash debit (mode = cash by default)
    if (_accountType == 'all' || _accountType == 'cash') {
      for (final e in _expenses) {
        final amt = (e['amount'] as num?)?.toDouble() ?? 0;
        list.add(_LedgerEntry(
          date: DateTime.parse(e['date'] as String),
          description: 'Expense',
          party: e['category'] as String? ?? '—',
          mode: 'cash',
          category: 'Expense',
          credit: 0, debit: amt,
        ));
      }
      for (final a in _advances) {
        final amt = (a['amount'] as num?)?.toDouble() ?? 0;
        list.add(_LedgerEntry(
          date: DateTime.parse(a['date'] as String),
          description: 'Advance',
          party: (a['employee'] is Map ? a['employee']['name'] : null) ?? '—',
          mode: 'cash',
          category: 'Advance',
          credit: 0, debit: amt,
        ));
      }
    }

    // Sort by date
    list.sort((a, b) => a.date.compareTo(b.date));

    // Apply search
    final q = _search.toLowerCase();
    final filtered = q.isEmpty
        ? list
        : list.where((e) =>
            e.party.toLowerCase().contains(q) ||
            e.description.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q)).toList();

    // Running balance
    double bal = 0;
    for (final e in filtered) {
      bal += e.credit - e.debit;
      e.balance = bal;
    }
    return filtered;
  }

  double get _totalCredit => _entries.fold(0, (s, e) => s + e.credit);
  double get _totalDebit  => _entries.fold(0, (s, e) => s + e.debit);
  double get _netBalance  => _totalCredit - _totalDebit;

  static String _catLabel(String c) => switch (c) {
    'labor'       => 'Labor Payment',
    'transport'   => 'Transport Payment',
    'expense'     => 'Expense Payment',
    'measurement' => 'Measurement Payment',
    'regular'     => 'Regular Payment',
    _             => 'Payment',
  };

  static String _modeLabel(String m) => switch (m) {
    'cash'   => 'Cash',
    'cheque' => 'Cheque',
    'online' => 'Online',
    'upi'    => 'UPI',
    _        => m.toUpperCase(),
  };

  static final _dateFmt = DateFormat('dd MMM yy');
  static final _amtFmt  = NumberFormat('#,##0.00');

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Column(children: [
      _buildFilters(),
      _buildAccountTabs(),
      // Summary bar
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          _summaryChip('Credit (In)', _totalCredit, _aGreen),
          const SizedBox(width: 12),
          _summaryChip('Debit (Out)', _totalDebit, _aRed),
          const SizedBox(width: 12),
          _summaryChip(
            _netBalance >= 0 ? 'Net Balance' : 'Net Deficit',
            _netBalance.abs(),
            _netBalance >= 0 ? _aGreen : _aRed,
            bold: true,
          ),
          const Spacer(),
          Text('${entries.length} entries',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ]),
      ),
      const Divider(height: 1, color: _aBorder),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _aGreen))
            : entries.isEmpty
                ? Center(child: Text('No transactions found',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14)))
                : _buildLedger(entries),
      ),
    ]);
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Wrap(spacing: 10, runSpacing: 8, children: [
        _dateChip('From', _from, () async {
          final now = DateTime.now();
          final p = await showDatePicker(
            context: context,
            initialDate: _from, firstDate: DateTime(2020),
            lastDate: DateTime(now.year, now.month, now.day),
            builder: (c, ch) => Theme(data: Theme.of(c).copyWith(
                colorScheme: const ColorScheme.light(primary: _aGreen)), child: ch!),
          );
          if (p != null) { setState(() => _from = p); _load(); }
        }),
        _dateChip('To', _to, () async {
          final now = DateTime.now();
          final p = await showDatePicker(
            context: context,
            initialDate: _to, firstDate: DateTime(2020),
            lastDate: DateTime(now.year, now.month, now.day),
            builder: (c, ch) => Theme(data: Theme.of(c).copyWith(
                colorScheme: const ColorScheme.light(primary: _aGreen)), child: ch!),
          );
          if (p != null) { setState(() => _to = p); _load(); }
        }),
        DropdownButton<String?>(
          value: _branchId,
          hint: const Text('All Branches', style: TextStyle(fontSize: 13)),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          underline: const SizedBox(),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Branches')),
            ..._branches.map((b) => DropdownMenuItem(
              value: b['_id'] as String, child: Text(b['name'] ?? ''))),
          ],
          onChanged: (v) { setState(() => _branchId = v); _load(); },
        ),
        SizedBox(
          height: 34,
          width: 200,
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search party / type…',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF9CA3AF)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: _aBg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        _quickBtn('This Month', () {
          final now = DateTime.now();
          setState(() { _from = DateTime(now.year, now.month, 1); _to = DateTime(now.year, now.month + 1, 0); });
          _load();
        }),
        _quickBtn('This Week', () {
          final now = DateTime.now();
          final sun = now.weekday % 7;
          setState(() { _from = DateTime(now.year, now.month, now.day - sun); _to = _from.add(const Duration(days: 6)); });
          _load();
        }),
      ]),
    );
  }

  Widget _buildAccountTabs() {
    final tabs = [
      ('all', 'All Accounts', Icons.account_balance_wallet_outlined),
      ('cash', 'Cash', Icons.money_rounded),
      ('cheque', 'Cheque', Icons.description_outlined),
      ('online', 'Online', Icons.language_rounded),
      ('upi', 'UPI', Icons.qr_code_rounded),
    ];
    return Container(
      color: Colors.white,
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: tabs.map((t) {
            final active = _accountType == t.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _accountType = t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? _aPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: active ? _aPrimary : _aBorder, width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(t.$3, size: 13,
                        color: active ? Colors.white : const Color(0xFF6B7280)),
                    const SizedBox(width: 5),
                    Text(t.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                          color: active ? Colors.white : const Color(0xFF374151),
                        )),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLedger(List<_LedgerEntry> entries) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    if (isDesktop) return _desktopTable(entries);
    return _mobileList(entries);
  }

  Widget _desktopTable(List<_LedgerEntry> entries) {
    const hdr = TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280), letterSpacing: 0.3);
    return Column(children: [
      Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: const Row(children: [
          SizedBox(width: 80,  child: Text('Date',     style: hdr)),
          SizedBox(width: 10),
          Expanded(flex: 3,   child: Text('Description / Party', style: hdr)),
          SizedBox(width: 90, child: Text('Mode',      style: hdr, textAlign: TextAlign.center)),
          SizedBox(width: 100,child: Text('Credit (₹)', style: hdr, textAlign: TextAlign.right)),
          SizedBox(width: 100,child: Text('Debit (₹)',  style: hdr, textAlign: TextAlign.right)),
          SizedBox(width: 110,child: Text('Balance (₹)',style: hdr, textAlign: TextAlign.right)),
        ]),
      ),
      const Divider(height: 1, color: _aBorder),
      Expanded(
        child: ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
          itemBuilder: (_, i) {
            final e = entries[i];
            final isProfit = e.balance >= 0;
            return Container(
              color: i.isEven ? Colors.white : const Color(0xFFFAFAFA),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(children: [
                SizedBox(width: 80,
                    child: Text(_dateFmt.format(e.date),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.description,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
                    Text(e.party,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                )),
                SizedBox(width: 90,
                    child: Center(child: _modeBadge(e.mode))),
                SizedBox(width: 100,
                    child: Text(e.credit > 0 ? '₹${_amtFmt.format(e.credit)}' : '—',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: e.credit > 0 ? _aGreen : const Color(0xFFD1D5DB)))),
                SizedBox(width: 100,
                    child: Text(e.debit > 0 ? '₹${_amtFmt.format(e.debit)}' : '—',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: e.debit > 0 ? _aRed : const Color(0xFFD1D5DB)))),
                SizedBox(width: 110,
                    child: Text('₹${_amtFmt.format(e.balance.abs())}${e.balance < 0 ? ' Dr' : ' Cr'}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold,
                            color: isProfit ? _aGreen : _aRed))),
              ]),
            );
          },
        ),
      ),
      // Footer total row
      Container(
        color: const Color(0xFFF0F9F4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          const Expanded(flex: 3, child: Text('TOTAL',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _aPrimary))),
          const SizedBox(width: 90),
          SizedBox(width: 100,
              child: Text('₹${_amtFmt.format(_totalCredit)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _aGreen))),
          SizedBox(width: 100,
              child: Text('₹${_amtFmt.format(_totalDebit)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _aRed))),
          SizedBox(width: 110,
              child: Text(
                  '₹${_amtFmt.format(_netBalance.abs())}${_netBalance < 0 ? ' Dr' : ' Cr'}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold,
                      color: _netBalance >= 0 ? _aGreen : _aRed))),
        ]),
      ),
    ]);
  }

  Widget _mobileList(List<_LedgerEntry> entries) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final e = entries[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _aBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_dateFmt.format(e.date),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              const SizedBox(width: 8),
              _modeBadge(e.mode),
              const Spacer(),
              Text(
                e.balance >= 0
                    ? '+₹${_amtFmt.format(e.balance)}'
                    : '-₹${_amtFmt.format(e.balance.abs())}',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold,
                    color: e.balance >= 0 ? _aGreen : _aRed),
              ),
            ]),
            const SizedBox(height: 6),
            Text(e.description,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(e.party,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            Row(children: [
              if (e.credit > 0) ...[
                const Icon(Icons.arrow_downward_rounded, size: 13, color: _aGreen),
                const SizedBox(width: 3),
                Text('₹${_amtFmt.format(e.credit)}',
                    style: const TextStyle(fontSize: 12, color: _aGreen, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
              ],
              if (e.debit > 0) ...[
                const Icon(Icons.arrow_upward_rounded, size: 13, color: _aRed),
                const SizedBox(width: 3),
                Text('₹${_amtFmt.format(e.debit)}',
                    style: const TextStyle(fontSize: 12, color: _aRed, fontWeight: FontWeight.w600)),
              ],
            ]),
          ]),
        );
      },
    );
  }

  Widget _modeBadge(String mode) {
    final (label, color) = switch (mode) {
      'cash'   => ('Cash',   const Color(0xFF16A34A)),
      'cheque' => ('Cheque', const Color(0xFF2563EB)),
      'online' => ('Online', const Color(0xFF7C3AED)),
      'upi'    => ('UPI',    const Color(0xFFEA580C)),
      _        => (_modeLabel(mode), const Color(0xFF6B7280)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _summaryChip(String label, double value, Color color, {bool bold = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        Text('₹${_amtFmt.format(value)}',
            style: TextStyle(
                fontSize: bold ? 14 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: color)),
      ]);

  Widget _dateChip(String label, DateTime date, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: _aBorder),
            borderRadius: BorderRadius.circular(8), color: Colors.white,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: _aGreen),
            const SizedBox(width: 6),
            Text('$label: ${DateFormat('dd MMM yy').format(date)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
          ]),
        ),
      );

  Widget _quickBtn(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      foregroundColor: _aPrimary,
      backgroundColor: const Color(0xFFF0F9F4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
  );
}
