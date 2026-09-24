import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Крупная кнопка действия: увеличенная зона нажатия, тактильный отклик
/// и подпись для скринридера.
class BigActionButton extends StatelessWidget {
  const BigActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = true,
    this.semanticHint,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// Залитая кнопка — основное действие, обведённая — второстепенное.
  final bool filled;

  /// Что произойдёт после нажатия — зачитывается скринридером после подписи.
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size.fromHeight(AppTheme.minTouchTarget),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 36),
        const SizedBox(width: 16),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );

    void handlePress() {
      // Подтверждение нажатия для тех, кто не видит изменения состояния.
      HapticFeedback.mediumImpact();
      onPressed();
    }

    return Semantics(
      button: true,
      label: label,
      hint: semanticHint,
      // Кнопка уже описана этим Semantics; иначе скринридер прочитает
      // подпись дважды.
      excludeSemantics: true,
      child: filled
          ? FilledButton(onPressed: handlePress, style: style, child: child)
          : OutlinedButton(
              onPressed: handlePress,
              style: style.copyWith(
                side: const WidgetStatePropertyAll(
                  BorderSide(color: AppTheme.accent, width: 3),
                ),
                foregroundColor: const WidgetStatePropertyAll(AppTheme.accent),
              ),
              child: child,
            ),
    );
  }
}
