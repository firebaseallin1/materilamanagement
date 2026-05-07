import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  List _locations = [];
  bool _loading = true;
  String _search = '';
  String _sortBy = 'name_asc'; // name_asc | name_desc

  final _searchCtrl = TextEditingController(); // mobile only

  static const _primary = Color(0xFF111827);
  static const _green = Color(0xFF16A34A);

  // ── Filtered + sorted list ───────────────────────────────────────────────

  List get _filtered {
    final q = _search.toLowerCase();
    var list = _locations
        .where((l) =>
            q.isEmpty || (l['name'] ?? '').toString().toLowerCase().contains(q))
        .toList();

    list.sort((a, b) {
      if (_sortBy == 'name_desc') {
        return (b['name'] ?? '').compareTo(a['name'] ?? '');
      }
      return (a['name'] ?? '').compareTo(b['name'] ?? '');
    });

    return list;
  }

  // ── Init / load ──────────────────────────────────────────────────────────

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
    final res = await ApiService.get('/locations');
    if (mounted) {
      setState(() {
        _locations = res['data'] ?? [];
        _loading = false;
      });
    }
  }

  // ── Form panel ───────────────────────────────────────────────────────────

  void _openForm([Map? location]) {
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
            child: LocationFormPanel(location: location, onSaved: _load),
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

  // ── Sort menu ────────────────────────────────────────────────────────────

  void _showSortMenu(BuildContext anchorCtx) {
    const items = {
      'name_asc': 'Name A → Z',
      'name_desc': 'Name Z → A',
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

  // ── Build ────────────────────────────────────────────────────────────────

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
              title: 'Locations',
              subtitle: 'Manage warehouse and storage locations',
              onRefresh: _load,
              onSearchChanged: (v) => setState(() => _search = v),
              searchHint: 'Search locations...',
              onAdd: _openForm,
              addLabel: 'Add Location',
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

  // ── Toolbar ──────────────────────────────────────────────────────────────

  Widget _buildToolbar(bool isMobile) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
      child: Row(
        children: [
          // Mobile: search field
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

          // Desktop: sort button
          if (!isMobile) Builder(builder: (ctx) => _sortBtn(ctx)),

          const Spacer(),

          // Row count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${_filtered.length} rows',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),

          // Mobile: compact add button
          if (isMobile) ...[
            const SizedBox(width: 8),
            _addBtn(),
          ],
        ],
      ),
    );
  }

  // ── Sort button ──────────────────────────────────────────────────────────

  Widget _sortBtn(BuildContext ctx) {
    const labels = {
      'name_asc': 'Name A → Z',
      'name_desc': 'Name Z → A',
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

  // ── Add button (mobile / compact) ────────────────────────────────────────

  Widget _addBtn() => ElevatedButton(
        onPressed: _openForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            SizedBox(width: 28, child: Text('#', style: _kHdr)),
            SizedBox(width: 12),
            Expanded(flex: 3, child: Text('Location Name', style: _kHdr)),
            Expanded(flex: 4, child: Text('Address', style: _kHdr)),
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

  Widget _buildRow(Map loc, int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openForm(loc),
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
            Expanded(flex: 3, child: _nameCell(loc, index)),
            Expanded(
              flex: 4,
              child: Text(loc['address'] ?? '—',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                  overflow: TextOverflow.ellipsis),
            ),
            _actionMenu(loc),
          ]),
        ),
      ),
    );
  }

  // ── Cells ────────────────────────────────────────────────────────────────

  Widget _nameCell(Map loc, int index) {
    return Row(children: [
      _avatar(loc, index),
      const SizedBox(width: 10),
      Flexible(
        child: Text(loc['name'] ?? '',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827)),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }

  Widget _avatar(Map loc, int index, {double size = 28}) {
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
          (loc['name'] as String? ?? '').isNotEmpty
              ? (loc['name'] as String)[0].toUpperCase()
              : '?',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.42),
        ),
      ),
    );
  }

  // ── Mobile list ──────────────────────────────────────────────────────────

  Widget _buildMobileList(List rows) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final loc = rows[i];
        const bgs = [
          Color(0xFF6366F1),
          Color(0xFF10B981),
          Color(0xFFF59E0B),
          Color(0xFFEF4444),
          Color(0xFF8B5CF6),
        ];
        final name = (loc['name'] ?? '') as String;
        return InkWell(
          onTap: () => _openForm(loc),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: bgs[i % bgs.length],
                    borderRadius: BorderRadius.circular(10)),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827))),
                    if ((loc['address'] ?? '').toString().isNotEmpty)
                      Text(loc['address'].toString(),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280)),
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _actionMenu(loc),
            ]),
          ),
        );
      },
    );
  }

  // ── Action menu ──────────────────────────────────────────────────────────

  Widget _actionMenu(Map loc) {
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
          if (val == 'edit') _openForm(loc);
        },
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────

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
          child: const Icon(Icons.location_on_outlined,
              size: 28, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 14),
        Text(hasFilter ? 'No results found' : 'No locations yet',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(
            hasFilter
                ? 'Try a different search term.'
                : 'Add your first location to get started.',
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
            label: const Text('Add Location', style: TextStyle(fontSize: 13)),
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

// ── Constants ─────────────────────────────────────────────────────────────────

const _kHdr = TextStyle(
    fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);

// ── Location form panel ───────────────────────────────────────────────────────

class LocationFormPanel extends StatefulWidget {
  final Map? location;
  final VoidCallback onSaved;

  const LocationFormPanel({super.key, this.location, required this.onSaved});

  @override
  State<LocationFormPanel> createState() => _LocationFormPanelState();
}

class _LocationFormPanelState extends State<LocationFormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  static const _primary = Color(0xFF1B3A27);
  static const _accent = Color(0xFF2E7D52);

  @override
  void initState() {
    super.initState();
    if (widget.location != null) {
      _nameCtrl.text = widget.location!['name'] ?? '';
      _addressCtrl.text = widget.location!['address'] ?? '';
      _descCtrl.text = widget.location!['description'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final body = {
      'name': _nameCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
    };

    final res = widget.location == null
        ? await ApiService.post('/locations', body)
        : await ApiService.put('/locations/${widget.location!['_id']}', body);

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

  @override
  Widget build(BuildContext context) {
    final isNew = widget.location == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        // Drag handle
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 2),
        // Gradient header
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
              child: const Icon(Icons.location_on_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isNew ? 'Add New Location' : 'Edit Location',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      isNew
                          ? 'Fill in the details to create a location'
                          : 'Update the location information below',
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
        // Form
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
                        'Location Name', Icons.location_on_outlined,
                        hint: 'e.g. Headquarters, Warehouse A'),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _addressCtrl,
                    maxLines: 3,
                    decoration: _fieldDecoration(
                        'Full Address', Icons.home_outlined,
                        hint: 'Street address, city, zip code'),
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
                              : Text(isNew ? 'Add Location' : 'Save Changes',
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
