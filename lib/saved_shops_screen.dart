import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SavedShopsScreen extends StatelessWidget {
  const SavedShopsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view saved shops.")),
      );
    }

    final savedShopsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_shops')
        .orderBy('saved_at', descending: true);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B981),
        title: const Text(
          "Saved Repair Shops",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: savedShopsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("You haven't saved any shops yet."),
            );
          }

          final shops = snapshot.data!.docs;

          return ListView.builder(
            itemCount: shops.length,
            itemBuilder: (context, i) {
              final shop = shops[i];
              final data = shop.data() as Map<String, dynamic>;
              final lat = data['lat'];
              final lon = data['lon'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text(
                    data['name'] ?? 'Unnamed Repair Shop',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    "${data['type'] ?? ''}\n${data['address'] ?? ''}",
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () async {
                      await shop.reference.delete();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Shop removed from saved list."),
                        ),
                      );
                    },
                  ),
                  onTap: () {

                    if (lat != null && lon != null) {
                      Navigator.pop(context, LatLng(lat, lon));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
