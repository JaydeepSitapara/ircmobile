import 'package:flutter/material.dart';

/// Small colored status chip indicating Active/Inactive state.
class StatusChipWidget extends StatelessWidget {
  const StatusChipWidget({
    super.key,
    required this.label,
    required this.active,
    this.onTap,
  });

  final String label;
  final bool active;

  /// Optional callback — makes the chip tappable (e.g., to navigate to
  /// Settings when tracking is disabled).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.tertiary;
    final inactiveColor = colorScheme.outline;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? activeColor.withAlpha(30)
            : inactiveColor.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? activeColor : inactiveColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: active ? activeColor : inactiveColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: active ? activeColor : inactiveColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: chip,
      );
    }
    return chip;
  }
}
