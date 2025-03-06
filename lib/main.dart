import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

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
  List<String> songs = ['Con mi Dios', 'Estamos juntos otra vez', 'Way Maker'];
  List<String> filteredSongs = [];

  @override
  void initState() {
    super.initState();
    filteredSongs = songs; // Inicialmente muestra todas las canciones
    _searchController.addListener(_filterSongs);
  }

  void _filterSongs() {
    setState(() {
      filteredSongs = songs
          .where((song) => song.toLowerCase().contains(_searchController.text.toLowerCase()))
          .toList();
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
            child: ListView.builder(
              itemCount: filteredSongs.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(filteredSongs[index]),
                  onTap: () {
                    // Aquí iría la lógica para mostrar el PDF/imagen
                    print('Selected: ${filteredSongs[index]}');
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