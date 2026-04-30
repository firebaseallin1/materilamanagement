import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

class BranchScreen extends StatefulWidget {
  const BranchScreen({super.key});

  @override
  State<BranchScreen> createState() => _BranchScreenState();
}

class _BranchScreenState extends State<BranchScreen> {
  List _branches = [];
  List _locations = [];
  bool _loading = true;
  String _search = '';
  int _tabIndex = 0; // 0=All 1=Active 2=Inactive
  final _searchCtrl = TextEditingController();

  static const _primary = Color(0xFF111827);
  static const _green = Color(0xFF16A34A);

  List get _filtered {
    return _branches.where((b) {
      final matchSearch = _search.isEmpty ||
          (b['name'] ?? '').toLowerCase().contains(_search.toLowerCase());
      final isActive = (b['active'] ?? true) as bool;
      final matchTab = _tabIndex == 0 ||
          (_tabIndex == 1 && isActive) ||
          (_tabIndex == 2 && !isActive);
      return matchSearch && matchTab;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.get('/branches'),
      ApiService.get('/locations'),
    ]);
    if (mounted) {
      setState(() {
        _branches = results[0]['data'] ?? [];
        _locations = results[1]['data'] ?? [];
        _loading = false;
      });
    }
  }

  void _openForm([Map? branch]) {
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
            child: BranchFormPanel(
                branch: branch, locations: _locations, onSaved: _load),
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

  // ── Build ────────────────────────────────────────────────────────────────────

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
              title: 'Branches',
              subtitle: 'Manage company branches and regional offices',
              onRefresh: _load,
            ),
            if (!isMobile) _buildTabBar(),
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

  // ── Title bar ────────────────────────────────────────────────────────────────

  Widget _addBtn(bool compact) => ElevatedButton(
        onPressed: () => _openForm(),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 34),
          padding:
              EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add_rounded, size: 16),
          if (!compact) const SizedBox(width: 4),
          if (!compact)
            const Text('Add Branch',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );

  // ── Tab bar ──────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = ['All Branches', 'Active', 'Inactive'];
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

  // ── Toolbar ──────────────────────────────────────────────────────────────────

  Widget _buildToolbar(bool isMobile) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
      child: Row(
        children: [
          // Search
          Container(
            width: isMobile ? 140 : 200,
            height: 34,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
              decoration: const InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 16, color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(top: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!isMobile) ...[
            _toolbarBtn(Icons.swap_vert_rounded, 'Sort'),
            const SizedBox(width: 8),
            _toolbarBtn(Icons.tune_rounded, 'Filter'),
          ],
          const Spacer(),
          // Row count chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${_filtered.length} rows',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),
          const SizedBox(width: 8),
          _addBtn(isMobile),
        ],
      ),
    );
  }

  Widget _toolbarBtn(IconData icon, String label) => OutlinedButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 14, color: const Color(0xFF6B7280)),
        label: Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w400)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      );

  // ── Desktop table ────────────────────────────────────────────────────────────

  Widget _buildTable(List rows) {
    return Column(
      children: [
        // Header row
        Container(
          color: const Color(0xFFF9FAFB),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            const SizedBox(width: 28, child: Text('#', style: _kHdr)),
            const SizedBox(width: 12),
            const Expanded(flex: 3, child: Text('Branch Name', style: _kHdr)),
            const Expanded(flex: 2, child: Text('Location', style: _kHdr)),
            const Expanded(flex: 2, child: Text('Contact', style: _kHdr)),
            const Expanded(flex: 2, child: Text('Phone', style: _kHdr)),
            const SizedBox(
                width: 88,
                child:
                    Text('Status', style: _kHdr, textAlign: TextAlign.center)),
            const SizedBox(width: 40),
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

  Widget _buildRow(Map b, int index) {
    final isActive = (b['active'] ?? true) as bool;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openForm(b),
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
            Expanded(flex: 3, child: _nameCell(b, index)),
            Expanded(
              flex: 2,
              child: Text(b['location']?['name'] ?? '—',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF374151))),
            ),
            Expanded(
              flex: 2,
              child: Text(b['contactPerson'] ?? '—',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF374151))),
            ),
            Expanded(flex: 2, child: _phoneCell(b['phone'])),
            SizedBox(width: 88, child: Center(child: _statusBadge(isActive))),
            _actionMenu(b),
          ]),
        ),
      ),
    );
  }

  // ── Mobile list ──────────────────────────────────────────────────────────────

  Widget _buildMobileList(List rows) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _mobileCard(rows[i], i),
    );
  }

  Widget _mobileCard(Map b, int index) {
    final isActive = (b['active'] ?? true) as bool;
    return InkWell(
      onTap: () => _openForm(b),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          _avatar(b, index, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b['name'] ?? '',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
              const SizedBox(height: 2),
              Text(
                  '${b['location']?['name'] ?? '—'}'
                  '${b['contactPerson'] != null ? ' · ${b['contactPerson']}' : ''}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]),
          ),
          const SizedBox(width: 8),
          _statusBadge(isActive),
          _actionMenu(b),
        ]),
      ),
    );
  }

  // ── Cells ────────────────────────────────────────────────────────────────────

  Widget _nameCell(Map b, int index) {
    return Row(children: [
      _avatar(b, index),
      const SizedBox(width: 10),
      Flexible(
        child: Text(b['name'] ?? '',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827)),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }

  Widget _avatar(Map b, int index, {double size = 28}) {
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
          b['name']?.substring(0, 1).toUpperCase() ?? '?',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.42),
        ),
      ),
    );
  }

  Widget _phoneCell(dynamic phone) {
    if (phone == null || phone.toString().isEmpty) {
      return const Text('—',
          style: TextStyle(fontSize: 13, color: Color(0xFFD1D5DB)));
    }
    return Text(phone.toString(),
        style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF2563EB),
            decoration: TextDecoration.underline),
        overflow: TextOverflow.ellipsis);
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
            color: active ? const Color(0xFF166534) : const Color(0xFF6B7280)),
      ),
    );
  }

  Widget _actionMenu(Map b) {
    return SizedBox(
      width: 40,
      child: PopupMenuButton(
        icon: const Icon(Icons.more_horiz_rounded,
            size: 18, color: Color(0xFF9CA3AF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 3,
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'edit',
            child: Row(children: const [
              Icon(Icons.edit_outlined, size: 15, color: Color(0xFF374151)),
              SizedBox(width: 8),
              Text('Edit', style: TextStyle(fontSize: 13)),
            ]),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(children: const [
              Icon(Icons.delete_outline_rounded,
                  size: 15, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Delete',
                  style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
            ]),
          ),
        ],
        onSelected: (val) {
          if (val == 'edit') _openForm(b);
        },
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    final hasSearch = _search.isNotEmpty;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.store_outlined,
              size: 28, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 14),
        Text(hasSearch ? 'No results found' : 'No branches yet',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(
            hasSearch
                ? 'Try a different search term.'
                : 'Add your first branch to get started.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        if (!hasSearch) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add Branch', style: TextStyle(fontSize: 13)),
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

const _kHdr = TextStyle(
    fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500);

// ── Branch form panel ──────────────────────────────────────────────────────────
class BranchFormPanel extends StatefulWidget {
  final Map? branch;
  final List locations;
  final VoidCallback onSaved;

  const BranchFormPanel(
      {super.key, this.branch, required this.locations, required this.onSaved});

  @override
  State<BranchFormPanel> createState() => _BranchFormPanelState();
}

class _BranchFormPanelState extends State<BranchFormPanel> {
  final _formKey = GlobalKey<FormState>();
  String? _locationId;
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;

  static const _primary = Color(0xFF1B3A27);
  static const _accent = Color(0xFF2E7D52);

  @override
  void initState() {
    super.initState();
    if (widget.branch != null) {
      _nameCtrl.text = widget.branch!['name'] ?? '';
      _contactCtrl.text = widget.branch!['contactPerson'] ?? '';
      _phoneCtrl.text = widget.branch!['phone'] ?? '';
      _locationId = widget.branch!['location']?['_id'];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'name': _nameCtrl.text.trim(),
      'location': _locationId,
      'contactPerson': _contactCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
    };
    final res = widget.branch == null
        ? await ApiService.post('/branches', body)
        : await ApiService.put('/branches/${widget.branch!['_id']}', body);
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
    final isNew = widget.branch == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Drag handle ──────────────────────────────────────────────────
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

        // ── Gradient header ──────────────────────────────────────────────
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
              child: const Icon(Icons.store_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isNew ? 'Add New Branch' : 'Edit Branch',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      isNew
                          ? 'Fill in the details to create a branch'
                          : 'Update the branch information below',
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

        // ── Form fields ──────────────────────────────────────────────────
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
                      'Branch Name', Icons.store_mall_directory_outlined,
                      hint: 'e.g. Coimbatore Main'),
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Branch name is required' : null,
                ),
                const SizedBox(height: 14),

                // Location dropdown styled to match
                DropdownButtonFormField<String>(
                  value: _locationId,
                  decoration:
                      _fieldDecoration('Location', Icons.location_on_outlined),
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                  borderRadius: BorderRadius.circular(10),
                  items: widget.locations
                      .map<DropdownMenuItem<String>>((l) => DropdownMenuItem(
                          value: l['_id'] as String,
                          child: Text(l['name'] as String)))
                      .toList(),
                  onChanged: (v) => setState(() => _locationId = v),
                  validator: (v) =>
                      v == null ? 'Please select a location' : null,
                  isExpanded: true,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _contactCtrl,
                  decoration: _fieldDecoration(
                      'Contact Person', Icons.person_outline_rounded,
                      hint: 'Optional'),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDecoration(
                      'Phone Number', Icons.phone_outlined,
                      hint: 'Optional'),
                ),
                const SizedBox(height: 24),

                // ── Action buttons ───────────────────────────────────────
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
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(isNew ? 'Add Branch' : 'Save Changes',
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
