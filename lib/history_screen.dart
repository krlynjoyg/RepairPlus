import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:repair_plus_one/profile_screen.dart';
import 'tutorial_screen.dart';
import 'repair_shops_screen.dart';
import 'home_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedIndex = 3;
  String _searchQuery = "";
  bool _showStarredOnly = false;
  final _auth = FirebaseAuth.instance;

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    Widget nextScreen;
    if (index == 0) {
      nextScreen = const HomeScreen();
    } else if (index == 1) {
      nextScreen = const TutorialScreen();
    } else if (index == 2) {
      nextScreen = const RepairShopsScreen();
    } else if (index == 4) {
      nextScreen = const ProfileScreen();
    } else {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
    setState(() {
      _selectedIndex = index;
    });
  }


  Stream<QuerySnapshot> _getHistoryStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    Query query = FirebaseFirestore.instance
        .collection('history')
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'tutorial')
        .orderBy('timestamp', descending: true);


    if (_showStarredOnly) {
      query = query.where('isStarred', isEqualTo: true);
    }

    return query.snapshots();
  }


  Future<void> _toggleStar(String docId, bool isStarred) async {
    final newStatus = !isStarred ? 'Saved' : 'Viewed';
    await FirebaseFirestore.instance.collection('history').doc(docId).set({
      'isStarred': !isStarred,
      'status': newStatus,
    }, SetOptions(merge: true));
    setState(() {});
  }


  Future<void> _deleteHistoryItem(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('history').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tutorial deleted from history')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete tutorial: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _showStarredOnly ? "Saved Tutorials" : "History",
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [

          IconButton(
            icon: Icon(
              _showStarredOnly ? Icons.star : Icons.star_border,
              color: _showStarredOnly ? Colors.amber : Colors.grey,
            ),
            tooltip: _showStarredOnly
                ? "Show all tutorials"
                : "Show only saved tutorials",
            onPressed: () {
              setState(() {
                _showStarredOnly = !_showStarredOnly;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: _showStarredOnly
                    ? "Search saved tutorials..."
                    : "Search tutorial history...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),


          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getHistoryStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      _showStarredOnly
                          ? "No saved tutorials found"
                          : "No tutorial history found",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }


                final docs = snapshot.data!.docs.where((doc) {
                  final data =
                  doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '')
                      .toString()
                      .toLowerCase();
                  return title
                      .contains(_searchQuery.toLowerCase());
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      _showStarredOnly
                          ? "No matching saved tutorials"
                          : "No matching tutorials found",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }


                return ListView.builder(
                  padding: const EdgeInsets.only(top: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data =
                    doc.data() as Map<String, dynamic>;

                    final title =
                        data['title'] ?? 'Untitled Tutorial';
                    final date = data['date'] ?? '';
                    final time = data['time'] ?? '';
                    final status =
                        data['status'] ?? 'Viewed';
                    final image =
                        data['image'] ?? 'images/history/h1.png';
                    final source = data['source'] ?? '';
                    final url = data['url'];
                    final isStarred =
                        data['isStarred'] ?? false;

                    return _buildTutorialCard(
                      doc.id,
                      title,
                      "$date • $time",
                      status,
                      image,
                      url,
                      source,
                      isStarred,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),


      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book), label: "Tutorials"),
          BottomNavigationBarItem(
              icon: Icon(Icons.store), label: "Shops"),
          BottomNavigationBarItem(
              icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }


  Widget _buildTutorialCard(
      String docId,
      String title,
      String time,
      String status,
      String imageUrl,
      String? url,
      String source,
      bool isStarred,
      ) {
    final statusColor =
    status == 'Saved' ? Colors.amber : Colors.green;

    return Container(
      margin:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Image.asset(
                    "images/history/h1.png",
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
            ),
          ),
          const SizedBox(width: 12),


          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text(time,
                    style: TextStyle(color: Colors.grey[600])),
                if (source.isNotEmpty)
                  Text(source,
                      style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        if (url != null && url.isNotEmpty) {
                          final Uri uri = Uri.parse(url);
                          await launchUrl(uri,
                              mode: LaunchMode
                                  .externalApplication);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(20)),
                      ),
                      child: Text(status == 'Saved'
                          ? "Open"
                          : "Rewatch"),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius:
                        BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),


          Column(
            children: [
              IconButton(
                icon: Icon(
                  isStarred
                      ? Icons.star
                      : Icons.star_border,
                  color: isStarred
                      ? Colors.amber
                      : Colors.grey,
                ),
                onPressed: () =>
                    _toggleStar(docId, isStarred),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                onPressed: () async {
                  final confirm =
                  await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title:
                      const Text("Delete Tutorial"),
                      content: const Text(
                          "Are you sure you want to remove this tutorial from your history?"),
                      actions: [
                        TextButton(
                          child:
                          const Text("Cancel"),
                          onPressed: () =>
                              Navigator.pop(
                                  context, false),
                        ),
                        TextButton(
                          child: const Text("Delete",
                              style: TextStyle(
                                  color:
                                  Colors.red)),
                          onPressed: () =>
                              Navigator.pop(
                                  context, true),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _deleteHistoryItem(docId);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
