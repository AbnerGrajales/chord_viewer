import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'resource_viewer_page.dart';

class SetListPage extends StatefulWidget {
  const SetListPage({super.key});

  @override
  State<SetListPage> createState() => _SetListPageState();
}

class _SetListPageState extends State<SetListPage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view your SetList.'));
    }

    final userId = user.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('My SetList')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('setlists').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No songs in your SetList yet.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final songs = List<Map<String, dynamic>>.from(data['songs'] ?? []);

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                title: Text(song['title']),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResourceViewerPage(
                        resourceUrl: song['resourceUrl'],
                        resourceType: song['resourceType'] ?? 'pdf', // Asume PDF si no está definido
                      ),
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    setState(() {
                      songs.removeAt(index);
                      FirebaseFirestore.instance
                          .collection('setlists')
                          .doc(userId)
                          .update({'songs': songs});
                    });
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