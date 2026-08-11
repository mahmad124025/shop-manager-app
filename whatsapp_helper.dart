import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class WhatsAppHelper {

  static Future<void> sendReminder({
    required String phone,
    required String name,
    required double balance,
    BuildContext? context,
  }) async {
    // Phone number format karo
    String formattedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '92' + formattedPhone.substring(1);
    }

    if (formattedPhone.isEmpty) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No phone number saved for this customer — نمبر محفوظ نہیں'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    // Message banao
    String message =
      'Assalam o Alaikum $name bhai,\n\n'
      'Aapka RS ${balance.toStringAsFixed(0)} udhar baaki hai.\n\n'
      'Please jald payment kar dein.\n\n'
      'Shukriya! ';

    // WhatsApp URL
    Uri url = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');

    try {
      bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp — واٹس ایپ نہیں کھل سکا'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WhatsApp is not installed — واٹس ایپ انسٹال نہیں ہے'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}