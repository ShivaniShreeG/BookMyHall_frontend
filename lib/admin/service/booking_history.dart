import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import 'Booking_details_page.dart';
// import 'package:month_year_picker/month_year_picker.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({super.key});

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  bool _loading = true;
  int? _hallId;
  List<dynamic> _bookings = [];
  List<dynamic> _filteredBookings = [];
  Map<String, dynamic>? hallDetails;

  final Color primaryColor = const Color(0xFF5B6547);
  final Color scaffoldBackground = const Color(0xFFECE5D8);
  final Color cardColor = const Color(0xFFD8C9A9);

  DateTime _selectedMonth = DateTime.now();
  // final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHallIdAndData();
    // _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    // _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHallIdAndData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt('hallId');

    if (hallId != null) {
      setState(() => _hallId = hallId);
      await Future.wait([
        _fetchHallDetails(hallId),
        _fetchAllBookings(), // 👈 fetch all bookings for history
      ]);
      _filterBookingsByMonth();
    } else {
      setState(() => _loading = false);
      print("No hallId found in SharedPreferences");
    }
  }

  Future<void> _fetchHallDetails(int hallId) async {
    try {
      final url = Uri.parse('$baseUrl/halls/$hallId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        hallDetails = jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching hall details: $e");
    } finally {
      setState(() {});
    }
  }

  Future<void> _fetchAllBookings() async {
    if (_hallId == null) return;

    try {
      final res = await http.get(Uri.parse('$baseUrl/history/$_hallId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;

        _bookings = data; // 👈 all bookings, not just future

        setState(() => _filteredBookings = _bookings);
      }
    } catch (e) {
      print("Error fetching bookings: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _filterBookingsByMonth() {
    setState(() {
      _filteredBookings = _bookings.where((b) {
        if (b['function_date'] == null) return false;
        final functionDate = DateTime.parse(b['function_date']);
        return functionDate.year == _selectedMonth.year &&
            functionDate.month == _selectedMonth.month;
      }).toList();
    });
  }

  Future<void> _pickMonthYear() async {
    int selectedYear = _selectedMonth.year;
    int selectedMonth = _selectedMonth.month;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Color(0xFFECE5D8).withOpacity(0.95),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Select Month and Year',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 20),

                // ✅ LayoutBuilder INSIDE the dialog now
                LayoutBuilder(
                  builder: (context, constraints) {
                    bool isNarrow = constraints.maxWidth < 360; // auto switch

                    // COLUMN for small widths, ROW for larger
                    return isNarrow
                        ? Column(
                      children: [
                        DropdownButtonFormField<int>(
                          value: selectedMonth,
                          decoration: InputDecoration(
                            labelText: "Month",
                            labelStyle: TextStyle(color: primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                          ),
                          dropdownColor: scaffoldBackground,
                          items: List.generate(12, (index) {
                            final month = index + 1;
                            final monthName = DateFormat.MMMM()
                                .format(DateTime(0, month));
                            return DropdownMenuItem(
                              value: month,
                              child: Text(
                                monthName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) selectedMonth = val;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: selectedYear,
                          decoration: InputDecoration(
                            labelText: "Year",
                            labelStyle: TextStyle(color: primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                          ),
                          dropdownColor: scaffoldBackground,
                          items: List.generate(30, (index) {
                            final year =
                                DateTime.now().year - 10 + index;
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) selectedYear = val;
                          },
                        ),
                      ],
                    )
                        : Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedMonth,
                            decoration: InputDecoration(
                              labelText: "Month",
                              labelStyle: TextStyle(color: primaryColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                            ),
                            dropdownColor: scaffoldBackground,
                            items: List.generate(12, (index) {
                              final month = index + 1;
                              final monthName = DateFormat.MMMM()
                                  .format(DateTime(0, month));
                              return DropdownMenuItem(
                                value: month,
                                child: Text(
                                  monthName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) selectedMonth = val;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedYear,
                            decoration: InputDecoration(
                              labelText: "Year",
                              labelStyle: TextStyle(color: primaryColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                            ),
                            dropdownColor: scaffoldBackground,
                            items: List.generate(30, (index) {
                              final year =
                                  DateTime.now().year - 10 + index;
                              return DropdownMenuItem(
                                value: year,
                                child: Text(year.toString()),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) selectedYear = val;
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 25),

                // Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: primaryColor, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: cardColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(selectedYear, selectedMonth);
                          _filterBookingsByMonth();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // void _onSearchChanged() {
  //   final query = _searchController.text.toLowerCase();
  //
  //   setState(() {
  //     if (query.isEmpty) {
  //       _filteredBookings = _bookings; // show all by default
  //     } else {
  //       _filteredBookings = _bookings.where((b) {
  //         final name = (b['customer_name'] ?? '').toString().toLowerCase();
  //         final id = (b['booking_id'] ?? '').toString();
  //         final event = (b['event_type'] ?? '').toString().toLowerCase();
  //         final date = b['function_date'] != null
  //             ? DateFormat('dd-MM-yyyy').format(DateTime.parse(b['function_date']).toLocal())
  //             : '';
  //
  //         return name.contains(query) ||
  //             id.contains(query) ||
  //             event.contains(query) ||
  //             date.contains(query);
  //       }).toList();
  //     }
  //   });
  // }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      padding: const EdgeInsets.all(16),
      height: 95,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hall['name'] != null) ...[
                  Text(
                    hall['name'].toString().toUpperCase(),
                    style: TextStyle(
                      color: cardColor.withOpacity(0.9),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ] else
                  const Text(
                    "HALL NAME",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor.withOpacity(0.6), width: 1),
            ),
            child: ClipOval(
              child: hall['logo'] != null
                  ? Image.memory(
                base64Decode(hall['logo']),
                fit: BoxFit.cover,
              )
                  : const Icon(Icons.home_work, color: Colors.white, size: 35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: cardColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _sectionContainer(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scaffoldBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(title),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _plainRowWithTanValue(String label, {String? value}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: screenWidth * 0.35,
            alignment: Alignment.centerLeft,
            child: Text(label,
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Container(
            width: screenWidth * 0.38,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              value ?? "—",
              style: TextStyle(color: primaryColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final DateTime? allotedFrom = booking['alloted_from'] != null
        ? DateTime.parse(booking['alloted_from'])
        : null;
    final DateTime? allotedTo = booking['alloted_to'] != null
        ? DateTime.parse(booking['alloted_to'])
        : null;

    final functionDate = booking['function_date'] != null
        ? DateFormat('dd-MM-yyyy').format(DateTime.parse(booking['function_date']))
        : "N/A";

    return _sectionContainer(
      "Booking ID: ${booking['booking_id'] ?? "N/A"} | Date: $functionDate",
      [
        _plainRowWithTanValue("NAME", value: booking['customer_name'] ?? "N/A"),
        _plainRowWithTanValue("EVENT", value: booking['event_type'] ?? "N/A"),
        _plainRowWithTanValue(
            "ALLOTED FROM",
            value: allotedFrom != null
                ? "${DateFormat('dd-MM-yyyy').format(allotedFrom)}\n${DateFormat('hh:mm a').format(allotedFrom)}"
                : "N/A"),
        _plainRowWithTanValue(
            "ALLOTED TO",
            value: allotedTo != null
                ? "${DateFormat('dd-MM-yyyy').format(allotedTo)}\n${DateFormat('hh:mm a').format(allotedTo)}"
                : "N/A"),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingDetailsPage(booking: booking,hallDetails: hallDetails),
                  ),
                );
              },
              child: const Text("View"),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: const Text("Booking History",
            style: TextStyle(color: Color(0xFFD8C7A5))),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: cardColor),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
        onRefresh: _fetchAllBookings,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          children: [
            const SizedBox(height: 16),
            if (hallDetails != null) _buildHallCard(hallDetails!),
            const SizedBox(height: 16),
            // _sectionHeader("Booking History Details"),
            // const SizedBox(height: 12),
            // TextField(
            //   controller: _searchController,
            //   decoration: InputDecoration(
            //     hintText: "Search by Name, Booking ID, Event, Date",
            //     prefixIcon: const Icon(Icons.search),
            //     filled: true,
            //     fillColor: cardColor,
            //     border: OutlineInputBorder(
            //       borderRadius: BorderRadius.circular(8),
            //       borderSide: BorderSide.none,
            //     ),
            //   ),
            // ),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: cardColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // minimal padding
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  minimumSize: Size.zero, // remove default minimum size
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap, // shrink touch area
                ),
                onPressed: _pickMonthYear,
                child: Text(
                  "${DateFormat('MMMM yyyy').format(_selectedMonth)}",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_filteredBookings.isEmpty)
              const Center(child: Text("No bookings found"))
            else
              ..._filteredBookings.map((b) => _bookingCard(b)).toList(),
            const SizedBox(height: 45),
          ],
        ),
      ),
    );
  }
}
