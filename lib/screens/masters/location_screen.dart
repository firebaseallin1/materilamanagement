import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
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
    final res = await ApiService.get('/locations');
    if (mounted) {
      setState(() {
        _locations = res['data'] ?? [];
        _loading = false;
      });
    }
  }

  void _openForm([Map? location]) {
    // Logic to determine panel width based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
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
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(20)),
            child: SizedBox(
              width: panelWidth,
              height: MediaQuery.of(context).size.height,
              child: LocationFormPanel(location: location, onSaved: _load),
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
    final filtered = _locations
        .where((l) =>
            _search.isEmpty ||
            (l['name'] ?? '').toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- RESPONSIVE HEADER ---
              isMobile ? _buildMobileHeader() : _buildDesktopHeader(),

              const SizedBox(height: 20),

              // --- COUNT CHIP ---
              Row(
                children: [
                  Icon(Icons.storefront,
                      size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text('${_locations.length} Locations',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 16),

              // --- DATA LIST ---
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
            Text('Locations',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E))),
            Text('Manage your business operation centers',
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
        const Text('Locations',
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
          Expanded(flex: 3, child: Text('Location Name', style: _kColHeader)),
          Expanded(flex: 4, child: Text('Address', style: _kColHeader)),
          SizedBox(width: 50),
        ],
      ),
    );
  }

  Widget _buildDesktopRow(Map location, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: _buildAvatarName(location, index)),
          Expanded(
              flex: 4,
              child: Text(location['address'] ?? '-',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          _buildActionMenu(location),
        ],
      ),
    );
  }

  Widget _buildMobileRow(Map location, int index) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _buildAvatarName(location, index, onlyAvatar: true),
      title: Text(location['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(location['address'] ?? '-',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)),
      trailing: _buildActionMenu(location),
    );
  }

  // --- REUSABLE WIDGETS ---

  Widget _buildAvatarName(Map location, int index, {bool onlyAvatar = false}) {
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
    final colorSet = index % colors.length;

    Widget avatar = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
          color: colors[colorSet], borderRadius: BorderRadius.circular(8)),
      child: Center(
          child: Text(location['name']?.substring(0, 2).toUpperCase() ?? '??',
              style: TextStyle(
                  color: textColors[colorSet],
                  fontWeight: FontWeight.bold,
                  fontSize: 12))),
    );

    if (onlyAvatar) return avatar;

    return Row(
      children: [
        avatar,
        const SizedBox(width: 12),
        Flexible(
            child: Text(location['name'] ?? '',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis)),
      ],
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
            const Text('Add Location', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildActionMenu(Map location) {
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
          if (val == 'edit') _openForm(location);
        },
      ),
    );
  }
}

const _kColHeader =
    TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600);

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
