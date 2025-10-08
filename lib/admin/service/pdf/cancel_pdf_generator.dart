// Full Cancel PDF with Booking PDF style

import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CancelPdfPage extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final Map<String, dynamic> hallDetails;
  final Map<String, dynamic> cancelData;
  final Color oliveGreen;
  final Color tan;
  final Color beigeBackground;

  const CancelPdfPage({
    super.key,
    required this.bookingData,
    required this.hallDetails,
    required this.cancelData,
    required this.oliveGreen,
    required this.tan,
    required this.beigeBackground,
  });

  @override
  Widget build(BuildContext context) {
    final pdfFuture = _generatePdf();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Cancel PDF",
          style: TextStyle(color: tan, fontWeight: FontWeight.bold),
        ),
        backgroundColor: oliveGreen,
        iconTheme: IconThemeData(color: tan),
      ),
      backgroundColor: beigeBackground,
      body: FutureBuilder<Uint8List>(
        future: pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error generating PDF: ${snapshot.error}"));
          } else {
            final pdfData = snapshot.data!;
            return PdfPreview(
              build: (format) => pdfData,
              allowPrinting: false,
              allowSharing: false,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
            );
          }
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: oliveGreen,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.print),
                label: const Text("Print"),
                onPressed: () {
                  pdfFuture.then((pdfData) {
                    Printing.layoutPdf(onLayout: (format) async => pdfData);
                  });
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.share),
                label: const Text("Share"),
                onPressed: () {
                  pdfFuture.then((pdfData) {
                    Printing.sharePdf(bytes: pdfData, filename: "booking.pdf");
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generatePdf() async {
    final ttf = await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf");
    final ttfBold = await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf");
    final font = pw.Font.ttf(ttf);
    final fontBold = pw.Font.ttf(ttfBold);

    final updatedBooking = cancelData['updatedBooking'] ?? {};
    final cancelRecord = cancelData['cancelRecord'] ?? {};

    final pdf = pw.Document();

    // Logo
    Uint8List? hallLogo;
    if (hallDetails['logo'] != null && hallDetails['logo'].isNotEmpty) {
      try { hallLogo = base64Decode(hallDetails['logo']); } catch (_) {}
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (hallLogo != null) pw.Image(pw.MemoryImage(hallLogo), width: 70, height: 70),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(hallDetails['name']?.toString().toUpperCase() ?? 'HALL NAME', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, font: fontBold)),
                    if ((hallDetails['address'] ?? '').toString().isNotEmpty) pw.Text(hallDetails['address'], style: pw.TextStyle(font: font)),
                    if ((hallDetails['phone'] ?? '').toString().isNotEmpty) pw.Text('Phone: ${hallDetails['phone']}', style: pw.TextStyle(font: font)),
                    if ((hallDetails['email'] ?? '').toString().isNotEmpty) pw.Text('Email: ${hallDetails['email']}', style: pw.TextStyle(font: font)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          // Bill info
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Bill no: ${bookingData['hall_id'] ?? ''}${bookingData['booking_id'] ?? ''}',
                style: pw.TextStyle(font: fontBold),
              ),
              pw.Text('Generated: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}', style: pw.TextStyle(font: font)),
            ],
          ),
          pw.Divider(thickness: 1.2),
          pw.SizedBox(height: 10),
          // Personal Info
          _sectionHeader('PERSONAL INFORMATION', fontBold),
          pw.SizedBox(height: 6),
          _infoTable([
            if ((updatedBooking['name'] ?? '').toString().isNotEmpty) ['NAME', updatedBooking['name']],
            if ((updatedBooking['phone'] ?? '').toString().isNotEmpty) ['PHONE', updatedBooking['phone']],
            if ((updatedBooking['address'] ?? '').toString().isNotEmpty) ['ADDRESS', updatedBooking['address']],
            if (updatedBooking['alternate_phone'] != null && (updatedBooking['alternate_phone'] as List).isNotEmpty)
              ['ALTERNATE PHONE', (updatedBooking['alternate_phone'] as List).join(', ')],
            if ((updatedBooking['email'] ?? '').toString().isNotEmpty) ['EMAIL', updatedBooking['email']],
          ], font),
          pw.SizedBox(height: 20),
          // Booking Info
          _sectionHeader('BOOKING INFORMATION', fontBold),
          pw.SizedBox(height: 6),
          _infoTable([
            if ((updatedBooking['event_type'] ?? '').toString().isNotEmpty) ['EVENT', updatedBooking['event_type']],
            if ((updatedBooking['function_date'] ?? '').toString().isNotEmpty)
              ['FUNCTION DATE', DateFormat('dd-MM-yyyy').format(DateTime.parse(updatedBooking['function_date']).toLocal())],
            if ((updatedBooking['alloted_datetime_from'] ?? '').toString().isNotEmpty &&
                (updatedBooking['alloted_datetime_to'] ?? '').toString().isNotEmpty)
              [
                'ALLOTED TIME',
                '${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(updatedBooking['alloted_datetime_from']).toLocal())} to ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(updatedBooking['alloted_datetime_to']).toLocal())}'
              ],
            if ((updatedBooking['rent'] ?? '').toString().isNotEmpty) ['RENT', updatedBooking['rent'].toString()],
            if ((updatedBooking['advance'] ?? '').toString().isNotEmpty) ['ADVANCE PAID', updatedBooking['advance'].toString()],
            if ((updatedBooking['balance'] ?? '').toString().isNotEmpty) ['BALANCE', updatedBooking['balance'].toString()],
          ], font),
          pw.SizedBox(height: 20),
          // Cancellation Info
          _sectionHeader('CANCELLATION INFORMATION', fontBold),
          pw.SizedBox(height: 6),
          _infoTable([
            if ((cancelRecord['reason'] ?? '').toString().isNotEmpty) ['REASON', cancelRecord['reason']],
            if ((cancelRecord['cancel_charge'] ?? '').toString().isNotEmpty) ['CANCEL CHARGE', cancelRecord['cancel_charge'].toString()],
            if ((cancelRecord['total_paid'] ?? '').toString().isNotEmpty) ['TOTAL PAID', cancelRecord['total_paid'].toString()],
            if ((cancelRecord['refund'] ?? '').toString().isNotEmpty) ['REFUND', cancelRecord['refund'].toString()],
            ['CANCELLED ON', DateFormat('dd-MM-yyyy hh:mm a').format(
                cancelRecord['created_at'] != null ? DateTime.parse(cancelRecord['created_at']).toLocal() : DateTime.now())],
          ], font),
          pw.SizedBox(height: 30),
          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 120, height: 1, color: PdfColors.grey),
                  pw.Text('Manager', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fontBold)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 120, height: 1, color: PdfColors.grey),
                  pw.Text('Booking Person', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fontBold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _sectionHeader(String title, pw.Font font) {
    return pw.Container(
      width: double.infinity,
      color: PdfColor.fromInt(oliveGreen.value),
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(title, style: pw.TextStyle(font: font, color: PdfColor.fromInt(tan.value), fontWeight: pw.FontWeight.bold, fontSize: 16)),
    );
  }

  pw.Widget _infoTable(List<List<String>> data, pw.Font font) {
    return pw.Table.fromTextArray(
      headers: ['Field', 'Value'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(oliveGreen.value)),
      cellStyle: pw.TextStyle(font: font),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      data: data,
      rowDecoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
    );
  }
}
