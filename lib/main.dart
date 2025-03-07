import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'resource_viewer_page.dart';
import 'set_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chord Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ChordHomePage(),
    );
  }
}

class ChordHomePage extends StatefulWidget {
  const ChordHomePage({super.key});

  @override
  State<ChordHomePage> createState() => _ChordHomePageState();
}

class _ChordHomePageState extends State<ChordHomePage> {
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
    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }

    final userId = user.uid;
    final setlistRef = FirebaseFirestore.instance.collection('setlists').doc(userId);
    final docSnapshot = await setlistRef.get();

    // Usa DateTime.now().toUtc() en lugar de FieldValue.serverTimestamp()
    final songWithTimestamp = {
      ...song,
      'addedAt': DateTime.now().toUtc().toIso8601String(), // Timestamp local en UTC
    };

    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      final currentSongs = List<Map<String, dynamic>>.from(data['songs'] ?? []);
      if (!currentSongs.any((s) => s['title'] == song['title'])) {
        currentSongs.add(songWithTimestamp);
        await setlistRef.set({'songs': currentSongs}, SetOptions(merge: true));
      }
    } else {
      await setlistRef.set({'songs': [songWithTimestamp]});
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to SetList!')),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String? displayName = user?.displayName;
    String initials = user != null && displayName != null && displayName.isNotEmpty
        ? displayName.trim().split(' ').map((s) => s[0]).take(2).join()
        : user?.email?.substring(0, 1).toUpperCase() ?? '??';

    return WillPopScope(
      onWillPop: () async {
        if (user != null) {
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chord Viewer'),
          actions: [
            if (user != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                  child: user.photoURL == null
                      ? Text(
                    initials,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  )
                      : null,
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            if (user != null)
              IconButton(
                icon: const Icon(Icons.list),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SetListPage()),
                  );
                },
              ),
            if (user != null)
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _signOut,
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search Songs',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('songs').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No songs found'));
                  }

                  final newSongs = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
                  if (_searchController.text.isEmpty && !listEquals(songs, newSongs)) {
                    songs = newSongs;
                    filteredSongs = List.from(songs);
                  }

                  return ListView.builder(
                    itemCount: filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
                      return ListTile(
                        title: Text(song['title']),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ResourceViewerPage(
                                resourceUrl: song['resourceUrl'],
                                resourceType: song['resourceType'],
                              ),
                            ),
                          );
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _addToSetList(song),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  if (identical(a, b)) return true;
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}