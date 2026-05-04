import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

// ── Generic Master List + Form ─────────────────────────────────────────────────
class _MasterListScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String endpoint;
  final Widget Function(Map item, VoidCallback onEdit, VoidCallback onDelete) cardBuilder;
  final Widget Function(Map? item, VoidCallback onSaved) formBuilder;

  const _MasterListScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.endpoint,
    required this.cardBuilder,
    required this.formBuilder,
  });

  @override
  State<_MasterListScreen> createState() => _MasterListScreenState();
}

class _MasterListScreenState extends State<_MasterListScreen> {
  List _items = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get(widget.endpoint);
    if (mounted) setState(() { _items = res['data'] ?? []; _loading = false; });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('${widget.endpoint}/$id');
    if (mounted) { showSnack(context, res['success'] == true ? 'Deleted' : res['message'], error: res['success'] != true); if (res['success'] == true) _load(); }
  }

  void _openForm([Map? item]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: widget.formBuilder(item, _load),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty ? _items : _items.where((i) =>
      (i['name'] ?? '').toLowerCase().contains(_search.toLowerCase())).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
      body: Column(children: [
        ScreenHeader(title: widget.title, subtitle: widget.subtitle, onRefresh: _load),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Search...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const EmptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => widget.cardBuilder(
                          filtered[i],
                          () => _openForm(filtered[i]),
                          () => _delete(filtered[i]['_id']),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

Widget _simpleCard(Map item, VoidCallback onEdit, VoidCallback onDelete, IconData icon, Color color) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 22)),
      title: Text(item['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: item['description'] != null ? Text(item['description']) : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (item['isActive'] == false) const StatusBadge(label: 'Inactive', color: Colors.red),
        PopupMenuButton(
          itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red)))],
          onSelected: (v) { if (v == 'edit') onEdit(); else onDelete(); },
        ),
      ]),
    ),
  );
}

// ── Simple Form ────────────────────────────────────────────────────────────────
class _SimpleForm extends StatefulWidget {
  final String label, endpoint;
  final Map? item;
  final VoidCallback onSaved;
  final List<Widget> Function(Map<String, TextEditingController> ctrls)? extraFields;

  const _SimpleForm({required this.label, required this.endpoint, this.item, required this.onSaved, this.extraFields});

  @override
  State<_SimpleForm> createState() => _SimpleFormState();
}

class _SimpleFormState extends State<_SimpleForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _ctrls = {
    'name': TextEditingController(text: widget.item?['name'] ?? ''),
    'description': TextEditingController(text: widget.item?['description'] ?? ''),
  };
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = _ctrls.map((k, v) => MapEntry(k, v.text));
    final res = widget.item == null
        ? await ApiService.post(widget.endpoint, body)
        : await ApiService.put('${widget.endpoint}/${widget.item!['_id']}', body);
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Saved!' : res['message'], error: res['success'] != true);
      if (res['success'] == true) { Navigator.pop(context); widget.onSaved(); }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.item == null ? 'Add ${widget.label}' : 'Edit ${widget.label}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(controller: _ctrls['name'], decoration: InputDecoration(labelText: widget.label + ' Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          if (widget.extraFields == null) TextFormField(controller: _ctrls['description'], decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          if (widget.extraFields != null) ...widget.extraFields!(_ctrls),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save'))),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// CATEGORY SCREEN
// ════════════════════════════════════════════════
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});
  @override
  Widget build(BuildContext context) => _MasterListScreen(
    title: 'Categories',
    subtitle: 'Organize and manage material categories',
    endpoint: '/categories',
    cardBuilder: (item, onEdit, onDelete) => _simpleCard(item, onEdit, onDelete, Icons.category, Colors.purple),
    formBuilder: (item, onSaved) => _SimpleForm(label: 'Category', endpoint: '/categories', item: item, onSaved: onSaved),
  );
}

// ════════════════════════════════════════════════
// MATERIAL SCREEN
// ════════════════════════════════════════════════
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
    var list = _items.where((m) =>
        q.isEmpty ||
        (m['name'] ?? '').toString().toLowerCase().contains(q) ||
        (m['code'] ?? '').toString().toLowerCase().contains(q) ||
        (m['category']?['name'] ?? '').toString().toLowerCase().contains(q)).toList();

    list.sort((a, b) {
      switch (_sortBy) {
        case 'name_desc':
          return (b['name'] ?? '').compareTo(a['name'] ?? '');
        case 'category':
          return (a['category']?['name'] ?? '').compareTo(b['category']?['name'] ?? '');
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
      showSnack(context,
          res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  void _showSortMenu(BuildContext anchorCtx) {
    const items = {
      'name_asc': 'Name A → Z',
      'name_desc': 'Name Z → A',
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
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.normal)),
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
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _green))
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

  // ── Toolbar ──────────────────────────────────────────────────────────────

  Widget _buildToolbar(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 20, vertical: 10),
      child: Row(
        children: [
          if (isMobile) ...[
            Expanded(
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF111827)),
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    hintStyle:
                        TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 16, color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(top: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (!isMobile) Builder(builder: (ctx) => _sortBtn(ctx)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${_filtered.length} rows',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280))),
          ),
          if (isMobile) ...[
            const SizedBox(width: 8),
            _addBtn(),
          ],
        ],
      ),
    );
  }

  Widget _sortBtn(BuildContext ctx) {
    const labels = {
      'name_asc': 'Name A → Z',
      'name_desc': 'Name Z → A',
      'category': 'By Category',
    };
    final sorted = _sortBy != 'name_asc';
    return _toolbarSurface(
      onTap: () => _showSortMenu(ctx),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.swap_vert_rounded,
            size: 14,
            color: sorted ? _green : const Color(0xFF6B7280)),
        const SizedBox(width: 6),
        Text(labels[_sortBy] ?? 'Sort',
            style: TextStyle(
                fontSize: 13,
                color: sorted ? _green : const Color(0xFF374151),
                fontWeight:
                    sorted ? FontWeight.w500 : FontWeight.w400)),
      ]),
    );
  }

  Widget _toolbarSurface(
      {required VoidCallback onTap, required Widget child}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _addBtn() => ElevatedButton(
        onPressed: _openForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 34),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        child: const Icon(Icons.add_rounded, size: 16),
      );

  // ── Desktop table ────────────────────────────────────────────────────────

  Widget _buildTable(List rows) {
    return Column(
      children: [
        Container(
          color: const Color(0xFFF9FAFB),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: const Row(children: [
            SizedBox(width: 28, child: Text('#', style: _kMatHdr)),
            SizedBox(width: 12),
            Expanded(
                flex: 3, child: Text('Material Name', style: _kMatHdr)),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
          child: Row(children: [
            SizedBox(
              width: 28,
              child: Text('${index + 1}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF))),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _nameCell(item, index)),
            Expanded(flex: 2, child: _codeCell(item['code'])),
            Expanded(
              flex: 2,
              child: Text(item['category']?['name'] ?? '—',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF374151)),
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 1,
              child: Text(item['unit'] ?? '—',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF374151))),
            ),
            _actionMenu(item),
          ]),
        ),
      ),
    );
  }

  // ── Cells ────────────────────────────────────────────────────────────────

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
          color: bg,
          borderRadius: BorderRadius.circular(size * 0.28)),
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
      return const Text('—',
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
              fontSize: 11,
              fontFamily: 'monospace',
              color: Color(0xFF374151))),
    );
  }

  // ── Mobile list ──────────────────────────────────────────────────────────

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
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(item['name'] ?? '',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
              const SizedBox(height: 2),
              Text(
                '${item['category']?['name'] ?? '—'}  ·  ${item['unit'] ?? ''}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ]),
          ),
          _actionMenu(item),
        ]),
      ),
    );
  }

  // ── Action menu ──────────────────────────────────────────────────────────

  Widget _actionMenu(Map item) {
    return SizedBox(
      width: 40,
      child: PopupMenuButton(
        icon: const Icon(Icons.more_horiz_rounded,
            size: 18, color: Color(0xFF9CA3AF)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 3,
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined,
                  size: 15, color: Color(0xFF374151)),
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
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFFDC2626))),
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

  // ── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    final hasFilter = _search.isNotEmpty;
    return Center(
      child:
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF6B7280))),
        if (hasFilter) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _search = '';
              _searchCtrl.clear();
            }),
            child: const Text('Clear filters',
                style: TextStyle(color: _green)),
          ),
        ] else ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openForm,
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add Material',
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

const _kMatHdr = TextStyle(
    fontSize: 12,
    color: Color(0xFF6B7280),
    fontWeight: FontWeight.w500);

// ── Material form panel ───────────────────────────────────────────────────────

class MaterialFormPanel extends StatefulWidget {
  final Map? item;
  final List categories;
  final VoidCallback onSaved;

  const MaterialFormPanel(
      {super.key,
      this.item,
      required this.categories,
      required this.onSaved});

  @override
  State<MaterialFormPanel> createState() => _MaterialFormPanelState();
}

class _MaterialFormPanelState extends State<MaterialFormPanel> {
  final _formKey = GlobalKey<FormState>();
  String? _unit = 'pcs';
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

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
      _categoryCtrl.text = widget.item!['category']?['name'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _categoryCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final body = {
      'name': _nameCtrl.text.trim(),
      'code': _codeCtrl.text.trim(),
      'category': _categoryCtrl.text.trim(),
      'unit': _unit,
      'description': _descCtrl.text.trim(),
    };

    final res = widget.item == null
        ? await ApiService.post('/materials', body)
        : await ApiService.put(
            '/materials/${widget.item!['_id']}', body);

    if (mounted) {
      showSnack(
          context,
          res['success'] == true
              ? 'Saved successfully!'
              : res['message'],
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
      labelStyle:
          const TextStyle(fontSize: 13, color: Colors.grey),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    Text(
                        isNew ? 'Add New Material' : 'Edit Material',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      isNew
                          ? 'Fill in the details to create a material'
                          : 'Update the material information below',
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
                  TextFormField(
                    controller: _categoryCtrl,
                    decoration: _fieldDecoration(
                        'Category', Icons.category_outlined),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter a category'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: _fieldDecoration(
                        'Unit', Icons.straighten_rounded),
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF1A1A2E)),
                    borderRadius: BorderRadius.circular(10),
                    items: [
                      'pcs', 'kg', 'ton', 'ltr', 'mtr',
                      'sqft', 'sqm', 'bag', 'box', 'set'
                    ]
                        .map((u) =>
                            DropdownMenuItem(value: u, child: Text(u)))
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
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(
                              color: Color(0xFFDDE3E0)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 14)),
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
                          color: _saving
                              ? const Color(0xFFD1D5DB)
                              : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2))
                              : Text(
                                  isNew
                                      ? 'Add Material'
                                      : 'Save Changes',
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

// ════════════════════════════════════════════════
// USER SCREEN (Admin only)
// ════════════════════════════════════════════════
class UserScreen extends StatefulWidget {
  const UserScreen({super.key});
  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  List _users = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/users');
    if (mounted) setState(() { _users = res['data'] ?? []; _loading = false; });
  }

  Future<void> _delete(String id) async {
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/users/$id');
    if (mounted) { showSnack(context, res['success'] == true ? 'User deactivated' : res['message'], error: res['success'] != true); if (res['success'] == true) _load(); }
  }

  void _openForm([Map? user]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _UserForm(item: user, onSaved: _load),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.person_add)),
      body: Column(children: [
        ScreenHeader(
          title: 'Users',
          subtitle: 'Manage system users and access permissions',
          onRefresh: _load,
        ),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const EmptyState(message: 'No users', icon: Icons.people)
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(u['name']?.substring(0, 1).toUpperCase() ?? 'U')),
                        title: Text(u['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${u['email']} · ${u['branch']?['name'] ?? 'No branch'}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          StatusBadge(label: u['role'] ?? 'user', color: u['role'] == 'admin' ? Colors.purple : Colors.blue),
                          PopupMenuButton(
                            itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Deactivate', style: TextStyle(color: Colors.red)))],
                            onSelected: (v) {
                              if (v == 'edit') { _openForm(u); } else { _delete(u['_id']); }
                            },
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _UserForm extends StatefulWidget {
  final Map? item;
  final VoidCallback onSaved;
  const _UserForm({this.item, required this.onSaved});
  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _formKey = GlobalKey<FormState>();
  List _branches = [];
  String? _branchId, _role = 'user';
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    if (widget.item != null) {
      _nameCtrl.text = widget.item!['name'] ?? '';
      _emailCtrl.text = widget.item!['email'] ?? '';
      _phoneCtrl.text = widget.item!['phone'] ?? '';
      _role = widget.item!['role'] ?? 'user';
      _branchId = widget.item!['branch']?['_id'];
    }
  }

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches');
    if (mounted) setState(() => _branches = res['data'] ?? []);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = { 'name': _nameCtrl.text, 'email': _emailCtrl.text, 'phone': _phoneCtrl.text, 'role': _role, 'branch': _branchId, if (widget.item == null && _passCtrl.text.isNotEmpty) 'password': _passCtrl.text, if (widget.item != null && _passCtrl.text.isNotEmpty) 'password': _passCtrl.text };
    final res = widget.item == null ? await ApiService.post('/users', body) : await ApiService.put('/users/${widget.item!['_id']}', body);
    if (mounted) { showSnack(context, res['success'] == true ? 'Saved!' : res['message'], error: res['success'] != true); if (res['success'] == true) { Navigator.pop(context); widget.onSaved(); } }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.item == null ? 'Add User' : 'Edit User', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextFormField(controller: _passCtrl, obscureText: true, decoration: InputDecoration(labelText: widget.item == null ? 'Password' : 'New Password (leave blank to keep)'), validator: (v) => widget.item == null && v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            AppDropdown<String>(label: 'Role', value: _role, items: const [DropdownMenuItem(value: 'user', child: Text('User')), DropdownMenuItem(value: 'admin', child: Text('Admin'))], onChanged: (v) => setState(() => _role = v)),
            const SizedBox(height: 12),
            AppDropdown<String>(label: 'Branch', value: _branchId, items: _branches.map<DropdownMenuItem<String>>((b) => DropdownMenuItem(value: b['_id'], child: Text(b['name']))).toList(), onChanged: (v) => setState(() => _branchId = v)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save'))),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
