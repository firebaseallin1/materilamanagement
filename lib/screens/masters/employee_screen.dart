import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/screen_header.dart';

// ════════════════════════════════════════════════
// EMPLOYEE SCREEN
// ════════════════════════════════════════════════
class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});
  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  List _employees = [];
  bool _loading = true;
  String _search = '';
  String? _error;
  int _tabIndex = 0; // 0=All  1=Active  2=Inactive
  String _sortBy = 'name_asc';

  List get _filtered {
    final q = _search.toLowerCase();
    var list = _employees.where((e) {
      final name = (e['name'] ?? '').toString().toLowerCase();
      final code = (e['empCode'] ?? '').toString().toLowerCase();
      final desig = (e['designation'] ?? '').toString().toLowerCase();
      final matchSearch = q.isEmpty || name.contains(q) || code.contains(q) || desig.contains(q);
      final isActive = e['isActive'] ?? true;
      final matchTab = _tabIndex == 0 ||
          (_tabIndex == 1 && isActive == true) ||
          (_tabIndex == 2 && isActive != true);
      return matchSearch && matchTab;
    }).toList();

    list.sort((a, b) {
      if (_sortBy == 'name_desc') return (b['name'] ?? '').compareTo(a['name'] ?? '');
      if (_sortBy == 'code_asc') return (a['empCode'] ?? '').compareTo(b['empCode'] ?? '');
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
    setState(() { _loading = true; _error = null; });
    final res = await ApiService.get('/employees');
    if (mounted) {
      setState(() {
        if (res['success'] == true) {
          _employees = res['data'] ?? [];
          _error = null;
        } else {
          final msg = (res['message'] ?? '').toString().toLowerCase();
          if (msg.contains('not found') || msg.contains('no data')) {
            _employees = [];
            _error = null;
          } else {
            _error = res['message'] ?? 'Something went wrong';
          }
        }
        _loading = false;
      });
    }
  }

  void _openForm([Map? emp]) {
    final isAdmin = context.read<AuthService>().isAdmin;
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
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
          child: SizedBox(
            width: panelWidth,
            height: MediaQuery.of(ctx).size.height,
            child: _EmployeeFormPanel(employee: emp, onSaved: _load, isAdmin: isAdmin),
          ),
        ),
      ),
      transitionBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }

  Future<void> _delete(String id) async {
    if (!mounted) return;
    if (!await confirmDelete(context)) return;
    final res = await ApiService.delete('/employees/$id');
    if (!mounted) return;
    if (res['success'] == true) {
      showSnack(context, 'Employee deactivated');
      _load();
    } else {
      showSnack(context, res['message'] ?? 'Delete failed', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<AuthService>().isAdmin;
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 800;
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        body: Column(children: [
          ScreenHeader(
            title: 'Employees',
            subtitle: isAdmin ? 'All employees across users' : 'Employees you manage',
            onSearchChanged: (v) => setState(() => _search = v),
            onAdd: () => _openForm(),
            addLabel: 'Add Employee',
          ),
          // Tab bar + sort
          _FilterBar(
            tabIndex: _tabIndex,
            sortBy: _sortBy,
            total: _filtered.length,
            onTab: (i) => setState(() => _tabIndex = i),
            onSort: (s) => setState(() => _sortBy = s),
          ),
          // Content
          Expanded(
            child: _loading
                ? const AppLoader(message: 'Loading employees…')
                : _error != null
                    ? _ErrorRetry(message: _error!, onRetry: _load)
                    : _filtered.isEmpty
                        ? const EmptyState(
                            icon: Icons.badge_outlined,
                            message: 'No employees found')
                        : isDesktop
                            ? _DesktopTable(
                                employees: _filtered,
                                isAdmin: isAdmin,
                                onEdit: _openForm,
                                onDelete: _delete,
                              )
                            : _MobileList(
                                employees: _filtered,
                                isAdmin: isAdmin,
                                onEdit: _openForm,
                                onDelete: _delete,
                              ),
          ),
        ]),
      );
    });
  }
}

// ─── Error Retry ──────────────────────────────────────────────────────────────

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(color: Color(0xFF374151), fontSize: 14)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
      ]),
    );
  }
}

// ─── Filter Bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final int tabIndex;
  final String sortBy;
  final int total;
  final ValueChanged<int> onTab;
  final ValueChanged<String> onSort;

  const _FilterBar({
    required this.tabIndex,
    required this.sortBy,
    required this.total,
    required this.onTab,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(children: [
        _Tab('All', 0, tabIndex, onTab),
        _Tab('Active', 1, tabIndex, onTab),
        _Tab('Inactive', 2, tabIndex, onTab),
        const Spacer(),
        Text('$total records', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(width: 12),
        PopupMenuButton<String>(
          initialValue: sortBy,
          onSelected: onSort,
          tooltip: 'Sort',
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'name_asc',  child: Text('Name A–Z')),
            PopupMenuItem(value: 'name_desc', child: Text('Name Z–A')),
            PopupMenuItem(value: 'code_asc',  child: Text('Code A–Z')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.sort, size: 14, color: Colors.grey),
              SizedBox(width: 4),
              Text('Sort', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        ),
        const SizedBox(height: 44),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int index;
  final int selected;
  final ValueChanged<int> onTap;
  const _Tab(this.label, this.index, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final active = index == selected;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF7C3AED) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              color: active ? const Color(0xFF7C3AED) : Colors.grey,
            )),
      ),
    );
  }
}

// ─── Desktop Table ────────────────────────────────────────────────────────────

class _DesktopTable extends StatelessWidget {
  final List employees;
  final bool isAdmin;
  final void Function(Map) onEdit;
  final void Function(String) onDelete;

  const _DesktopTable({
    required this.employees,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              _colH('Employee', flex: 4),
              _colH('Code', flex: 2),
              _colH('Designation', flex: 3),
              _colH('Branch', flex: 3),
              _colH('Phone', flex: 3),
              _colH('Rate/Hr', flex: 2),
              if (isAdmin) _colH('Created By', flex: 3),
              _colH('Status', flex: 2),
              const SizedBox(width: 36),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          // Data rows
          ...List.generate(employees.length, (i) {
            final emp = employees[i];
            final isActive = emp['isActive'] ?? true;
            final branch = emp['branch'];
            final createdBy = emp['createdBy'];
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                    // Name + avatar
                    Expanded(
                      flex: 4,
                      child: Row(children: [
                        _EmpAvatar(name: emp['name'] ?? '', index: i, photo: emp['photo'] as String?),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(emp['name'] ?? '—',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF111827))),
                        ),
                      ]),
                    ),
                    // Code
                    Expanded(flex: 2,
                      child: Text(emp['empCode'] ?? '—',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontFamily: 'monospace'))),
                    // Designation
                    Expanded(flex: 3,
                      child: Text(emp['designation'] ?? '—',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
                    // Branch
                    Expanded(flex: 3,
                      child: Text(
                          branch is Map ? (branch['name'] ?? '—') : '—',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
                    // Phone
                    Expanded(flex: 3,
                      child: Text(emp['phone'] ?? '—',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                    // Hour Rate
                    Expanded(flex: 2,
                      child: Text(
                          (emp['hourRate'] != null && emp['hourRate'] != 0)
                              ? '₹${emp['hourRate']}'
                              : '—',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600))),
                    // Created By (admin only)
                    if (isAdmin)
                      Expanded(flex: 3,
                        child: Text(
                            createdBy is Map ? (createdBy['name'] ?? createdBy['userId'] ?? '—') : '—',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                    // Status
                    Expanded(flex: 2, child: _StatusChip(isActive: isActive)),
                    // Actions
                    InkWell(
                      onTap: () => onEdit(emp),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9F4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_outlined,
                            size: 16, color: Color(0xFF2E7D52)),
                      ),
                    ),
                  ]),
                ),
              if (i < employees.length - 1) const Divider(height: 1, color: Color(0xFFF3F4F6)),
            ]);
          }),
        ]),
      ),
    );
  }

  Widget _colH(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280), letterSpacing: 0.3)),
  );
}

// ─── Mobile List ──────────────────────────────────────────────────────────────

class _MobileList extends StatelessWidget {
  final List employees;
  final bool isAdmin;
  final void Function(Map) onEdit;
  final void Function(String) onDelete;

  const _MobileList({
    required this.employees,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final emp = employees[i];
        final isActive = emp['isActive'] ?? true;
        final branch = emp['branch'];
        final createdBy = emp['createdBy'];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            leading: _EmpAvatar(name: emp['name'] ?? '', index: i, photo: emp['photo'] as String?),
            title: Row(children: [
              Expanded(
                child: Text(emp['name'] ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              _StatusChip(isActive: isActive),
            ]),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),
              if ((emp['empCode'] ?? '').isNotEmpty)
                Text(emp['empCode'], style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontFamily: 'monospace')),
              Text(emp['designation'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
              if (branch is Map && (branch['name'] ?? '').isNotEmpty)
                Text(branch['name'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (emp['hourRate'] != null && emp['hourRate'] != 0)
                Text('Rate: ₹${emp['hourRate']}/hr',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
              if (isAdmin && createdBy is Map)
                Text('By: ${createdBy['name'] ?? createdBy['userId'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
            trailing: InkWell(
              onTap: () => onEdit(emp),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9F4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined,
                    size: 17, color: Color(0xFF2E7D52)),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Employee Avatar ──────────────────────────────────────────────────────────

class _EmpAvatar extends StatelessWidget {
  final String name;
  final int index;
  final String? photo;
  const _EmpAvatar({required this.name, required this.index, this.photo});

  static const _colors = [
    Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFF059669),
    Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF0891B2),
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name.isEmpty) return '?';
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (photo != null && photo!.isNotEmpty) {
      try {
        final bytes = base64Decode(photo!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(bytes, width: 36, height: 36, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    final color = _colors[index % _colors.length];
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(_initials, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}

// ─── Status Chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final bool isActive;
  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? const Color(0xFF15803D) : const Color(0xFFDC2626),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// EMPLOYEE FORM PANEL
// ════════════════════════════════════════════════
class _EmployeeFormPanel extends StatefulWidget {
  final Map? employee;
  final VoidCallback onSaved;
  final bool isAdmin;
  const _EmployeeFormPanel({this.employee, required this.onSaved, this.isAdmin = false});

  @override
  State<_EmployeeFormPanel> createState() => _EmployeeFormPanelState();
}

class _EmployeeFormPanelState extends State<_EmployeeFormPanel> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _loadingBranches = true;
  List _branches = [];

  late final TextEditingController _name;
  late final TextEditingController _designation;
  late final TextEditingController _department;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _hourRate;
  late final TextEditingController _aadharNo;
  late final TextEditingController _panNo;
  String? _branchId;
  DateTime? _joiningDate;
  bool _isActive = true;
  String? _photoBase64;
  String? _aadharPhotoBase64;
  String? _panPhotoBase64;

  bool get _isEdit => widget.employee != null;

  static const _primary = Color(0xFF1B3A27);
  static const _accent = Color(0xFF2E7D52);

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _name = TextEditingController(text: emp?['name'] ?? '');
    _designation = TextEditingController(text: emp?['designation'] ?? '');
    _department = TextEditingController(text: emp?['department'] ?? '');
    _phone = TextEditingController(text: emp?['phone'] ?? '');
    _email = TextEditingController(text: emp?['email'] ?? '');
    _address = TextEditingController(text: emp?['address'] ?? '');
    _hourRate = TextEditingController(
        text: emp?['hourRate'] != null ? emp!['hourRate'].toString() : '');
    _aadharNo = TextEditingController(text: emp?['aadharNo'] ?? '');
    _panNo = TextEditingController(text: emp?['panNo'] ?? '');
    _isActive = emp?['isActive'] ?? true;
    final rawPhoto = emp?['photo'] as String?;
    _photoBase64 = (rawPhoto != null && rawPhoto.isNotEmpty) ? rawPhoto : null;
    final rawAadhar = emp?['aadharPhoto'] as String?;
    _aadharPhotoBase64 = (rawAadhar != null && rawAadhar.isNotEmpty) ? rawAadhar : null;
    final rawPan = emp?['panPhoto'] as String?;
    _panPhotoBase64 = (rawPan != null && rawPan.isNotEmpty) ? rawPan : null;

    final branch = emp?['branch'];
    _branchId = branch is Map ? branch['_id'] : (branch is String ? branch : null);

    final jd = emp?['joiningDate'];
    if (jd != null) {
      try { _joiningDate = DateTime.parse(jd.toString()); } catch (_) {}
    }

    _loadBranches();
  }

  @override
  void dispose() {
    _name.dispose();
    _designation.dispose();
    _department.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _hourRate.dispose();
    _aadharNo.dispose();
    _panNo.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final res = await ApiService.get('/branches');
    if (mounted) {
      setState(() {
        _branches = (res['data'] as List? ?? []).where((b) => b['isActive'] == true).toList();
        _loadingBranches = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _joiningDate = picked);
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4,
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
              child: Icon(Icons.photo_library_outlined, color: Color(0xFF16A34A), size: 20),
            ),
            title: const Text('Gallery',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFDEECFF),
              child: Icon(Icons.camera_alt_outlined, color: Color(0xFF1D4ED8), size: 20),
            ),
            title: const Text('Camera',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          if (_photoBase64 != null)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFEF2F2),
                child: Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
              ),
              title: const Text('Remove Photo',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                      color: Color(0xFFDC2626))),
              onTap: () { setState(() => _photoBase64 = null); Navigator.pop(context); },
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, maxWidth: 400, maxHeight: 400, imageQuality: 75);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    setState(() => _photoBase64 = base64Encode(bytes));
  }

  Widget _photoPicker() {
    final bytes = _photoBase64 != null
        ? (() { try { return base64Decode(_photoBase64!); } catch (_) { return null; } })()
        : null;
    return Center(
      child: GestureDetector(
        onTap: _pickPhoto,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _accent.withValues(alpha: 0.25), width: 2),
            ),
            child: bytes != null
                ? ClipOval(child: Image.memory(bytes, width: 88, height: 88, fit: BoxFit.cover))
                : Icon(Icons.person_outline_rounded, size: 38,
                    color: _accent.withValues(alpha: 0.45)),
          ),
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _accent, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _pickDocumentPhoto(
      String? current, void Function(String?) onResult) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Choose Document Photo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFDCFCE7),
              child: Icon(Icons.photo_library_outlined, color: Color(0xFF16A34A), size: 20),
            ),
            title: const Text('Gallery',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFDEECFF),
              child: Icon(Icons.camera_alt_outlined, color: Color(0xFF1D4ED8), size: 20),
            ),
            title: const Text('Camera',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          if (current != null)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFEF2F2),
                child: Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626), size: 20),
              ),
              title: const Text('Remove Photo',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                      color: Color(0xFFDC2626))),
              onTap: () {
                onResult(null);
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
        source: source, maxWidth: 1000, maxHeight: 700, imageQuality: 80);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    onResult(base64Encode(bytes));
  }

  Widget _docPhotoTile(
      String label, IconData icon, Color color, String? base64,
      VoidCallback onTap) {
    final bytes = base64 != null
        ? (() {
            try {
              return base64Decode(base64);
            } catch (_) {
              return null;
            }
          })()
        : null;
    final hasPhoto = bytes != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasPhoto ? color.withValues(alpha: 0.05) : const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: hasPhoto ? color.withValues(alpha: 0.5) : const Color(0xFFDDE3E0)),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: hasPhoto
                ? Image.memory(bytes, width: 52, height: 52, fit: BoxFit.cover)
                : Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 24, color: color.withValues(alpha: 0.5)),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: hasPhoto ? color : const Color(0xFF374151))),
              const SizedBox(height: 2),
              Text(hasPhoto ? 'Tap to change' : 'Tap to add photo (optional)',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ]),
          ),
          Icon(
            hasPhoto ? Icons.check_circle_rounded : Icons.add_photo_alternate_outlined,
            size: 20,
            color: hasPhoto ? color : const Color(0xFF9CA3AF),
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'designation': _designation.text.trim(),
      'department': _department.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'address': _address.text.trim(),
      'isActive': _isActive,
      'photo': _photoBase64 ?? '',
      'aadharPhoto': _aadharPhotoBase64 ?? '',
      'panPhoto': _panPhotoBase64 ?? '',
    };
    if (_branchId != null) body['branch'] = _branchId;
    if (_joiningDate != null) body['joiningDate'] = _joiningDate!.toIso8601String();
    final hr = double.tryParse(_hourRate.text.trim());
    if (hr != null) body['hourRate'] = hr;
    if (_aadharNo.text.trim().isNotEmpty) body['aadharNo'] = _aadharNo.text.trim();
    if (_panNo.text.trim().isNotEmpty) body['panNo'] = _panNo.text.trim();

    final res = _isEdit
        ? await ApiService.put('/employees/${widget.employee!['_id']}', body)
        : await ApiService.post('/employees', body);

    if (mounted) {
      setState(() => _saving = false);
      if (res['success'] == true) {
        showSnack(context, _isEdit ? 'Employee updated' : 'Employee added');
        Navigator.pop(context);
        widget.onSaved();
      } else {
        showSnack(context, res['message'] ?? 'Save failed', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
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

        // Header card — matches branch style
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
              child: const Icon(Icons.badge_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_isEdit ? 'Edit Employee' : 'Add New Employee',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  _isEdit
                      ? 'Update the employee information below'
                      : 'Fill in the details to create an employee',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
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

        // Scrollable form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _photoPicker(),
                const SizedBox(height: 20),
                _field(_name, 'Full Name', Icons.person_outline_rounded,
                    hint: 'e.g. Ravi Kumar', required: true),
                const SizedBox(height: 14),
                _field(_designation, 'Designation', Icons.work_outline_rounded,
                    hint: 'e.g. Site Engineer', required: true),
                const SizedBox(height: 14),
                _field(_department, 'Department', Icons.business_outlined,
                    hint: 'Optional'),
                const SizedBox(height: 14),
                _field(_phone, 'Phone Number', Icons.phone_outlined,
                    hint: 'Optional', type: TextInputType.phone),
                const SizedBox(height: 14),
                _field(_email, 'Email', Icons.email_outlined,
                    hint: 'Optional', type: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _field(_address, 'Address', Icons.location_on_outlined,
                    hint: 'Optional', maxLines: 2),
                const SizedBox(height: 14),
                _field(_hourRate, 'Hour Rate (₹)', Icons.access_time_outlined,
                    hint: 'Optional', type: TextInputType.numberWithOptions(decimal: true),
                    readOnly: !widget.isAdmin),
                const SizedBox(height: 14),

                // Branch dropdown
                _loadingBranches
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _branchId,
                        decoration: _fieldDecoration('Branch', Icons.store_outlined),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                        borderRadius: BorderRadius.circular(10),
                        hint: const Text('Select Branch'),
                        isExpanded: true,
                        items: _branches.map<DropdownMenuItem<String>>((b) {
                          return DropdownMenuItem(
                              value: b['_id'].toString(),
                              child: Text(b['name'] ?? ''));
                        }).toList(),
                        onChanged: (v) => setState(() => _branchId = v),
                      ),
                const SizedBox(height: 14),

                // Joining date
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: _fieldDecoration(
                        'Joining Date', Icons.calendar_today_outlined),
                    child: Text(
                      _joiningDate != null
                          ? DateFormat('dd MMM yyyy').format(_joiningDate!)
                          : 'Select date',
                      style: TextStyle(
                        fontSize: 13,
                        color: _joiningDate != null
                            ? const Color(0xFF1A1A2E)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Documents section
                _sectionLabel('Documents (Optional)'),
                const SizedBox(height: 10),
                _field(_aadharNo, 'Aadhaar Card Number', Icons.credit_card_outlined,
                    hint: 'Optional · 12-digit number',
                    type: TextInputType.number),
                const SizedBox(height: 10),
                _docPhotoTile(
                  'Aadhaar Card Photo',
                  Icons.credit_card_outlined,
                  const Color(0xFF0891B2),
                  _aadharPhotoBase64,
                  () async {
                    await _pickDocumentPhoto(_aadharPhotoBase64, (v) {
                      setState(() => _aadharPhotoBase64 = v);
                    });
                  },
                ),
                const SizedBox(height: 10),
                _field(_panNo, 'PAN Card Number', Icons.badge_outlined,
                    hint: 'Optional · e.g. ABCDE1234F'),
                const SizedBox(height: 10),
                _docPhotoTile(
                  'PAN Card Photo',
                  Icons.badge_outlined,
                  const Color(0xFF7C3AED),
                  _panPhotoBase64,
                  () async {
                    await _pickDocumentPhoto(_panPhotoBase64, (v) {
                      setState(() => _panPhotoBase64 = v);
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Status toggle — matches branch
                _activeToggle(),
                const SizedBox(height: 24),

                // Buttons inside scroll area — matches branch
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
                            ? const ButtonLoader()
                            : Text(_isEdit ? 'Save Changes' : 'Add Employee',
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
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 2),
    child: Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(
              color: _accent, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF374151), letterSpacing: 0.3)),
    ]),
  );

  Widget _activeToggle() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9F8),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFDDE3E0)),
    ),
    child: Row(children: [
      const Icon(Icons.toggle_on_outlined, size: 18, color: _accent),
      const SizedBox(width: 12),
      const Expanded(
        child: Text('Status', style: TextStyle(fontSize: 13, color: Colors.grey)),
      ),
      Text(
        _isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
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

  InputDecoration _fieldDecoration(String label, IconData icon, {String? hint}) {
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

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    String? hint,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      readOnly: readOnly,
      style: readOnly
          ? const TextStyle(color: Color(0xFF6B7280))
          : null,
      decoration: _fieldDecoration(label, icon, hint: hint).copyWith(
        fillColor: readOnly ? const Color(0xFFF3F4F6) : const Color(0xFFF7F9F8),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
          : null,
    );
  }
}
