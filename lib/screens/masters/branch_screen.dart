import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

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
  final _searchCtrl = TextEditingController();

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

  // --- UPDATED DIALOG (MATCHES LOCATION SCREEN) ---
  void _openForm([Map? branch]) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Desktop: 35% width, Mobile: 85% width
    final panelWidth =
        screenWidth > 900 ? screenWidth * 0.35 : screenWidth * 0.85;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 16,
            // Only round the left side to look like a sliding drawer
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(20)),
            child: SizedBox(
              width: panelWidth,
              height: MediaQuery.of(context).size.height, // Full Height
              child: BranchFormPanel(
                  branch: branch, locations: _locations, onSaved: _load),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(1, 0), end: const Offset(0, 0))
                  .animate(animation),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final filtered = _branches
            .where((b) =>
                _search.isEmpty ||
                (b['name'] ?? '').toLowerCase().contains(_search.toLowerCase()))
            .toList();

        return Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Responsive Header
              isMobile ? _buildMobileHeader() : _buildDesktopHeader(),

              const SizedBox(height: 20),

              // Stats Strip
              Row(
                children: [
                  const Icon(Icons.store_rounded,
                      size: 16, color: Color(0xFF2E7D52)),
                  const SizedBox(width: 6),
                  Text('${_branches.length} Branches',
                      style: const TextStyle(
                          color: Color(0xFF2E7D52),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 16),

              // Data List Container
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            if (!isMobile) _buildTableHeader(),
                            if (!isMobile) const Divider(height: 1),
                            Expanded(
                              child: ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) => isMobile
                                    ? _buildMobileRow(filtered[index], index)
                                    : _buildDesktopRow(filtered[index], index),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // --- HEADER VARIANTS ---

  Widget _buildDesktopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Branches',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E))),
            Text('Manage your business branch offices',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
        Row(
          children: [
            _buildSearchBox(width: 260),
            const SizedBox(width: 12),
            _buildAddButton(),
          ],
        )
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Branches',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E))),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSearchBox(width: double.infinity)),
            const SizedBox(width: 8),
            _buildAddButton(isCompact: true),
          ],
        )
      ],
    );
  }

  // --- TABLE COMPONENTS ---

  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Branch Name', style: _kColHeader)),
          Expanded(flex: 2, child: Text('Location', style: _kColHeader)),
          Expanded(flex: 2, child: Text('Contact', style: _kColHeader)),
          SizedBox(width: 50),
        ],
      ),
    );
  }

  Widget _buildDesktopRow(Map branch, int index) {
    return InkWell(
      onTap: () => _openForm(branch),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Expanded(flex: 3, child: _buildAvatarName(branch, index)),
            Expanded(
                flex: 2,
                child: _buildSimpleBadge(branch['location']?['name'] ?? '—')),
            Expanded(
                flex: 2,
                child: Text(branch['contactPerson'] ?? '—',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13))),
            _buildActionMenu(branch),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(Map branch, int index) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _buildAvatarName(branch, index, onlyAvatar: true),
      title: Text(branch['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text("${branch['location']?['name'] ?? 'No Location'}",
          style: const TextStyle(fontSize: 12)),
      trailing: _buildActionMenu(branch),
      onTap: () => _openForm(branch),
    );
  }

  // --- REUSABLE UI ELEMENTS ---

  Widget _buildAvatarName(Map b, int index, {bool onlyAvatar = false}) {
    final colors = [
      const Color(0xFFE3F2FD),
      const Color(0xFFE8F5E9),
      const Color(0xFFFFF3E0)
    ];
    final textColors = [
      const Color(0xFF1565C0),
      const Color(0xFF2E7D52),
      const Color(0xFFE65100)
    ];
    final i = index % colors.length;

    Widget avatar = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
          color: colors[i], borderRadius: BorderRadius.circular(8)),
      child: Center(
          child: Text(b['name']?.substring(0, 1).toUpperCase() ?? '?',
              style: TextStyle(
                  color: textColors[i],
                  fontWeight: FontWeight.bold,
                  fontSize: 12))),
    );

    if (onlyAvatar) return avatar;
    return Row(
      children: [
        avatar,
        const SizedBox(width: 12),
        Flexible(
            child: Text(b['name'] ?? '',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildSimpleBadge(String text) {
    return UnconstrainedBox(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildSearchBox({required double width}) {
    return Container(
      width: width,
      height: 40,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: const InputDecoration(
          hintText: 'Search...',
          prefixIcon: Icon(Icons.search, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(top: 8),
        ),
      ),
    );
  }

  Widget _buildAddButton({bool isCompact = false}) {
    return ElevatedButton(
      onPressed: () => _openForm(),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1B3A27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, size: 18, color: Colors.white),
          if (!isCompact) const SizedBox(width: 8),
          if (!isCompact)
            const Text('Add Branch', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildActionMenu(Map branch) {
    return SizedBox(
      width: 40,
      child: PopupMenuButton(
        icon: const Icon(Icons.more_horiz, color: Colors.grey),
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red))),
        ],
        onSelected: (val) {
          if (val == 'edit') _openForm(branch);
          // if (val == 'delete') _delete(branch['_id']);
        },
      ),
    );
  }
}

const _kColHeader =
    TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600);

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
