import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onRefresh;
  final ValueChanged<String>? onSearchChanged;
  final String? searchHint;
  final VoidCallback? onAdd;
  final String? addLabel;

  const ScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onRefresh,
    this.onSearchChanged,
    this.searchHint,
    this.onAdd,
    this.addLabel,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 600;
      final h = isWide ? 28.0 : 16.0;

      if (!isWide) {
        return Container(
          width: double.infinity,
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(h, 16, h, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E))),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (onAdd != null) ...[
                    const SizedBox(width: 8),
                    _CompactAddBtn(onTap: onAdd!),
                  ],
                ],
              ),
              if (onSearchChanged != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: TextField(
                    onChanged: onSearchChanged,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: searchHint ?? 'Search...',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFFAAAAAA)),
                      prefixIcon: const Icon(Icons.search,
                          size: 18, color: Color(0xFFAAAAAA)),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }

      // Wide layout
      return Container(
        width: double.infinity,
        color: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: h, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (onSearchChanged != null) ...[
                  SizedBox(
                    width: 220,
                    height: 36,
                    child: TextField(
                      onChanged: onSearchChanged,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: searchHint ?? 'Search...',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFFAAAAAA)),
                        prefixIcon: const Icon(Icons.search,
                            size: 18, color: Color(0xFFAAAAAA)),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (onAdd != null) ...[
                  _AddButton(label: addLabel ?? 'Add', onTap: onAdd!),
                  const SizedBox(width: 14),
                ],
                _HeaderIconBtn(
                    icon: Icons.mail_outline_rounded, onTap: () {}),
                const SizedBox(width: 6),
                _HeaderIconBtn(
                    icon: Icons.notifications_none_rounded,
                    onTap: () {}),
                const SizedBox(width: 6),
                _HeaderIconBtn(
                  icon: onRefresh != null
                      ? Icons.refresh_rounded
                      : Icons.menu_rounded,
                  onTap: onRefresh ?? () {},
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(height: 28, child: VerticalDivider()),
                ),
                PopupMenuButton<String>(
                  offset: const Offset(0, 44),
                  tooltip: '',
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFF2E7D52),
                    child: Text(
                      _initials(auth.userName),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        enabled: false,
                        child: Text(auth.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold))),
                    PopupMenuItem(
                        enabled: false,
                        child: Text(auth.userRole.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey))),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                        value: 'logout', child: Text('Logout')),
                  ],
                  onSelected: (v) {
                    if (v == 'logout') auth.logout();
                  },
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, size: 16),
        label: Text(label,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D52),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _CompactAddBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _CompactAddBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D52),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white),
        child: Icon(icon, size: 18, color: Colors.grey.shade600),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.isEmpty || name.isEmpty) return 'U';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
