import 'package:flutter/services.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/spacing_extension.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.isPassword = false,
    this.prefixIcon,
    this.maxLength,
    this.enabled = true,
    this.onFieldSubmitted,
    this.onChanged,
    this.focusNode,
    this.autofillHints,
    this.decoration,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool isPassword;
  final IconData? prefixIcon;
  final int? maxLength;
  final bool enabled;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final InputDecoration? decoration;
  final AutovalidateMode autovalidateMode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
      8.sizedBoxHeight(),
      _buildInput(),
    ],
  );

  Widget _buildInput() => TextFormField(
    controller: widget.controller,
    focusNode: widget.focusNode,
    validator: widget.validator,
    keyboardType: widget.keyboardType,
    textInputAction: widget.textInputAction,
    inputFormatters: widget.inputFormatters,
    obscureText: widget.isPassword && _obscure,
    autocorrect: false,
    enableSuggestions: !widget.isPassword,
    autofillHints: widget.autofillHints,
    maxLength: widget.maxLength,
    enabled: widget.enabled,
    onChanged: widget.onChanged,
    onFieldSubmitted: widget.onFieldSubmitted,
    autovalidateMode: widget.autovalidateMode,
    style: Theme.of(context).textTheme.bodyMedium,
    decoration:
        widget.decoration ??
        InputDecoration(
          hintText: widget.hint,
          counterText: '',
          prefixIcon: widget.prefixIcon == null
              ? null
              : Icon(widget.prefixIcon, size: 20.r),
          suffixIcon: widget.isPassword ? _buildVisibilityToggle() : null,
        ),
  );

  Widget _buildVisibilityToggle() => IconButton(
    tooltip: _obscure ? 'Show password' : 'Hide password',
    icon: Icon(
      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      size: 20.r,
    ),
    onPressed: widget.enabled
        ? () => setState(() => _obscure = !_obscure)
        : null,
  );
}
