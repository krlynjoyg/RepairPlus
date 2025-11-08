import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:repair_plus_one/profile_screen.dart';
import 'package:repair_plus_one/tutorial_screen.dart';
import 'package:repair_plus_one/repair_shops_screen.dart';
import 'package:repair_plus_one/history_screen.dart';
import 'package:repair_plus_one/models/tutorial_model.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:repair_plus_one/services/repair_shop_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:repair_plus_one/find_guide_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _selectedIndex = 0;
  Future<List<DocumentSnapshot>>? _ecoTipsFuture;
  Future<List<Tutorial>>? _featuredTutorialsFuture;
  List<Map<String, dynamic>> _nearbyShops = [];
  User? _currentUser;
  bool _isFetchingShops = false;

  @override
  void initState() {
    super.initState();
    _ecoTipsFuture = loadEcoTips();
    _featuredTutorialsFuture = _fetchFeaturedTutorials();
    _loadUserData();
    _fetchNearbyRepairShops();
  }

  // ---------------- USER DATA ----------------
  void _loadUserData() {
    _currentUser = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) setState(() => _currentUser = user);
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  // ---------------- FETCH DATA ----------------
  Future<List<DocumentSnapshot>> loadEcoTips() async {
    final snapshot =
    await FirebaseFirestore.instance.collection('eco_tips').get();
    if (snapshot.docs.isEmpty) return [];
    final docs = snapshot.docs..shuffle();
    return docs.take(2).toList();
  }

  Future<List<Tutorial>> _fetchFeaturedTutorials() async {
    try {
      final res =
      await http.get(Uri.parse('https://www.ifixit.com/api/2.0/guides?limit=10'));
      if (res.statusCode == 200) {
        List data = json.decode(res.body);
        return data.map((e) => Tutorial.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Tutorial load error: $e');
    }
    return [];
  }

  Future<void> _fetchNearbyRepairShops() async {
    setState(() => _isFetchingShops = true);
    try {
      final shops = await fetchNearbyRepairShops();
      if (mounted) setState(() => _nearbyShops = shops.take(3).toList());
    } catch (e) {
      debugPrint("Error fetching nearby shops: $e");
    }
    setState(() => _isFetchingShops = false);
  }

  // ---------------- NAVIGATION ----------------
  void _onItemTapped(int index) {
    final pages = [
      null,
      const TutorialScreen(),
      const RepairShopsScreen(),
      const HistoryScreen(),
      const ProfileScreen(),
    ];
    if (index != 0 && pages[index] != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => pages[index]!));
    }
  }

  // ---------------- BUILD UI ----------------
  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();
    final userName = _currentUser?.displayName?.split(' ').first ?? 'User';
    final avatarImage = (_currentUser?.photoURL?.isNotEmpty ?? false)
        ? NetworkImage(_currentUser!.photoURL!)
        : const AssetImage("images/dash/dash2.png") as ImageProvider;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(greeting, userName, avatarImage),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  PreferredSizeWidget _buildAppBar(
      String greeting, String userName, ImageProvider avatarImage) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(160),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "RePair+",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.search,
                              color: Colors.white, size: 26),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FindGuideScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            backgroundImage: avatarImage,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "$greeting, $userName 👋",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Let’s get something fixed today!",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _sectionHeader(
            "Featured Tutorials",
            viewAllText: "View All",
            onViewAll: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TutorialScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _buildFeaturedTutorials(),
          const SizedBox(height: 24),
          _sectionHeader(
            "Nearby Repair Shops",
            viewAllText: "View on Map",
            onViewAll: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RepairShopsScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _buildNearbyShops(),
          const SizedBox(height: 24),
          _sectionHeader("Eco-Friendly Tips"),
          const SizedBox(height: 16),
          _buildEcoTipsSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  BottomNavigationBar _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF10B981),
      unselectedItemColor: Colors.grey,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.build), label: "Tutorials"),
        BottomNavigationBarItem(icon: Icon(Icons.store), label: "Shops"),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }

  // ---------------- HELPERS ----------------
  Widget _sectionHeader(String title,
      {String? viewAllText, VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: Text(viewAllText ?? '',
                  style:
                  const TextStyle(color: Color(0xFF10B981), fontSize: 14)),
            )
        ],
      ),
    );
  }

  Widget _buildFeaturedTutorials() {
    return SizedBox(
      height: 200,
      child: FutureBuilder<List<Tutorial>>(
        future: _featuredTutorialsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No tutorials available."));
          }
          final tutorials = snapshot.data!;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tutorials.length,
            itemBuilder: (context, index) {
              final t = tutorials[index];
              return GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(t.url);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Container(
                  width: 180,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(10)),
                        child: Image.network(
                          t.imageUrl,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          t.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNearbyShops() {
    if (_isFetchingShops) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_nearbyShops.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text("No repair shops found nearby."),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _nearbyShops.map((s) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.store, color: Color(0xFF10B981)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text("${s['category']} • ${s['distance']} km away"),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: Colors.orange, size: 16),
                          Text(" ${s['rating']}"),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEcoTipsSection() {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: _ecoTipsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text("No eco-tips available."),
          );
        }

        final tips = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: tips.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['title'] ?? 'Tip',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Text(data['description'] ?? '',
                          style: const TextStyle(fontSize: 13)),
                    ]),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
