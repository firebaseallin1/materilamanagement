import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

const _expCatAccent = Color(0xFFEA580C);

// ════════════════════════════════════════════════
// EXPENSE CATEGORY SCREEN
// ════════════════════════════════════════════════
class ExpenseCategoryScreen extends StatefulWidget {
  const ExpenseCategoryScreen({super.key});
  @override
  State<ExpenseCategoryScreen> createState() => _ExpenseCategoryScreenState();
}

class _ExpenseCategoryScreenState extends State<ExpenseCategoryScreen> {
  List _categories = [];
  bool _loading = true;
  String _search = '';
  String _sortBy = 'name_asc';

  final _searchCtrl = TextEditingController();

  List get _filtered {
    final q = _search.toLowerCase();
    var list = _categories.where((c) {
      return q.isEmpty ||
          (c['name'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) {
      if (_sortBy == 'name_desc')
        return (b['name'] ?? '').compareTo(a['name'] ?? '');
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
    final res = await ApiService.get('/expense-categories');
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
          borderRadius:
              const BorderRadius.horizontal(left: Radius.circular(20)),
          child: SizedBox(
            width: panelWidth,
            height: MediaQuery.of(ctx).size.height,
            child: ExpenseCategoryFormPanel(category: category, onSaved: _load),
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
    final res = await ApiService.delete('/expense-categories/$id');
    if (mounted) {
      showSnack(context, res['success'] == true ? 'Deleted' : res['message'],
          error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  void _showSortMenu(BuildContext anchorCtx) {
    const items = {'name_asc': 'Name A → Z', 'name_desc': 'Name Z → A'};
    final box = anchorCtx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final position = RelativeRect.fromLTRB(offset.dx,
        offset.dy + box.size.height + 4, offset.dx + box.size.width, 0);
    showMenu<String>(
      context: anchorCtx,
      position: position,
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
              color: active ? _expCatAccent : const Color(0xFFD1D5DB),
            ),
            const SizedBox(width: 10),
            Text(e.value,
                style: TextStyle(
                    fontSize: 13,
                    color: active ? _expCatAccent : const Color(0xFF374151),
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
              title: 'Expense Categories',
              subtitle: 'Manage expense category master data',
              onRefresh: _load,
              onSearchChanged: (v) => setState(() => _search = v),
              searchHint: 'Search categories...',
              onAdd: _openForm,
              addLabel: 'Add Category',
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
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF111827)),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${_filtered.length} rows',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
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
              color: sorted ? _expCatAccent : const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(labels[_sortBy] ?? 'Sort',
              style: TextStyle(
                  fontSize: 13,
                  color: sorted ? _expCatAccent : const Color(0xFF374151),
                  fontWeight: sorted ? FontWeight.w500 : FontWeight.w400)),
        ]),
      ),
    );
  }

  Widget _addBtn() => ElevatedButton(
        onPressed: _openForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: _expCatAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Icon(Icons.add_rounded, size: 16),
      );

  // ── Desktop card list ────────────────────────────────────────────────────────

  Widget _buildTable(List rows) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      itemCount: rows.length,
      itemBuilder: (_, i) => _buildCard(rows[i], i),
    );
  }

  Widget _buildCard(Map c, int index) {
    final accent = _cardColor(index);
    final name = c['name'] as String? ?? '';
    final desc = (c['description'] as String? ?? '').trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return InkWell(
      onTap: () => _openForm(c),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Left accent strip
            Container(width: 4, color: accent),

            // Index badge
            Container(
              width: 40,
              alignment: Alignment.center,
              child: Text('${index + 1}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFCBD5E1))),
            ),

            // Avatar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(initial,
                      style: TextStyle(
                          color: accent,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Name + description
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827)),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      desc.isNotEmpty ? desc : 'No description added',
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
                  ],
                ),
              ),
            ),

            const SizedBox(width: 4),

            // Category label chip
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                child: Text('Category',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: accent)),
              ),
            ),

            // Actions
            Center(child: _actionMenu(c)),
            const SizedBox(width: 4),
          ]),
        ),
      ),
    );
  }

  // ── Mobile card list ─────────────────────────────────────────────────────────

  Widget _buildMobileList(List rows) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: rows.length,
      itemBuilder: (_, i) => _mobileCard(rows[i], i),
    );
  }

  Widget _mobileCard(Map c, int index) {
    final accent = _cardColor(index);
    final name = c['name'] as String? ?? '';
    final desc = (c['description'] as String? ?? '').trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF2F6)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Left accent strip
          Container(width: 4, color: accent),

          // Body
          Expanded(
            child: InkWell(
              onTap: () => _openForm(c),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Soft avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(initial,
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827)),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(
                              desc.isNotEmpty ? desc : 'No description added',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: desc.isNotEmpty
                                      ? const Color(0xFF6B7280)
                                      : const Color(0xFFD1D5DB),
                                  fontStyle: desc.isEmpty
                                      ? FontStyle.italic
                                      : FontStyle.normal),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // Category tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Expense Category',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: accent)),
                            ),
                          ],
                        ),
                      ),
                      _actionMenu(c),
                    ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Color _cardColor(int index) {
    const colors = [
      Color(0xFFEA580C),
      Color(0xFFDC2626),
      Color(0xFFDB2777),
      Color(0xFF9333EA),
      Color(0xFF2563EB),
      Color(0xFF0D9488),
      Color(0xFF16A34A),
      Color(0xFFF59E0B),
    ];
    return colors[index % colors.length];
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
              ])),
          PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded,
                    size: 15, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('Delete',
                    style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
              ])),
        ],
        onSelected: (val) {
          if (val == 'edit') _openForm(c);
          if (val == 'delete') _delete(c['_id']);
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.receipt_long_outlined,
              size: 28, color: _expCatAccent),
        ),
        const SizedBox(height: 14),
        Text(
            _search.isNotEmpty
                ? 'No results found'
                : 'No expense categories yet',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(
          _search.isNotEmpty
              ? 'Try a different search term.'
              : 'Add your first expense category to get started.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        if (_search.isNotEmpty) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _search = '';
              _searchCtrl.clear();
            }),
            child: const Text('Clear filters',
                style: TextStyle(color: _expCatAccent)),
          ),
        ] else ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openForm,
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add Category', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _expCatAccent,
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

// ── Expense Category Form Panel ───────────────────────────────────────────────
class ExpenseCategoryFormPanel extends StatefulWidget {
  final Map? category;
  final VoidCallback onSaved;
  const ExpenseCategoryFormPanel(
      {super.key, this.category, required this.onSaved});
  @override
  State<ExpenseCategoryFormPanel> createState() =>
      _ExpenseCategoryFormPanelState();
}

class _ExpenseCategoryFormPanelState extends State<ExpenseCategoryFormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  static const _primary = Color(0xFF1B5E37);
  static const _accent = Color(0xFF2E7D52);
  static const _gradient2 = Color(0xFF1E6F5C);

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameCtrl.text = widget.category!['name'] ?? '';
      _descCtrl.text = widget.category!['description'] ?? '';
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
    };
    final res = widget.category == null
        ? await ApiService.post('/expense-categories', body)
        : await ApiService.put(
            '/expense-categories/${widget.category!['_id']}', body);
    if (mounted) {
      print('res : ${res['success']}');
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
        fillColor: Colors.white,
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
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 2),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _gradient2],
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
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.receipt_long_outlined,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        isNew
                            ? 'Add Expense Category'
                            : 'Edit Expense Category',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      isNew
                          ? 'Fill in the details to create a category'
                          : 'Update the category information below',
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
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close, color: Colors.white70, size: 16),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Form(
            key: _formKey,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: _dec('Category Name', Icons.receipt_long_outlined,
                    hint: 'e.g. Labour, Fuel, Maintenance'),
                validator: (v) =>
                    v!.trim().isEmpty ? 'Category name is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration:
                    _dec('Description', Icons.notes_rounded, hint: 'Optional'),
              ),
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
                          : Text(isNew ? 'Add Category' : 'Save Changes',
                              style: const TextStyle(
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
      ],
    );
  }
}
