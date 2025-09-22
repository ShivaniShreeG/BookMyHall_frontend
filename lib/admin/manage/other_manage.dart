import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart'; // where baseUrl is defined

class OtherManagePage extends StatefulWidget {
  const OtherManagePage({super.key});

  @override
  State<OtherManagePage> createState() => _OtherManagePageState();
}

class _OtherManagePageState extends State<OtherManagePage> {
  String? hallName;
  String? hallAddress;
  String? hallLogo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHallData();
  }

  Future<void> _fetchHallData() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");

    if (hallId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final url = Uri.parse("$baseUrl/halls/$hallId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          hallName = data["name"];
          hallAddress = data["address"];
          hallLogo = data["logo"];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        debugPrint("❌ Failed to fetch hall: ${response.body}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("❌ Error fetching hall: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Card with logo, name, address
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: (hallLogo != null && hallLogo!.isNotEmpty)
                          ? MemoryImage(base64Decode(hallLogo!))
                          : null,
                      child: hallLogo == null || hallLogo!.isEmpty
                          ? const Icon(Icons.store, size: 40)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hallName ?? "Unknown Hall",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hallAddress ?? "No address available",
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Other Manage Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Manage here",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 3,
                      ),
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to Reports
                          },
                          icon: const Icon(Icons.access_time),
                          label: const Text("Peak Hours"),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to Feedback
                          },
                          icon: const Icon(Icons.attach_money),
                          label: const Text("Estimation/Amount"),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to Inventory
                          },
                          icon: const Icon(Icons.book_online),
                          label: const Text("Bookings"),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
