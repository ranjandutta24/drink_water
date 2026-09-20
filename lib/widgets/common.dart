import 'package:flutter/material.dart';

import '../theme.dart';

/// A plain white panel with a hairline border. Used everywhere instead of
/// elevated cards so the home-screen vessel stays the only dimensional object.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.accent,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Optional left edge stripe, used to colour-code medicines.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final stripe = accent;

    // The stripe is drawn with a Stack rather than a stretched Row: a Row's
    // cross axis is vertical, so CrossAxisAlignment.stretch demands a bounded
    // height — which a panel inside a scrolling list never has. A Stack instead
    // sizes itself to the padded content and lets the stripe fill that height.
    final Widget body = stripe == null
        ? Padding(padding: padding, child: child)
        : Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  padding.left + 4,
                  padding.top,
                  padding.right,
                  padding.bottom,
                ),
                child: child,
              ),
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                width: 4,
                child: ColoredBox(color: stripe),
              ),
            ],
          );

    final palette = AppColors.of(context);
    final content = Container(
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.hairline),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(17), child: body),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: content,
    );
  }
}

/// Section heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Empty state that tells the user what to do next rather than apologising.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.of(context).aqua),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// Small key/value stat used in the reports and the home summary.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.color,
  });

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: color ?? AppColors.of(context).ink),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
