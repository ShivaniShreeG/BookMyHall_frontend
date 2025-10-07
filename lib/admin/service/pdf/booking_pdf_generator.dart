import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class BookingPdfPage extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final Map<String, dynamic> hallDetails;
  final Color oliveGreen;
  final Color tan;
  final Color beigeBackground;

  const BookingPdfPage({
    super.key,
    required this.bookingData,
    required this.hallDetails,
    required this.oliveGreen,
    required this.tan,
    required this.beigeBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Booking PDF", style: TextStyle(color: tan, fontWeight: FontWeight.bold)),
        backgroundColor: oliveGreen,
        iconTheme: IconThemeData(color: tan),
      ),
      backgroundColor: beigeBackground,
      body: PdfPreview(
        build: (format) => _buildPdf(),
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }

  Future<Uint8List> _buildPdf() async {
    final ttf = await PdfGoogleFonts.notoSerifTamilRegular();
    final ttfBold = await PdfGoogleFonts.notoSerifTamilBold();
    final pdf = pw.Document();

    Uint8List? hallLogo;
    if (hallDetails['logo'] != null && hallDetails['logo'].isNotEmpty) {
      try {
        hallLogo = base64Decode(hallDetails['logo']);
      } catch (_) {
        hallLogo = null;
      }
    }

    final hallName = hallDetails['name'] ?? '';
    final hallAddress = hallDetails['address'] ?? '';
    final hallPhone = hallDetails['phone'] ?? '';
    final hallId = hallDetails['hall_id'] ?? 0;
    final bookingId = bookingData['booking_id'] ?? 0;
    final billNo = '$hallId$bookingId';
    final billDateTime = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (hallLogo != null)
                pw.Image(pw.MemoryImage(hallLogo), width: 60, height: 60),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(hallName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.Text(hallAddress),
                  pw.Text("Phone: $hallPhone"),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Bill Info
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("Bill No: $billNo", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
              pw.Text("Generated: $billDateTime"),
            ],
          ),
          pw.Divider(thickness: 1.5, color: PdfColors.green900),
          pw.SizedBox(height: 10),

          // Personal Details
          _pdfSectionHeader("Personal Details", PdfColors.green900),
          pw.SizedBox(height: 6),
          _pdfTableWithShading([
            _pdfTableRow("Customer Name", bookingData['name']),
            _pdfTableRow("Phone", bookingData['phone']),
            _pdfTableRow("Address", bookingData['address']),
            if (bookingData['email'] != null)
              _pdfTableRow("Email", bookingData['email']),
            if (bookingData['alternate_phone'] != null &&
                (bookingData['alternate_phone'] as List).isNotEmpty)
              _pdfTableRow("Alternate Phone", (bookingData['alternate_phone'] as List).join(", ")),
          ]),
          pw.SizedBox(height: 20),

          // Booking Details
          _pdfSectionHeader("Booking Details", PdfColors.green900),
          pw.SizedBox(height: 6),
          _pdfTableWithShading([
            _pdfTableRow("Event Type", bookingData['event_type']),
            _pdfTableRow("Function Date", DateFormat('dd-MM-yyyy').format(DateTime.parse(bookingData['function_date']))),
            _pdfTableRow("From", DateFormat('dd-MM-yyyy hh:mm a').format(DateFormat('yyyy-MM-dd hh:mm a').parse(bookingData['alloted_datetime_from']))),
            _pdfTableRow("To", DateFormat('dd-MM-yyyy hh:mm a').format(DateFormat('yyyy-MM-dd hh:mm a').parse(bookingData['alloted_datetime_to']))),
          ]),
          pw.SizedBox(height: 20),

          // Payment Details
          _pdfSectionHeader("Payment Details", PdfColors.green900),
          pw.SizedBox(height: 6),
          _pdfTableWithShading([
            _pdfTableRow("Rent", "Rs.${bookingData['rent']}", isAmount: true),
            _pdfTableRow("Advance", "Rs.${bookingData['advance']}", isAmount: true),
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Balance", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Rs.${bookingData['balance']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
              ],
            ),
          ]),

          pw.SizedBox(height: 20),
          pw.Center(child: pw.Text("Thank you for your booking!", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
          pw.SizedBox(height: 40),

          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 150, height: 1, color: PdfColors.grey),
                  pw.Text("Manager", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(width: 150, height: 1, color: PdfColors.grey),
                  pw.Text("Booking Person", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final instructions = hallDetails['instructions'] as List<dynamic>?;
    if (instructions != null && instructions.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          build: (context) => [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              color: PdfColors.green900,
              child: pw.Text("Instructions", textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: instructions.map((instr) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Text("• ${instr.toString()}", style: pw.TextStyle(fontSize: 12)),
              )).toList(),
            ),
          ],
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _pdfSectionHeader(String title, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      color: color,
      child: pw.Text(title, style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Table _pdfTableWithShading(List<pw.TableRow> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: rows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: index.isEven ? PdfColors.grey100 : PdfColors.white),
          children: row.children!,
        );
      }).toList(),
    );
  }

  pw.TableRow _pdfTableRow(String label, String? value, {bool isAmount = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Align(alignment: isAmount ? pw.Alignment.centerRight : pw.Alignment.centerLeft, child: pw.Text(value ?? "")),
        ),
      ],
    );
  }
}
