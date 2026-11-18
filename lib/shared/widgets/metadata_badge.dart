import 'package:flutter/material.dart';

/// Read-only metadata/status pill with a subtle outline and transparent
/// background so it stays visually distinct from interactive Material chips.
class MetadataBadge extends StatelessWidget {
  const MetadataBadge({
    required this.label,
    this.icon,
    this.iconColor,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: fontSize + 3,
              color: iconColor ?? colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
