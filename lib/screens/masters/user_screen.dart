import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

// ════════════════════════════════════════════════
// USER SCREEN
// ════════════════════════════════════════════════
class UserScreen extends StatefulWidget {
  const UserScreen({super.key});
  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  List _users = [];
  List _branches = [];
  List _userCategories = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  int _tabIndex = 0;
  String _sortBy = 'name_asc';
  String? _filterBranchId;
  String? _filterCategoryId;

  final _searchCtrl = TextEditingController();

  static const _primary = Color(0xFF111827);
  static const _green = Color(0xFF16A34A);

  // ── Filtered list ──────────────────────────────────────────────────────────

  List get _filtered {
    final q = _search.toLowerCase();
    var list = _users.where((u) {
      final matchSearch = q.isEmpty ||
          (u['name'] ?? '').toString().toLowerCase().contains(q) ||
          (u['userId'] ?? '').toString().toLowerCase().contains(q);
      final isActive = u['isActive'] ?? true;
      final matchTab = _tabIndex == 0 ||
          (_tabIndex == 1 && isActive == true) ||
          (_tabIndex == 2 && isActive != true);
      final matchBranch = _filterBranchId == null ||
          u['branch']?['_id'] == _filterBranchId;
      final matchCat = _filterCategoryId == null ||
          u['userCategory']?['_id'] == _filterCategoryId ||
          u['role'] == _filterCategoryId;
      return matchSearch && matchTab && matchBranch && matchCat;
    }).toList();

    list.sort((a, b) {
      switch (_sortBy) {
        case 'name_desc':
          return (b['name'] ?? '').compareTo(a['name'] ?? '');
        case 'branch':
          return (a['branch']?['name'] ?? '')
              .compareTo(b['branch']?['name'] ?? '');
        default:
          return (a['name'] ?? '').compareTo(b['name'] ?? '');
      }
    });
    return list;
  }

  int get _activeFilterCount =>
      (_filterBranchId != null ? 1 : 0) + (_filterCategoryId != null ? 1 : 0);

  // ── Init / load ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      ApiService.get('/users'),
      ApiService.get('/branches', params: {'isActive': 'true', 'limit': '1000'}),
      ApiService.get('/user-categories', params: {'isActive': 'true', 'limit': '1000'}),
    ]);
    if (mounted) {
      setState(() {
        if (results[0]['success'] == true) {
          _users = results[0]['data'] ?? [];
          _error = null;
        } else {
          _error = results[0]['message'] ?? 'Failed to load users';
        }
        _branches = results[1]['data'] ?? [];
        _userCategories = results[2]['data'] ?? [];
        _loading = false;
      });
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/users/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  // ── Form panel ─────────────────────────────────────────────────────────────

  void _openForm([Map? user]) {
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
          borderRadius:
              const BorderRadius.horizontal(left: Radius.circular(20)),
          child: SizedBox(
            width: panelWidth,
            height: MediaQuery.of(ctx).size.height,
            child: UserFormPanel(
              user: user,
              branches: _branches,
              userCategories: _userCategories,
              onSaved: _load,
            ),
          ),
        ),
      ),
      transitionBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(a),
        child: child,
      ),
    );
  }

  // ── Sort / Filter ──────────────────────────────────────────────────────────

  void _showSortMenu(BuildContext anchorCtx) {
    final items = {
      'name_asc': 'Name A → Z',
      'name_desc': 'Name Z → A',
      'branch': 'By Branch',
    };
    showMenu<String>(
      context: anchorCtx,
      position: _buttonPosition(anchorCtx),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 4,
      items: items.entries.map((e) {
        final active = _sortBy == e.key;
        return PopupMenuItem<String>(
          value: e.key,
          child: Row(children: [
            Icon(
              active
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: active ? _green : const Color(0xFFD1D5DB),
            ),
            const SizedBox(width: 10),
            Text(e.value,
                style: TextStyle(
                    fontSize: 13,
                    color: active ? _green : const Color(0xFF374151),
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.normal)),
          ]),
        );
      }).toList(),
    ).then((val) {
      if (val != null) setState(() => _sortBy = val);
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => _UserFilterDialog(
        branches: _branches,
        userCategories: _userCategories,
        selectedBranchId: _filterBranchId,
        selectedCategoryId: _filterCategoryId,
        onApply: (branchId, catId) {
          setState(() {
            _filterBranchId = branchId;
            _filterCategoryId = catId;
          });
          Navigator.pop(ctx);
        },
        onClear: () {
          setState(() {
            _filterBranchId = null;
            _filterCategoryId = null;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  RelativeRect _buttonPosition(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    return RelativeRect.fromLTRB(
        offset.dx, offset.dy + box.size.height + 4, offset.dx + box.size.width, 0);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
              title: 'Users',
              subtitle: 'Manage system users and access permissions',
              onRefresh: _load,
              onSearchChanged: (v) => setState(() => _search = v),
              searchHint: 'Search users...',
              onAdd: _openForm,
              addLabel: 'Add User',
            ),
            _buildTabBar(),
            _buildToolbar(isMobile),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Expanded(
              child: _loading
                  ? const AppLoader()
                  : _error != null
                      ? _buildError(_error!)
                      : rows.isEmpty
                          ? _buildEmpty()
                          : isMobile
                              ? _buildMobileList(rows)
                              : _buildTable(rows),
            ),
          ],
        );
      }),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = ['All Users', 'Active', 'Inactive'];
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _tabIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _tabIndex = i),
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? _green : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(tabs[i],
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? _green : const Color(0xFF6B7280))),
            ),
          );
        }),
      ),
    );
  }

  // ── Toolbar ────────────────────────────────────────────────────────────────

  Widget _buildToolbar(bool isMobile) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
      child: Row(children: [
        if (!isMobile) ...[
          Builder(builder: (ctx) => _sortBtn(ctx)),
          const SizedBox(width: 8),
          _filterBtn(),
        ],
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${_filtered.length} rows',
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ),
      ]),
    );
  }

  Widget _sortBtn(BuildContext ctx) {
    const labels = {
      'name_asc': 'Name A → Z',
      'name_desc': 'Name Z → A',
      'branch': 'By Branch',
    };
    final sorted = _sortBy != 'name_asc';
    return _toolbarSurface(
      onTap: () => _showSortMenu(ctx),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.swap_vert_rounded,
            size: 14, color: sorted ? _green : const Color(0xFF6B7280)),
        const SizedBox(width: 6),
        Text(labels[_sortBy] ?? 'Sort',
            style: TextStyle(
                fontSize: 13,
                color: sorted ? _green : const Color(0xFF374151),
                fontWeight: sorted ? FontWeight.w500 : FontWeight.w400)),
      ]),
    );
  }

  Widget _filterBtn() {
    final count = _activeFilterCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _toolbarSurface(
          onTap: _showFilterDialog,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.tune_rounded,
                size: 14, color: count > 0 ? _green : const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text('Filter',
                style: TextStyle(
                    fontSize: 13,
                    color: count > 0 ? _green : const Color(0xFF374151),
                    fontWeight:
                        count > 0 ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                  color: _green, shape: BoxShape.circle),
              child: Center(
                child: Text('$count',
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _toolbarSurface(
          {required VoidCallback onTap, required Widget child}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(7),
            color: Colors.white,
          ),
          child: child,
        ),
      );

  // ── Desktop table ──────────────────────────────────────────────────────────

  Widget _buildTable(List rows) {
    return Column(children: [
      Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: const Row(children: [
          SizedBox(width: 28, child: Text('#', style: _kUHdr)),
          SizedBox(width: 12),
          Expanded(flex: 3, child: Text('Name', style: _kUHdr)),
          Expanded(flex: 2, child: Text('User ID', style: _kUHdr)),
          Expanded(flex: 2, child: Text('Password', style: _kUHdr)),
          Expanded(flex: 2, child: Text('Branch', style: _kUHdr)),
          Expanded(flex: 2, child: Text('User Category', style: _kUHdr)),
          SizedBox(
              width: 88,
              child: Text('Status', style: _kUHdr, textAlign: TextAlign.center)),
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

  Widget _buildRow(Map u, int index) {
    final isActive = u['isActive'] ?? true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: Text('${index + 1}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: _nameCell(u, index)),
        Expanded(
          flex: 2,
          child: Text(u['userId'] ?? '—',
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          flex: 2,
          child: Text(u['password'] ?? '—',
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          flex: 2,
          child: Text(u['branch']?['name'] ?? '—',
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(flex: 2, child: _categoryBadge(u)),
        SizedBox(width: 88, child: Center(child: _statusBadge(isActive == true))),
        _actionMenu(u),
      ]),
    );
  }

  // ── Mobile list ────────────────────────────────────────────────────────────

  Widget _buildMobileList(List rows) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _mobileCard(rows[i], i),
    );
  }

  Widget _mobileCard(Map u, int index) {
    final isActive = u['isActive'] ?? true;
    final userId = (u['userId'] as String? ?? '').trim();
    final branch = u['branch']?['name'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
          _avatarTappable(u, index, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(u['name'] ?? '',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
              const SizedBox(height: 2),
              Text(
                  '${userId.isNotEmpty ? userId : '—'}'
                  '${branch.isNotEmpty ? ' · $branch' : ''}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusBadge(isActive == true),
                const SizedBox(height: 4),
                _categoryBadge(u),
              ]),
          _actionMenu(u),
        ]),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  void _viewPhoto(BuildContext context, Map u) {
    final photo = u['photo'] as String?;
    if (photo == null || photo.isEmpty) return;
    Uint8List? bytes;
    try { bytes = base64Decode(photo); } catch (_) { return; }
    final name = u['name'] as String? ?? '';
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.72;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ]),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: InteractiveViewer(
                    child: Image.memory(bytes!,
                        fit: BoxFit.contain,
                        width: double.infinity),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _avatarTappable(Map u, int index, {double size = 28}) {
    final photo = u['photo'] as String?;
    final hasPhoto = photo != null && photo.isNotEmpty;
    return GestureDetector(
      onTap: hasPhoto ? () => _viewPhoto(context, u) : null,
      child: _avatar(u, index, size: size),
    );
  }

  Widget _nameCell(Map u, int index) {
    return Row(children: [
      _avatarTappable(u, index),
      const SizedBox(width: 10),
      Flexible(
        child: Text(u['name'] ?? '',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827)),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }

  Widget _avatar(Map u, int index, {double size = 28}) {
    const bgs = [
      Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFF0D9488),
      Color(0xFFEA580C), Color(0xFFDC2626), Color(0xFFDB2777),
      Color(0xFF16A34A), Color(0xFFF59E0B),
    ];
    final photo = u['photo'] as String?;
    if (photo != null && photo.isNotEmpty) {
      try {
        final bytes = base64Decode(photo);
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.28),
          child: Image.memory(bytes,
              width: size, height: size, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    final bg = bgs[index % bgs.length];
    final name = u['name'] as String? ?? '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.42),
        ),
      ),
    );
  }

  Widget _categoryBadge(Map u) {
    final catName = u['userCategory']?['name'] as String? ??
        u['role'] as String? ??
        'user';
    final isAdmin = catName.toLowerCase() == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAdmin
            ? const Color(0xFFEDE9FE)
            : const Color(0xFFDEECFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(catName,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isAdmin
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFF1D4ED8))),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color:
                active ? const Color(0xFF166534) : const Color(0xFF6B7280)),
      ),
    );
  }

  Widget _actionMenu(Map u) {
    if (!context.read<AuthService>().isAdmin) return const SizedBox.shrink();
    return SizedBox(
      width: 40,
      child: PopupMenuButton(
        icon: const Icon(Icons.more_horiz_rounded,
            size: 18, color: Color(0xFF9CA3AF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 3,
        itemBuilder: (_) => const [
          PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 15, color: Color(0xFF374151)),
                SizedBox(width: 8),
                Text('Edit', style: TextStyle(fontSize: 13)),
              ])),
          PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded,
                    size: 15, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('Delete',
                    style:
                        TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
              ])),
        ],
        onSelected: (val) {
          if (val == 'edit') _openForm(u);
          if (val == 'delete') _delete(u['_id']);
        },
      ),
    );
  }

  // ── Error state ────────────────────────────────────────────────────────────

  Widget _buildError(String message) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.cloud_off_rounded,
              size: 28, color: Color(0xFFDC2626)),
        ),
        const SizedBox(height: 14),
        const Text('Failed to load',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 15),
          label: const Text('Retry', style: TextStyle(fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ]),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    final hasFilter = _search.isNotEmpty || _activeFilterCount > 0;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.people_outline,
              size: 28, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 14),
        Text(hasFilter ? 'No results found' : 'No users yet',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(
            hasFilter
                ? 'Try adjusting your search or filters.'
                : 'Add your first user to get started.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        if (hasFilter) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _search = '';
              _searchCtrl.clear();
              _filterBranchId = null;
              _filterCategoryId = null;
            }),
            child: const Text('Clear filters',
                style: TextStyle(color: _green)),
          ),
        ] else ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openForm,
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add User', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _kUHdr = TextStyle(
    fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);

// ── Filter dialog ─────────────────────────────────────────────────────────────

class _UserFilterDialog extends StatefulWidget {
  final List branches;
  final List userCategories;
  final String? selectedBranchId;
  final String? selectedCategoryId;
  final void Function(String?, String?) onApply;
  final VoidCallback onClear;

  const _UserFilterDialog({
    required this.branches,
    required this.userCategories,
    required this.selectedBranchId,
    required this.selectedCategoryId,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_UserFilterDialog> createState() => _UserFilterDialogState();
}

class _UserFilterDialogState extends State<_UserFilterDialog> {
  String? _branchId;
  String? _catId;

  @override
  void initState() {
    super.initState();
    _branchId = widget.selectedBranchId;
    _catId = widget.selectedCategoryId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(children: [
        const Text('Filter',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton(
          onPressed: widget.onClear,
          style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
          child: const Text('Clear all',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ),
      ]),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BRANCH',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.6)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _UChip(
                      label: 'All',
                      selected: _branchId == null,
                      onTap: () => setState(() => _branchId = null)),
                  ...widget.branches.map((b) => _UChip(
                        label: b['name'] ?? '',
                        selected: _branchId == b['_id'],
                        onTap: () => setState(() => _branchId = b['_id']),
                      )),
                ],
              ),
              const SizedBox(height: 16),
              const Text('USER CATEGORY',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.6)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _UChip(
                      label: 'All',
                      selected: _catId == null,
                      onTap: () => setState(() => _catId = null)),
                  ...widget.userCategories.map((c) => _UChip(
                        label: c['name'] ?? '',
                        selected: _catId == c['_id'],
                        onTap: () => setState(() => _catId = c['_id']),
                      )),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFD1D5DB)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFF374151), fontSize: 13)),
        ),
        ElevatedButton(
          onPressed: () => widget.onApply(_branchId, _catId),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text('Apply', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

class _UChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _UChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF16A34A)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF16A34A)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : const Color(0xFF374151))),
      ),
    );
  }
}

// ── User Form Panel ───────────────────────────────────────────────────────────

class UserFormPanel extends StatefulWidget {
  final Map? user;
  final List branches;
  final List userCategories;
  final VoidCallback onSaved;

  const UserFormPanel({
    super.key,
    this.user,
    required this.branches,
    required this.userCategories,
    required this.onSaved,
  });

  @override
  State<UserFormPanel> createState() => _UserFormPanelState();
}

class _UserFormPanelState extends State<UserFormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String? _branchId;
  String? _userCategoryId;
  final Set<String> _employeeIds = {};
  bool _saving = false;
  bool _isActive = true;
  bool _obscurePass = true;

  String? _photoBase64;
  String? _generatedUserId;
  bool _generatingId = false;
  List _employees = [];

  static const _primary = Color(0xFF1B3A27);
  static const _accent = Color(0xFF16A34A);
  static const _gradient2 = Color(0xFF1E6F5C);

  bool get _isEdit => widget.user != null && widget.user!['_id'] != null;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _nameCtrl.text = widget.user!['name'] ?? '';
      _generatedUserId = widget.user!['userId'] as String?;
      _phoneCtrl.text = widget.user!['phone'] ?? '';
      _passCtrl.text = widget.user!['password'] ?? '';
      _branchId = widget.user!['branch']?['_id'];
      _isActive = widget.user!['isActive'] ?? true;
      final rawPhoto = widget.user!['photo'] as String?;
      _photoBase64 = (rawPhoto != null && rawPhoto.isNotEmpty) ? rawPhoto : null;
      _userCategoryId = widget.user!['userCategory']?['_id'];
      if (_userCategoryId == null) {
        final role = widget.user!['role'] as String?;
        if (role != null) {
          final match = widget.userCategories
              .where((c) =>
                  (c['name'] as String? ?? '').toLowerCase() ==
                  role.toLowerCase())
              .firstOrNull;
          if (match != null) _userCategoryId = match['_id'];
        }
      }
      final rawList = widget.user!['employees'];
      if (rawList is List) {
        for (final e in rawList) {
          final id = e is Map ? e['_id'] as String? : (e is String ? e : null);
          if (id != null && id.isNotEmpty) _employeeIds.add(id);
        }
      }
    }
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final res = await ApiService.get('/employees', params: {'limit': '1000', 'isActive': 'true'});
    if (mounted) {
      setState(() => _employees = res['data'] ?? []);
    }
  }

  void _openEmployeePicker() {
    String search = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filtered = _employees.where((e) {
            if (search.isEmpty) return true;
            final q = search.toLowerCase();
            return (e['name'] ?? '').toString().toLowerCase().contains(q) ||
                (e['empCode'] ?? '').toString().toLowerCase().contains(q);
          }).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            expand: false,
            builder: (_, sc) => Column(children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(children: [
                  const Text('Select Employees',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_employeeIds.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() => _employeeIds.clear());
                        setModal(() {});
                      },
                      child: const Text('Clear all',
                          style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                    ),
                ]),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search by name or code…',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9CA3AF)),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setModal(() => search = v),
                ),
              ),
              const Divider(height: 1),
              // Employee list
              Expanded(
                child: ListView.separated(
                  controller: sc,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  itemBuilder: (_, i) {
                    final emp = filtered[i];
                    final id = emp['_id'] as String;
                    final selected = _employeeIds.contains(id);
                    final photo = emp['photo'] as String?;
                    Uint8List? bytes;
                    if (photo != null && photo.isNotEmpty) {
                      try { bytes = base64Decode(photo); } catch (_) {}
                    }
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (selected) _employeeIds.remove(id);
                          else _employeeIds.add(id);
                        });
                        setModal(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(children: [
                          // Avatar
                          bytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(bytes, width: 36, height: 36, fit: BoxFit.cover))
                              : Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: _accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.person_outline_rounded,
                                      size: 18, color: _accent),
                                ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(emp['name'] ?? '—',
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827))),
                              Text(
                                '${emp['empCode'] ?? ''}${(emp['empCode'] ?? '').isNotEmpty && (emp['designation'] ?? '').isNotEmpty ? ' · ' : ''}${emp['designation'] ?? ''}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                              ),
                            ],
                          )),
                          Checkbox(
                            value: selected,
                            onChanged: (_) {
                              setState(() {
                                if (selected) _employeeIds.remove(id);
                                else _employeeIds.add(id);
                              });
                              setModal(() {});
                            },
                            activeColor: _accent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              // Done button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _employeeIds.isEmpty
                            ? 'Done'
                            : 'Done  (${_employeeIds.length} selected)',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _employeeMultiSelect() {
    final selected = _employees
        .where((e) => _employeeIds.contains(e['_id'] as String))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Tap-to-open button
      GestureDetector(
        onTap: _openEmployeePicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: _employeeIds.isEmpty
                ? const Color(0xFFF7F9F8)
                : _accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _employeeIds.isEmpty
                  ? const Color(0xFFDDE3E0)
                  : _accent.withValues(alpha: 0.4),
            ),
          ),
          child: Row(children: [
            Icon(Icons.badge_outlined, size: 18,
                color: _employeeIds.isEmpty ? Colors.grey : _accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _employeeIds.isEmpty
                    ? 'Select employees (optional)'
                    : '${_employeeIds.length} employee${_employeeIds.length == 1 ? '' : 's'} selected',
                style: TextStyle(
                  fontSize: 13,
                  color: _employeeIds.isEmpty
                      ? const Color(0xFF9CA3AF)
                      : _accent,
                  fontWeight: _employeeIds.isEmpty
                      ? FontWeight.normal
                      : FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18,
                color: _employeeIds.isEmpty ? Colors.grey : _accent),
          ]),
        ),
      ),
      // Selected employee chips
      if (selected.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: selected.map((emp) {
            final id = emp['_id'] as String;
            final photo = emp['photo'] as String?;
            Uint8List? bytes;
            if (photo != null && photo.isNotEmpty) {
              try { bytes = base64Decode(photo); } catch (_) {}
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                bytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(bytes, width: 20, height: 20, fit: BoxFit.cover))
                    : Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.2),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.person_outline_rounded,
                            size: 12, color: _accent),
                      ),
                const SizedBox(width: 6),
                Text(emp['name'] ?? '',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: Color(0xFF166534))),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => _employeeIds.remove(id)),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: Color(0xFF6B7280)),
                ),
              ]),
            );
          }).toList(),
        ),
      ],
    ]);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Auto-generate userId ───────────────────────────────────────────────────

  Future<void> _generateUserId() async {
    if (_userCategoryId == null) return;
    final selCat = widget.userCategories
        .where((c) => c['_id'] == _userCategoryId)
        .firstOrNull;
    if (selCat == null) return;

    final catName = (selCat['name'] as String? ?? '').trim();
    final catPrefix = catName.length >= 3
        ? catName.substring(0, 3).toUpperCase()
        : catName.toUpperCase().padRight(3, 'X');

    setState(() => _generatingId = true);
    final res = await ApiService.get(
        '/users/generate-id?catPrefix=$catPrefix');
    if (mounted) {
      setState(() {
        _generatingId = false;
        if (res['success'] == true) _generatedUserId = res['userId'] as String?;
      });
    }
  }

  // ── Photo picker ───────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Choose Photo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFDCFCE7),
              child: Icon(Icons.photo_library_outlined,
                  color: Color(0xFF16A34A), size: 20),
            ),
            title: const Text('Gallery',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFDEECFF),
              child: Icon(Icons.camera_alt_outlined,
                  color: Color(0xFF1D4ED8), size: 20),
            ),
            title: const Text('Camera',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          if (_photoBase64 != null)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFEF2F2),
                child: Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626), size: 20),
              ),
              title: const Text('Remove Photo',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFDC2626))),
              onTap: () {
                setState(() => _photoBase64 = null);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 75,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    setState(() => _photoBase64 = base64Encode(bytes));
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_generatedUserId == null || _generatedUserId!.isEmpty) {
      showSnack(context, 'Please select a category to generate the User ID',
          error: true);
      return;
    }

    setState(() => _saving = true);

    final selCat = widget.userCategories
        .where((c) => c['_id'] == _userCategoryId)
        .firstOrNull;
    final catName = (selCat?['name'] as String? ?? '').trim();
    // In edit mode with no category selected, preserve the existing role
    final String role;
    if (catName.isNotEmpty) {
      role = catName.toLowerCase().contains('admin') ? 'admin' : 'user';
    } else if (_isEdit) {
      role = (widget.user!['role'] as String? ?? 'user');
    } else {
      role = 'user';
    }

    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'userId': _generatedUserId,
      'phone': _phoneCtrl.text.trim(),
      'branch': _branchId,
      'userCategory': _userCategoryId,
      'role': role,
      'isActive': _isActive,
      'photo': _photoBase64 ?? '',
      'employees': _employeeIds.toList(),
      if (_passCtrl.text.isNotEmpty) 'password': _passCtrl.text,
    };

    final res = !_isEdit
        ? await ApiService.post('/users', body)
        : await ApiService.put('/users/${widget.user!['_id']}', body);

    if (mounted) {
      showSnack(context,
          res['success'] == true ? 'Saved successfully!' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) {
        Navigator.pop(context);
        widget.onSaved();
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  // ── Decoration helpers ─────────────────────────────────────────────────────

  InputDecoration _dec(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: _accent),
        labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFF7F9F8),
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
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      );

  Widget _activeToggle() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDDE3E0)),
        ),
        child: Row(children: [
          Icon(Icons.toggle_on_outlined, size: 18, color: _accent),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Status',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Text(
            _isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _isActive
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
            activeThumbColor: const Color(0xFF16A34A),
            activeTrackColor: const Color(0xFFBBF7D0),
          ),
        ]),
      );

  // ── Photo widget ───────────────────────────────────────────────────────────

  Widget _photoPicker() {
    Uint8List? bytes;
    if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      try {
        bytes = base64Decode(_photoBase64!);
      } catch (_) {}
    }
    return Center(
      child: GestureDetector(
        onTap: _pickPhoto,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _accent.withValues(alpha: 0.25), width: 2),
              ),
              child: bytes != null
                  ? ClipOval(
                      child: Image.memory(bytes,
                          width: 88, height: 88, fit: BoxFit.cover),
                    )
                  : Icon(Icons.person_outline_rounded,
                      size: 38, color: _accent.withValues(alpha: 0.45)),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── User ID display ────────────────────────────────────────────────────────

  Widget _userIdField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: _generatedUserId != null
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _generatedUserId != null
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFDDE3E0),
        ),
      ),
      child: Row(children: [
        Icon(Icons.badge_outlined,
            size: 18,
            color: _generatedUserId != null ? _accent : Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('User ID (Auto-generated)',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 3),
              _generatingId
                  ? const SizedBox(
                      height: 16,
                      width: 80,
                      child: LinearProgressIndicator(
                        backgroundColor: Color(0xFFDCFCE7),
                        color: Color(0xFF16A34A),
                        minHeight: 3,
                      ),
                    )
                  : Text(
                      _generatedUserId ?? 'Select a category first',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _generatedUserId != null
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: _generatedUserId != null
                            ? const Color(0xFF166534)
                            : const Color(0xFF9CA3AF),
                        letterSpacing: _generatedUserId != null ? 1.5 : 0,
                      ),
                    ),
            ],
          ),
        ),
        if (!_isEdit && _generatedUserId != null)
          GestureDetector(
            onTap: _generateUserId,
            child: Tooltip(
              message: 'Regenerate',
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.refresh_rounded,
                    size: 14, color: Color(0xFF16A34A)),
              ),
            ),
          ),
        if (_generatedUserId != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.check_circle_rounded,
              size: 16, color: Color(0xFF16A34A)),
        ],
      ]),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [_primary, _gradient2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 18,
            left: 20,
            right: 8),
        child: Row(children: [
          const Icon(Icons.person_outline_rounded,
              color: Colors.white70, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(_isEdit ? 'Edit User' : 'Add User',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                _isEdit
                    ? 'Update user information'
                    : 'Fill in details to create a user',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ]),
          ),
          IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
      Expanded(
        child: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            // Photo picker
            _photoPicker(),
            const SizedBox(height: 20),

            // Full Name
            TextFormField(
              controller: _nameCtrl,
              decoration: _dec('Full Name', Icons.person_outline_rounded,
                  hint: 'e.g. John Doe'),
              validator: (v) =>
                  v!.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),

            // User Category — must come before userId so generation can happen
            DropdownButtonFormField<String>(
              initialValue: _userCategoryId,
              decoration: _dec('User Category', Icons.label_outline_rounded),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
              borderRadius: BorderRadius.circular(10),
              items: widget.userCategories
                  .map<DropdownMenuItem<String>>((c) => DropdownMenuItem(
                        value: c['_id'] as String,
                        child: Text(c['name'] ?? ''),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _userCategoryId = v;
                  if (!_isEdit) _generatedUserId = null;
                });
                if (!_isEdit) _generateUserId();
              },
              validator: (v) =>
                  !_isEdit && v == null ? 'Please select a user category' : null,
            ),
            const SizedBox(height: 14),

            // Auto-generated User ID + Password side by side
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _userIdField()),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    decoration: _dec(
                            _isEdit
                                ? 'New Password'
                                : 'Password',
                            Icons.lock_outline_rounded)
                        .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: const Color(0xFF9CA3AF),
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    validator: (v) =>
                        !_isEdit && v!.trim().isEmpty ? 'Password is required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Phone
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration:
                  _dec('Phone', Icons.phone_outlined, hint: 'Optional'),
            ),
            const SizedBox(height: 14),

            // Branch
            DropdownButtonFormField<String>(
              initialValue: _branchId,
              decoration: _dec('Branch', Icons.store_outlined),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
              borderRadius: BorderRadius.circular(10),
              items: widget.branches
                  .map<DropdownMenuItem<String>>((b) => DropdownMenuItem(
                        value: b['_id'] as String,
                        child: Text(b['name'] ?? ''),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _branchId = v),
            ),
            const SizedBox(height: 14),

            // Linked Employees (multi-select, optional)
            _employeeMultiSelect(),
            const SizedBox(height: 14),

            _activeToggle(),
            const SizedBox(height: 28),

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
                        : Text(
                            _isEdit ? 'Save Changes' : 'Add User',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ]);
  }
}
