import 'package:flutter/services.dart';

/// Formatter that automatically inserts thousands separators (,) every 3 digits.
///
/// Examples:
///   1200 -> 1,200
///   1200000 -> 1,200,000
///   1200.50 -> 1,200.50
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final bool allowFraction;

  ThousandsSeparatorInputFormatter({this.allowFraction = true});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String text = newValue.text;

    // Check if user typed a comma intended as decimal separator (e.g. single comma with no dot and <= 2 decimal digits)
    if (allowFraction && text.contains(',') && !text.contains('.')) {
      final parts = text.split(',');
      if (parts.length == 2 && parts[1].length <= 2 && !RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(text)) {
        text = '${parts[0]}.${parts[1]}';
      }
    }

    // Remove existing commas to get raw digits/dot
    text = text.replaceAll(',', '');

    bool hasDot = allowFraction && text.contains('.');
    String integerPart = text;
    String decimalPart = '';

    if (hasDot) {
      final parts = text.split('.');
      integerPart = parts[0];
      if (parts.length > 1) {
        decimalPart = parts.sublist(1).join('');
      }
    }

    // Clean out any non-numeric characters
    integerPart = integerPart.replaceAll(RegExp(r'[^\d]'), '');
    decimalPart = decimalPart.replaceAll(RegExp(r'[^\d]'), '');

    if (integerPart.isEmpty && !hasDot) {
      return const TextEditingValue();
    }

    String formattedInteger = '';
    if (integerPart.isNotEmpty) {
      final bigVal = BigInt.tryParse(integerPart);
      if (bigVal != null) {
        formattedInteger = formatThousands(bigVal);
      } else {
        formattedInteger = integerPart;
      }
    }

    String formattedText = formattedInteger;
    if (hasDot) {
      if (formattedText.isEmpty) {
        formattedText = '0';
      }
      formattedText += '.$decimalPart';
    }

    // Maintain accurate cursor position
    int digitsBeforeCursor = 0;
    for (int i = 0; i < newValue.selection.end && i < newValue.text.length; i++) {
      final char = newValue.text[i];
      if (RegExp(r'[\d.]').hasMatch(char)) {
        digitsBeforeCursor++;
      }
    }

    int newCursorIndex = 0;
    int digitsSeen = 0;
    for (int i = 0; i < formattedText.length; i++) {
      if (digitsSeen >= digitsBeforeCursor) {
        break;
      }
      final char = formattedText[i];
      if (RegExp(r'[\d.]').hasMatch(char)) {
        digitsSeen++;
      }
      newCursorIndex = i + 1;
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newCursorIndex),
    );
  }

  static String formatThousands(BigInt val) {
    final str = val.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }
}
