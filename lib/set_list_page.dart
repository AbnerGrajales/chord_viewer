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
  String _sortCriterion = 'Orden de adición'; // Criterio inicial

  // Lista de opciones para el popup
  final List<String> _sortOptions = ['Orden de adición', 'Por nombre'];

  // Método para limpiar el setlist
  Future<void> _clearSetList() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;
    await FirebaseFirestore.instance.collection('setlists').doc(userId).set({'songs': []});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SetList cleared!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view your SetList.'));
    }

    final userId = user.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My SetList'),
        actions: [
          // PopupMenuButton para ordenar
          PopupMenuButton<String>(
            onSelected: (String value) {
              setState(() {
                _sortCriterion = value;
              });
            },
            itemBuilder: (BuildContext context) {
              return _sortOptions.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
            icon: const Icon(Icons.sort),
          ),
          // Opción para limpiar el setlist
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear SetList'),
                  content: const Text('Are you sure you want to clear your SetList?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ) ?? false;
              if (confirmed) {
                await _clearSetList();
              }
            },
          ),
        ],
      ),
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
          List<Map<String, dynamic>> songs = List<Map<String, dynamic>>.from(data['songs'] ?? []);

          // Aplica el ordenamiento según el criterio seleccionado
          if (_sortCriterion == 'Por nombre') {
            songs.sort((a, b) => a['title'].toLowerCase().compareTo(b['title'].toLowerCase()));
          } else if (_sortCriterion == 'Orden de adición') {
            songs.sort((a, b) {
              final timestampA = a['addedAt'] as String?; // Cambiado a String?
              final timestampB = b['addedAt'] as String?;
              // Maneja el caso en que addedAt sea null (canciones antiguas)
              if (timestampA == null && timestampB == null) return 0;
              if (timestampA == null) return 1;
              if (timestampB == null) return -1;
              return timestampA.compareTo(timestampB); // Compara como strings
            });
          }

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
                        resourceType: song['resourceType'] ?? 'pdf',
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