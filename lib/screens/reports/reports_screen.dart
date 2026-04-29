import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final _reports = [
    _ReportTab('Stock', 'stock', Icons.inventory_2, Colors.blue),
    _ReportTab('Attendance', 'attendance', Icons.how_to_reg, Colors.green),
    _ReportTab('Expense', 'expense', Icons.receipt_long, Colors.orange),
    _ReportTab('Payment', 'payment', Icons.payment, Colors.purple),
    _ReportTab('Transport', 'transport', Icons.local_shipping, Colors.teal),
    _ReportTab('Measurement', 'measurement', Icons.straighten, Colors.indigo),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _reports.length, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: _reports.map((r) => Tab(text: r.label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: _reports.map((r) => _ReportView(report: r)).toList(),
      ),
    );
  }
}

class _ReportTab {
  final String label, key;
  final IconData icon;
  final Color color;
  const _ReportTab(this.label, this.key, this.icon, this.color);
}

class _ReportView extends StatefulWidget {
  final _ReportTab report;
  const _ReportView({super.key, required this.report});
  @override
  State<_ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<_ReportView> {
  List _data = [];
  bool _loading = false;
  bool _fetched = false;
  DateTime? _from, _to;
  num _total = 0;

  Future<void> _load() async {
    setState(() => _loading = true);
    final params = <String, String>{};
    if (_from != null) params['from'] = _from!.toIso8601String();
    if (_to != null) params['to'] = _to!.toIso8601String();

    final res = await ApiService.get('/reports/${widget.report.key}', params: params);
    if (mounted) {
      setState(() {
        _data = res['data'] ?? [];
        _total = res['total'] ?? 0;
        _loading = false;
        _fetched = true;
      });
    }
  }

  Future<void> _export(String format) async {
    final params = <String, String>{'format': format};
    if (_from != null) params['from'] = _from!.toIso8601String();
    if (_to != null) params['to'] = _to!.toIso8601String();

    final token = await ApiService.getToken();
    final uri = Uri.parse(
        '${ApiService.baseUrl}/reports/${widget.report.key}?${Uri(queryParameters: params).query}');
    showSnack(context, 'Download started — open in browser:\n$uri');
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filter bar
      Container(
        padding: const EdgeInsets.all(12),
        color: Colors.grey.shade50,
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_from == null ? 'From Date' : DateFormat('dd MMM yy').format(_from!)),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _from ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                if (d != null) setState(() => _from = d);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_to == null ? 'To Date' : DateFormat('dd MMM yy').format(_to!)),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _to ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                if (d != null) setState(() => _to = d);
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _load, child: const Text('Go')),
        ]),
      ),
      // Export buttons
      if (_fetched)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.grey.shade100,
          child: Row(children: [
            Text('${_data.length} records${_total > 0 ? ' · Total: ₹$_total' : ''}',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.table_chart, size: 16, color: Colors.green),
              label: const Text('Excel', style: TextStyle(color: Colors.green)),
              onPressed: () => _export('excel'),
            ),
            TextButton.icon(
              icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.red),
              label: const Text('PDF', style: TextStyle(color: Colors.red)),
              onPressed: () => _export('pdf'),
            ),
          ]),
        ),
      // Data list
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !_fetched
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(widget.report.icon, size: 64, color: Colors.grey.shade200),
                      const SizedBox(height: 16),
                      const Text('Set filters and tap Go', style: TextStyle(color: Colors.grey)),
                    ]),
                  )
                : _data.isEmpty
                    ? const EmptyState(message: 'No records found')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _data.length,
                        itemBuilder: (_, i) => _ReportCard(
                          item: _data[i],
                          reportKey: widget.report.key,
                          color: widget.report.color,
                        ),
                      ),
      ),
    ]);
  }
}

class _ReportCard extends StatelessWidget {
  final Map item;
  final String reportKey;
  final Color color;
  const _ReportCard({required this.item, required this.reportKey, required this.color});

  String _formatDate(String? d) =>
      d != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(d)) : '—';

  @override
  Widget build(BuildContext context) {
    String title = '—', subtitle = '', trailing = '';
    switch (reportKey) {
      case 'stock':
        title = item['material']?['name'] ?? '—';
        subtitle = '${item['branch']?['name'] ?? '—'} · ${_formatDate(item['date'])}';
        trailing = '${item['type'] == 'in' ? '+' : '-'}${item['quantity']}';
        break;
      case 'attendance':
        title = item['employee']?['name'] ?? '—';
        subtitle = '${item['branch']?['name'] ?? '—'} · ${_formatDate(item['date'])}';
        trailing = item['status'] ?? '—';
        break;
      case 'expense':
        title = item['category'] ?? '—';
        subtitle = '${item['branch']?['name'] ?? '—'} · ${_formatDate(item['date'])}';
        trailing = '₹${item['amount']}';
        break;
      case 'payment':
        title = item['partyName'] ?? '—';
        subtitle = '${item['paymentMode']?.toUpperCase()} · ${_formatDate(item['date'])}';
        trailing = '₹${item['amount']}';
        break;
      case 'transport':
        title = '${item['vehicleNo']} · ${item['driverName']}';
        subtitle = '${item['fromLocation']?['name'] ?? '—'} → ${item['toLocation']?['name'] ?? '—'}';
        trailing = item['cost'] != null ? '₹${item['cost']}' : '—';
        break;
      case 'measurement':
        title = item['material']?['name'] ?? '—';
        subtitle = '${item['branch']?['name'] ?? '—'} · ${_formatDate(item['date'])}';
        trailing = '${item['quantity']} ${item['unit'] ?? ''}';
        break;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          radius: 18,
          child: Text(
            (title.isNotEmpty ? title[0] : '?').toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Text(trailing, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}
