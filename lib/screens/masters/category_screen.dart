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
class MaterialScreen extends StatelessWidget {
  const MaterialScreen({super.key});
  @override
  Widget build(BuildContext context) => _MasterListScreen(
    title: 'Materials',
    subtitle: 'Configure material master data and specifications',
    endpoint: '/materials',
    cardBuilder: (item, onEdit, onDelete) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: Icon(Icons.widgets, color: Colors.blue.shade700)),
          title: Text(item['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${item['category']?['name'] ?? '—'} · ${item['unit'] ?? ''}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (item['code'] != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)), child: Text(item['code'], style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
            PopupMenuButton(
              itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red)))],
              onSelected: (v) { if (v == 'edit') onEdit(); else onDelete(); },
            ),
          ]),
        ),
      );
    },
    formBuilder: (item, onSaved) => _MaterialForm(item: item, onSaved: onSaved),
  );
}

class _MaterialForm extends StatefulWidget {
  final Map? item;
  final VoidCallback onSaved;
  const _MaterialForm({this.item, required this.onSaved});
  @override
  State<_MaterialForm> createState() => _MaterialFormState();
}

class _MaterialFormState extends State<_MaterialForm> {
  final _formKey = GlobalKey<FormState>();
  List _categories = [];
  String? _categoryId, _unit = 'pcs';
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  static const units = ['pcs', 'kg', 'ton', 'ltr', 'mtr', 'sqft', 'sqm', 'bag', 'box', 'set'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.item != null) {
      _nameCtrl.text = widget.item!['name'] ?? '';
      _codeCtrl.text = widget.item!['code'] ?? '';
      _descCtrl.text = widget.item!['description'] ?? '';
      _unit = widget.item!['unit'] ?? 'pcs';
      _categoryId = widget.item!['category']?['_id'];
    }
  }

  Future<void> _loadCategories() async {
    final res = await ApiService.get('/categories');
    if (mounted) setState(() => _categories = res['data'] ?? []);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = { 'name': _nameCtrl.text, 'code': _codeCtrl.text, 'category': _categoryId, 'unit': _unit, 'description': _descCtrl.text };
    final res = widget.item == null ? await ApiService.post('/materials', body) : await ApiService.put('/materials/${widget.item!['_id']}', body);
    if (mounted) { showSnack(context, res['success'] == true ? 'Saved!' : res['message'], error: res['success'] != true); if (res['success'] == true) { Navigator.pop(context); widget.onSaved(); } }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.item == null ? 'Add Material' : 'Edit Material', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Material Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Material Code (optional)')),
          const SizedBox(height: 12),
          AppDropdown<String>(label: 'Category', value: _categoryId, items: _categories.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['_id'], child: Text(c['name']))).toList(), onChanged: (v) => setState(() => _categoryId = v), validator: (v) => v == null ? 'Required' : null),
          const SizedBox(height: 12),
          AppDropdown<String>(label: 'Unit', value: _unit, items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) => setState(() => _unit = v)),
          const SizedBox(height: 12),
          TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save'))),
          const SizedBox(height: 8),
        ]),
      ),
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
                            onSelected: (v) { if (v == 'edit') _openForm(u); else _delete(u['_id']); },
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
