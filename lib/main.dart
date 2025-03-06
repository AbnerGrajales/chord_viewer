import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'resource_viewer_page.dart';
import 'package:flutter/foundation.dart';

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
    _searchController.addListener(_onSearchChanged); // Usa un método seguro para filtrar
  }

  void _onSearchChanged() {
    if (!mounted) return; // Evita llamadas si el widget ya no está montado
    _filterSongs(); // Llama al filtrado de forma segura
  }

  void _filterSongs() {
    setState(() {
      if (_searchController.text.isEmpty) {
        filteredSongs = List.from(songs); // Copia los songs originales
      } else {
        filteredSongs = songs
            .where((song) =>
            song['title'].toLowerCase().contains(_searchController.text.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chord Viewer'),
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

                // Actualiza songs y filteredSongs sin setState directo
                final newSongs = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
                if (_searchController.text.isEmpty && !listEquals(songs, newSongs)) {
                  songs = newSongs;
                  filteredSongs = List.from(songs); // Sincroniza filteredSongs al inicio
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
                        onPressed: () {
                          _showAddToRepertoireDialog(context, song);
                        },
                      ),
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

  void _showAddToRepertoireDialog(BuildContext context, Map<String, dynamic> song) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to Repertoire'),
          content: const Text('You need to sign in to add songs to your repertoire.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                print('Redirect to login page');
                // Aquí implementarás la redirección a login más adelante
              },
              child: const Text('Sign In'),
            ),
          ],
        );
      },
    );
  }
}

// Importa listEquals para comparar listas

bool listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  if (identical(a, b)) return true;
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}