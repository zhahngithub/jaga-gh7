import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jaga/core/theme/app_colors.dart';

class PinInputField extends StatelessWidget {
  const PinInputField({
    required this.controller,
    required this.focusNode,
    required this.semanticLabel,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.onCompleted,
    this.obscureText = true,
    this.textInputAction = TextInputAction.next,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String semanticLabel;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool obscureText;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, focusNode]),
      builder: (context, _) {
        final value = controller.text;
        final hasError = errorText != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: semanticLabel,
              value: '${value.length} dari 4 digit terisi',
              textField: true,
              obscured: obscureText,
              enabled: enabled,
              onTap: enabled ? focusNode.requestFocus : null,
              child: GestureDetector(
                onTap: enabled ? focusNode.requestFocus : null,
                child: Stack(
                  children: [
                    ExcludeSemantics(
                      child: Opacity(
                        opacity: 0,
                        child: SizedBox(
                          height: 58,
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            enabled: enabled,
                            keyboardType: TextInputType.number,
                            textInputAction: textInputAction,
                            obscureText: obscureText,
                            enableSuggestions: false,
                            autocorrect: false,
                            showCursor: false,
                            maxLines: 1,
                            inputFormatters: const [PinTextInputFormatter()],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              counterText: '',
                            ),
                            onChanged: (newValue) {
                              onChanged?.call(newValue);
                              if (newValue.length == 4) {
                                onCompleted?.call(newValue);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Row(
                        children: List.generate(4, (index) {
                          final isFilled = index < value.length;
                          final isActive =
                              focusNode.hasFocus &&
                              index == (value.length < 4 ? value.length : 3);
                          final borderColor = hasError
                              ? Colors.red
                              : isActive
                              ? AppColors.primary
                              : const Color(0xFFD6E7F2);

                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: index == 3 ? 0 : 10,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                height: 58,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: enabled
                                      ? const Color(0xFFF7FBFE)
                                      : const Color(0xFFF0F2F4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: borderColor,
                                    width: isActive ? 1.6 : 1,
                                  ),
                                ),
                                child: Text(
                                  isFilled
                                      ? obscureText
                                            ? '\u2022'
                                            : value[index]
                                      : '',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: AppColors.textDark,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  errorText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class PinTextInputFormatter extends TextInputFormatter {
  const PinTextInputFormatter();

  static final RegExp _digitsOnly = RegExp(r'^\d*$');
  static final RegExp _completePin = RegExp(r'^\d{4}$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.length > 4 || !_digitsOnly.hasMatch(text)) {
      return oldValue;
    }

    final selectedLength = oldValue.selection.isValid
        ? oldValue.selection.end - oldValue.selection.start
        : 0;
    final insertedLength =
        text.length - (oldValue.text.length - selectedLength);
    if (insertedLength > 1 && !_completePin.hasMatch(text)) {
      return oldValue;
    }

    return newValue.copyWith(
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }
}
