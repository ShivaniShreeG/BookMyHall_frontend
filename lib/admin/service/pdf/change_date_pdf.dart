import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;


class ChangeDatePdfPage extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final Map<String, dynamic> hallDetails;
  final DateTime updatedFunctionDate;
  final DateTime updatedFrom;
  final DateTime updatedTo;
  final Color oliveGreen;
  final Color tan;
  final Color beigeBackground;

  const ChangeDatePdfPage({
    super.key,
    required this.bookingData,
    required this.hallDetails,
    required this.updatedFunctionDate,
    required this.updatedFrom,
    required this.updatedTo,
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
          "Change Date/Time PDF",
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
            return Center(
                child: Text("Error generating PDF: ${snapshot.error}"));
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
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 20),
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
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 20),
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
    final ttfBold = await rootBundle.load(
        "assets/fonts/NotoSansTamil-Bold.ttf");
    final font = pw.Font.ttf(ttf);
    final fontBold = pw.Font.ttf(ttfBold);
    debugPrint("Cancel Data: ${jsonEncode(updatedFunctionDate.toIso8601String())}");
    debugPrint("Billing Data: ${jsonEncode(updatedFrom.toIso8601String())}");
    debugPrint("Billing Data: ${jsonEncode(updatedTo.toIso8601String())}");

    // final updatedBooking = cancelData['updatedBooking'] ?? {};
    // final cancelRecord = cancelData['cancelRecord'] ?? {};

    final pdf = pw.Document();

    final darkBlue = PdfColor.fromInt(0xFF556B2F); // header & section titles
    final lightBlue = PdfColor.fromInt(0xFFF5F5DC); // table row background
    final mutedTanPdf = PdfColor.fromInt(0xFFD2B48C); // signature lines


    // Logo
    Uint8List? hallLogo;
    if (hallDetails['logo'] != null && hallDetails['logo'].isNotEmpty) {
      try {
        hallLogo = base64Decode(hallDetails['logo']);
      } catch (_) {}
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) =>
        [
          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (hallLogo != null) pw.Image(
                  pw.MemoryImage(hallLogo), width: 70, height: 70),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                        hallDetails['name']?.toString().toUpperCase() ??
                            'HALL NAME',
                        style: pw.TextStyle(
                            fontSize: 20,
                            color: darkBlue,
                            fontWeight: pw.FontWeight.bold,
                            font: fontBold
                        )
                    ),
                    if ((hallDetails['address'] ?? '')
                        .toString()
                        .isNotEmpty)
                      pw.Text(hallDetails['address'],
                          style: pw.TextStyle(font: font)),
                    if ((hallDetails['phone'] ?? '')
                        .toString()
                        .isNotEmpty)
                      pw.Text('Phone: ${hallDetails['phone']}',
                          style: pw.TextStyle(font: font)),
                    if ((hallDetails['email'] ?? '')
                        .toString()
                        .isNotEmpty)
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
                'Bill no: ${bookingData['hall_id'] ??
                    ''}${bookingData['booking_id'] ?? ''}',
                style: pw.TextStyle(font: fontBold, color: darkBlue),
              ),
              pw.Text('Generated: ${DateFormat('dd-MM-yyyy hh:mm a').format(
                  DateTime.now())}', style: pw.TextStyle(font: font)),
            ],
          ),
          pw.Divider(thickness: 1.2),
          pw.SizedBox(height: 10),
          // BOOKING INFORMATION
          _sectionHeader('BOOKING INFORMATION', darkBlue, fontBold),
          _infoTable([
            if ((bookingData['name'] ?? '')
                .toString()
                .isNotEmpty) ['NAME', bookingData['name']],
            if ((bookingData['phone'] ?? '')
                .toString()
                .isNotEmpty) ['PHONE', bookingData['phone']],
            if ((bookingData['email'] ?? '')
                .toString()
                .isNotEmpty)
              ["EMAIL", bookingData['email']],
            if ((bookingData['address'] ?? '')
                .toString()
                .isNotEmpty) ['ADDRESS', bookingData['address']],
            if (bookingData['alternate_phone'] != null &&
                (bookingData['alternate_phone'] as List).isNotEmpty)
              [
                "ALTERNATE PHONE",
                (bookingData['alternate_phone'] as List).join(", ")
              ],
            if ((bookingData['event_type'] ?? '')
                .toString()
                .isNotEmpty) ['EVENT', bookingData['event_type']],
            // if ((bookingData['function_date'] ?? '')
            //     .toString()
            //     .isNotEmpty)
            //   [
            //     'FUNCTION DATE',
            //     DateFormat('dd-MM-yyyy').format(
            //         DateTime.parse(bookingData['function_date']).toLocal())
            //   ],
            // if ((bookingData['alloted_datetime_from'] ?? '')
            //     .toString()
            //     .isNotEmpty &&
            //     (bookingData['alloted_datetime_to'] ?? '')
            //         .toString()
            //         .isNotEmpty)
            //   [
            //     'ALLOTED TIME',
            //     DateFormat('dd-MM-yyyy hh:mm a').format(
            //         DateTime
            //             .parse(bookingData['alloted_datetime_from'])
            //             .toLocal()),
            //     DateFormat('dd-MM-yyyy hh:mm a').format(
            //         DateTime
            //             .parse(bookingData['alloted_datetime_to'])
            //             .toLocal()),
            //   ],

          ], lightBlue, font),
          _sectionHeader('PREVIOUSLY SCHEDULED DATE & TIME', darkBlue, fontBold),
          _infoTable([
            if ((bookingData['function_date'] ?? '')
                .toString()
                .isNotEmpty)
              [
                'FUNCTION DATE',
                DateFormat('dd-MM-yyyy').format(
                    DateTime.parse(bookingData['function_date']))
              ],
            if ((bookingData['alloted_datetime_from'] ?? '')
                .toString()
                .isNotEmpty &&
                (bookingData['alloted_datetime_to'] ?? '')
                    .toString()
                    .isNotEmpty)
              [
                'ALLOTED TIME',
                DateFormat('dd-MM-yyyy hh:mm a').format(
                    DateTime
                        .parse(bookingData['alloted_datetime_from'])),
                DateFormat('dd-MM-yyyy hh:mm a').format(
                    DateTime
                        .parse(bookingData['alloted_datetime_to'])),
              ],
          ], lightBlue, font),
          pw.SizedBox(height: 10),
          _sectionHeader('NEWLY SCHEDULED DATE & TIME', darkBlue, fontBold),
          _infoTable(
            [
              // Function Date
              [
                'FUNCTION DATE',
                DateFormat('dd-MM-yyyy').format(updatedFunctionDate),
              ],
              // Alloted Time
              [
                'ALLOTED TIME',
                DateFormat('dd-MM-yyyy hh:mm a').format(updatedFrom),
                DateFormat('dd-MM-yyyy hh:mm a').format(updatedTo),
              ],
            ],
            lightBlue,
            font,
          ),

          pw.SizedBox(height: 30),
          pw.Center(
            child: pw.Text(
              "The booking has been successfully rescheduled.\n We look forward to your visit!",
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
                  pw.Text('Manager', style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, font: fontBold)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 120, height: 1, color: PdfColors.grey),
                  pw.Text('Booking Person', style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, font: fontBold)),
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
        0: const pw.FixedColumnWidth(100),
        // first column width
        1: const pw.FixedColumnWidth(300),
        // second column width (adjust as needed)
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
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, font: font)),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(
                    left: 20, top: 6, bottom: 6, right: 6),
                // <-- shift column 2
                child: pw.Row(
                  children: [
                    pw.Container(
                      color: shade,
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: pw.Text(row[1] ?? "", style: pw.TextStyle(
                          font: font)),
                    ),
                    pw.SizedBox(width: 4),
                    pw.Text("to", style: pw.TextStyle(font: font)),
                    pw.SizedBox(width: 4),
                    pw.Container(
                      color: shade,
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: pw.Text(row[2] ?? "", style: pw.TextStyle(
                          font: font)),
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
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, font: font)),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(
                    left: 20, top: 6, bottom: 6, right: 6),
                // <-- shift column 2
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

//               // Original Dates
//               pw.Text("ORIGINAL DATES",
//                   style: pw.TextStyle(
//                       fontWeight: pw.FontWeight.bold,
//                       color: PdfColor.fromInt(oliveGreen.value))),
//               pw.Divider(),
//               _infoRow("Function Date",
//                   DateFormat('dd-MM-yyyy').format(DateTime.parse(bookingData['function_date']))),
//               _infoRow("Alloted From",
//                   DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(bookingData['alloted_datetime_from']))),
//               _infoRow("Alloted To",
//                   DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(bookingData['alloted_datetime_to']))),
//               pw.SizedBox(height: 16),
//
//               // Updated Dates
//               pw.Text("UPDATED DATES",
//                   style: pw.TextStyle(
//                       fontWeight: pw.FontWeight.bold,
//                       color: PdfColor.fromInt(oliveGreen.value))),
//               pw.Divider(),
//               _infoRow("Function Date", DateFormat('dd-MM-yyyy').format(updatedFunctionDate)),
//               _infoRow("Alloted From", DateFormat('dd-MM-yyyy hh:mm a').format(updatedFrom)),
//               _infoRow("Alloted To", DateFormat('dd-MM-yyyy hh:mm a').format(updatedTo)),
//
//               pw.SizedBox(height: 16),
//               pw.Text("Thank you for using our service!",
//                   textAlign: pw.TextAlign.center,
//                   style: pw.TextStyle(color: PdfColor.fromInt(oliveGreen.value))),
//             ],
//           ),
//         );
//       },
//     ),
//   );
//
//   return pdf.save();
// }
//
// pw.Widget _infoRow(String label, String value) {
//   return pw.Container(
//     margin: const pw.EdgeInsets.symmetric(vertical: 4),
//     child: pw.Row(
//       children: [
//         pw.Expanded(
//           flex: 3,
//           child: pw.Text("$label:",
//               style: pw.TextStyle(
//                   fontWeight: pw.FontWeight.bold,
//                   color: PdfColor.fromInt(oliveGreen.value))),
//         ),
//         pw.Expanded(
//           flex: 5,
//           child: pw.Text(value, style: pw.TextStyle(color: PdfColor.fromInt(oliveGreen.value))),
//         ),
//       ],
//     ),
//   );
// }
}