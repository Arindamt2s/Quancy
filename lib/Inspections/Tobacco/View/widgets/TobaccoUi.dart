import 'package:flutter/material.dart';
import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoTheme.dart';

/// Shared pieces of the Tobacco inspection screens (Food-style design).
///
/// Path: lib/Inspections/Tobacco/View/widgets/TobaccoUi.dart

/// White card with an icon tile, title and subtitle.
class TbCard extends StatelessWidget {
  const TbCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: TbColors.iconTile,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: TbColors.brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: TbColors.textDark)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: const TextStyle(
                                fontSize: 11, color: TbColors.textMuted)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDF1F6)),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}

/// Bold small label with an optional red *.
class TbLabel extends StatelessWidget {
  const TbLabel(this.text, {super.key, this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(
          TextSpan(
            text: text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: TbColors.textDark),
            children: [
              if (required)
                const TextSpan(
                    text: ' *', style: TextStyle(color: TbColors.error)),
            ],
          ),
        ),
      );
}

/// Input look: grey + lock when [locked], white otherwise, red on error.
InputDecoration tbInputDecoration({
  String? hint,
  bool locked = false,
  bool hasError = false,
  Widget? prefix,
  Widget? suffix,
}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c, width: w),
      );
  final base = hasError ? TbColors.error : TbColors.fieldBorder;
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: locked ? TbColors.fieldFill : Colors.white,
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9AA5B4), fontSize: 13),
    prefixIcon: prefix,
    suffixIcon: locked
        ? const Icon(Icons.lock_outline, size: 16, color: Color(0xFF9AA5B4))
        : suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: b(base),
    enabledBorder: b(locked && !hasError ? TbColors.fieldFill : base),
    disabledBorder: b(TbColors.fieldFill),
    focusedBorder: b(hasError ? TbColors.error : TbColors.brand, 1.5),
  );
}

/// Red helper text under a field.
class TbErrorText extends StatelessWidget {
  const TbErrorText(this.text, {super.key});
  final String? text;

  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(text!,
              style: const TextStyle(color: TbColors.error, fontSize: 11)),
        );
}

/// Lays children out in [columns] (1 on phones) with equal widths.
class TbGrid extends StatelessWidget {
  const TbGrid({super.key, required this.children, this.spans});

  final List<Widget> children;

  /// Relative width of each child on wide screens (default 1 each).
  final List<int>? spans;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 520) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(flex: spans?[i] ?? 1, child: children[i]),
          ],
        ],
      );
    });
  }
}

/// Primary / secondary bottom buttons.
ButtonStyle tbPrimaryButton([Color color = TbColors.brand]) =>
    FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );

ButtonStyle tbSecondaryButton() => OutlinedButton.styleFrom(
      foregroundColor: TbColors.brand,
      side: const BorderSide(color: TbColors.brand),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
