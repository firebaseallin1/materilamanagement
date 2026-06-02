import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── Generic List Screen ────────────────────────────────────────────────────────
class BaseListScreen extends StatefulWidget {
  final String title;
  final String endpoint;
  final Widget Function(Map<String, dynamic> item, VoidCallback onRefresh) itemBuilder;
  final Widget Function(VoidCallback onRefresh)? addButton;

  const BaseListScreen({
    super.key,
    required this.title,
    required this.endpoint,
    required this.itemBuilder,
    this.addButton,
  });

  @override
  State<BaseListScreen> createState() => _BaseListScreenState();
}

class _BaseListScreenState extends State<BaseListScreen> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

// ── Status Badge ───────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Info Row ───────────────────────────────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Date Picker Field ──────────────────────────────────────────────────────────
class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const DatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final first = firstDate ?? DateTime(2020);
    final last  = lastDate  ?? DateTime(2100);
    final readOnly = first == last ||
        (first.year == last.year && first.month == last.month && first.day == last.day);

    return GestureDetector(
      onTap: readOnly ? null : () async {
        final initial = (value != null && !value!.isBefore(first) && !value!.isAfter(last))
            ? value!
            : last;
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Icon(
            readOnly ? Icons.calendar_today : Icons.calendar_today,
            color: readOnly ? Colors.grey : null,
          ),
        ),
        child: Text(
          value != null
              ? DateFormat('dd MMM yyyy').format(value!)
              : 'Select date',
          style: TextStyle(
            color: value != null
                ? (readOnly ? Colors.grey.shade600 : Colors.black87)
                : Colors.grey,
          ),
        ),
      ),
    );
  }
}

// ── Dropdown Field ─────────────────────────────────────────────────────────────
class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      isExpanded: true,
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState(
      {super.key,
      this.message = 'No data found',
      this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}

// ── Confirm Delete Dialog ─────────────────────────────────────────────────────
Future<bool> confirmDelete(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this item?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

// ── Show Snack (success toasts only) ──────────────────────────────────────────
void showSnack(BuildContext context, String msg, {bool error = false}) {
  if (error) {
    showAppDialog(context, msg, type: AppDialogType.error);
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
    ]),
    backgroundColor: const Color(0xFF16A34A),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    margin: const EdgeInsets.all(14),
    duration: const Duration(seconds: 2),
  ));
}

// ── App Dialog ────────────────────────────────────────────────────────────────
enum AppDialogType { error, success, warning, info }

Future<void> showAppDialog(
  BuildContext context,
  String message, {
  String? title,
  AppDialogType type = AppDialogType.error,
}) {
  final cfg = _dialogConfig(type);
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _AppDialog(
      message: message,
      title: title ?? cfg.title,
      icon: cfg.icon,
      color: cfg.color,
      btnLabel: cfg.btnLabel,
    ),
  );
}

({String title, IconData icon, Color color, String btnLabel}) _dialogConfig(
    AppDialogType type) {
  return switch (type) {
    AppDialogType.error   => (
        title: 'Something went wrong',
        icon: Icons.error_rounded,
        color: const Color(0xFFDC2626),
        btnLabel: 'OK',
      ),
    AppDialogType.success => (
        title: 'Success',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF16A34A),
        btnLabel: 'Done',
      ),
    AppDialogType.warning => (
        title: 'Warning',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFD97706),
        btnLabel: 'OK',
      ),
    AppDialogType.info    => (
        title: 'Info',
        icon: Icons.info_rounded,
        color: const Color(0xFF2563EB),
        btnLabel: 'Got it',
      ),
  };
}

class _AppDialog extends StatelessWidget {
  final String message;
  final String title;
  final IconData icon;
  final Color color;
  final String btnLabel;

  const _AppDialog({
    required this.message,
    required this.title,
    required this.icon,
    required this.color,
    required this.btnLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        margin: const EdgeInsets.only(top: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon badge sits above the card top edge
            Transform.translate(
              offset: const Offset(0, -40),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.70)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
            ),
            // Compensate for the translate offset
            const SizedBox(height: 0),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        btnLabel,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ), // ConstrainedBox
    );
  }
}

// ── App Loader ─────────────────────────────────────────────────────────────────
class AppLoader extends StatefulWidget {
  final String? message;
  const AppLoader({super.key, this.message});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with TickerProviderStateMixin {
  late AnimationController _dotCtrl;
  late AnimationController _pulseCtrl;
  late List<Animation<double>> _dotAnims;
  late Animation<double> _pulseAnim;

  static const _green = Color(0xFF2E7D52);
  static const _greenLight = Color(0xFF43A047);

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _dotAnims = List.generate(3, (i) => Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _dotCtrl,
        curve: Interval(i * 0.2, i * 0.2 + 0.5, curve: Curves.easeInOut),
      ),
    ));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Pulsing brand icon
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: _pulseAnim.value,
            child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_green, _greenLight],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 30),
        // Bouncing dots
        AnimatedBuilder(
          animation: _dotCtrl,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = _dotAnims[i].value;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Transform.translate(
                  offset: Offset(0, -10 * t),
                  child: Container(
                    width: 9, height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green.withValues(alpha: 0.35 + 0.65 * t),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 18),
          Text(
            widget.message!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _green.withValues(alpha: 0.65),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Button Loader (inline spinner for save/submit buttons) ─────────────────────
class ButtonLoader extends StatelessWidget {
  final Color color;
  const ButtonLoader({super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18, height: 18,
      child: CircularProgressIndicator(
        color: color,
        strokeWidth: 2.5,
        strokeCap: StrokeCap.round,
      ),
    );
  }
}
