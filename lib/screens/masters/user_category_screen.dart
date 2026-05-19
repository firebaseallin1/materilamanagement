import 'package:flutter/material.dart';
import '../../constants/screen_permissions.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

// ════════════════════════════════════════════════
// USER CATEGORY SCREEN
// ════════════════════════════════════════════════
class UserCategoryScreen extends StatefulWidget {
  const UserCategoryScreen({super.key});
  @override
  State<UserCategoryScreen> createState() => _UserCategoryScreenState();
}

class _UserCategoryScreenState extends State<UserCategoryScreen> {
  List _categories = [];
  bool _loading = true;
  String _search = '';
  String? _error;
  int _tabIndex = 0; // 0=All  1=Active  2=Inactive
  String _sortBy = 'name_asc';

  static const _primary = Color(0xFF111827);
  static const _teal = Color(0xFF0D9488);

  List get _filtered {
    final q = _search.toLowerCase();
    var list = _categories.where((c) {
      final matchSearch =
          q.isEmpty || (c['name'] ?? '').toString().toLowerCase().contains(q);
      final isActive = c['isActive'] ?? true;
      final matchTab = _tabIndex == 0 ||
          (_tabIndex == 1 && isActive == true) ||
          (_tabIndex == 2 && isActive != true);
      return matchSearch && matchTab;
    }).toList();
    list.sort((a, b) {
      if (_sortBy == 'name_desc') {
        return (b['name'] ?? '').compareTo(a['name'] ?? '');
      }
      return (a['name'] ?? '').compareTo(b['name'] ?? '');
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.get('/user-categories');
    if (mounted) {
      setState(() {
        if (res['success'] == true) {
          _categories = res['data'] ?? [];
          _error = null;
        } else {
          _error = res['message'] ?? 'Something went wrong';
        }
        _loading = false;
      });
    }
  }

  void _openForm([Map? category]) {
    final sw = MediaQuery.of(context).size.width;
    final panelWidth = sw > 900 ? sw * 0.35 : sw * 0.85;
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
            child: UserCategoryFormPanel(
                category: category, onSaved: _load),
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

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/user-categories/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  void _showSortMenu(BuildContext anchorCtx) {
    const items = {'name_asc': 'Name A → Z', 'name_desc': 'Name Z → A'};
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
              color: active ? _teal : const Color(0xFFD1D5DB),
            ),
            const SizedBox(width: 10),
            Text(e.value,
                style: TextStyle(
                    fontSize: 13,
                    color: active ? _teal : const Color(0xFF374151),
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.normal)),
          ]),
        );
      }).toList(),
    ).then((val) {
      if (val != null) setState(() => _sortBy = val);
    });
  }

  RelativeRect _buttonPosition(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    return RelativeRect.fromLTRB(
        offset.dx, offset.dy + box.size.height + 4, offset.dx + box.size.width, 0);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
              title: 'User Categories',
              subtitle: 'Manage user category master data',
              onRefresh: _load,
              onSearchChanged: (v) => setState(() => _search = v),
              searchHint: 'Search categories...',
              onAdd: _openForm,
              addLabel: 'Add Category',
            ),
            if (!isMobile) _buildTabBar(),
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

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = ['All Categories', 'Active', 'Inactive'];
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
                    color: active ? _teal : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(tabs[i],
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? _teal : const Color(0xFF6B7280))),
            ),
          );
        }),
      ),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────

  Widget _buildToolbar(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 20, vertical: 10),
      child: Row(children: [
        if (!isMobile) Builder(builder: (ctx) => _sortBtn(ctx)),
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
    const labels = {'name_asc': 'Name A → Z', 'name_desc': 'Name Z → A'};
    final sorted = _sortBy != 'name_asc';
    return InkWell(
      onTap: () => _showSortMenu(ctx),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(7),
          color: Colors.white,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.swap_vert_rounded,
              size: 14,
              color: sorted ? _teal : const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(labels[_sortBy] ?? 'Sort',
              style: TextStyle(
                  fontSize: 13,
                  color: sorted ? _teal : const Color(0xFF374151),
                  fontWeight:
                      sorted ? FontWeight.w500 : FontWeight.w400)),
        ]),
      ),
    );
  }

  // ── Desktop table ─────────────────────────────────────────────────────────

  Widget _buildTable(List rows) {
    return Column(children: [
      Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: const Row(children: [
          SizedBox(width: 28, child: Text('#', style: _kUCHdr)),
          SizedBox(width: 12),
          Expanded(flex: 3, child: Text('Category Name', style: _kUCHdr)),
          Expanded(flex: 3, child: Text('Description', style: _kUCHdr)),
          SizedBox(width: 80, child: Text('Screens', style: _kUCHdr, textAlign: TextAlign.center)),
          SizedBox(width: 88, child: Text('Status', style: _kUCHdr, textAlign: TextAlign.center)),
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

  Widget _buildRow(Map c, int index) {
    final isActive = c['isActive'] ?? true;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openForm(c),
        hoverColor: const Color(0xFFF9FAFB),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFF3F4F6)))),
          child: Row(children: [
            SizedBox(
              width: 28,
              child: Text('${index + 1}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF))),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _nameCell(c, index)),
            Expanded(
              flex: 3,
              child: Text(
                (c['description'] as String? ?? '').isEmpty
                    ? '—'
                    : c['description'],
                style: TextStyle(
                    fontSize: 13,
                    color: (c['description'] as String? ?? '').isEmpty
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF374151)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 80, child: Center(child: _permsBadge(c))),
            SizedBox(
                width: 88,
                child: Center(child: _statusBadge(isActive == true))),
            _actionMenu(c),
          ]),
        ),
      ),
    );
  }

  // ── Mobile list ───────────────────────────────────────────────────────────

  Widget _buildMobileList(List rows) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _mobileCard(rows[i], i),
    );
  }

  Widget _mobileCard(Map c, int index) {
    final isActive = c['isActive'] ?? true;
    final desc = (c['description'] as String? ?? '').trim();
    return InkWell(
      onTap: () => _openForm(c),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          _avatar(c, index, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(c['name'] ?? '',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
              const SizedBox(height: 2),
              Text(
                desc.isNotEmpty ? desc : 'No description',
                style: TextStyle(
                    fontSize: 12,
                    color: desc.isNotEmpty
                        ? const Color(0xFF6B7280)
                        : const Color(0xFFD1D5DB),
                    fontStyle: desc.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _statusBadge(isActive == true),
              const SizedBox(height: 4),
              _permsBadge(c),
            ],
          ),
          _actionMenu(c),
        ]),
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _nameCell(Map c, int index) {
    return Row(children: [
      _avatar(c, index),
      const SizedBox(width: 10),
      Flexible(
        child: Text(c['name'] ?? '',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827)),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }

  Widget _avatar(Map c, int index, {double size = 28}) {
    const bgs = [
      Color(0xFF0D9488), Color(0xFF2563EB), Color(0xFF9333EA),
      Color(0xFF16A34A), Color(0xFFEA580C), Color(0xFFDC2626),
      Color(0xFFDB2777), Color(0xFFF59E0B),
    ];
    final bg = bgs[index % bgs.length];
    final name = c['name'] as String? ?? '';
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

  Widget _permsBadge(Map c) {
    final perms = c['permissions'];
    final count = perms is List ? perms.length : 0;
    final total = kAllScreens.length;
    final hasPerms = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: hasPerms ? const Color(0xFFEDE9FE) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        hasPerms ? '$count / $total' : 'None',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: hasPerms ? const Color(0xFF6D28D9) : const Color(0xFF9CA3AF)),
      ),
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
            color: active
                ? const Color(0xFF166534)
                : const Color(0xFF6B7280)),
      ),
    );
  }

  Widget _actionMenu(Map c) {
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
                Icon(Icons.edit_outlined,
                    size: 15, color: Color(0xFF374151)),
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
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFFDC2626))),
              ])),
        ],
        onSelected: (val) {
          if (val == 'edit') _openForm(c);
          if (val == 'delete') _delete(c['_id']);
        },
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ]),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    final hasFilter = _search.isNotEmpty || _tabIndex != 0;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.label_outline_rounded,
              size: 28, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 14),
        Text(
            hasFilter
                ? 'No results found'
                : 'No user categories yet',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(
            hasFilter
                ? 'Try adjusting your search or filters.'
                : 'Add your first user category to get started.',
            style:
                const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        if (hasFilter) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _search = '';
              _tabIndex = 0;
            }),
            child: const Text('Clear filters',
                style: TextStyle(color: _teal)),
          ),
        ] else ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openForm,
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add Category',
                style: TextStyle(fontSize: 13)),
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

const _kUCHdr = TextStyle(
    fontSize: 12,
    color: Color(0xFF6B7280),
    fontWeight: FontWeight.w500);

// ── User Category Form Panel ──────────────────────────────────────────────────
class UserCategoryFormPanel extends StatefulWidget {
  final Map? category;
  final VoidCallback onSaved;
  const UserCategoryFormPanel(
      {super.key, this.category, required this.onSaved});
  @override
  State<UserCategoryFormPanel> createState() =>
      _UserCategoryFormPanelState();
}

class _UserCategoryFormPanelState extends State<UserCategoryFormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;
  bool _isActive = true;
  Set<String> _permissions = {};

  static const _primary = Color(0xFF0C2D3F);
  static const _accent = Color(0xFF0D9488);
  static const _gradient2 = Color(0xFF0F766E);

  bool get _isEdit =>
      widget.category != null && widget.category!['_id'] != null;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameCtrl.text = widget.category!['name'] ?? '';
      _descCtrl.text = widget.category!['description'] ?? '';
      _isActive = widget.category!['isActive'] ?? true;
      final perms = widget.category!['permissions'];
      if (perms is List) _permissions = Set<String>.from(perms);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'isActive': _isActive,
      'permissions': _permissions.toList(),
    };
    final res = !_isEdit
        ? await ApiService.post('/user-categories', body)
        : await ApiService.put(
            '/user-categories/${widget.category!['_id']}', body);
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

  Widget _permissionsEditor() {
    final sections = <String, List<ScreenDef>>{};
    for (final s in kAllScreens) {
      sections.putIfAbsent(s.section, () => []).add(s);
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE3E0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Icon(Icons.security_outlined, size: 16, color: _accent),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Screen Access Permissions',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
            ),
            TextButton(
              onPressed: () => setState(() {
                if (_permissions.length == kAllScreens.length) {
                  _permissions = {};
                } else {
                  _permissions = kAllScreens.map((s) => s.key).toSet();
                }
              }),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _permissions.length == kAllScreens.length ? 'Clear All' : 'Select All',
                style: TextStyle(fontSize: 11, color: _accent),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        ...sections.entries.map((entry) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(entry.key.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.8)),
            ),
            ...entry.value.map((screen) => InkWell(
              onTap: () => setState(() {
                if (_permissions.contains(screen.key)) {
                  _permissions.remove(screen.key);
                } else {
                  _permissions.add(screen.key);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(children: [
                  Checkbox(
                    value: _permissions.contains(screen.key),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _permissions.add(screen.key);
                      } else {
                        _permissions.remove(screen.key);
                      }
                    }),
                    activeColor: _accent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  Text(screen.label,
                      style: TextStyle(
                          fontSize: 13,
                          color: _permissions.contains(screen.key)
                              ? const Color(0xFF111827)
                              : const Color(0xFF6B7280))),
                ]),
              ),
            )),
            const SizedBox(height: 4),
          ],
        )),
        const SizedBox(height: 4),
      ]),
    );
  }

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
        child: Text('Status', style: TextStyle(fontSize: 13, color: Colors.grey)),
      ),
      Text(
        _isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: _isActive ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
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
          const Icon(Icons.label_outline_rounded,
              color: Colors.white70, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                  _isEdit
                      ? 'Edit User Category'
                      : 'Add User Category',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                _isEdit
                    ? 'Update category information'
                    : 'Fill in details to create a category',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 11),
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
            TextFormField(
              controller: _nameCtrl,
              decoration: _dec(
                  'Category Name', Icons.label_outline_rounded,
                  hint: 'e.g. Operator, Supervisor, Contractor'),
              validator: (v) =>
                  v!.trim().isEmpty ? 'Category name is required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: _dec('Description', Icons.notes_rounded,
                  hint: 'Optional'),
            ),
            const SizedBox(height: 14),
            _activeToggle(),
            const SizedBox(height: 20),
            _permissionsEditor(),
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
                      style:
                          TextStyle(color: Colors.grey, fontSize: 14)),
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
                            _isEdit ? 'Save Changes' : 'Add Category',
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
