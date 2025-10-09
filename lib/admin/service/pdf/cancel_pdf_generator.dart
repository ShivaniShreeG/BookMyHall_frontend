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
  final List<dynamic> billingList;
  final Color oliveGreen;
  final Color tan;
  final Color beigeBackground;

  const CancelPdfPage({
    super.key,
    required this.bookingData,
    required this.hallDetails,
    required this.cancelData,
    required this.billingList,
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
    // 🟢 Print all incoming data for debugging
    debugPrint("🧾 ===== Cancel PDF Data =====");
    debugPrint("Booking Data: ${jsonEncode(bookingData)}");
    debugPrint("Hall Details: ${jsonEncode(hallDetails)}");
    debugPrint("Cancel Data: ${jsonEncode(cancelData)}");
    debugPrint("Billing Data: ${jsonEncode(billingList)}");
    debugPrint("============================");
    final ttf = await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf");
    final ttfBold = await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf");
    final font = pw.Font.ttf(ttf);
    final fontBold = pw.Font.ttf(ttfBold);

    final updatedBooking = cancelData['updatedBooking'] ?? {};
    final cancelRecord = cancelData['cancelRecord'] ?? {};

    final pdf = pw.Document();

    final darkBlue = PdfColor.fromInt(0xFF556B2F); // header & section titles
    final lightBlue = PdfColor.fromInt(0xFFF5F5DC); // table row background
    final mutedTanPdf = PdfColor.fromInt(0xFFD2B48C); // signature lines



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
                    pw.Text(
                        hallDetails['name']?.toString().toUpperCase() ?? 'HALL NAME',
                        style: pw.TextStyle(
                            fontSize: 20,
                            color: darkBlue,
                            fontWeight: pw.FontWeight.bold,
                            font: fontBold
                        )
                    ),
                    if ((hallDetails['address'] ?? '').toString().isNotEmpty)
                      pw.Text(hallDetails['address'],
                          style: pw.TextStyle(font: font)),
                    if ((hallDetails['phone'] ?? '').toString().isNotEmpty)
                      pw.Text('Phone: ${hallDetails['phone']}',
                          style: pw.TextStyle(font: font)),
                    if ((hallDetails['email'] ?? '').toString().isNotEmpty)
                      pw.Text('Email: ${hallDetails['email']}',
                          style: pw.TextStyle(font: font)),
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
                style: pw.TextStyle(font: fontBold,color: darkBlue),
              ),
              pw.Text('Generated: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}', style: pw.TextStyle(font: font)),
            ],
          ),
          pw.Divider(thickness: 1.2),
          pw.SizedBox(height: 10),
          // BOOKING INFORMATION
          _sectionHeader('BOOKING INFORMATION', darkBlue, fontBold),
          _infoTable([
            if ((updatedBooking['name'] ?? '').toString().isNotEmpty) ['NAME', updatedBooking['name']],
            if ((updatedBooking['phone'] ?? '').toString().isNotEmpty) ['PHONE', updatedBooking['phone']],
            if ((bookingData['email'] ?? '').toString().isNotEmpty)
              ["EMAIL", bookingData['email']],
            if ((updatedBooking['address'] ?? '').toString().isNotEmpty) ['ADDRESS', updatedBooking['address']],
            if (bookingData['alternate_phone'] != null &&
                (bookingData['alternate_phone'] as List).isNotEmpty)
              [
                "ALTERNATE PHONE",
                (bookingData['alternate_phone'] as List).join(", ")
              ],
            if ((updatedBooking['event_type'] ?? '').toString().isNotEmpty) ['EVENT', updatedBooking['event_type']],
            if ((updatedBooking['function_date'] ?? '').toString().isNotEmpty)
              ['FUNCTION DATE', DateFormat('dd-MM-yyyy').format(DateTime.parse(updatedBooking['function_date']).toLocal())],
            if ((updatedBooking['alloted_datetime_from'] ?? '').toString().isNotEmpty &&
                (updatedBooking['alloted_datetime_to'] ?? '').toString().isNotEmpty)
              [
                'ALLOTED TIME',
                DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(updatedBooking['alloted_datetime_from']).toLocal()),
                DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(updatedBooking['alloted_datetime_to']).toLocal()),
              ],

          ], lightBlue, font),
          pw.SizedBox(height: 10),
// CANCELLATION INFORMATION
          _sectionHeader('CANCELLATION INFORMATION', darkBlue, fontBold),
          _infoTable([
            if ((cancelRecord['reason'] ?? '').toString().isNotEmpty) ['REASON', cancelRecord['reason']],
            ['CANCELLED ON', DateFormat('dd-MM-yyyy hh:mm a').format(
                cancelRecord['created_at'] != null ? DateTime.parse(cancelRecord['created_at']).toLocal() : DateTime.now())],
          ], lightBlue, font),
          pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left Column - Labels
            pw.Container(
              width: PdfPageFormat.a4.availableWidth * 0.84,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: double.infinity,
                    color: darkBlue,
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      "PAYMENT INFORMATION",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        font: font,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),

                  // Rent label
                  if ((updatedBooking['rent'] ?? '').toString().isNotEmpty)
                    pw.Container(
                      width: double.infinity,
                      color: lightBlue,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Text("RENT", style: pw.TextStyle(font: font)),
                    ),

                  // Loop through billing reasons
                  ...billingList.map((bill) {
                    if (bill['reason'] != null && bill['reason'] is Map<String, dynamic>) {
                      return pw.Column(
                        children: (bill['reason'] as Map<String, dynamic>).entries.map((entry) {
                          return pw.Container(
                            width: double.infinity,
                            color: lightBlue,
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            margin: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text(entry.key.toString().toUpperCase()),
                          );
                        }).toList(),
                      );
                    } else {
                      return pw.Container();
                    }
                  }).toList(),

                  // Total Paid label (only if more than one billing reason)
                  if (billingList.length > 1 && (cancelRecord['total_paid'] ?? '').toString().isNotEmpty)
                    pw.Container(
                      width: double.infinity,
                      color: lightBlue,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Text("TOTAL AMOUNT PAID", style: pw.TextStyle(font: fontBold)),
                    ),

                  // Cancel Charge
                  if ((cancelRecord['cancel_charge'] ?? '').toString().isNotEmpty)
                    pw.Container(
                      width: double.infinity,
                      color: lightBlue,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Text("CANCELLATION CHARGE", style: pw.TextStyle(font: font)),
                    ),

                  // Refund
                  if ((cancelRecord['refund'] ?? '').toString().isNotEmpty)
                    pw.Container(
                      width: double.infinity,
                      color: lightBlue,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Text("REFUND", style: pw.TextStyle(font: fontBold)),
                    ),
                ],
              ),
            ),


            pw.SizedBox(width: PdfPageFormat.a4.availableWidth * 0.04),

            // Right Column - Amounts
            // Right Column - Amounts
            pw.Container(
              width: PdfPageFormat.a4.availableWidth * 0.26,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
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
                          font: fontBold
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),

                  // Rent amount
                  if ((updatedBooking['rent'] ?? '').toString().isNotEmpty)
                    pw.Container(
                      width: double.infinity,
                      color: lightBlue,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Text(
                        "Rs.${updatedBooking['rent']}",
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: font),
                      ),
                    ),

                  // Billing reason amounts
                  ...billingList.map((bill) {
                    if (bill['reason'] != null && bill['reason'] is Map<String, dynamic>) {
                      return pw.Column(
                        children: (bill['reason'] as Map<String, dynamic>).entries.map((entry) {
                          return pw.Container(
                            width: double.infinity,
                            color: lightBlue,
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            margin: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text(
                              "Rs.${entry.value}",
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(font: font),
                            ),
                          );
                        }).toList(),
                      );
                    } else {
                      return pw.Container();
                    }
                  }).toList(),

                  // Total Paid (only if billingList has more than 1 reason)
                  if (billingList.length > 1 && (cancelRecord['total_paid'] ?? '').toString().isNotEmpty)
                    pw.Container(
                      width: double.infinity,
                      color: lightBlue,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Text(
                        "TOTAL AMOUNT PAID: Rs.${cancelRecord['total_paid']}",
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          font: fontBold,
                        ),
                      ),
                    ),

                  // Cancel charge
                  if ((cancelRecord['cancel_charge'] ?? '').toString().isNotEmpty)
                    pw.Container(
                      width: double.infinity,
                      color: lightBlue,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Text(
                        "Rs.${cancelRecord['cancel_charge']}",
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: font),
                      ),
                    ),

                  // Refund
                  if ((cancelRecord['refund'] ?? '').toString().isNotEmpty)
                    pw.Container(
                      width: double.infinity,
                      color: lightBlue,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Text(
                        "Rs.${cancelRecord['refund']}",
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fontBold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        //       _sectionHeader('BOOKING INFORMATION', darkBlue, fontBold),
    //   _infoTable([
    //     if ((updatedBooking['name'] ?? '').toString().isNotEmpty) ['NAME', updatedBooking['name']],
    //     if ((updatedBooking['phone'] ?? '').toString().isNotEmpty) ['PHONE', updatedBooking['phone']],
    //     if ((updatedBooking['address'] ?? '').toString().isNotEmpty) ['ADDRESS', updatedBooking['address']],
    //     if (updatedBooking['alternate_phone'] != null && (updatedBooking['alternate_phone'] as List).isNotEmpty)
    //       ['ALTERNATE PHONE', (updatedBooking['alternate_phone'] as List).join(', ')],
    //     if ((updatedBooking['email'] ?? '').toString().isNotEmpty) ['EMAIL', updatedBooking['email']],
    //     if ((updatedBooking['event_type'] ?? '').toString().isNotEmpty) ['EVENT', updatedBooking['event_type']],
    //     if ((updatedBooking['function_date'] ?? '').toString().isNotEmpty)
    //       ['FUNCTION DATE', DateFormat('dd-MM-yyyy').format(DateTime.parse(updatedBooking['function_date']).toLocal())],
    //     if ((updatedBooking['alloted_datetime_from'] ?? '').toString().isNotEmpty &&
    //         (updatedBooking['alloted_datetime_to'] ?? '').toString().isNotEmpty)
    //       [
    //         'ALLOTED TIME',
    //         DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(updatedBooking['alloted_datetime_from'])),
    //         DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(updatedBooking['alloted_datetime_to'])),
    //       ],
    //
    //     // if ((updatedBooking['alloted_datetime_from'] ?? '').toString().isNotEmpty &&
    //     //     (updatedBooking['alloted_datetime_to'] ?? '').toString().isNotEmpty)
    //     //   [
    //     //     'ALLOTED TIME',
    //     //     '${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(updatedBooking['alloted_datetime_from']))} to ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(updatedBooking['alloted_datetime_to']))}'
    //     //   ],
    //   ], lightBlue, font),
    //
    //       _sectionHeader('CANCELLATION INFORMATION', darkBlue, fontBold),
    //       _infoTable([
    //         if ((cancelRecord['reason'] ?? '').toString().isNotEmpty) ['REASON', cancelRecord['reason']],
    //         // if ((cancelRecord['cancel_charge'] ?? '').toString().isNotEmpty) ['CANCEL CHARGE', cancelRecord['cancel_charge'].toString()],
    //         // if ((cancelRecord['total_paid'] ?? '').toString().isNotEmpty) ['TOTAL PAID', cancelRecord['total_paid'].toString()],
    //         // if ((cancelRecord['refund'] ?? '').toString().isNotEmpty) ['REFUND', cancelRecord['refund'].toString()],
    //         ['CANCELLED ON', DateFormat('dd-MM-yyyy hh:mm a').format(
    //             cancelRecord['created_at'] != null ? DateTime.parse(cancelRecord['created_at']).toLocal() : DateTime.now())],
    //       ], lightBlue, font),
    //
    //
    //       _sectionHeader('PAYMENT INFORMATION', darkBlue, fontBold),
    // _infoTable([
    //   if ((updatedBooking['rent'] ?? '').toString().isNotEmpty) ['RENT', updatedBooking['rent'].toString()],
    //   if ((updatedBooking['advance'] ?? '').toString().isNotEmpty) ['ADVANCE/AMOUNT PAID', updatedBooking['advance'].toString()],
    //   // if ((updatedBooking['balance'] ?? '').toString().isNotEmpty) ['BALANCE', updatedBooking['balance'].toString()],
    // // if ((cancelRecord['reason'] ?? '').toString().isNotEmpty) ['REASON', cancelRecord['reason']],
    // if ((cancelRecord['cancel_charge'] ?? '').toString().isNotEmpty) ['CANCEL CHARGE', cancelRecord['cancel_charge'].toString()],
    // // if ((cancelRecord['total_paid'] ?? '').toString().isNotEmpty) ['TOTAL PAID', cancelRecord['total_paid'].toString()],
    // if ((cancelRecord['refund'] ?? '').toString().isNotEmpty) ['REFUND', cancelRecord['refund'].toString()],
    // // ['CANCELLED ON', DateFormat('dd-MM-yyyy hh:mm a').format(
    // // cancelRecord['created_at'] != null ? DateTime.parse(cancelRecord['created_at']).toLocal() : DateTime.now())],
    // ], lightBlue, font),


          pw.SizedBox(height: 30),
          pw.Center(
            child: pw.Text(
              "We confirm your booking cancellation.\nWe hope to serve you again in the future.",
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: darkBlue,
                font: fontBold,
              ),
            ),
          ),
          pw.SizedBox(height: 60),
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

  pw.Widget _sectionHeader(String title, PdfColor color, pw.Font font) {
    return pw.Container(
      width: double.infinity,
      color: color,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          font: font,
        ),
      ),
    );
  }

  pw.Widget _infoTable(List<List<String?>> data, PdfColor shade, pw.Font font) {
    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(100), // first column width
        1: const pw.FixedColumnWidth(300), // second column width (adjust as needed)
      },
      // defaultColumnWidth: const pw.FlexColumnWidth(),
      border: pw.TableBorder.all(color: PdfColors.white), // no visible border
      children: data.map((row) {

        if (row.length == 3) {
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
                padding: const pw.EdgeInsets.only(left: 20, top: 6, bottom: 6, right: 6), // <-- shift column 2
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
                padding: const pw.EdgeInsets.only(left: 20, top: 6, bottom: 6, right: 6), // <-- shift column 2
                child: pw.Container(
                  color: shade,
                  child: pw.Text(row[1] ?? "", style: pw.TextStyle(font: font)),
                ),
              ),
            ],
          );
        }
      }).toList(),
    );
  }

}
