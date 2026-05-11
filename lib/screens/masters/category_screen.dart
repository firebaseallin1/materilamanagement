import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// CATEGORY SCREEN
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List _categories = [];
  bool _loading = true;
  String _search = '';
  int _tabIndex = 0;
  String _sortBy = 'name_asc';

  final _searchCtrl = TextEditingController();

  static const _primary = Color(0xFF111827);
  static const _green = Color(0xFF16A34A);

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
      if (_sortBy == 'name_desc') return (b['name'] ?? '').compareTo(a['name'] ?? '');
      return (a['name'] ?? '').compareTo(b['name'] ?? '');
    });

    return list;
  }

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
    setState(() => _loading = true);
    final res = await ApiService.get('/categories');
    if (mounted) {
      setState(() {
        _categories = res['data'] ?? [];
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
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
          child: SizedBox(
            width: panelWidth,
            height: MediaQuery.of(ctx).size.height,
            child: CategoryFormPanel(category: category, onSaved: _load),
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
    final res = await ApiService.delete('/categories/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  void _showSortMenu(BuildContext anchorCtx) {
    const items = {
      'name_asc': 'Name A-Z',
      'name_desc': 'Name Z-A',
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
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ]),
        );
      }).toList(),
    ).then((val) {
      if (val != null) setState(() => _sortBy = val);
    });
  }

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
              title: 'Categories',
              subtitle: 'Organize and manage material categories',
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

  Widget _buildToolbar(bool isMobile) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
      child: Row(
        children: [
          if (!isMobile) Builder(builder: (ctx) => _sortBtn(ctx)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${_filtered.length} rows',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),
        ],
      ),
    );
  }

  Widget _sortBtn(BuildContext ctx) {
    const labels = {'name_asc': 'Name A-Z', 'name_desc': 'Name Z-A'};
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

  Widget _toolbarSurface({required VoidCallback onTap, required Widget child}) {
    return InkWell(
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
  }

  RelativeRect _buttonPosition(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    return RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + box.size.height + 4,
      offset.dx + box.size.width,
      0,
    );
  }


  Widget _buildTable(List rows) {
    return Column(
      children: [
        Container(
          color: const Color(0xFFF9FAFB),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: const Row(children: [
            SizedBox(width: 28, child: Text('#', style: _kCatHdr)),
            SizedBox(width: 12),
            Expanded(flex: 3, child: Text('Category Name', style: _kCatHdr)),
            Expanded(flex: 4, child: Text('Description', style: _kCatHdr)),
            SizedBox(
                width: 88,
                child: Text('Status', style: _kCatHdr, textAlign: TextAlign.center)),
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
      ],
    );
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
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
          child: Row(children: [
            SizedBox(
              width: 28,
              child: Text('${index + 1}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _nameCell(c, index)),
            Expanded(
              flex: 4,
              child: Text(c['description'] ?? 'â€"',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
                width: 88,
                child: Center(child: _statusBadge(isActive == true))),
            _actionMenu(c),
          ]),
        ),
      ),
    );
  }

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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['name'] ?? '',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
              const SizedBox(height: 2),
              Text(c['description'] ?? 'â€"',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          _statusBadge(isActive == true),
          _actionMenu(c),
        ]),
      ),
    );
  }

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
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF3B82F6),
    ];
    final bg = bgs[index % bgs.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Center(
        child: Text(
          (c['name'] as String? ?? '').isNotEmpty
              ? (c['name'] as String)[0].toUpperCase()
              : '?',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.42),
        ),
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
            color:
                active ? const Color(0xFF166534) : const Color(0xFF6B7280)),
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
              Icon(Icons.edit_outlined, size: 15, color: Color(0xFF374151)),
              SizedBox(width: 8),
              Text('Edit', style: TextStyle(fontSize: 13)),
            ]),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline_rounded,
                  size: 15, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Delete',
                  style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
            ]),
          ),
        ],
        onSelected: (val) {
          if (val == 'edit') _openForm(c);
          if (val == 'delete') _delete(c['_id']);
        },
      ),
    );
  }

  Widget _buildEmpty() {
    final hasFilter = _search.isNotEmpty;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.category_outlined,
              size: 28, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 14),
        Text(hasFilter ? 'No results found' : 'No categories yet',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(
            hasFilter
                ? 'Try a different search term.'
                : 'Add your first category to get started.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        if (hasFilter) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _search = '';
              _searchCtrl.clear();
            }),
            child: const Text('Clear filters', style: TextStyle(color: _green)),
          ),
        ] else ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openForm,
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add Category', style: TextStyle(fontSize: 13)),
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
        ],
      ]),
    );
  }
}

const _kCatHdr = TextStyle(
    fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);

// â"€â"€ Category form panel â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€

class CategoryFormPanel extends StatefulWidget {
  final Map? category;
  final VoidCallback onSaved;

  const CategoryFormPanel(
      {super.key, this.category, required this.onSaved});

  @override
  State<CategoryFormPanel> createState() => _CategoryFormPanelState();
}

class _CategoryFormPanelState extends State<CategoryFormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;
  bool _isActive = true;

  static const _primary = Color(0xFF1B3A27);
  static const _accent = Color(0xFF2E7D52);

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameCtrl.text = widget.category!['name'] ?? '';
      _descCtrl.text = widget.category!['description'] ?? '';
      _isActive = widget.category!['isActive'] ?? true;
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
    };
    final res = widget.category == null
        ? await ApiService.post('/categories', body)
        : await ApiService.put(
            '/categories/${widget.category!['_id']}', body);
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

  InputDecoration _fieldDecoration(String label, IconData icon,
      {String? hint}) {
    return InputDecoration(
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
        borderSide: const BorderSide(color: Color(0xFFDDE3E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDE3E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
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
    final isNew = widget.category == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, Color(0xFF1E6F5C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.category_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isNew ? 'Add New Category' : 'Edit Category',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      isNew
                          ? 'Fill in the details to create a category'
                          : 'Update the category information below',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                    ),
                  ]),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close,
                    color: Colors.white70, size: 16),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _fieldDecoration(
                      'Category Name', Icons.category_outlined,
                      hint: 'e.g. Steel, Cement, Electrical'),
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Category name is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: _fieldDecoration(
                      'Description', Icons.notes_rounded,
                      hint: 'Optional'),
                ),
                const SizedBox(height: 14),
                _activeToggle(),
                const SizedBox(height: 24),
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
                                colors: [_primary, Color(0xFF1E6F5C)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
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
                                isNew ? 'Add Category' : 'Save Changes',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// MATERIAL SCREEN
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class MaterialScreen extends StatefulWidget {
  const MaterialScreen({super.key});
  @override
  State<MaterialScreen> createState() => _MaterialScreenState();
}

class _MaterialScreenState extends State<MaterialScreen> {
  List _items = [];
  List _categories = [];
  bool _loading = true;
  String _search = '';
  String _sortBy = 'name_asc';

  final _searchCtrl = TextEditingController();

  static const _primary = Color(0xFF111827);
  static const _green = Color(0xFF16A34A);

  List get _filtered {
    final q = _search.toLowerCase();
    var list = _items
        .where((m) =>
            q.isEmpty ||
            (m['name'] ?? '').toString().toLowerCase().contains(q) ||
            (m['code'] ?? '').toString().toLowerCase().contains(q) ||
            (m['category']?['name'] ?? '').toString().toLowerCase().contains(q))
        .toList();

    list.sort((a, b) {
      switch (_sortBy) {
        case 'name_desc':
          return (b['name'] ?? '').compareTo(a['name'] ?? '');
        case 'category':
          return (a['category']?['name'] ?? '')
              .compareTo(b['category']?['name'] ?? '');
        default:
          return (a['name'] ?? '').compareTo(b['name'] ?? '');
      }
    });
    return list;
  }

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
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.get('/materials'),
      ApiService.get('/categories'),
    ]);
    if (mounted) {
      setState(() {
        _items = results[0]['data'] ?? [];
        _categories = results[1]['data'] ?? [];
        _loading = false;
      });
    }
  }

  void _openForm([Map? item]) {
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
            child: MaterialFormPanel(
                item: item, categories: _categories, onSaved: _load),
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
    final res = await ApiService.delete('/materials/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  void _showSortMenu(BuildContext anchorCtx) {
    const items = {
      'name_asc': 'Name A-Z',
      'name_desc': 'Name Z-A',
      'category': 'By Category',
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
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ]),
        );
      }).toList(),
    ).then((val) {
      if (val != null) setState(() => _sortBy = val);
    });
  }

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
              title: 'Materials',
              subtitle: 'Configure material master data and specifications',
              onRefresh: _load,
              onSearchChanged: (v) => setState(() => _search = v),
              searchHint: 'Search materials...',
              onAdd: _openForm,
              addLabel: 'Add Material',
            ),
            _buildToolbar(isMobile),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Expanded(
              child: _loading
                  ? const AppLoader()
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

  Widget _buildToolbar(bool isMobile) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
      child: Row(
        children: [
          if (!isMobile) Builder(builder: (ctx) => _sortBtn(ctx)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${_filtered.length} rows',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),
        ],
      ),
    );
  }

  Widget _sortBtn(BuildContext ctx) {
    const labels = {
      'name_asc': 'Name A-Z',
      'name_desc': 'Name Z-A',
      'category': 'By Category',
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

  Widget _toolbarSurface({required VoidCallback onTap, required Widget child}) {
    return InkWell(
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
  }

  RelativeRect _buttonPosition(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    return RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + box.size.height + 4,
      offset.dx + box.size.width,
      0,
    );
  }


  Widget _buildTable(List rows) {
    return Column(
      children: [
        Container(
          color: const Color(0xFFF9FAFB),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: const Row(children: [
            SizedBox(width: 28, child: Text('#', style: _kMatHdr)),
            SizedBox(width: 12),
            Expanded(flex: 3, child: Text('Material Name', style: _kMatHdr)),
            Expanded(flex: 2, child: Text('Code', style: _kMatHdr)),
            Expanded(flex: 2, child: Text('Category', style: _kMatHdr)),
            Expanded(flex: 1, child: Text('Unit', style: _kMatHdr)),
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
      ],
    );
  }

  Widget _buildRow(Map item, int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openForm(item),
        hoverColor: const Color(0xFFF9FAFB),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
          child: Row(children: [
            SizedBox(
              width: 28,
              child: Text('${index + 1}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _nameCell(item, index)),
            Expanded(flex: 2, child: _codeCell(item['code'])),
            Expanded(
              flex: 2,
              child: Text(item['category']?['name'] ?? 'â€"',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 1,
              child: Text(item['unit'] ?? 'â€"',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF374151))),
            ),
            _actionMenu(item),
          ]),
        ),
      ),
    );
  }

  Widget _nameCell(Map item, int index) {
    return Row(children: [
      _avatar(item, index),
      const SizedBox(width: 10),
      Flexible(
        child: Text(item['name'] ?? '',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827)),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }

  Widget _avatar(Map item, int index, {double size = 28}) {
    const bgs = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF3B82F6),
    ];
    final bg = bgs[index % bgs.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Center(
        child: Text(
          (item['name'] as String? ?? '').isNotEmpty
              ? (item['name'] as String)[0].toUpperCase()
              : '?',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.42),
        ),
      ),
    );
  }

  Widget _codeCell(dynamic code) {
    if (code == null || code.toString().isEmpty) {
      return const Text('â€"',
          style: TextStyle(fontSize: 13, color: Color(0xFFD1D5DB)));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(code.toString(),
          style: const TextStyle(
              fontSize: 11, fontFamily: 'monospace', color: Color(0xFF374151))),
    );
  }

  Widget _buildMobileList(List rows) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _mobileCard(rows[i], i),
    );
  }

  Widget _mobileCard(Map item, int index) {
    return InkWell(
      onTap: () => _openForm(item),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          _avatar(item, index, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] ?? '',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
              const SizedBox(height: 2),
              Text(
                '${item['category']?['name'] ?? 'â€"'}  Â·  ${item['unit'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ]),
          ),
          _actionMenu(item),
        ]),
      ),
    );
  }

  Widget _actionMenu(Map item) {
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
            ]),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline_rounded,
                  size: 15, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Delete',
                  style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
            ]),
          ),
        ],
        onSelected: (val) {
          if (val == 'edit') _openForm(item);
          if (val == 'delete') _delete(item['_id']);
        },
      ),
    );
  }

  Widget _buildEmpty() {
    final hasFilter = _search.isNotEmpty;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.widgets_outlined,
              size: 28, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 14),
        Text(hasFilter ? 'No results found' : 'No materials yet',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(
            hasFilter
                ? 'Try a different search term.'
                : 'Add your first material to get started.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        if (hasFilter) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _search = '';
              _searchCtrl.clear();
            }),
            child: const Text('Clear filters', style: TextStyle(color: _green)),
          ),
        ] else ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openForm,
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add Material', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ]),
    );
  }
}

const _kMatHdr = TextStyle(
    fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);

// â"€â"€ Material form panel â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€

class MaterialFormPanel extends StatefulWidget {
  final Map? item;
  final List categories;
  final VoidCallback onSaved;

  const MaterialFormPanel(
      {super.key, this.item, required this.categories, required this.onSaved});

  @override
  State<MaterialFormPanel> createState() => _MaterialFormPanelState();
}

class _MaterialFormPanelState extends State<MaterialFormPanel> {
  final _formKey = GlobalKey<FormState>();
  String? _unit = 'pcs';
  String? _categoryId;
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;
  bool _isActive = true;

  static const _primary = Color(0xFF1B3A27);
  static const _accent = Color(0xFF2E7D52);

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameCtrl.text = widget.item!['name'] ?? '';
      _codeCtrl.text = widget.item!['code'] ?? '';
      _descCtrl.text = widget.item!['description'] ?? '';
      _unit = widget.item!['unit'] ?? 'pcs';
      _categoryId = widget.item!['category']?['_id'];
      _isActive = widget.item!['isActive'] ?? true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final body = {
      'name': _nameCtrl.text.trim(),
      'code': _codeCtrl.text.trim(),
      'category': _categoryId,
      'unit': _unit,
      'description': _descCtrl.text.trim(),
      'isActive': _isActive,
    };

    final res = widget.item == null
        ? await ApiService.post('/materials', body)
        : await ApiService.put('/materials/${widget.item!['_id']}', body);

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

  InputDecoration _fieldDecoration(String label, IconData icon,
      {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: _accent),
      labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFFF7F9F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDE3E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDE3E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
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
    final isNew = widget.item == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, Color(0xFF1E6F5C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.widgets_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isNew ? 'Add New Material' : 'Edit Material',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      isNew
                          ? 'Fill in the details to create a material'
                          : 'Update the material information below',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ]),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close, color: Colors.white70, size: 16),
              ),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: _fieldDecoration(
                        'Material Name', Icons.widgets_outlined,
                        hint: 'e.g. Steel Rod, Portland Cement'),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codeCtrl,
                    decoration: _fieldDecoration(
                        'Material Code', Icons.tag_rounded,
                        hint: 'Optional (e.g. STL-001)'),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration:
                        _fieldDecoration('Category', Icons.category_outlined),
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF1A1A2E)),
                    borderRadius: BorderRadius.circular(10),
                    items: widget.categories
                        .map<DropdownMenuItem<String>>((c) => DropdownMenuItem(
                            value: c['_id'] as String,
                            child: Text(c['name'] as String)))
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (v) =>
                        v == null ? 'Please select a category' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration:
                        _fieldDecoration('Unit', Icons.straighten_rounded),
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                    borderRadius: BorderRadius.circular(10),
                    items: [
                      'pcs',
                      'kg',
                      'ton',
                      'ltr',
                      'mtr',
                      'sqft',
                      'sqm',
                      'bag',
                      'box',
                      'set'
                    ]
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v),
                    isExpanded: true,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: _fieldDecoration(
                        'Notes / Description', Icons.notes_rounded,
                        hint: 'Additional info...'),
                  ),
                  const SizedBox(height: 14),
                  _activeToggle(),
                  const SizedBox(height: 24),
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
                                  colors: [_primary, Color(0xFF1E6F5C)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          color: _saving ? const Color(0xFFD1D5DB) : null,
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
                              : Text(isNew ? 'Add Material' : 'Save Changes',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
