import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';// where baseUrl is defined
import 'create_admin.dart';
class OwnerPage extends StatefulWidget {
  const OwnerPage({super.key});

  @override
  State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {
  String? hallName;
  String? hallAddress;
  String? hallLogo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHallData();
  }

  // ✅ Fetch hall details from API instead of SharedPreferences
  Future<void> _fetchHallData() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId"); // saved at login/session

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
          hallLogo = data["logo"]; // base64 string
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
            // 🔹 Top Card with logo, name, address
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
                    // Logo (base64 -> MemoryImage)
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

                    // Name & Address (prevent overflow)
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

            // 🔹 Manage Here Card
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
                      "Manage Here",
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
                        childAspectRatio: 3, // wide buttons
                      ),
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreateAdminPage()),
                            );
                          },
                          icon: const Icon(Icons.admin_panel_settings),
                          label: const Text("Admin"),
                        ),

                        ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to Peak Hours
                          },
                          icon: const Icon(Icons.access_time),
                          label: const Text("Peak Hours"),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to Estimation/Amount
                          },
                          icon: const Icon(Icons.attach_money),
                          label: const Text("Estimation/Amount"),
                        ),

                        ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to Bookings
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
