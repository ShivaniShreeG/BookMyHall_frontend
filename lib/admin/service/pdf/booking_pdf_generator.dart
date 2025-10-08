import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

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
    final pdfFuture = _buildPdf();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Booking PDF",
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

  Future<Uint8List> _buildPdf() async {
    final pdf = pw.Document();

    // ---------- LOAD TAMIL FONT ----------
    final tamilFont = pw.Font.ttf(
      await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf"),
    );
    final tamilFontBold = pw.Font.ttf(
      await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf"),
    );

    final darkBlue = PdfColor.fromInt(0xFF556B2F);
    final lightBlue = PdfColor.fromInt(0xFFF5F5DC);
    final mutedTanPdf = PdfColor.fromInt(0xFFD2B48C);

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
    final hallEmail = hallDetails['email'] ?? '';
    final hallId = hallDetails['hall_id'] ?? 0;
    final bookingId = bookingData['booking_id'] ?? 0;
    final billNo = '$hallId$bookingId';
    final billDateTime = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());

    // ---------- PAGE 1 ----------
    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: tamilFont, bold: tamilFontBold),
        build: (context) => [
          // HEADER (LOGO + NAME)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (hallLogo != null)
                pw.Image(pw.MemoryImage(hallLogo), width: 70, height: 70),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      hallName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: darkBlue,
                        font: tamilFontBold,
                      ),
                    ),
                    if (hallAddress.isNotEmpty)
                      pw.Text(hallAddress,
                          textAlign: pw.TextAlign.center, style: pw.TextStyle(font: tamilFont)),
                    if (hallPhone.isNotEmpty)
                      pw.Text("Phone: $hallPhone", style: pw.TextStyle(font: tamilFont)),
                    if (hallEmail.isNotEmpty)
                      pw.Text("Email: $hallEmail", style: pw.TextStyle(font: tamilFont)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // BILL INFO
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("Bill No: $billNo",
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: darkBlue,
                      font: tamilFontBold)),
              pw.Text("Generated: $billDateTime",
                  style: pw.TextStyle(fontSize: 10, font: tamilFont)),
            ],
          ),
          pw.Divider(thickness: 1.2, color: darkBlue),
          pw.SizedBox(height: 10),

          // PERSONAL DETAILS
          _sectionHeader("PERSONAL INFORMATION", darkBlue, tamilFontBold),
          pw.SizedBox(height: 6),
          _infoTable([
            if ((bookingData['name'] ?? '').toString().isNotEmpty)
              ["NAME", bookingData['name']],
            if ((bookingData['phone'] ?? '').toString().isNotEmpty)
              ["PHONE", bookingData['phone']],
            if ((bookingData['address'] ?? '').toString().isNotEmpty)
              ["ADDRESS", bookingData['address']],
            if ((bookingData['email'] ?? '').toString().isNotEmpty)
              ["EMAIL", bookingData['email']],
            if (bookingData['alternate_phone'] != null &&
                (bookingData['alternate_phone'] as List).isNotEmpty)
              [
                "ALTERNATE PHONE",
                (bookingData['alternate_phone'] as List).join(", ")
              ],
          ], lightBlue, tamilFont),

          pw.SizedBox(height: 20),

          // BOOKING DETAILS
          _sectionHeader("BOOKING INFORMATION", darkBlue, tamilFontBold),
          pw.SizedBox(height: 6),
          _infoTable([
            if ((bookingData['event_type'] ?? '').toString().isNotEmpty)
              ["EVENT", bookingData['event_type']],
            if ((bookingData['function_date'] ?? '').toString().isNotEmpty)
              [
                "FUNCTION DATE",
                DateFormat('dd-MM-yyyy')
                    .format(DateTime.parse(bookingData['function_date'])),
              ],
            if ((bookingData['alloted_datetime_from'] ?? '').toString().isNotEmpty &&
                (bookingData['alloted_datetime_to'] ?? '').toString().isNotEmpty)
              [
                "ALLOTED TIME",
                DateFormat('dd-MM-yyyy hh:mm a')
                    .format(DateFormat('yyyy-MM-dd hh:mm a')
                    .parse(bookingData['alloted_datetime_from'])),
                DateFormat('dd-MM-yyyy hh:mm a')
                    .format(DateFormat('yyyy-MM-dd hh:mm a')
                    .parse(bookingData['alloted_datetime_to'])),
              ],
          ], lightBlue, tamilFont),

          pw.SizedBox(height: 20),

          // ---------- PAYMENT DETAILS ----------
          pw.SizedBox(height: 10),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left Column - Payment Information
              pw.Container(
                width: PdfPageFormat.a4.availableWidth * 0.74, // 48% of page
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header
                    pw.Container(
                      width: double.infinity,
                      color: darkBlue,
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        "PAYMENT INFORMATION",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          font: tamilFontBold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4), // space after header

                    // Rows
                    ...[
                      if (bookingData['rent'] != null) "RENT",
                      if (bookingData['advance'] != null) "ADVANCE",
                      if (bookingData['balance'] != null) "BALANCE",
                    ].map((label) {
                      final isBalance = label == "BALANCE";
                      return pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        margin: const pw.EdgeInsets.only(bottom: 4), // space between rows
                        child: pw.Text(
                          label,
                          style: pw.TextStyle(
                            fontWeight: isBalance ? pw.FontWeight.bold : pw.FontWeight.normal,
                            font: tamilFont,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),

              pw.SizedBox(width: PdfPageFormat.a4.availableWidth * 0.04), // 4% gap

              // Right Column - Amounts
              pw.Container(
                width: PdfPageFormat.a4.availableWidth * 0.35,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Header
                    pw.Container(
                      width: double.infinity,
                      color: darkBlue,
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        "AMOUNT",
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          font: tamilFontBold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4), // space after header

                    // Rows
                    ...[
                      if (bookingData['rent'] != null) "Rs.${bookingData['rent']}",
                      if (bookingData['advance'] != null) "Rs.${bookingData['advance']}",
                      if (bookingData['balance'] != null) "Rs.${bookingData['balance']}",
                    ].map((amount) {
                      final isBalance = amount.contains(bookingData['balance'].toString());
                      return pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        margin: const pw.EdgeInsets.only(bottom: 4), // space between rows
                        child: pw.Text(
                          amount,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontWeight: isBalance ? pw.FontWeight.bold : pw.FontWeight.normal,
                            font: tamilFont,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),


          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text("Thank you for your booking!",
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: darkBlue,
                    font: tamilFontBold)),
          ),
          pw.SizedBox(height: 40),

          // SIGNATURES
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 120, height: 1, color: PdfColors.grey),
                  pw.Text("Manager",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, font: tamilFontBold))
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 120, height: 1, color: PdfColors.grey),
                  pw.Text("Booking Person",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, font: tamilFontBold))
                ],
              ),
            ],
          ),
        ],
      ),
    );

    // ---------- PAGE 2 (INSTRUCTIONS) ----------
    final instructions = hallDetails['instructions'] as List<dynamic>?;

    if (instructions != null && instructions.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(20),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                color: darkBlue,
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Center(
                  child: pw.Text(
                    "INSTRUCTIONS",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      font: tamilFontBold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: instructions.map((instr) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Text(
                      "• ${instr.toString()}",
                      style: pw.TextStyle(font: tamilFont),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    }

    return pdf.save();
  }

  // ---------- Helper Widgets ----------

  pw.Widget _sectionHeader(String title, PdfColor color, pw.Font font) {
    return pw.Container(
      width: double.infinity,
      color: color,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(title,
          style: pw.TextStyle(
              color: PdfColors.white, fontWeight: pw.FontWeight.bold, font: font)),
    );
  }

  pw.Widget _infoTable(List<List<String?>> data, PdfColor shade, pw.Font font) {
    return pw.Center(
      child: pw.Table(
        children: data.map((row) {
          if (row.length == 3) {
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Container(
                    color: PdfColors.white,
                    child: pw.Text(row[0] ?? "",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, font: font)),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        color: shade,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: pw.Text(row[1] ?? "", style: pw.TextStyle(font: font)),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text("to", style: pw.TextStyle(font: font)),
                      pw.SizedBox(width: 4),
                      pw.Container(
                        color: shade,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: pw.Text(row[2] ?? "", style: pw.TextStyle(font: font)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Container(
                    color: PdfColors.white,
                    child: pw.Text(row[0] ?? "",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font)),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Container(
                    color: shade,
                    child: pw.Text(row[1] ?? "", style: pw.TextStyle(font: font)),
                  ),
                ),
              ],
            );
          }
        }).toList(),
      ),
    );
  }
}
