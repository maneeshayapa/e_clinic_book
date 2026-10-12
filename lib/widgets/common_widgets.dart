import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? Colors.red.shade700 : Colors.teal.shade800,
    ));
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, this.icon = Icons.inbox_outlined, required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message.localized(context), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ]),
        ),
      );
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorState({super.key, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: Text('Retry'.localized(context))),
            ],
          ]),
        ),
      );
}

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined, loading;
  const CustomButton({super.key, required this.label, this.onPressed, this.icon, this.outlined = false, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(label.localized(context), overflow: TextOverflow.ellipsis)),
          ]);
    final action = loading ? null : onPressed;
    return outlined ? OutlinedButton(onPressed: action, child: child) : FilledButton(onPressed: action, child: child);
  }
}

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final IconData? icon;
  final String? Function(String?)? validator;
  final bool obscure, readOnly;
  final TextInputType? keyboardType;
  final int maxLines;
  final VoidCallback? onTap;
  final Widget? suffix;
  const CustomTextField({super.key, this.controller, required this.label, this.icon, this.validator, this.obscure = false, this.readOnly = false, this.keyboardType, this.maxLines = 1, this.onTap, this.suffix});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscure,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          maxLines: obscure ? 1 : maxLines,
          decoration: InputDecoration(labelText: label.localized(context), prefixIcon: icon == null ? null : Icon(icon), suffixIcon: suffix),
        ),
      );
}

class SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  const SectionCard({super.key, this.title, this.icon, required this.child});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) ...[
              Row(children: [
                if (icon != null) ...[Icon(icon, color: AppTheme.primary, size: 22), const SizedBox(width: 8)],
                Text(title!.localized(context), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
            ],
            child,
          ]),
        ),
      );
}

class InfoRow extends StatelessWidget {
  final String label, value;
  const InfoRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label.localized(context), style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const StatusChip(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text.localized(context), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? color;
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: c),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(label.localized(context), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ]),
      ),
    );
  }
}

/// Placeholder QR renderer. Replace internals with `qr_flutter` later.
class QrCodeView extends StatelessWidget {
  final String data;
  final double size;
  const QrCodeView({super.key, required this.data, this.size = 200});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _QrPainter(data));
}

class _QrPainter extends CustomPainter {
  final String data;
  _QrPainter(this.data);
  static const n = 25;
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / n;
    final paint = Paint()..color = Colors.black;
    var seed = data.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    bool finder(int x, int y) => (x < 8 && y < 8) || (x >= n - 8 && y < 8) || (x < 8 && y >= n - 8);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        if (!finder(x, y) && (seed >> 16) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        }
      }
    }
    for (final o in [const Offset(0, 0), Offset((n - 7) * cell, 0), Offset(0, (n - 7) * cell)]) {
      canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, 7 * cell, 7 * cell), paint);
      canvas.drawRect(Rect.fromLTWH(o.dx + cell, o.dy + cell, 5 * cell, 5 * cell), Paint()..color = Colors.white);
      canvas.drawRect(Rect.fromLTWH(o.dx + 2 * cell, o.dy + 2 * cell, 3 * cell, 3 * cell), paint);
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.data != data;
}
