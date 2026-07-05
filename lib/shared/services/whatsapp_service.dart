import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  /// Sends a WhatsApp message to the given phone number.
  /// Phone number should be in international format without + (e.g., '201012345678')
  static Future<bool> sendMessage({required String phone, required String message}) async {
    // Clean the phone number
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Add Egypt country code if not present
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = '2$cleaned'; // Egypt: 0 → 20
    } else if (!cleaned.startsWith('20') && cleaned.length == 10) {
      cleaned = '20$cleaned';
    }

    final encoded = Uri.encodeComponent(message);
    final url = 'https://wa.me/$cleaned?text=$encoded';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // --- Pre-built message templates ---

  static String invoiceMessage({
    required String customerName,
    required String invoiceNumber,
    required double totalAmount,
    required String paymentType,
  }) {
    final payment = paymentType == 'CASH' ? 'كاش' : 'بالتقسيط';
    return '''السلام عليكم ورحمة الله، أستاذ/ة $customerName 🌊

نشكركم على ثقتكم بشركة زمزم للفلاتر ✨

تفاصيل فاتورتكم:
📋 رقم الفاتورة: $invoiceNumber
💰 إجمالي المبلغ: ${totalAmount.toStringAsFixed(2)} ج.م
💳 طريقة الدفع: $payment

نتمنى لكم دوام الصحة والسلامة 🤲''';
  }

  static String installmentReminderMessage({
    required String customerName,
    required double amount,
    required String dueDate,
    required int installmentNumber,
  }) {
    return '''السلام عليكم أستاذ/ة $customerName 👋

تذكير بموعد سداد القسط رقم $installmentNumber:
📅 تاريخ الاستحقاق: $dueDate
💰 المبلغ: ${amount.toStringAsFixed(2)} ج.م

نرجو التكرم بالسداد في الموعد المحدد.
شركة زمزم للفلاتر 🌊''';
  }

  static String maintenanceConfirmationMessage({
    required String customerName,
    required String date,
    required String issueDescription,
  }) {
    return '''السلام عليكم أستاذ/ة $customerName 🔧

نؤكد لكم موعد زيارة الصيانة:
📅 التاريخ: $date
🔍 الخدمة: $issueDescription

سيقوم فنينا بالزيارة في الوقت المحدد.
شركة زمزم للفلاتر 🌊''';
  }

  static String maintenanceDueMessage({
    required String customerName,
  }) {
    return '''السلام عليكم أستاذ/ة $customerName 💧

نود إعلامكم أن موعد الصيانة الدورية لجهاز الفلتر لديكم قد حان.

للحجز وتحديد الموعد المناسب، يرجى التواصل معنا.
شركة زمزم للفلاتر 🌊''';
  }
}
