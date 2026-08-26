import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readytech/core/theme/app_spacing.dart';

/// The single text input used across ReadyTech.
///
/// Wraps [TextFormField] to standardise the label-above-field layout, the error
/// presentation and the password reveal. Validation messages sit outside the
/// field's own decoration so a long message does not shift the layout of a
/// form as the user types.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    required this.controller,
    super.key,
    this.hint,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.obscureText = false,
    this.autofillHints,
    this.prefixIcon,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helperText;

  /// Server-side or cross-field error. Local [validator] errors take priority.
  final String? errorText;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final IconData? prefixIcon;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.titleSmall),
        VGap.sm,
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          maxLines: _obscured ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          // Validate as soon as the user has had a chance to be wrong, not on
          // every keystroke from the first character.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            counterText: '',
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 20),
            suffixIcon: widget.obscureText
                ? IconButton(
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                  )
                : null,
          ),
        ),
        if (widget.helperText != null) ...[
          VGap.xs,
          Text(widget.helperText!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
