import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../transactions/stock_screen.dart';
import '../transactions/attendance_screen.dart';
import '../transactions/advance_screen.dart';
import '../transactions/expense_screen.dart';
import '../transactions/payment_screen.dart';
import '../transactions/transport_screen.dart'
    hide MeasurementScreen, MeasurementFormScreen;
import '../transactions/measurement_screen.dart';
import '../masters/location_screen.dart';
import '../masters/branch_screen.dart';
import '../masters/category_screen.dart';
import '../masters/expense_category_screen.dart';
import '../masters/user_category_screen.dart';
import '../masters/user_screen.dart';
import '../masters/employee_screen.dart';
import '../transactions/outstanding_screen.dart';
import '../reports/reports_screen.dart';

const _kSidebar = Color(0xFF1B3A27);
const _kSidebarActive = Color(0xFF2E7D52);
const _kBg = Color(0xFFF4F6F8);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _summary;
  bool _loading = true;
  int _navIndex = 0;
  int _refreshCount = 0;
  late final AnimationController _ctrl;
  late final Animation<double> _fadeHeader;
  late final Animation<Offset> _slideHeader;
  late final Animation<double> _fadeCharts;
  late final Animation<double> _fadeTable;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _fadeHeader = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.0, 0.35, curve: Curves.easeOut));
    _slideHeader = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));
    _fadeCharts = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.4, 0.75, curve: Curves.easeOut));
    _fadeTable = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.6, 1.0, curve: Curves.easeOut));
    _loadDashboard();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() { _loading = true; _refreshCount++; });
    _ctrl.reset();
    final res = await ApiService.get('/dashboard');
    if (mounted) {
      setState(() {
        if (res['success'] == true) _summary = res['data'];
        _loading = false;
      });
      _ctrl.forward();
    }
  }

  void _navigate(int index, Widget? screen) {
    setState(() => _navIndex = index);
    if (screen != null) {
      Navigator.push(context, _slide(screen));
    }
  }

  Widget _accessDenied() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.lock_outline_rounded,
                size: 32, color: Color(0xFFDC2626)),
          ),
          const SizedBox(height: 16),
          const Text('Access Denied',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 6),
          const Text("You don't have permission to view this screen.",
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          const Text('Contact your administrator to request access.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => setState(() => _navIndex = 0),
            icon: const Icon(Icons.dashboard_outlined, size: 16),
            label: const Text('Go to Dashboard'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kSidebar,
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 900;
      return Scaffold(
        backgroundColor: _kBg,
        appBar: isDesktop ? null : _mobileAppBar(),
        drawer: isDesktop ? null : _buildDrawer(),
        body: isDesktop
            ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Sidebar(
                    selectedIndex: _navIndex,
                    onNavigate: _navigate,
                    auth: context.read<AuthService>()),
                Expanded(child: _buildContent(isDesktop)),
              ])
            : _buildContent(false),
      );
    });
  }

  PreferredSizeWidget _mobileAppBar() {
    final auth = context.read<AuthService>();
    return AppBar(
      backgroundColor: _kSidebar,
      title: const Text('MMS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboard),
        PopupMenuButton<String>(
          icon: CircleAvatar(
            radius: 14,
            backgroundColor: _kSidebarActive,
            child: Text(
              _initials(auth.userName),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
          itemBuilder: (_) => [
            PopupMenuItem(
                enabled: false,
                child: Text(auth.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            PopupMenuItem(
                enabled: false,
                child: Text(auth.userRole.toUpperCase(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey))),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'logout', child: Text('Logout')),
          ],
          onSelected: (v) {
            if (v == 'logout') auth.logout();
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _kSidebar,
      child: _SidebarContent(
        selectedIndex: _navIndex,
        onNavigate: (i, s) {
          Navigator.pop(context);
          _navigate(i, s);
        },
        auth: context.read<AuthService>(),
      ),
    );
  }

  Widget _buildContent(bool isDesktop) {
    final auth = context.read<AuthService>();
    switch (_navIndex) {
      case 1:
        return auth.canAccess('attendance')
            ? const AttendanceScreen()
            : _accessDenied();
      case 14:
        return auth.canAccess('advances')
            ? const AdvanceScreen()
            : _accessDenied();
      case 2:
        return auth.canAccess('stock') ? const StockScreen() : _accessDenied();
      case 3:
        return auth.canAccess('transport')
            ? const TransportScreen()
            : _accessDenied();
      case 17:
        return auth.canAccess('measurements')
            ? const MeasurementScreen()
            : _accessDenied();
      case 4:
        return auth.canAccess('expenses')
            ? const ExpenseScreen()
            : _accessDenied();
      case 5:
        return auth.canAccess('payments')
            ? const PaymentScreen()
            : _accessDenied();
      case 6:
        return auth.canAccess('location')
            ? const LocationScreen()
            : _accessDenied();
      case 7:
        return auth.canAccess('materials')
            ? const MaterialScreen()
            : _accessDenied();
      case 8:
        return auth.canAccess('users') ? const UserScreen() : _accessDenied();
      case 11:
        return auth.canAccess('category')
            ? const CategoryScreen()
            : _accessDenied();
      case 12:
        return auth.canAccess('expense_cat')
            ? const ExpenseCategoryScreen()
            : _accessDenied();
      case 13:
        return auth.canAccess('user_cat')
            ? const UserCategoryScreen()
            : _accessDenied();
      case 9:
        return auth.canAccess('reports')
            ? const ReportsScreen()
            : _accessDenied();
      case 10:
        return auth.canAccess('branches')
            ? const BranchScreen()
            : _accessDenied();
      case 15:
        return auth.canAccess('employees')
            ? const EmployeeScreen()
            : _accessDenied();
      case 16:
        return auth.canAccess('outstanding')
            ? const OutstandingScreen()
            : _accessDenied();
    }

    if (_loading) {
      return _DashboardShimmer(isDesktop: isDesktop);
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: _kSidebarActive,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 28 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          SlideTransition(
            position: _slideHeader,
            child: FadeTransition(
              opacity: _fadeHeader,
              child: _DashHeader(
                isDesktop: isDesktop,
                onRefresh: _loadDashboard,
                auth: context.read<AuthService>(),
                isLoading: _loading,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Today's real-time overview cards
          _TodaySection(key: ValueKey(_refreshCount)),
          const SizedBox(height: 24),

          // Charts
          FadeTransition(
            opacity: _fadeCharts,
            child: _buildChartsRow(context, isDesktop),
          ),
          const SizedBox(height: 24),

          // Location table
          FadeTransition(
            opacity: _fadeTable,
            child: _LocationTable(
                locations:
                    _summary?['locationStock'] as List? ?? _mockLocations),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _buildChartsRow(BuildContext context, bool isDesktop) {
    const attendanceCard = _AttendanceBarChartCard();
    final donutCard = _DonutChartCard(
        categoryData: _summary?['categoryStock'] as List? ?? _mockCategoryData);

    if (isDesktop) {
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 55, child: attendanceCard),
          const SizedBox(width: 16),
          Expanded(flex: 45, child: donutCard),
        ]),
      );
    }
    return Column(
        children: [attendanceCard, const SizedBox(height: 16), donutCard]);
  }


  static const _mockCategoryData = [
    {'name': 'Raw', 'value': 45},
    {'name': 'Processed', 'value': 20},
    {'name': 'Finished', 'value': 25},
    {'name': 'Electrical', 'value': 10},
  ];

  static const _mockLocations = [
    {
      'name': 'Coimbatore',
      'totalUnits': 4820,
      'materialCount': 68,
      'inward': 1240,
      'outward': 680,
      'status': 'Near full'
    },
    {
      'name': 'Erode',
      'totalUnits': 4820,
      'materialCount': 68,
      'inward': 1240,
      'outward': 680,
      'status': 'Good'
    },
    {
      'name': 'Chennai',
      'totalUnits': 4820,
      'materialCount': 68,
      'inward': 1240,
      'outward': 680,
      'status': 'Low Space'
    },
    {
      'name': 'Kerala',
      'totalUnits': 4820,
      'materialCount': 68,
      'inward': 1240,
      'outward': 680,
      'status': 'Near full'
    },
  ];
}

// ─── Today's overview section ────────────────────────────────────────────────

class _TodaySection extends StatefulWidget {
  const _TodaySection({super.key});
  @override
  State<_TodaySection> createState() => _TodaySectionState();
}

class _TodaySectionState extends State<_TodaySection> {
  List _payments = [];
  List _stocks = [];
  List _transports = [];
  List _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 6));
    final fromStr = DateTime(from.year, from.month, from.day).toIso8601String();
    final toStr =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
    final p = {'from': fromStr, 'to': toStr};
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.get('/payments', params: p),
      ApiService.get('/stocks', params: p),
      ApiService.get('/transports', params: p),
      ApiService.get('/expenses', params: p),
    ]);
    if (mounted) {
      setState(() {
        _payments = results[0]['data'] ?? [];
        _stocks = results[1]['data'] ?? [];
        _transports = results[2]['data'] ?? [];
        _expenses = results[3]['data'] ?? [];
        _loading = false;
      });
    }
  }

  double get _payTotal => _payments.fold(
      0.0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
  double get _expTotal => _expenses.fold(
      0.0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
  double get _stockQty => _stocks.fold(
      0.0, (s, r) => s + ((r['quantity'] as num?)?.toDouble() ?? 0));
  double get _tripCost => _transports.fold(
      0.0, (s, r) => s + ((r['cost'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (_loading) {
      return const _CardShimmer();
    }

    final cards = [
      _TodayCardData('Payments', _payments.length, '₹${_dashFmt(_payTotal)}',
          Icons.payment_outlined, const Color(0xFF1B3A27)),
      _TodayCardData(
          'Material Stock',
          _stocks.length,
          '${_dashQty(_stockQty)} units',
          Icons.inventory_2_outlined,
          const Color(0xFF1565C0)),
      _TodayCardData(
          'Transport',
          _transports.length,
          '₹${_dashFmt(_tripCost)} cost',
          Icons.local_shipping_outlined,
          const Color(0xFFF57C00)),
      _TodayCardData('Expenses', _expenses.length, '₹${_dashFmt(_expTotal)}',
          Icons.receipt_long_outlined, const Color(0xFFDC2626)),
    ];

    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 6));
    final weekLabel =
        '${DateFormat('dd MMM').format(weekStart)} – ${DateFormat('dd MMM yyyy').format(now)}';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('This Week',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827))),
        const Spacer(),
        Text(weekLabel,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(width: 8),
        InkWell(
          onTap: _load,
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child:
                Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF6B7280)),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      if (isMobile)
        Column(children: [
          Row(children: [
            Expanded(child: _buildCard(context, cards[0])),
            const SizedBox(width: 10),
            Expanded(child: _buildCard(context, cards[1])),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildCard(context, cards[2])),
            const SizedBox(width: 10),
            Expanded(child: _buildCard(context, cards[3])),
          ]),
        ])
      else
        Row(children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(child: _buildCard(context, cards[i])),
            if (i < cards.length - 1) const SizedBox(width: 12),
          ],
        ]),
    ]);
  }

  Widget _buildCard(BuildContext ctx, _TodayCardData d) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _showDetail(ctx, d),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: d.color, width: 3)),
            //  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Icon(d.icon, size: 18, color: d.color),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: d.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${d.count}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: d.color),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(d.sub,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            Row(children: [
              Text(d.title,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              const Spacer(),
              Text('View →',
                  style: TextStyle(
                      fontSize: 11,
                      color: d.color,
                      fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showDetail(BuildContext ctx, _TodayCardData d) {
    List data;
    List<String> colLabels;
    List<double> colWidths;
    List<List<Widget>> Function(List) rowCells;

    Widget serialW(int i) => Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6)),
          alignment: Alignment.center,
          child: Text('${i + 1}',
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280))));

    Widget dateW(dynamic v) {
      String label = '—';
      if (v != null) {
        try {
          label = DateFormat('dd MMM yy, h:mm a')
              .format(DateTime.parse(v.toString()).toLocal());
        } catch (_) { label = v.toString(); }
      }
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFF9CA3AF)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      ]);
    }

    switch (d.title) {
      case 'Payments':
        data = _payments;
        colLabels = const ['#', 'Party', 'Amount', 'Mode', 'Type', 'Description', 'Date'];
        colWidths = const [36, 130, 95, 90, 80, 160, 145];
        rowCells = (list) => List.generate(list.length, (i) {
          final r = list[i];
          return [
            serialW(i),
            Text(r['partyName'] ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            _amtBadge('₹${_dashFmt((r['amount'] as num?)?.toDouble() ?? 0)}',
                const Color(0xFF1B3A27)),
            _modeBadge((r['paymentMode'] ?? '—').toString().toUpperCase()),
            _badge(r['type'] ?? ''),
            Text(r['description'] ?? '—',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            dateW(r['createdAt'] ?? r['date']),
          ];
        });
        break;

      case 'Material Stock':
        data = _stocks;
        colLabels = const ['#', 'Material', 'Branch', 'Type', 'Quantity', 'Remarks', 'Date'];
        colWidths = const [36, 140, 110, 75, 95, 155, 145];
        rowCells = (list) => List.generate(list.length, (i) {
          final r = list[i];
          return [
            serialW(i),
            Text(r['material']?['name'] ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(r['branch']?['name'] ?? '—',
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
            _badge(r['type'] ?? ''),
            _amtBadge(_dashQty((r['quantity'] as num?)?.toDouble() ?? 0),
                const Color(0xFF1565C0)),
            Text(r['remarks'] ?? '—',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            dateW(r['createdAt'] ?? r['date']),
          ];
        });
        break;

      case 'Transport':
        data = _transports;
        colLabels = const ['#', 'Vehicle No', 'Driver', 'From', 'To', 'Cost', 'Date'];
        colWidths = const [36, 105, 120, 115, 115, 90, 145];
        rowCells = (list) => List.generate(list.length, (i) {
          final r = list[i];
          return [
            serialW(i),
            Text(r['vehicleNo'] ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(r['driverName'] ?? '—',
                style: const TextStyle(fontSize: 12)),
            Text(r['fromBranch']?['name'] ?? '—',
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
            Text(r['toBranch']?['name'] ?? '—',
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
            r['cost'] != null
                ? _amtBadge('₹${_dashFmt((r['cost'] as num).toDouble())}',
                    const Color(0xFFF57C00))
                : const Text('—', style: TextStyle(color: Color(0xFF9CA3AF))),
            dateW(r['createdAt'] ?? r['date']),
          ];
        });
        break;

      default: // Expenses
        data = _expenses;
        colLabels = const ['#', 'Category', 'Amount', 'Branch', 'Description', 'Date'];
        colWidths = const [36, 120, 95, 115, 165, 145];
        rowCells = (list) => List.generate(list.length, (i) {
          final r = list[i];
          return [
            serialW(i),
            Text(r['category'] ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            _amtBadge('₹${_dashFmt((r['amount'] as num?)?.toDouble() ?? 0)}',
                const Color(0xFFDC2626)),
            Text(r['branch']?['name'] ?? '—',
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
            Text(r['description'] ?? '—',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            dateW(r['createdAt'] ?? r['date']),
          ];
        });
    }

    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 6));
    final weekLabel =
        '${DateFormat('dd MMM').format(weekStart)} – ${DateFormat('dd MMM yyyy').format(now)}';
    final totalW = colWidths.fold(0.0, (s, w) => s + w);
    final hCtrl = ScrollController();
    const hPad = 12.0;

    Widget buildHeader() => Container(
          color: const Color(0xFFF8FAFC),
          child: SingleChildScrollView(
            controller: hCtrl,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: totalW + hPad * 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: hPad),
                child: Row(
                  children: List.generate(colLabels.length, (i) => SizedBox(
                    width: colWidths[i],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(colLabels[i],
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280), letterSpacing: 0.4)),
                    ),
                  )),
                ),
              ),
            ),
          ),
        );

    Widget buildBody() => Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              controller: hCtrl,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: totalW + hPad * 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: hPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(rowCells(data).length, (i) {
                      final cells = rowCells(data)[i];
                      return Container(
                        color: i.isEven ? Colors.white : const Color(0xFFFAFAFB),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(cells.length, (j) => SizedBox(
                            width: colWidths[j],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: cells[j],
                            ),
                          )),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        );

    showDialog(
      context: ctx,
      barrierColor: Colors.black45,
      builder: (dctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Gradient header ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [d.color, d.color.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(d.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(weekLabel,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${data.length} records',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => Navigator.pop(dctx),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),

            // ── Table: fixed header + scrollable body ────────────────────
            if (data.isEmpty)
              const Padding(
                padding: EdgeInsets.all(52),
                child: Column(children: [
                  Icon(Icons.inbox_outlined, size: 44, color: Color(0xFFD1D5DB)),
                  SizedBox(height: 12),
                  Text('No records this week',
                      style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                ]),
              )
            else
              SizedBox(
                height: 420,
                child: Column(children: [
                  buildHeader(),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  buildBody(),
                ]),
              ),
          ]),
        ),
      ),
    ).then((_) => hCtrl.dispose());
  }

  Widget _badge(String type) {
    final isPos = type == 'in' || type == 'received' || type == 'inside';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPos ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(type.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color:
                  isPos ? const Color(0xFF166534) : const Color(0xFFDC2626))),
    );
  }

  Widget _amtBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _modeBadge(String mode) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9F4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD1FAE5)),
        ),
        child: Text(mode,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF065F46))),
      );
}

class _TodayCardData {
  final String title, sub;
  final int count;
  final IconData icon;
  final Color color;
  const _TodayCardData(this.title, this.count, this.sub, this.icon, this.color);
}

// ─── Card shimmer loader ──────────────────────────────────────────────────────

class _CardShimmer extends StatefulWidget {
  const _CardShimmer();
  @override
  State<_CardShimmer> createState() => _CardShimmerState();
}

class _CardShimmerState extends State<_CardShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double w, double h, {double radius = 6}) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: const [
              Color(0xFFE8E8E8),
              Color(0xFFF5F5F5),
              Color(0xFFE8E8E8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: const Border(
              left: BorderSide(color: Color(0xFFE5E7EB), width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _box(36, 36, radius: 8),
            const Spacer(),
            _box(52, 28, radius: 20),
          ]),
          const SizedBox(height: 12),
          _box(double.infinity, 10, radius: 4),
          const SizedBox(height: 10),
          Row(children: [
            _box(64, 9, radius: 4),
            const Spacer(),
            _box(36, 9, radius: 4),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    if (isMobile) {
      return Column(children: [
        Row(children: [
          Expanded(child: _card()),
          const SizedBox(width: 10),
          Expanded(child: _card()),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _card()),
          const SizedBox(width: 10),
          Expanded(child: _card()),
        ]),
      ]);
    }
    return Row(children: [
      for (int i = 0; i < 4; i++) ...[
        Expanded(child: _card()),
        if (i < 3) const SizedBox(width: 12),
      ],
    ]);
  }
}

// ─── Full dashboard shimmer ───────────────────────────────────────────────────

class _DashboardShimmer extends StatefulWidget {
  final bool isDesktop;
  const _DashboardShimmer({required this.isDesktop});

  @override
  State<_DashboardShimmer> createState() => _DashboardShimmerState();
}

class _DashboardShimmerState extends State<_DashboardShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double w, double h, {double radius = 6}) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          width: w == double.infinity ? null : w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: const [
                Color(0xFFE8E8E8),
                Color(0xFFF5F5F5),
                Color(0xFFE8E8E8),
              ],
            ),
          ),
        ),
      );

  Widget _wCard(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ],
        ),
        child: child,
      );

  Widget _header() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _box(150, 22, radius: 6),
            const SizedBox(height: 8),
            _box(260, 11, radius: 4),
          ]),
          if (widget.isDesktop)
            Row(children: [
              _box(32, 32, radius: 8),
              const SizedBox(width: 6),
              _box(32, 32, radius: 8),
              const SizedBox(width: 6),
              _box(32, 32, radius: 8),
              const SizedBox(width: 16),
              _box(34, 34, radius: 17),
            ]),
        ],
      );

  Widget _sectionLabel() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _box(90, 13, radius: 4),
          _box(100, 11, radius: 4),
        ],
      );

  Widget _summaryCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              const Border(left: BorderSide(color: Color(0xFFE5E7EB), width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _box(36, 36, radius: 8),
            const Spacer(),
            _box(52, 28, radius: 20),
          ]),
          const SizedBox(height: 12),
          _box(double.infinity, 10, radius: 4),
          const SizedBox(height: 10),
          Row(children: [
            _box(64, 9, radius: 4),
            const Spacer(),
            _box(36, 9, radius: 4),
          ]),
        ]),
      );

  Widget _cardsRow() {
    if (!widget.isDesktop) {
      return Column(children: [
        Row(children: [
          Expanded(child: _summaryCard()),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard()),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _summaryCard()),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard()),
        ]),
      ]);
    }
    return Row(children: [
      for (int i = 0; i < 4; i++) ...[
        Expanded(child: _summaryCard()),
        if (i < 3) const SizedBox(width: 12),
      ],
    ]);
  }

  Widget _chartCard() => _wCard(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _box(160, 13, radius: 4),
            _box(110, 11, radius: 4),
          ]),
          const SizedBox(height: 20),
          _box(double.infinity, 220, radius: 8),
        ],
      ));

  Widget _donutCard() => _wCard(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(150, 13, radius: 4),
          const SizedBox(height: 20),
          _box(double.infinity, 200, radius: 8),
        ],
      ));

  Widget _chartsRow() {
    if (!widget.isDesktop) {
      return Column(children: [
        _chartCard(),
        const SizedBox(height: 16),
        _donutCard(),
      ]);
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(flex: 55, child: _chartCard()),
        const SizedBox(width: 16),
        Expanded(flex: 45, child: _donutCard()),
      ]),
    );
  }

  Widget _tableRow() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(children: [
          _box(36, 36, radius: 10),
          const SizedBox(width: 10),
          Expanded(flex: 4, child: _box(double.infinity, 12, radius: 4)),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: _box(double.infinity, 12, radius: 4)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _box(double.infinity, 12, radius: 4)),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: _box(double.infinity, 12, radius: 4)),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: _box(double.infinity, 12, radius: 4)),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: _box(60, 24, radius: 12)),
          const SizedBox(width: 32),
        ]),
      );

  Widget _table() => _wCard(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _box(140, 13, radius: 4),
            _box(70, 11, radius: 4),
          ]),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          for (int i = 0; i < 4; i++) ...[
            _tableRow(),
            if (i < 3)
              const Divider(height: 1, color: Color(0xFFF5F5F5)),
          ],
        ],
      ));

  @override
  Widget build(BuildContext context) {
    final pad = widget.isDesktop ? 28.0 : 16.0;
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(),
        const SizedBox(height: 24),
        _sectionLabel(),
        const SizedBox(height: 12),
        _cardsRow(),
        const SizedBox(height: 24),
        _chartsRow(),
        const SizedBox(height: 24),
        _table(),
        const SizedBox(height: 24),
      ]),
    );
  }
}

String _dashFmt(double v) {
  if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

String _dashQty(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

// ─── Sidebar ─────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int, Widget?) onNavigate;
  final AuthService auth;

  const _Sidebar(
      {required this.selectedIndex,
      required this.onNavigate,
      required this.auth});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: _kSidebar,
      child: _SidebarContent(
          selectedIndex: selectedIndex, onNavigate: onNavigate, auth: auth),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  final int selectedIndex;
  final void Function(int, Widget?) onNavigate;
  final AuthService auth;

  const _SidebarContent(
      {required this.selectedIndex,
      required this.onNavigate,
      required this.auth});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        // Brand
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: _kSidebarActive,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.grid_view_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('MMS',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ]),
        ),

        // Nav items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _sectionLabel('MAIN'),
              _navItem(0, Icons.dashboard_outlined, 'Dashboard', null),
              const SizedBox(height: 8),
              if (_hasAny(auth, [
                'attendance',
                'advances',
                'outstanding',
                'stock',
                'transport',
                'measurements',
                'expenses',
                'payments'
              ])) ...[
                _sectionLabel('OPERATIONS'),
                if (auth.canAccess('attendance'))
                  _navItem(1, Icons.how_to_reg_outlined, 'Attendance', null),
                if (auth.canAccess('advances'))
                  _navItem(14, Icons.account_balance_wallet_outlined,
                      'Advances', null),
                if (auth.canAccess('outstanding'))
                  _navItem(
                      16, Icons.account_balance_outlined, 'Outstanding', null),
                if (auth.canAccess('stock'))
                  _navItem(
                      2, Icons.inventory_2_outlined, 'Material Stock', null),
                if (auth.canAccess('transport'))
                  _navItem(3, Icons.local_shipping_outlined, 'Transport Detail',
                      null),
                if (auth.canAccess('measurements'))
                  _navItem(17, Icons.straighten_rounded, 'Measurement', null),
                if (auth.canAccess('expenses'))
                  _navItem(4, Icons.receipt_long_outlined, 'Expenses', null),
                if (auth.canAccess('payments'))
                  _navItem(5, Icons.payment_outlined, 'Payments', null),
                const SizedBox(height: 8),
              ],
              if (_hasAny(auth, [
                'branches',
                'location',
                'category',
                'expense_cat',
                'user_cat',
                'materials',
                'employees',
                'users'
              ])) ...[
                _sectionLabel('MASTERS'),
                if (auth.canAccess('branches'))
                  _navItem(10, Icons.store_outlined, 'Branches', null),
                if (auth.canAccess('location'))
                  _navItem(6, Icons.location_on_outlined, 'Location', null),
                if (auth.canAccess('category'))
                  _navItem(11, Icons.category_outlined, 'Category', null),
                if (auth.canAccess('expense_cat'))
                  _navItem(12, Icons.receipt_long_outlined, 'Expense Category',
                      null),
                if (auth.canAccess('user_cat'))
                  _navItem(
                      13, Icons.label_outline_rounded, 'User Category', null),
                if (auth.canAccess('materials'))
                  _navItem(7, Icons.widgets_outlined, 'Material', null),
                if (auth.canAccess('employees'))
                  _navItem(15, Icons.badge_outlined, 'Employees', null),
                if (auth.canAccess('users'))
                  _navItem(8, Icons.people_outline, 'Users', null),
                const SizedBox(height: 8),
              ],
              if (auth.canAccess('reports')) ...[
                _sectionLabel('REPORTS'),
                _navItem(9, Icons.bar_chart_outlined, 'Overall Report', null),
              ],
            ],
          ),
        ),

        // User footer
        Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: _kSidebarActive,
              child: Text(_initials(auth.userName),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(auth.userName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  Text(auth.userRole,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 10)),
                ])),
            GestureDetector(
              onTap: auth.logout,
              child: const Icon(Icons.logout, color: Colors.white38, size: 17),
            ),
          ]),
        ),
      ]),
    );
  }

  bool _hasAny(AuthService auth, List<String> keys) =>
      keys.any((k) => auth.canAccess(k));

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white30,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2)),
    );
  }

  Widget _navItem(int index, IconData icon, String label, Widget? screen) {
    final active = selectedIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
          color: active ? _kSidebarActive : Colors.transparent,
          borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        dense: true,
        leading:
            Icon(icon, color: active ? Colors.white : Colors.white60, size: 18),
        title: Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
        onTap: () => onNavigate(index, screen),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─── Dashboard header ─────────────────────────────────────────────────────────

class _DashHeader extends StatelessWidget {
  final bool isDesktop;
  final VoidCallback onRefresh;
  final AuthService auth;
  final bool isLoading;

  const _DashHeader(
      {required this.isDesktop,
      required this.onRefresh,
      required this.auth,
      this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM yyyy').format(DateTime.now());
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Dashboard',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 4),
            Text(
              'Real-time insights into stock levels and warehouse operations — $date',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ]),
          if (isDesktop)
            Row(children: [
              _IconBtn(icon: Icons.mail_outline_rounded, onTap: () {}),
              const SizedBox(width: 6),
              _IconBtn(icon: Icons.notifications_none_rounded, onTap: () {}),
              const SizedBox(width: 6),
              _SpinRefreshBtn(isLoading: isLoading, onTap: onRefresh),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(height: 28, child: VerticalDivider()),
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 44),
                tooltip: '',
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: _kSidebarActive,
                  child: Text(_initials(auth.userName),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                      enabled: false,
                      child: Text(auth.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  PopupMenuItem(
                      enabled: false,
                      child: Text(auth.userRole.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey))),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'logout', child: Text('Logout')),
                ],
                onSelected: (v) {
                  if (v == 'logout') auth.logout();
                },
              ),
            ]),
        ]);
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white),
        child: Icon(icon, size: 18, color: Colors.grey.shade600),
      ),
    );
  }
}

class _SpinRefreshBtn extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _SpinRefreshBtn({required this.isLoading, required this.onTap});

  @override
  State<_SpinRefreshBtn> createState() => _SpinRefreshBtnState();
}

class _SpinRefreshBtnState extends State<_SpinRefreshBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    if (widget.isLoading) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_SpinRefreshBtn old) {
    super.didUpdateWidget(old);
    if (widget.isLoading && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.isLoading && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.isLoading ? null : widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(
              color: widget.isLoading
                  ? _kSidebarActive.withValues(alpha: 0.3)
                  : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
          color: widget.isLoading
              ? _kSidebarActive.withValues(alpha: 0.06)
              : Colors.white,
        ),
        child: RotationTransition(
          turns: _ctrl,
          child: Icon(
            Icons.refresh_rounded,
            size: 18,
            color: widget.isLoading ? _kSidebarActive : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ─── Attendance chart shimmer ─────────────────────────────────────────────────

class _AttendanceChartShimmer extends StatefulWidget {
  const _AttendanceChartShimmer();
  @override
  State<_AttendanceChartShimmer> createState() =>
      _AttendanceChartShimmerState();
}

class _AttendanceChartShimmerState extends State<_AttendanceChartShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double w, double h, {double radius = 6}) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          width: w == double.infinity ? null : w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: const [
                Color(0xFFE8E8E8),
                Color(0xFFF5F5F5),
                Color(0xFFE8E8E8),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row — title + legend dots
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            _box(160, 14, radius: 4),
            const SizedBox(width: 8),
            _box(50, 20, radius: 20),
          ]),
          Row(children: [
            _box(10, 10, radius: 5),
            const SizedBox(width: 5),
            _box(46, 10, radius: 4),
            const SizedBox(width: 14),
            _box(10, 10, radius: 5),
            const SizedBox(width: 5),
            _box(36, 10, radius: 4),
            const SizedBox(width: 8),
            _box(14, 14, radius: 4),
          ]),
        ]),
        const SizedBox(height: 24),
        // Bar placeholders — grouped pairs per branch
        SizedBox(
          height: 220,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Y-axis labels
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                    5, (_) => _box(24, 9, radius: 3)),
              ),
              const SizedBox(width: 8),
              // Bar groups
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(5, (i) {
                    final heights = [0.75, 0.5, 0.9, 0.35, 0.65];
                    final h = 160.0 * heights[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _box(13, h, radius: 4),
                            const SizedBox(width: 4),
                            _box(13, h * 1.2 > 160 ? 160 : h * 1.2,
                                radius: 4),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _box(36, 9, radius: 3),
                        const SizedBox(height: 4),
                        _box(28, 9, radius: 3),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Attendance bar chart ─────────────────────────────────────────────────────

class _AttendanceBarChartCard extends StatefulWidget {
  const _AttendanceBarChartCard();

  @override
  State<_AttendanceBarChartCard> createState() =>
      _AttendanceBarChartCardState();
}

class _AttendanceBarChartCardState extends State<_AttendanceBarChartCard> {
  List<Map<String, dynamic>> _chartData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final params = {
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    };

    final results = await Future.wait([
      ApiService.get('/branches'),
      ApiService.get('/employees'),
      ApiService.get('/attendance', params: params),
    ]);

    final branches = results[0]['data'] as List? ?? [];
    final employees = results[1]['data'] as List? ?? [];
    final attendances = results[2]['data'] as List? ?? [];

    // Build ordered branch id → name from the branches list
    final branchOrder = <String>[];
    final branchNames = <String, String>{};
    for (final b in branches) {
      final id = b['_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      branchOrder.add(id);
      branchNames[id] = b['name']?.toString() ?? id;
    }

    // Total employees per branch
    final totalMap = <String, int>{};
    for (final emp in employees) {
      final id = emp['branch']?['_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      totalMap[id] = (totalMap[id] ?? 0) + 1;
    }

    // Present count per branch from this week's attendance
    final presentMap = <String, int>{};
    for (final rec in attendances) {
      if (rec['isPresent'] != true) continue;
      final id = rec['branch']?['_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      presentMap[id] = (presentMap[id] ?? 0) + 1;
    }

    // All branches always shown, even with 0/0
    final chartData = branchOrder
        .map((id) => {
              'name': branchNames[id] ?? id,
              'attendance': presentMap[id] ?? 0,
              'total': totalMap[id] ?? 0,
            })
        .toList();

    if (mounted) setState(() { _chartData = chartData; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _AttendanceChartShimmer();
    }

    final maxVal = _chartData.fold<double>(
        0,
        (mx, item) =>
            ((item['total'] as num?)?.toDouble() ?? 0) > mx
                ? (item['total'] as num).toDouble()
                : mx);
    final rawMax = maxVal <= 0 ? 10.0 : maxVal;
    final interval = rawMax <= 10
        ? 2.0
        : rawMax <= 30
            ? 5.0
            : rawMax <= 60
                ? 10.0
                : rawMax <= 150
                    ? 20.0
                    : 50.0;
    final maxY = ((rawMax / interval).ceil() * interval + interval);

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Text('Branch wise Attendance',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD1FAE5)),
              ),
              child: Text(
                '${_chartData.length} branches',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF065F46)),
              ),
            ),
          ]),
          Row(children: [
            const _LegendDot(color: Color(0xFF2E7D52), label: 'Present'),
            const SizedBox(width: 14),
            const _LegendDot(color: Color(0xFFBDBDBD), label: 'Total'),
            const SizedBox(width: 8),
            InkWell(
              onTap: _load,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.refresh_rounded,
                    size: 14, color: Color(0xFF9CA3AF)),
              ),
            ),
          ]),
        ]),
        const SizedBox(height: 20),
        if (_chartData.isEmpty)
          const SizedBox(
            height: 220,
            child: Center(
              child: Text('No attendance data this week',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gi, rod, ri) {
                      final name = gi < _chartData.length
                          ? _chartData[gi]['name'] ?? ''
                          : '';
                      final lbl = ri == 0 ? 'Present' : 'Total';
                      return BarTooltipItem('$name\n$lbl: ${rod.toY.toInt()}',
                          const TextStyle(color: Colors.white, fontSize: 11));
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < _chartData.length) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: SizedBox(
                              width: 56,
                              child: Text(
                                _chartData[i]['name'] ?? '',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827)),
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: interval,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style:
                            const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.12),
                      strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                barGroups: List.generate(_chartData.length, (i) {
                  final item = _chartData[i];
                  return BarChartGroupData(x: i, barsSpace: 4, barRods: [
                    BarChartRodData(
                      toY: (item['attendance'] ?? 0).toDouble(),
                      color: const Color(0xFF2E7D52),
                      width: 13,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                    BarChartRodData(
                      toY: (item['total'] ?? 0).toDouble(),
                      color: const Color(0xFFFFA726),
                      width: 13,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ]);
                }),
              ),
              swapAnimationDuration: const Duration(milliseconds: 900),
              swapAnimationCurve: Curves.easeInOut,
            ),
          ),
      ]),
    );
  }
}

// ─── Donut chart ──────────────────────────────────────────────────────────────

const _kCatColors = [
  Color(0xFF1565C0),
  Color(0xFFE53935),
  Color(0xFF2E7D32),
  Color(0xFFFF8F00),
];

class _DonutChartCard extends StatelessWidget {
  final List categoryData;
  const _DonutChartCard({required this.categoryData});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Godown stock by category',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: Row(children: [
            Expanded(
              flex: 3,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 52,
                  sections: List.generate(categoryData.length, (i) {
                    final item = categoryData[i];
                    return PieChartSectionData(
                      color: _kCatColors[i % _kCatColors.length],
                      value: (item['value'] ?? 0).toDouble(),
                      title: '',
                      radius: 42,
                    );
                  }),
                ),
                swapAnimationDuration: const Duration(milliseconds: 900),
                swapAnimationCurve: Curves.easeInOut,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(categoryData.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: _kCatColors[i % _kCatColors.length],
                                shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(categoryData[i]['name'] ?? '',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF333333))),
                      ]),
                    );
                  })),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Location table ───────────────────────────────────────────────────────────

class _LocationTable extends StatelessWidget {
  final List locations;
  const _LocationTable({required this.locations});

  static const _avatarColors = [
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFFB8C00),
    Color(0xFF6750A4),
    Color(0xFF0077B6),
    Color(0xFF2D6A4F),
  ];

  Color _avatarColor(int index) => _avatarColors[index % _avatarColors.length];

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name.isEmpty) return '?';
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Location wise stock',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Text('${locations.length} locations',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        const SizedBox(height: 12),

        // ── Column headers ───────────────────────────────────────────────
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            Expanded(flex: 5, child: Text('Location', style: _kColHeader)),
            Expanded(flex: 3, child: Text('Total Units', style: _kColHeader)),
            Expanded(flex: 2, child: Text('Material', style: _kColHeader)),
            Expanded(flex: 3, child: Text('Inward', style: _kColHeader)),
            Expanded(flex: 3, child: Text('Outward', style: _kColHeader)),
            Expanded(flex: 3, child: Text('Status', style: _kColHeader)),
            SizedBox(width: 32),
          ]),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

        // ── Rows ─────────────────────────────────────────────────────────
        ...List.generate(locations.length, (i) {
          final loc = locations[i];
          final name = loc['name'] as String? ?? '—';
          final color = _avatarColor(i);
          final isLast = i == locations.length - 1;

          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Row(children: [
                // Avatar + name
                Expanded(
                  flex: 5,
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(_initials(name),
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF1A1A2E))),
                    ),
                  ]),
                ),

                // Total units
                Expanded(
                  flex: 3,
                  child: Text(
                    NumberFormat('#,###').format(loc['totalUnits'] ?? 0),
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),

                // Material count
                Expanded(
                  flex: 2,
                  child: Text(
                    '${loc['materialCount'] ?? 0}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),

                // Inward
                Expanded(
                  flex: 3,
                  child: Text(
                    '+${NumberFormat('#,###').format(loc['inward'] ?? 0)}',
                    style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),

                // Outward
                Expanded(
                  flex: 3,
                  child: Text(
                    '-${NumberFormat('#,###').format(loc['outward'] ?? 0)}',
                    style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),

                // Status badge
                Expanded(
                  flex: 3,
                  child: _StatusBadge(status: loc['status'] ?? 'Good'),
                ),

                // Three-dot menu
                SizedBox(
                  width: 32,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded,
                        size: 18, color: Colors.grey),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 3,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'view', child: Text('View Details')),
                      PopupMenuItem(value: 'stock', child: Text('View Stock')),
                    ],
                  ),
                ),
              ]),
            ),
            if (!isLast)
              const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
          ]);
        }),
      ]),
    );
  }
}

const _kColHeader = TextStyle(
  fontSize: 11,
  color: Colors.grey,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.3,
);

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ]),
      child: child,
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = switch (status.toLowerCase()) {
      'good' => (const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
      'near full' => (const Color(0xFFE65100), const Color(0xFFFFF3E0)),
      'low space' => (const Color(0xFFEF6C00), const Color(0xFFFFF8E1)),
      _ => (Colors.grey, const Color(0xFFF5F5F5)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: cfg.$2, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: cfg.$1, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(status,
            style: TextStyle(
                color: cfg.$1, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.isEmpty || name.isEmpty) return 'U';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

Route _slide(Widget screen) => PageRouteBuilder(
      pageBuilder: (_, a, __) => screen,
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeInOut)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 300),
    );
