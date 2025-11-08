import 'package:flutter/material.dart';
import 'package:repair_plus_one/profile_screen.dart';
import 'find_guide_screen.dart';
import 'repair_shops_screen.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'services/video_tutorial_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'phone_repair_screen.dart';
import 'pc_laptop_repair_screen.dart';
import 'mac_imac_repair_screen.dart';
import 'tablets_ipads_screen.dart';
import 'computer_hardware_repair_screen.dart';
import 'electronic_repair_screen.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _selectedIndex = 1;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    _currentUser = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    Widget page;
    switch (index) {
      case 0:
        page = const HomeScreen();
        break;
      case 2:
        page = const RepairShopsScreen();
        break;
      case 3:
        page = const HistoryScreen();
        break;
      case 4:
        page = const ProfileScreen();
        break;
      case 1:
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String greeting = _getGreeting();
    final String userName = _currentUser?.displayName?.split(' ').first ?? 'User';
    ImageProvider<Object> avatarImage;
    if (_currentUser?.photoURL != null && _currentUser!.photoURL!.isNotEmpty) {
      avatarImage = NetworkImage(_currentUser!.photoURL!);
    } else {
      avatarImage = const AssetImage("images/dash/dash2.png");
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(color: Color(0xFF10B981)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: const [
                          Icon(Icons.build_outlined, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            "RePair+",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        ]),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                      const FindGuideScreen()),
                                );
                              },
                              child:
                              const Icon(Icons.search, color: Colors.white),
                            ),
                            const SizedBox(width: 16),

                            CircleAvatar(
                              radius: 16,
                              backgroundImage: avatarImage,
                              backgroundColor: Colors.grey.shade300,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "$greeting, $userName! Ready to repair today?",
                      style: const TextStyle(color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Text(
                      "What do you need to fix?",
                      textAlign: TextAlign.center,
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Choose a category to get started",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double aspectRatio =
                    constraints.maxWidth < 400 ? 0.80 : 0.90;

                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: aspectRatio,
                      children: [
                        _buildCategory(
                          context,
                          "images/tutorial/tutorial1.png",
                          "Phones",
                          "Screen, battery, charging port, etc.",
                          const PhoneRepairScreen(),
                        ),
                        _buildCategory(
                          context,
                          "images/tutorial/tutorial2.png",
                          "PC & Laptops",
                          "Keyboard, fan cleaning, thermal paste",
                          const PcLaptopRepairScreen(),
                        ),
                        _buildCategory(
                          context,
                          "images/tutorial/tutorial3.png",
                          "Mac & iMac",
                          "Specialized Apple guides",
                          const MacImacRepairScreen(),
                        ),
                        _buildCategory(
                          context,
                          "images/tutorial/tutorial4.png",
                          "Tablets & iPads",
                          "Screen, battery, speakers",
                          const TabletsIpadsRepairScreen(),
                        ),
                        _buildCategory(
                          context,
                          "images/tutorial/tutorial5.png",
                          "Computer Hardwares",
                          "Chargers, headphones, smartwatches",
                          const ComputerHardwareRepairScreen(),
                        ),
                        _buildCategory(
                          context,
                          "images/tutorial/tutorial6.png",
                          "Electronic Repair",
                          "Miscellaneous gadgets",
                          const ElectronicRepairScreen(),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF10B981),
        unselectedItemColor: Colors.grey.shade600,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.build_outlined), label: "Tutorials"),
          BottomNavigationBarItem(
              icon: Icon(Icons.store_mall_directory_outlined), label: "Shops"),
          BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined), label: "History"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }

  Widget _buildCategory(BuildContext context, String img, String title,
      String subtitle, Widget destinationScreen) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => destinationScreen),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              img,
              height: 65,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
