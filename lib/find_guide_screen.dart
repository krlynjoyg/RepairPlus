import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services/video_tutorial_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FindGuideScreen extends StatefulWidget {
  const FindGuideScreen({super.key});

  @override
  State<FindGuideScreen> createState() => _FindGuideScreenState();
}

class _FindGuideScreenState extends State<FindGuideScreen> {
  String searchQuery = "";
  String selectedFilter = "All";

  bool isLoading = false;
  bool isLoadingMore = false;
  int currentOffset = 0;
  final int limit = 20;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> savedIds = [];

  List<Map<String, dynamic>> externalResults = [];

  final String youtubeApiKey = "AIzaSyDHPDJWZqdS8px7AWGW7avsSZU4mHRtz_k";

  StreamSubscription<DocumentSnapshot>? _savedListener;

  @override
  void initState() {
    super.initState();
    _listenToSavedTutorials();
  }

  @override
  void dispose() {
    _savedListener?.cancel();
    super.dispose();
  }


  void _listenToSavedTutorials() {
    final user = _auth.currentUser;
    if (user == null) return;

    _savedListener =
        _firestore.collection('users').doc(user.uid).snapshots().listen((snapshot) {
          final data = snapshot.data();
          if (data != null && data['savedTutorials'] != null) {
            setState(() {
              savedIds = List<String>.from(data['savedTutorials']);
            });
          } else {
            setState(() {
              savedIds = [];
            });
          }
        });
  }


  String _generateSafeId(String rawId) {
    return rawId.replaceAll(RegExp(r'[^\w]+'), '_');
  }


  Future<void> _addToHistory(Map<String, dynamic> tutorialData, String status) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('history').add({
      'type': 'tutorial',
      'title': tutorialData['title'] ?? 'Untitled',
      'subtitle': tutorialData['subtitle'] ?? '',
      'image': tutorialData['image'] ?? '',
      'url': tutorialData['videoUrl'] ?? '',
      'source': tutorialData['source'] ?? '',
      'status': status, // 'Viewed' or 'Saved'
      'date': DateTime.now().toIso8601String().split('T')[0],
      'time': TimeOfDay.now().format(context),
      'userId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }


  Future<void> _toggleSaveTutorial(
      String tutorialId, Map<String, dynamic> tutorialData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final safeId = _generateSafeId(tutorialId);
    final userDoc = _firestore.collection('users').doc(user.uid);
    final tutorialDoc =
    _firestore.collection('savedTutorials').doc("${user.uid}_$safeId");

    if (savedIds.contains(safeId)) {
      // Unsave
      savedIds.remove(safeId);
      await userDoc.set({
        'savedTutorials': FieldValue.arrayRemove([safeId])
      }, SetOptions(merge: true));
      await tutorialDoc.delete().catchError((_) {});
    } else {
      // Save
      savedIds.add(safeId);
      await userDoc.set({
        'savedTutorials': FieldValue.arrayUnion([safeId])
      }, SetOptions(merge: true));
      await tutorialDoc.set({
        'title': tutorialData['title'],
        'subtitle': tutorialData['subtitle'],
        'image': tutorialData['image'],
        'videoUrl': tutorialData['videoUrl'],
        'type': tutorialData['type'],
        'source': tutorialData['source'],
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });


      await _addToHistory(tutorialData, 'Saved');
    }

    setState(() {});
  }


  Future<void> fetchExternalTutorials(String query, {bool reset = true}) async {
    if (query.isEmpty) return;

    if (reset) {
      setState(() {
        isLoading = true;
        externalResults.clear();
        currentOffset = 0;
      });
    } else {
      setState(() => isLoadingMore = true);
    }

    try {
      List<Map<String, dynamic>> results = [];

      // YouTube API
      final youtubeUrl =
          'https://www.googleapis.com/youtube/v3/search?part=snippet&q=$query&type=video&maxResults=5&key=$youtubeApiKey';
      final youtubeResponse = await http.get(Uri.parse(youtubeUrl));

      if (youtubeResponse.statusCode == 200) {
        final data = json.decode(youtubeResponse.body);
        final items = data['items'];
        if (items is List) {
          for (var item in items) {
            final snippet = item['snippet'];
            if (snippet != null) {
              results.add({
                'title': snippet['title'] ?? 'Untitled Video',
                'subtitle': snippet['description'] ?? '',
                'image': snippet['thumbnails']?['high']?['url'] ?? '',
                'videoUrl':
                'https://www.youtube.com/watch?v=${item['id']?['videoId']}',
                'type': 'video',
                'source': 'YouTube',
              });
            }
          }
        }
      }

      // iFixit
      results.addAll(await fetchIfixitGuides(query));

      setState(() {
        if (reset) {
          externalResults = results;
        } else {
          externalResults.addAll(results);
        }
      });
    } catch (e) {
      debugPrint("❌ Error fetching external tutorials: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load tutorials.')),
      );
    } finally {
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchIfixitGuides(String query) async {
    final url =
        'https://www.ifixit.com/api/2.0/search/$query?doctypes=guide&limit=$limit';
    final response = await http.get(Uri.parse(url));

    List<Map<String, dynamic>> guides = [];
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['results'] is List) {
        final results = data['results'] as List;
        final seenIds = <int>{};

        for (var item in results) {
          if (item['guideid'] == null || seenIds.contains(item['guideid']))
            continue;
          seenIds.add(item['guideid']);

          String imageUrl = "";
          if (item['image'] is Map && item['image']['standard'] != null) {
            imageUrl = item['image']['standard'];
          } else if (item['image'] is String) {
            imageUrl = item['image'];
          } else {
            imageUrl =
            "https://www.ifixit.com/static/images/meta/ifixit-meta-image.jpg";
          }

          guides.add({
            'title': item['title'] ?? 'Untitled Guide',
            'subtitle': item['summary'] ?? '',
            'image': imageUrl,
            'videoUrl':
            'https://www.ifixit.com/Guide/${item['title']}/${item['guideid']}',
            'type': 'ifixit',
            'source': 'iFixit',
          });
        }
      }
    }
    return guides;
  }

  @override
  Widget build(BuildContext context) {
    final filters = ["All", "YouTube", "iFixit"];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B981),
        elevation: 0,
        title: const Text(
          "Find A Guide",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.star, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedTutorialsScreen()),
              );
            },
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((filter) {
                  final isSelected = selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      selectedColor: const Color(0xFF10B981),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                      onSelected: (_) {
                        setState(() {
                          selectedFilter = filter;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildResultsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        onSubmitted: (value) => fetchExternalTutorials(value),
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: "Search repair guides or video tutorials...",
          icon: Icon(Icons.search, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }
    if (externalResults.isEmpty) {
      return const Center(child: Text("No guides found."));
    }

    final filteredResults = selectedFilter == "All"
        ? externalResults
        : externalResults.where((e) => e['source'] == selectedFilter).toList();

    return ListView.builder(
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final guide = filteredResults[index];
        return tutorialCard(
          context,
          guide['image'] ?? '',
          guide['title'] ?? 'No Title',
          guide['subtitle'] ?? '',
          guide['type'],
          guide['videoUrl'],
          guide['source'],
        );
      },
    );
  }

  Widget tutorialCard(BuildContext context, String imgUrl, String title,
      String subtitle, String type, String? videoUrl, String source) {
    String label;
    switch (type) {
      case 'ifixit':
        label = "Read Guide (iFixit)";
        break;
      case 'video':
        label = "Watch Video (YouTube)";
        break;
      default:
        label = "View Guide";
    }

    final tutorialId = videoUrl ?? title;
    final safeId = _generateSafeId(tutorialId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imgUrl,
              height: 70,
              width: 70,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 70,
                width: 70,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, color: Colors.grey),
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
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onPressed: () async {
                          if (videoUrl == null || videoUrl.isEmpty) return;

                          // ✅ Record as Viewed
                          await _addToHistory({
                            'title': title,
                            'subtitle': subtitle,
                            'image': imgUrl,
                            'videoUrl': videoUrl,
                            'source': source,
                          }, 'Viewed');

                          if (type == 'video') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VideoTutorialScreen(videoUrl: videoUrl),
                              ),
                            );
                          } else {
                            final Uri url = Uri.parse(videoUrl);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url,
                                  mode: LaunchMode.externalApplication);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                    Text('Could not open guide link')),
                              );
                            }
                          }
                        },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(label, textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        savedIds.contains(safeId)
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                      ),
                      onPressed: () => _toggleSaveTutorial(safeId, {
                        'title': title,
                        'subtitle': subtitle,
                        'image': imgUrl,
                        'videoUrl': videoUrl,
                        'type': type,
                        'source': source,
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SavedTutorialsScreen extends StatefulWidget {
  const SavedTutorialsScreen({super.key});

  @override
  State<SavedTutorialsScreen> createState() => _SavedTutorialsScreenState();
}

class _SavedTutorialsScreenState extends State<SavedTutorialsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _generateSafeId(String rawId) {
    return rawId.replaceAll(RegExp(r'[^\w]+'), '_');
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("You must be logged in.")),
      );
    }

    final savedTutorialsRef =
    _firestore.collection('savedTutorials').where('userId', isEqualTo: user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Tutorials"),
        backgroundColor: const Color(0xFF10B981),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: savedTutorialsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text("Failed to load tutorials. Please try again."),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No saved tutorials yet."),
            );
          }

          final docs = snapshot.data!.docs;
          final sortedDocs = docs.toList()
            ..sort((a, b) {
              final at = a['timestamp'] ?? Timestamp.now();
              final bt = b['timestamp'] ?? Timestamp.now();
              return bt.compareTo(at);
            });

          return ListView.builder(
            itemCount: sortedDocs.length,
            itemBuilder: (context, index) {
              final data = sortedDocs[index].data() as Map<String, dynamic>;

              return ListTile(
                leading: Image.network(
                  data['image'] ?? '',
                  height: 50,
                  width: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: Colors.grey),
                ),
                title: Text(data['title'] ?? 'Untitled'),
                subtitle: Text(
                  data['subtitle'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final tutorialId = data['videoUrl'] ?? data['title'];
                    final safeId = _generateSafeId(tutorialId);

                    await _firestore
                        .collection('savedTutorials')
                        .doc(sortedDocs[index].id)
                        .delete();

                    await _firestore.collection('users').doc(user.uid).update({
                      'savedTutorials': FieldValue.arrayRemove([safeId])
                    });
                  },
                ),
                onTap: () async {
                  final url = data['videoUrl'];
                  if (url == null) return;
                  if (data['type'] == 'video') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoTutorialScreen(videoUrl: url),
                      ),
                    );
                  } else {
                    final Uri link = Uri.parse(url);
                    if (await canLaunchUrl(link)) {
                      await launchUrl(link,
                          mode: LaunchMode.externalApplication);
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
