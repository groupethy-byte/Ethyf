import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Hapus semua karakter selain angka
    String numericString = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numericString.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final formatter = NumberFormat('#,##0', 'id_ID');
    String formatted = formatter.format(int.parse(numericString));

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CurrencyWithDecimalFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Hapus semua karakter selain angka dan koma
    String text = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');

    // Jika ada lebih dari satu koma, hapus yang tambahan
    List<String> parts = text.split(',');
    if (parts.length > 2) {
      text = '${parts[0]},${parts[1]}';
    }

    // Pisahkan bagian integer dan desimal
    if (!text.contains(',')) {
      String numericString = text.replaceAll(RegExp(r'[^0-9]'), '');
      if (numericString.isEmpty) {
        return newValue.copyWith(text: '');
      }
      
      final formatter = NumberFormat('#,##0', 'id_ID');
      String formatted = formatter.format(int.parse(numericString));
      
      return newValue.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } else {
      List<String> parts = text.split(',');
      String integerPart = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
      String decimalPart = parts[1];

      if (integerPart.isEmpty) integerPart = '0';
      
      // Format integer part
      final formatter = NumberFormat('#,##0', 'id_ID');
      String formattedInteger = formatter.format(int.parse(integerPart));
      
      // Batasi decimal part ke 2 digit
      if (decimalPart.length > 2) {
        decimalPart = decimalPart.substring(0, 2);
      }

      String result = '$formattedInteger,$decimalPart';
      
      return newValue.copyWith(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
  }
}

// Helper function untuk parse nilai dari formatted string
String parseFormattedCurrency(String formattedValue) {
  return formattedValue.replaceAll('.', '').replaceAll(',', '.');
}

String parseFormattedInteger(String formattedValue) {
  return formattedValue.replaceAll('.', '').replaceAll(',', '');
}

