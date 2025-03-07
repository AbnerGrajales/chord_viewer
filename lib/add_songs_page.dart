import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'resource_viewer_page.dart';

class AddSongsPage extends StatefulWidget {
  final int setlistIndex;

  const AddSongsPage({super.key, required this.setlistIndex});

  @override
  State<AddSongsPage> createState() => _AddSongsPageState();
}

class _AddSongsPageState extends State<AddSongsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> songs = [];
  List<Map<String, dynamic>> filteredSongs = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (!mounted) return;
    _filterSongs();
  }

  void _filterSongs() {
    setState(() {
      if (_searchController.text.isEmpty) {
        filteredSongs = List.from(songs);
      } else {
        filteredSongs = songs
            .where((song) =>
            song['title'].toLowerCase().contains(_searchController.text.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _addToSetList(Map<String, dynamic> song) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;
    final setlistRef = FirebaseFirestore.instance.collection('setlists').doc(userId);
    final docSnapshot = await setlistRef.get();

    final songWithTimestamp = {
      ...song,
      'addedAt': DateTime.now().toUtc().toIso8601String(),
    };

    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      final currentSetlists = List<Map<String, dynamic>>.from(data['setlists'] ?? []);
      final currentSongs = List<Map<String, dynamic>>.from(
        currentSetlists[widget.setlistIndex]['songs'] ?? [],
      );

      if (!currentSongs.any((s) => s['title'] == song['title'])) {
        currentSongs.add(songWithTimestamp);
        currentSetlists[widget.setlistIndex]['songs'] = currentSongs;
        currentSetlists[widget.setlistIndex]['lastModified'] = DateTime.now().toUtc().toIso8601String();
        await setlistRef.set({'setlists': currentSetlists}, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Canción añadida')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La canción ya está en este setlist')),
          );
        }
      }
    }
  }

  Future<void> _removeFromSetList(Map<String, dynamic> song) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;
    final setlistRef = FirebaseFirestore.instance.collection('setlists').doc(userId);
    final docSnapshot = await setlistRef.get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      final currentSetlists = List<Map<String, dynamic>>.from(data['setlists'] ?? []);
      final currentSongs = List<Map<String, dynamic>>.from(
        currentSetlists[widget.setlistIndex]['songs'] ?? [],
      );

      currentSongs.removeWhere((s) => s['title'] == song['title']);
      currentSetlists[widget.setlistIndex]['songs'] = currentSongs;
      currentSetlists[widget.setlistIndex]['lastModified'] = DateTime.now().toUtc().toIso8601String();
      await setlistRef.set({'setlists': currentSetlists}, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canción eliminada')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final userId = user.uid;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Buscar canciones',
          style: GoogleFonts.raleway(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar por nombre...',
                labelStyle: GoogleFonts.raleway(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('setlists').doc(userId).snapshots(),
              builder: (context, setlistSnapshot) {
                List<Map<String, dynamic>> setlistSongs = [];
                if (setlistSnapshot.hasData && setlistSnapshot.data!.exists) {
                  final data = setlistSnapshot.data!.data() as Map<String, dynamic>;
                  final setlists = List<Map<String, dynamic>>.from(data['setlists'] ?? []);
                  if (setlists.isNotEmpty && widget.setlistIndex < setlists.length) {
                    setlistSongs = List<Map<String, dynamic>>.from(
                      setlists[widget.setlistIndex]['songs'] ?? [],
                    );
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('songs').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No hay canciones disponibles'));
                    }

                    songs = snapshot.data!.docs
                        .map((doc) => doc.data() as Map<String, dynamic>)
                        .toList();
                    if (_searchController.text.isEmpty) {
                      filteredSongs = List.from(songs);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = filteredSongs[index];
                        final isInSetlist = setlistSongs.any((s) => s['title'] == song['title']);
                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              song['title'],
                              style: GoogleFonts.raleway(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () {
                              final urlLower = song['resourceUrl'].toLowerCase();
                              ResourceType resourceType = urlLower.contains('.pdf') ? ResourceType.pdf : ResourceType.image;
                              print('Navigating to ResourceViewerPage with URL: ${song['resourceUrl']}, Type: $resourceType');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ResourceViewerPage(
                                    resourceUrl: song['resourceUrl'],
                                    resourceType: resourceType,
                                    songTitle: song['title'],
                                  ),
                                ),
                              );
                            },
                            trailing: isInSetlist
                                ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check, color: Colors.green),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.remove, color: Colors.red),
                                  onPressed: () => _removeFromSetList(song),
                                ),
                              ],
                            )
                                : IconButton(
                              icon: const Icon(Icons.add, color: Color(0xFF6A1B9A)),
                              onPressed: () => _addToSetList(song),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}