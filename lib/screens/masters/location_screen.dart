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
  int _tabIndex = 0;
  final _searchCtrl = TextEditingController();

  static const _dark = Color(0xFF111827);
  static const _green = Color(0xFF16A34A);

  List get _filtered => _locations.where((l) =>
      _search.isEmpty ||
      (l['name'] ?? '').toLowerCase().contains(_search.toLowerCase())).toList();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/locations');
    if (mounted) setState(() { _locations = res['data'] ?? []; _loading = false; });
  }

  void _openForm([Map? location]) {
    final sw = MediaQuery.of(context).size.width;
    final pw = sw > 900 ? sw * 0.35 : sw * 0.85;
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
            width: pw, height: MediaQuery.of(ctx).size.height,
            child: LocationFormPanel(location: location, onSaved: _load),
          ),
        ),
      ),
      transitionBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final rows = _filtered;
        return Column(children: [
          ScreenHeader(
            title: 'Locations',
            subtitle: 'Manage warehouse and storage locations',
            onRefresh: _load,
          ),
          if (!isMobile) _tabBar(),
          _toolbar(isMobile),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _green))
                : rows.isEmpty ? _empty() : isMobile ? _mobileList(rows) : _table(rows),
          ),
        ]);
      }),
    );
  }

  Widget _addBtn(bool compact) => ElevatedButton(
    onPressed: () => _openForm(),
    style: ElevatedButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size(0, 34), padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.add_rounded, size: 16),
      if (!compact) const SizedBox(width: 4),
      if (!compact) const Text('Add Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _tabBar() {
    const tabs = ['All Locations'];
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
      child: Row(children: List.generate(tabs.length, (i) {
        final active = _tabIndex == i;
        return GestureDetector(
          onTap: () => setState(() => _tabIndex = i),
          child: Container(
            margin: const EdgeInsets.only(right: 24),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? _green : Colors.transparent, width: 2))),
            child: Text(tabs[i], style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? _green : const Color(0xFF6B7280))),
          ),
        );
      })),
    );
  }

  Widget _toolbar(bool isMobile) => Padding(
    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
    child: Row(children: [
      Container(
        width: isMobile ? 140 : 200, height: 34,
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(7)),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Search...', hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            prefixIcon: Icon(Icons.search_rounded, size: 16, color: Color(0xFF9CA3AF)),
            border: InputBorder.none, contentPadding: EdgeInsets.only(top: 8),
          ),
        ),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
        child: Text('${_filtered.length} rows', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      ),
      const SizedBox(width: 8),
      _addBtn(isMobile),
    ]),
  );

  Widget _table(List rows) => Column(children: [
    Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: const Row(children: [
        SizedBox(width: 28, child: Text('#', style: _kH)),
        SizedBox(width: 12),
        Expanded(flex: 3, child: Text('Location Name', style: _kH)),
        Expanded(flex: 4, child: Text('Address', style: _kH)),
        SizedBox(width: 40),
      ]),
    ),
    const Divider(height: 1, color: Color(0xFFE5E7EB)),
    Expanded(child: ListView.builder(itemCount: rows.length, itemBuilder: (_, i) => _row(rows[i], i))),
  ]);

  Widget _row(Map loc, int index) {
    const bgs = [Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF3B82F6)];
    final bg = bgs[index % bgs.length];
    final name = loc['name'] ?? '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openForm(loc),
        hoverColor: const Color(0xFFF9FAFB),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
          child: Row(children: [
            SizedBox(width: 28, child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
              ),
              const SizedBox(width: 10),
              Flexible(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827)), overflow: TextOverflow.ellipsis)),
            ])),
            Expanded(flex: 4, child: Text(loc['address'] ?? '—', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)), overflow: TextOverflow.ellipsis)),
            _menu(loc),
          ]),
        ),
      ),
    );
  }

  Widget _mobileList(List rows) => ListView.separated(
    padding: const EdgeInsets.all(12),
    itemCount: rows.length,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (_, i) {
      final loc = rows[i];
      const bgs = [Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6)];
      return InkWell(
        onTap: () => _openForm(loc),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: bgs[i % bgs.length], borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text((loc['name'] ?? '?').substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(loc['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
              if ((loc['address'] ?? '').isNotEmpty) Text(loc['address'], style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), overflow: TextOverflow.ellipsis),
            ])),
            _menu(loc),
          ]),
        ),
      );
    },
  );

  Widget _menu(Map loc) => SizedBox(
    width: 40,
    child: PopupMenuButton(
      icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF9CA3AF)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 3,
      itemBuilder: (_) => [
        PopupMenuItem(value: 'edit', child: Row(children: const [Icon(Icons.edit_outlined, size: 15, color: Color(0xFF374151)), SizedBox(width: 8), Text('Edit', style: TextStyle(fontSize: 13))])),
        PopupMenuItem(value: 'delete', child: Row(children: const [Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFDC2626)), SizedBox(width: 8), Text('Delete', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626)))])),
      ],
      onSelected: (v) { if (v == 'edit') _openForm(loc); },
    ),
  );

  Widget _empty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 64, height: 64, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.location_on_outlined, size: 28, color: Color(0xFF9CA3AF))),
    const SizedBox(height: 14),
    Text(_search.isNotEmpty ? 'No results found' : 'No locations yet', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
    const SizedBox(height: 4),
    Text(_search.isNotEmpty ? 'Try a different search.' : 'Add your first location.', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
    if (_search.isEmpty) ...[
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add_rounded, size: 15), label: const Text('Add Location', style: TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10))),
    ],
  ]));
}

const _kH = TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.location == null;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // ── HEADER ──
          Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 16, 24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNew ? 'New Location' : 'Edit Location',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter the details for this office location',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),

          // ── FORM CONTENT ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Location Name"),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration:
                          _inputDecoration('e.g. Headquarters, Warehouse'),
                      validator: (v) => v!.isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel("Full Address"),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressCtrl,
                      maxLines: 3,
                      decoration:
                          _inputDecoration('Street address, city, zip code'),
                    ),
                    const SizedBox(height: 20),
                    _buildLabel("Notes / Description"),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: _inputDecoration('Additional info...'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── FOOTER ACTIONS ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B3A27),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(isNew ? 'Create Location' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1B3A27), width: 1.5),
      ),
    );
  }
}
