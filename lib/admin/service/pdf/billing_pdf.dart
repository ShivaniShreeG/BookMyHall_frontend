import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


class UpdateBookingPdfPage extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final Map<String, dynamic> hallDetails;
  final List<Map<String, dynamic>> existingCharges;
  final List<Map<String, dynamic>> newCharges;

  // 👇 Add these 3
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;

  const UpdateBookingPdfPage({
    super.key,
    required this.bookingData,
    required this.hallDetails,
    required this.existingCharges,
    required this.newCharges,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
  });


  @override
  Widget build(BuildContext context) {
    final pdfFuture = _generatePdf();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Billing PDF",
          style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: secondaryColor),
      ),
      backgroundColor: backgroundColor,
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
          color: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondaryColor,
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
                  backgroundColor: secondaryColor,
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
    // 1️⃣ Get advance
    final advance = double.tryParse(bookingData['advance']?.toString() ?? "0") ?? 0.0;

// 2️⃣ Sum existing charges
    final existingChargesTotal = existingCharges.fold<double>(0.0, (sum, c) {
      final amt = double.tryParse(c['amount']?.toString() ?? "0") ?? 0.0;
      return sum + amt;
    });

// 3️⃣ Sum new charges
    final newChargesTotal = newCharges.fold<double>(0.0, (sum, c) {
      final amt = double.tryParse(c['amount']?.toString() ?? "0") ?? 0.0;
      return sum + amt;
    });

// 4️⃣ Total paid
    final totalPaid = advance + existingChargesTotal + newChargesTotal;

    print("=== Existing Charges ===");
    print(existingCharges);

    print("=== New Charges ===");
    print(newCharges);
    final ttf = await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf");
    final ttfBold = await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf");
    final font = pw.Font.ttf(ttf);
    final fontBold = pw.Font.ttf(ttfBold);

    // final updatedBooking = cancelData['updatedBooking'] ?? {};
    // final cancelRecord = cancelData['cancelRecord'] ?? {};

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
            if ((bookingData['name'] ?? '').toString().isNotEmpty) ['NAME', bookingData['name']],
            if ((bookingData['phone'] ?? '').toString().isNotEmpty) ['PHONE', bookingData['phone']],
            if ((bookingData['email'] ?? '').toString().isNotEmpty)
              ["EMAIL", bookingData['email']],
            if ((bookingData['address'] ?? '').toString().isNotEmpty) ['ADDRESS', bookingData['address']],
            if (bookingData['alternate_phone'] != null &&
                (bookingData['alternate_phone'] as List).isNotEmpty)
              [
                "ALTERNATE PHONE",
                (bookingData['alternate_phone'] as List).join(", ")
              ],
            if ((bookingData['event_type'] ?? '').toString().isNotEmpty) ['EVENT', bookingData['event_type']],
            if ((bookingData['function_date'] ?? '').toString().isNotEmpty)
              ['FUNCTION DATE', DateFormat('dd-MM-yyyy').format(DateTime.parse(bookingData['function_date']).toLocal())],
            if ((bookingData['alloted_datetime_from'] ?? '').toString().isNotEmpty &&
                (bookingData['alloted_datetime_to'] ?? '').toString().isNotEmpty)
              [
                'ALLOTED TIME',
                DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(bookingData['alloted_datetime_from']).toLocal()),
                DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(bookingData['alloted_datetime_to']).toLocal()),
              ],
          ], lightBlue, font),
          pw.SizedBox(height: 10),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left Column - Payment Information
              pw.Container(
                width: PdfPageFormat.a4.availableWidth * 0.80, // ~74% width
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
                          font: font,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),

                    // Labels as Containers
                    if ((bookingData['rent'] ?? '').toString().isNotEmpty)
                      pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        margin: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text("RENT", style: pw.TextStyle(font: font)),
                      ),

                    if ((bookingData['advance'] ?? '').toString().isNotEmpty)
                      pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        margin: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text("ADVANCE", style: pw.TextStyle(font: font)),
                      ),

                    ...existingCharges.map((c) {
                      final reason = c['reason']?.toString() ?? 'N/A';
                      return pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        margin: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text(reason.toUpperCase(), style: pw.TextStyle(font: font)),
                      );
                    }).toList(),

                    ...newCharges.map((c) {
                      final reason = c['reason']?.toString() ?? 'N/A';
                      return pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        margin: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text(reason.toUpperCase(), style: pw.TextStyle(font: font)),
                      );
                    }).toList(),
                    // Total Paid
                    pw.Container(
                      width: double.infinity,
                      color: lightBlue,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Text(
                        "TOTAL AMOUNT PAID",
                        style: pw.TextStyle(
                          font: fontBold,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),



                    if ((bookingData['balance'] ?? '').toString().isNotEmpty)
                      pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        margin: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text("BALANCE", style: pw.TextStyle(font: font)),
                      ),
                  ],
                ),
              ),

              pw.SizedBox(width: PdfPageFormat.a4.availableWidth * 0.04), // 4% gap

              // Right Column - Amounts
              pw.Container(
                width: PdfPageFormat.a4.availableWidth * 0.30, // ~22% width
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
                          font: fontBold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),

                    // Values
                    if ((bookingData['rent'] ?? '').toString().isNotEmpty)
                      pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        margin: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text("Rs.${bookingData['rent']}", textAlign: pw.TextAlign.right),
                      ),

                    if ((bookingData['advance'] ?? '').toString().isNotEmpty)
                      pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        margin: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text("Rs.${bookingData['advance']}", textAlign: pw.TextAlign.right),
                      ),

                    ...existingCharges.map((c) {
                      final amount = c['amount'] != null
                          ? double.tryParse(c['amount'].toString())?.toStringAsFixed(2) ?? "0.00"
                          : "0.00";
                      return pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        margin: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text("Rs.$amount", textAlign: pw.TextAlign.right),
                      );
                    }).toList(),

                    ...newCharges.map((c) {
                      final amount = c['amount'] != null
                          ? double.tryParse(c['amount'].toString())?.toStringAsFixed(2) ?? "0.00"
                          : "0.00";
                      return pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        margin: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text("Rs.$amount", textAlign: pw.TextAlign.right),
                      );
                    }).toList(),
                    // Display the heading for "Total Amount Paid" in the left column of the PDF.
// The actual total amount will be shown in the corresponding right column for alignment.
                    pw.Container(
                      width: double.infinity,
                      color: lightBlue,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Text(
                        "Rs.${totalPaid.toStringAsFixed(2)}", // display the calculated total amount
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),

                    if ((bookingData['balance'] ?? '').toString().isNotEmpty)
                      pw.Container(
                        width: double.infinity,
                        color: lightBlue,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        margin: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text("Rs.${bookingData['balance']}", textAlign: pw.TextAlign.right),
                      ),
                  ],
                ),
              ),
            ],
          ),


          pw.SizedBox(height: 30),
          pw.Center(
            child: pw.Text(
              "Billing completed successfully.\n Kindly verify the details and retain this receipt for reference.",
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


  //           if (newCharges.isNotEmpty) _chargesSection("NEW CHARGES", newCharges, olive, tan),
  //           pw.SizedBox(height: 16),
  //           if (existingCharges.isNotEmpty) _chargesSection("EXISTING CHARGES", existingCharges, olive, tan),
  //           pw.SizedBox(height: 16),
  //           _bookingDetailsSection(olive, tan),
  //         ];
  //       },
  //     ),
  //   );
  //
  //   await Printing.layoutPdf(
  //     onLayout: (PdfPageFormat format) async => pdf.save(),
  //   );
  // }
  //
  // pw.Widget _chargesSection(String title, List<Map<String, dynamic>> charges, PdfColor olive, PdfColor tan) {
  //   return pw.Container(
  //     padding: const pw.EdgeInsets.all(12),
  //     decoration: pw.BoxDecoration(
  //       color: tan,
  //       border: pw.Border.all(color: olive, width: 1.5),
  //       borderRadius: pw.BorderRadius.circular(8),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: olive)),
  //         pw.SizedBox(height: 8),
  //         ...charges.map((c) {
  //           final reason = c['reason'] ?? "N/A";
  //           final amount = c['amount'] != null
  //               ? double.tryParse(c['amount'].toString())?.toStringAsFixed(2) ?? "0.00"
  //               : "0.00";
  //           return pw.Row(
  //             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //             children: [
  //               pw.Text(reason.toUpperCase(), style: pw.TextStyle(color: olive)),
  //               pw.Text("₹$amount", style: pw.TextStyle(color: olive)),
  //             ],
  //           );
  //         }).toList(),
  //       ],
  //     ),
  //   );
  // }
  //         _row("Balance", bookingData['balance'].toString(), olive),
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
