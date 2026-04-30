import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MaterialMovementList extends StatelessWidget {
  final List items;
  final void Function(Map)? onEdit;
  final void Function(Map)? onDelete;

  const MaterialMovementList({
    super.key,
    required this.items,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildHeader(),
          for (int i = 0; i < items.length; i++) ...[
            Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
            _MovementRow(
              item: items[i],
              onEdit: onEdit != null ? () => onEdit!(items[i]) : null,
              onDelete: onDelete != null ? () => onDelete!(items[i]) : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF9E9E9E),
      letterSpacing: 0.8,
    );
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('MATERIAL', style: style)),
          SizedBox(width: 84, child: Text('QTY', style: style)),
          SizedBox(width: 110, child: Text('STATUS', style: style)),
          SizedBox(width: 100, child: Text('WAREHOUSE', style: style)),
          SizedBox(width: 72, child: Text('TIME', style: style)),
          SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  final Map item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MovementRow({required this.item, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final type = item['type'] ?? 'in';
    final materialName = item['material']?['name'] ?? '—';
    final branchName = item['branch']?['name'] ?? '—';
    final quantity = item['quantity'] ?? 0;
    final cfg = _typeConfig(type);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Material
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cfg.iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _iconForMaterial(materialName),
                    size: 18,
                    color: cfg.iconColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        materialName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF1A1A1A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _skuCode(item),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // QTY
          SizedBox(
            width: 84,
            child: Text(
              '${cfg.prefix} $quantity',
              style: TextStyle(
                color: cfg.qtyColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),

          // STATUS
          SizedBox(
            width: 110,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cfg.badgeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cfg.status,
                style: TextStyle(
                  fontSize: 11,
                  color: cfg.badgeColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // WAREHOUSE
          SizedBox(
            width: 100,
            child: Text(
              branchName,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF424242),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // TIME
          SizedBox(
            width: 72,
            child: Text(
              _timeAgo(item['date']),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9E9E9E),
              ),
            ),
          ),

          // Actions
          SizedBox(
            width: 32,
            child: (onEdit != null || onDelete != null)
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 18, color: Color(0xFFBDBDBD)),
                    padding: EdgeInsets.zero,
                    itemBuilder: (_) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                            value: 'edit', child: Text('Edit')),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') {
                        onEdit?.call();
                      } else {
                        onDelete?.call();
                      }
                    },
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  String _skuCode(Map item) {
    final id = (item['_id'] ?? '') as String;
    if (id.length >= 6) return 'SKU ${id.substring(id.length - 6).toUpperCase()}';
    final name = (item['material']?['name'] ?? '') as String;
    if (name.isNotEmpty) {
      final parts = name.trim().split(' ');
      final code = parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join();
      return 'SKU $code'.toUpperCase();
    }
    return 'SKU —';
  }

  String _timeAgo(dynamic dateStr) {
    if (dateStr == null) return '—';
    final date = DateTime.tryParse(dateStr.toString());
    if (date == null) return '—';
    final diff = DateTime.now().difference(date.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(date.toLocal());
  }
}

class _TypeConfig {
  final String status;
  final String prefix;
  final Color qtyColor;
  final Color badgeColor;
  final Color badgeBg;
  final Color iconBg;
  final Color iconColor;

  const _TypeConfig({
    required this.status,
    required this.prefix,
    required this.qtyColor,
    required this.badgeColor,
    required this.badgeBg,
    required this.iconBg,
    required this.iconColor,
  });
}

_TypeConfig _typeConfig(String type) {
  switch (type) {
    case 'out':
      return const _TypeConfig(
        status: 'Shipped',
        prefix: '−',
        qtyColor: Color(0xFFF57C00),
        badgeColor: Color(0xFFF57C00),
        badgeBg: Color(0xFFFFF3E0),
        iconBg: Color(0xFFFFF3E0),
        iconColor: Color(0xFFF57C00),
      );
    case 'transfer':
      return const _TypeConfig(
        status: 'In transit',
        prefix: '↔',
        qtyColor: Color(0xFF5C6BC0),
        badgeColor: Color(0xFF5C6BC0),
        badgeBg: Color(0xFFEDE7F6),
        iconBg: Color(0xFFEDE7F6),
        iconColor: Color(0xFF5C6BC0),
      );
    default:
      return const _TypeConfig(
        status: 'Received',
        prefix: '+',
        qtyColor: Color(0xFF2E7D32),
        badgeColor: Color(0xFF2E7D32),
        badgeBg: Color(0xFFE8F5E9),
        iconBg: Color(0xFFE8F5E9),
        iconColor: Color(0xFF2E7D32),
      );
  }
}

IconData _iconForMaterial(String name) {
  final n = name.toLowerCase();
  if (n.contains('rebar') || n.contains('steel') || n.contains('metal') || n.contains('iron')) {
    return Icons.grid_4x4;
  }
  if (n.contains('wood') || n.contains('lumber') || n.contains('timber') || n.contains('ply')) {
    return Icons.layers_outlined;
  }
  if (n.contains('cement') || n.contains('concrete') || n.contains('mortar') || n.contains('sand')) {
    return Icons.blur_on;
  }
  if (n.contains('pipe') || n.contains('pvc') || n.contains('tube')) {
    return Icons.plumbing;
  }
  if (n.contains('wire') || n.contains('cable') || n.contains('copper')) {
    return Icons.electrical_services;
  }
  if (n.contains('paint') || n.contains('coat') || n.contains('primer')) {
    return Icons.format_paint;
  }
  if (n.contains('brick') || n.contains('tile') || n.contains('block')) {
    return Icons.view_quilt;
  }
  if (n.contains('glass') || n.contains('window')) {
    return Icons.window;
  }
  return Icons.inventory_2_outlined;
}
