import 'package:flutter/material.dart';

import '../../services/audio/audio_service.dart';
import '../art.dart';
import '../theme/app_theme.dart';

enum ButtonSound { tap, back, none }

class CabinBackground extends StatelessWidget {
  const CabinBackground({required this.asset, required this.child, super.key});

  final String asset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        image: DecorationImage(
          image: AssetImage(asset),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: child,
    );
  }
}

class CabinButton extends StatefulWidget {
  const CabinButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.highlighted = false,
    this.sound = ButtonSound.tap,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool highlighted;
  final ButtonSound sound;

  @override
  State<CabinButton> createState() => _CabinButtonState();
}

class _CabinButtonState extends State<CabinButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        final sound = SoundScope.maybeOf(context);
        if (!enabled) {
          sound?.unavailable();
          return;
        }
        if (widget.sound == ButtonSound.tap) sound?.tap();
        if (widget.sound == ButtonSound.back) sound?.back();
        widget.onPressed!();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 44),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.highlighted
                  ? const Color(0xFF2C3138)
                  : widget.filled
                  ? AppColors.panel
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.highlighted
                    ? AppColors.text
                    : enabled
                    ? AppColors.steel
                    : AppColors.muted,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Center(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 0.4,
                    color: enabled ? AppColors.text : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TechnicalLabel extends StatelessWidget {
  const TechnicalLabel(this.text, {this.center = false, super.key});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.text,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({required this.title, required this.onBack, super.key});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CabinButton(label: 'BACK', onPressed: onBack, sound: ButtonSound.back),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    );
  }
}

Future<bool> showCabinConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  required String cancel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _CabinDialog(
      title: title,
      body: body,
      actions: [
        CabinButton(label: cancel, onPressed: () => Navigator.pop(context, false)),
        CabinButton(
          label: confirm,
          filled: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  ).then((value) => value ?? false);
}

Future<void> showCabinMessage(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CabinDialog(
      title: null,
      body: message,
      actions: [
        CabinButton(label: 'CLOSE', onPressed: () => Navigator.pop(context)),
      ],
    ),
  );
}

class _CabinDialog extends StatelessWidget {
  const _CabinDialog({
    required this.title,
    required this.body,
    required this.actions,
  });

  final String? title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.steel),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
              ],
              Text(body, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 20),
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                actions[index],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CabinImage extends StatelessWidget {
  const CabinImage(this.asset, {this.fit = BoxFit.contain, super.key});

  final String asset;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, fit: fit, filterQuality: FilterQuality.medium);
  }
}

String cabinIllustration({required bool steel}) =>
    steel ? Art.cabinSteel : Art.cabinClosed;
