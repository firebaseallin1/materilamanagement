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
import '../transactions/transport_screen.dart';
import '../transactions/measurement_screen.dart';
import '../masters/location_screen.dart';
import '../masters/branch_screen.dart';
import '../masters/category_screen.dart';
import '../masters/expense_category_screen.dart';
import '../masters/user_category_screen.dart';
import '../masters/material_screen.dart';
import '../masters/user_screen.dart';
import '../masters/employee_screen.dart';
import '../transactions/outstanding_screen.dart';
import '../reports/reports_screen.dart';
import '../../widgets/common_widgets.dart';

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
  late final AnimationController _ctrl;
  late final Animation<double> _fadeHeader;
  late final Animation<Offset> _slideHeader;
  late final Animation<double> _fadeCards;
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
    _fadeCards = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.2, 0.55, curve: Curves.easeOut));
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
    setState(() => _loading = true);
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      case 1:  return auth.canAccess('attendance')  ? const AttendanceScreen()       : _accessDenied();
      case 14: return auth.canAccess('advances')    ? const AdvanceScreen()          : _accessDenied();
      case 2:  return auth.canAccess('stock')       ? const StockScreen()            : _accessDenied();
      case 3:  return auth.canAccess('transport')   ? const TransportScreen()        : _accessDenied();
      case 4:  return auth.canAccess('expenses')    ? const ExpenseScreen()          : _accessDenied();
      case 5:  return auth.canAccess('payments')    ? const PaymentScreen()          : _accessDenied();
      case 6:  return auth.canAccess('location')    ? const LocationScreen()         : _accessDenied();
      case 7:  return auth.canAccess('materials')   ? const MaterialScreen()         : _accessDenied();
      case 8:  return auth.canAccess('users')       ? const UserScreen()             : _accessDenied();
      case 11: return auth.canAccess('category')    ? const CategoryScreen()         : _accessDenied();
      case 12: return auth.canAccess('expense_cat') ? const ExpenseCategoryScreen()  : _accessDenied();
      case 13: return auth.canAccess('user_cat')    ? const UserCategoryScreen()     : _accessDenied();
      case 9:  return auth.canAccess('reports')     ? const ReportsScreen()          : _accessDenied();
      case 10: return auth.canAccess('branches')    ? const BranchScreen()           : _accessDenied();
      case 15: return auth.canAccess('employees')   ? const EmployeeScreen()         : _accessDenied();
      case 16: return auth.canAccess('outstanding') ? const OutstandingScreen()      : _accessDenied();
    }

    if (_loading) {
      return const AppLoader(message: 'Loading dashboard…');
    }

    final counts = _summary?['counts'] ?? {};
    final statCards = <_StatCardData>[
      _StatCardData(
        title: 'Total Material',
        value: counts['materials'] ?? 248,
        trend: '+12 this month',
        trendUp: true,
        borderColor: const Color(0xFF43A047),
        bgColor: Colors.white,
      ),
      _StatCardData(
        title: 'Total Godown Stock (units)',
        value: counts['godownStock'] ?? 14320,
        trend: '3.4%',
        trendUp: true,
        borderColor: const Color(0xFF1E88E5),
        bgColor: Colors.white,
      ),
      _StatCardData(
        title: 'Inward Today',
        value: counts['inwardToday'] ?? 1845,
        trend: '18 GRNs',
        trendUp: true,
        borderColor: const Color(0xFFFB8C00),
        bgColor: Colors.white,
      ),
      _StatCardData(
        title: 'Outward Today',
        value: counts['outwardToday'] ?? 920,
        trend: '5 dispatches',
        trendUp: false,
        borderColor: const Color(0xFF43A047),
        bgColor: Colors.white,
      ),
    ];

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
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Stat cards
          FadeTransition(
            opacity: _fadeCards,
            child: _StaggeredStatCards(
                cards: statCards, ctrl: _ctrl, isDesktop: isDesktop),
          ),
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
    final barCard = _BarChartCard(
        stockData: _summary?['stockOverview'] as List? ?? _mockStockData);
    final donutCard = _DonutChartCard(
        categoryData: _summary?['categoryStock'] as List? ?? _mockCategoryData);

    if (isDesktop) {
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 55, child: barCard),
          const SizedBox(width: 16),
          Expanded(flex: 45, child: donutCard),
        ]),
      );
    }
    return Column(children: [barCard, const SizedBox(height: 16), donutCard]);
  }

  static const _mockStockData = [
    {'name': 'Steel Rods', 'inStock': 3100, 'reserved': 1900},
    {'name': 'Cements', 'inStock': 800, 'reserved': 650},
    {'name': 'PVC Pipes', 'inStock': 1400, 'reserved': 2600},
    {'name': 'Copper Wire', 'inStock': 350, 'reserved': 250},
    {'name': 'Bricks', 'inStock': 600, 'reserved': 450},
    {'name': 'Sands', 'inStock': 500, 'reserved': 1200},
  ];

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
              if (_hasAny(auth, ['attendance','advances','outstanding','stock','transport','expenses','payments'])) ...[
                _sectionLabel('OPERATIONS'),
                if (auth.canAccess('attendance'))   _navItem(1,  Icons.how_to_reg_outlined,              'Attendance',        null),
                if (auth.canAccess('advances'))     _navItem(14, Icons.account_balance_wallet_outlined,   'Advances',          null),
                if (auth.canAccess('outstanding'))  _navItem(16, Icons.account_balance_outlined,          'Outstanding',       null),
                if (auth.canAccess('stock'))       _navItem(2,  Icons.inventory_2_outlined,              'Material Stock',    null),
                if (auth.canAccess('transport'))   _navItem(3,  Icons.local_shipping_outlined,           'Transport Detail',  null),
                if (auth.canAccess('expenses'))    _navItem(4,  Icons.receipt_long_outlined,             'Expenses',          null),
                if (auth.canAccess('payments'))    _navItem(5,  Icons.payment_outlined,                  'Payments',          null),
                const SizedBox(height: 8),
              ],
              if (_hasAny(auth, ['branches','location','category','expense_cat','user_cat','materials','employees','users'])) ...[
                _sectionLabel('MASTERS'),
                if (auth.canAccess('branches'))    _navItem(10, Icons.store_outlined,                    'Branches',          null),
                if (auth.canAccess('location'))    _navItem(6,  Icons.location_on_outlined,              'Location',          null),
                if (auth.canAccess('category'))    _navItem(11, Icons.category_outlined,                 'Category',          null),
                if (auth.canAccess('expense_cat')) _navItem(12, Icons.receipt_long_outlined,             'Expense Category',  null),
                if (auth.canAccess('user_cat'))    _navItem(13, Icons.label_outline_rounded,             'User Category',     null),
                if (auth.canAccess('materials'))   _navItem(7,  Icons.widgets_outlined,                  'Material',          null),
                if (auth.canAccess('employees'))   _navItem(15, Icons.badge_outlined,                    'Employees',         null),
                if (auth.canAccess('users'))       _navItem(8,  Icons.people_outline,                    'Users',             null),
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

  const _DashHeader(
      {required this.isDesktop, required this.onRefresh, required this.auth});

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
              _IconBtn(icon: Icons.menu_rounded, onTap: () {}),
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

// ─── Stat cards ───────────────────────────────────────────────────────────────

class _StatCardData {
  final String title;
  final dynamic value;
  final String trend;
  final bool trendUp;
  final Color borderColor;
  final Color bgColor;
  const _StatCardData({
    required this.title,
    required this.value,
    required this.trend,
    required this.trendUp,
    required this.borderColor,
    required this.bgColor,
  });
}

class _StaggeredStatCards extends StatelessWidget {
  final List<_StatCardData> cards;
  final AnimationController ctrl;
  final bool isDesktop;

  const _StaggeredStatCards(
      {required this.cards, required this.ctrl, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(
              child: _StatCard(
                data: cards[i],
                ctrl: ctrl,
                interval: Interval(0.2 + i * 0.05, 0.55 + i * 0.05,
                    curve: Curves.easeOut),
              ),
            ),
            if (i < cards.length - 1) const SizedBox(width: 14),
          ],
        ],
      );
    }
    return Column(children: [
      Row(children: [
        Expanded(
            child: _StatCard(
                data: cards[0],
                ctrl: ctrl,
                interval: const Interval(0.2, 0.55, curve: Curves.easeOut))),
        const SizedBox(width: 12),
        Expanded(
            child: _StatCard(
                data: cards[1],
                ctrl: ctrl,
                interval: const Interval(0.25, 0.6, curve: Curves.easeOut))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _StatCard(
                data: cards[2],
                ctrl: ctrl,
                interval: const Interval(0.3, 0.65, curve: Curves.easeOut))),
        const SizedBox(width: 12),
        Expanded(
            child: _StatCard(
                data: cards[3],
                ctrl: ctrl,
                interval: const Interval(0.35, 0.7, curve: Curves.easeOut))),
      ]),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  final AnimationController ctrl;
  final Interval interval;

  const _StatCard(
      {required this.data, required this.ctrl, required this.interval});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final t = CurvedAnimation(parent: ctrl, curve: interval).value;
        final rawVal = int.tryParse(data.value.toString()) ?? 0;
        final displayVal = (rawVal * t).toInt();

        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: data.bgColor,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border(left: BorderSide(color: data.borderColor, width: 3)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(data.title,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    Text(
                      NumberFormat('#,###').format(displayVal),
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E)),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(
                          data.trendUp
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 12,
                          color: data.trendUp
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE53935)),
                      const SizedBox(width: 3),
                      Text(data.trend,
                          style: TextStyle(
                              fontSize: 11,
                              color: data.trendUp
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFE53935))),
                    ]),
                  ]),
            ),
          ),
        );
      },
    );
  }
}

// ─── Bar chart ────────────────────────────────────────────────────────────────

class _BarChartCard extends StatelessWidget {
  final List stockData;
  const _BarChartCard({required this.stockData});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Material stock overview',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Row(children: [
            _LegendDot(color: const Color(0xFF1565C0), label: 'In-Stock'),
            const SizedBox(width: 14),
            _LegendDot(color: const Color(0xFFFFA726), label: 'Reserved'),
          ]),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 3500,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  // getTooltipColor: (_) => Colors.black87,
                  getTooltipItem: (group, gi, rod, ri) {
                    final name = gi < stockData.length
                        ? stockData[gi]['name'] ?? ''
                        : '';
                    final lbl = ri == 0 ? 'In-Stock' : 'Reserved';
                    return BarTooltipItem('$name\n$lbl: ${rod.toY.toInt()}',
                        const TextStyle(color: Colors.white, fontSize: 11));
                  },
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < stockData.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(stockData[i]['name'] ?? '',
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.grey)),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    interval: 500,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt() == 0 ? '00' : v.toInt().toString(),
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                horizontalInterval: 500,
                getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.withOpacity(0.12), strokeWidth: 1),
                drawVerticalLine: false,
              ),
              barGroups: List.generate(stockData.length, (i) {
                final item = stockData[i];
                return BarChartGroupData(x: i, barsSpace: 4, barRods: [
                  BarChartRodData(
                    toY: (item['inStock'] ?? 0).toDouble(),
                    color: const Color(0xFF1565C0),
                    width: 13,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  BarChartRodData(
                    toY: (item['reserved'] ?? 0).toDouble(),
                    color: const Color(0xFFFFA726),
                    width: 13,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
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
            Expanded(flex: 5, child: Text('Location',    style: _kColHeader)),
            Expanded(flex: 3, child: Text('Total Units', style: _kColHeader)),
            Expanded(flex: 2, child: Text('Material',    style: _kColHeader)),
            Expanded(flex: 3, child: Text('Inward',      style: _kColHeader)),
            Expanded(flex: 3, child: Text('Outward',     style: _kColHeader)),
            Expanded(flex: 3, child: Text('Status',      style: _kColHeader)),
            SizedBox(width: 32),
          ]),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

        // ── Rows ─────────────────────────────────────────────────────────
        ...List.generate(locations.length, (i) {
          final loc    = locations[i];
          final name   = loc['name'] as String? ?? '—';
          final color  = _avatarColor(i);
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
