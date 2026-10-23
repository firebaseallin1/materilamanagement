import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/screen_header.dart';

const _plGreen  = Color(0xFF16A34A);
const _plRed    = Color(0xFFDC2626);
const _plPrimary = Color(0xFF1B3A27);
const _plBg     = Color(0xFFF4F6F8);
const _plBorder = Color(0xFFE5E7EB);

class ProfitLossScreen extends StatelessWidget {
  const ProfitLossScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _plBg,
    body: Column(children: [
      ScreenHeader(title: 'Profit & Loss', subtitle: 'Income vs Outgoing summary by type'),
      const Expanded(child: _PLView()),
    ]),
  );
}

class _PLView extends StatefulWidget {
  const _PLView();
  @override
  State<_PLView> createState() => _PLViewState();
}

class _PLViewState extends State<_PLView> {
  List _payments = [], _expenses = [], _advances = [], _branches = [];
  bool _loading = false;
  late DateTime _from, _to;
  String? _branchId;

  static String _iso(DateTime d, {bool endOfDay = false}) => endOfDay
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

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches', params: {'isActive': 'true', 'limit': '1000'});
    if (mounted) setState(() => _branches = res['data'] ?? []);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final params = <String, String>{
      'from': _iso(_from), 'to': _iso(_to, endOfDay: true), 'limit': '5000',
    };
    if (_branchId != null) params['branch'] = _branchId!;

    final results = await Future.wait([
      ApiService.get('/payments',  params: params),
      ApiService.get('/expenses',  params: params),
      ApiService.get('/advances',  params: params),
    ]);
    if (!mounted) return;
    setState(() {
      _payments  = results[0]['data'] ?? [];
      _expenses  = results[1]['data'] ?? [];
      _advances  = results[2]['data'] ?? [];
      _loading   = false;
    });
  }

  // ── Aggregations ──────────────────────────────────────────────────────────

  Map<String, double> get _income {
    final map = <String, double>{};
    for (final p in _payments) {
      if ((p['type'] as String? ?? '') != 'received') continue;
      final cat = _catLabel(p['category'] as String? ?? 'other');
      map[cat] = (map[cat] ?? 0) + ((p['amount'] as num?)?.toDouble() ?? 0);
    }
    return map;
  }

  Map<String, double> get _outgoing {
    final map = <String, double>{};
    // Paid payments by category
    for (final p in _payments) {
      if ((p['type'] as String? ?? '') != 'paid') continue;
      final cat = _catLabel(p['category'] as String? ?? 'other');
      map[cat] = (map[cat] ?? 0) + ((p['amount'] as num?)?.toDouble() ?? 0);
    }
    // Direct expenses
    double expTotal = 0;
    for (final e in _expenses) {
      expTotal += (e['amount'] as num?)?.toDouble() ?? 0;
    }
    if (expTotal > 0) map['Direct Expenses'] = (map['Direct Expenses'] ?? 0) + expTotal;
    // Advances
    double advTotal = 0;
    for (final a in _advances) {
      advTotal += (a['amount'] as num?)?.toDouble() ?? 0;
    }
    if (advTotal > 0) map['Advances'] = (map['Advances'] ?? 0) + advTotal;
    return map;
  }

  double get _totalIncome  => _income.values.fold(0, (s, v) => s + v);
  double get _totalOutgoing => _outgoing.values.fold(0, (s, v) => s + v);
  double get _net => _totalIncome - _totalOutgoing;

  static String _catLabel(String c) => switch (c) {
    'labor'       => 'Labor Payments',
    'transport'   => 'Transport',
    'expense'     => 'Expense Payments',
    'measurement' => 'Measurement Payments',
    'regular'     => 'Regular Payments',
    _             => 'Other',
  };

  static final _fmt = NumberFormat('#,##0.00');

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildFilters(),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _plGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(builder: (_, c) {
                  final wide = c.maxWidth >= 750;
                  return Column(children: [
                    // Summary cards
                    wide
                        ? Row(children: [
                            _summaryCard('Total Income',  _totalIncome,  _plGreen, Icons.trending_up_rounded),
                            const SizedBox(width: 12),
                            _summaryCard('Total Outgoing', _totalOutgoing, _plRed, Icons.trending_down_rounded),
                            const SizedBox(width: 12),
                            _netCard(),
                          ])
                        : Column(children: [
                            _summaryCard('Total Income',  _totalIncome,  _plGreen, Icons.trending_up_rounded),
                            const SizedBox(height: 10),
                            _summaryCard('Total Outgoing', _totalOutgoing, _plRed, Icons.trending_down_rounded),
                            const SizedBox(height: 10),
                            _netCard(),
                          ]),
                    const SizedBox(height: 24),
                    // Income & Outgoing side by side on wide
                    wide
                        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: _breakdownCard('INCOME', _income, _plGreen, Icons.arrow_downward_rounded)),
                            const SizedBox(width: 16),
                            Expanded(child: _breakdownCard('OUTGOING', _outgoing, _plRed, Icons.arrow_upward_rounded)),
                          ])
                        : Column(children: [
                            _breakdownCard('INCOME', _income, _plGreen, Icons.arrow_downward_rounded),
                            const SizedBox(height: 16),
                            _breakdownCard('OUTGOING', _outgoing, _plRed, Icons.arrow_upward_rounded),
                          ]),
                  ]);
                }),
              ),
      ),
    ]);
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Wrap(spacing: 12, runSpacing: 10, children: [
        // From date
        _dateChip('From', _from, () async {
          final now = DateTime.now();
          final p = await showDatePicker(
            context: context,
            initialDate: _from,
            firstDate: DateTime(2020),
            lastDate: DateTime(now.year, now.month, now.day),
            builder: (c, ch) => Theme(data: Theme.of(c).copyWith(
                colorScheme: const ColorScheme.light(primary: _plGreen)), child: ch!),
          );
          if (p != null) { setState(() => _from = p); _load(); }
        }),
        // To date
        _dateChip('To', _to, () async {
          final now = DateTime.now();
          final p = await showDatePicker(
            context: context,
            initialDate: _to,
            firstDate: DateTime(2020),
            lastDate: DateTime(now.year, now.month, now.day),
            builder: (c, ch) => Theme(data: Theme.of(c).copyWith(
                colorScheme: const ColorScheme.light(primary: _plGreen)), child: ch!),
          );
          if (p != null) { setState(() => _to = p); _load(); }
        }),
        // Branch
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
        // Quick ranges
        _quickBtn('This Month', () {
          final now = DateTime.now();
          setState(() {
            _from = DateTime(now.year, now.month, 1);
            _to   = DateTime(now.year, now.month + 1, 0);
          });
          _load();
        }),
        _quickBtn('This Week', () {
          final now = DateTime.now();
          final sun = now.weekday % 7;
          setState(() {
            _from = DateTime(now.year, now.month, now.day - sun);
            _to   = _from.add(const Duration(days: 6));
          });
          _load();
        }),
      ]),
    );
  }

  Widget _dateChip(String label, DateTime date, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: _plBorder),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: _plGreen),
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
      foregroundColor: _plPrimary,
      backgroundColor: const Color(0xFFF0F9F4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
  );

  Widget _summaryCard(String title, double value, Color color, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _plBorder),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 4),
              Text('₹${_fmt.format(value)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ])),
          ]),
        ),
      );

  Widget _netCard() {
    final profit = _net >= 0;
    final color  = profit ? _plGreen : _plRed;
    final label  = profit ? 'Net Profit' : 'Net Loss';
    final icon   = profit ? Icons.thumb_up_alt_rounded : Icons.thumb_down_alt_rounded;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: profit ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('₹${_fmt.format(_net.abs())}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ])),
        ]),
      ),
    );
  }

  Widget _breakdownCard(String title, Map<String, double> data, Color color, IconData icon) {
    final total = data.values.fold(0.0, (s, v) => s + v);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _plBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            const Spacer(),
            Text('₹${_fmt.format(total)}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
        // Rows
        if (data.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(child: Text('No data', style: TextStyle(color: Colors.grey.shade400, fontSize: 13))),
          )
        else
          ...data.entries.map((e) {
            final pct = total > 0 ? (e.value / total * 100) : 0.0;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(e.key,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
                    Text('₹${_fmt.format(e.value)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${pct.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? e.value / total : 0,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 4,
                    ),
                  ),
                ]),
              ),
              if (e.key != data.keys.last) const Divider(height: 1, color: _plBorder),
            ]);
          }),
        // Total row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: Row(children: [
            const Text('TOTAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
            const Spacer(),
            Text('₹${_fmt.format(total)}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      ]),
    );
  }
}
