import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_page.dart';
import 'add_songs_page.dart';
import 'resource_viewer_page.dart';

class MySetlistsPage extends StatefulWidget {
  const MySetlistsPage({super.key});

  @override
  State<MySetlistsPage> createState() => _MySetlistsPageState();
}

class _MySetlistsPageState extends State<MySetlistsPage> {
  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  Future<void> _createSetlist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;
    final setlistRef = FirebaseFirestore.instance.collection('setlists').doc(userId);

    final nameController = TextEditingController();
    final createdAt = DateTime.now().toUtc().toIso8601String();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.library_music, color: Color(0xFF6A1B9A), size: 24),
            const SizedBox(width: 8),
            Text(
              'Crear nuevo setlist',
              style: GoogleFonts.raleway(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Nombre del setlist',
            labelStyle: GoogleFonts.raleway(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.raleway()),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context, nameController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Crear', style: GoogleFonts.raleway()),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    final newSetlist = {
      'name': result,
      'songs': [],
      'createdAt': createdAt,
      'lastModified': createdAt,
    };

    final docSnapshot = await setlistRef.get();
    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      final currentSetlists = List<Map<String, dynamic>>.from(data['setlists'] ?? []);
      currentSetlists.add(newSetlist);
      await setlistRef.set({'setlists': currentSetlists}, SetOptions(merge: true));
    } else {
      await setlistRef.set({'setlists': [newSetlist]});
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setlist creado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const LoginPage();
    }

    final userId = user.uid;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F5FF), Color(0xFFAB47BC)],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.music_note, size: 36, color: Colors.white.withOpacity(0.9)),
                ),
                title: Text(
                  'Mis Setlists',
                  style: GoogleFonts.raleway(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () => _signOut(context),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('setlists').doc(userId).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final List<Map<String, dynamic>> setlists;
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        setlists = [];
                      } else {
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        setlists = List<Map<String, dynamic>>.from(data['setlists'] ?? []);
                      }

                      if (setlists.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.music_note, size: 150, color: Color(0xFF6A1B9A).withOpacity(0.8)),
                              const SizedBox(height: 30),
                              Text(
                                '¡Aún no tienes setlists!\nCrea uno ahora.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.raleway(
                                  fontSize: 22,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: setlists.length,
                        itemBuilder: (context, index) {
                          final setlist = setlists[index];
                          final setlistSongs = List<Map<String, dynamic>>.from(setlist['songs'] ?? []);
                          final createdAt = DateTime.parse(setlist['createdAt']).toLocal();
                          return Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            margin: const EdgeInsets.only(bottom: 20),
                            color: Colors.white.withOpacity(0.95),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SetlistDetailPage(
                                      setlistIndex: index,
                                      setlistName: setlist['name'],
                                      setlistSongs: setlistSongs,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.white, Color(0xFFEDE7F6)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.library_music, size: 30, color: Color(0xFF6A1B9A)),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            setlist['name'] ?? 'Sin nombre',
                                            style: GoogleFonts.raleway(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            '${createdAt.day} ${createdAt.month} ${createdAt.year}, ${setlistSongs.length} canciones',
                                            style: GoogleFonts.raleway(
                                              fontSize: 16,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Color(0xFF6A1B9A)),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => SetlistDetailPage(
                                                  setlistIndex: index,
                                                  setlistName: setlist['name'],
                                                  setlistSongs: setlistSongs,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () async {
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                title: Text(
                                                  'Eliminar setlist',
                                                  style: GoogleFonts.raleway(fontWeight: FontWeight.bold),
                                                ),
                                                content: Text(
                                                  '¿Estás seguro de eliminar este setlist?',
                                                  style: GoogleFonts.raleway(),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: Text('Cancelar', style: GoogleFonts.raleway()),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, true),
                                                    child: Text('Eliminar', style: GoogleFonts.raleway()),
                                                  ),
                                                ],
                                              ),
                                            ) ?? false;

                                            if (confirmed) {
                                              final docRef = FirebaseFirestore.instance.collection('setlists').doc(userId);
                                              final docSnapshot = await docRef.get();
                                              if (docSnapshot.exists) {
                                                final data = docSnapshot.data() as Map<String, dynamic>;
                                                final updatedSetlists = List<Map<String, dynamic>>.from(data['setlists'] ?? []);
                                                updatedSetlists.removeAt(index);
                                                await docRef.set({'setlists': updatedSetlists}, SetOptions(merge: true));
                                              }
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Setlist eliminado')),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSetlist,
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add),
        label: Text(
          'Nuevo setlist',
          style: GoogleFonts.raleway(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class SetlistDetailPage extends StatefulWidget {
  final int setlistIndex;
  final String setlistName;
  final List<Map<String, dynamic>> setlistSongs;

  const SetlistDetailPage({
    super.key,
    required this.setlistIndex,
    required this.setlistName,
    required this.setlistSongs,
  });

  @override
  State<SetlistDetailPage> createState() => _SetlistDetailPageState();
}

class _SetlistDetailPageState extends State<SetlistDetailPage> {
  Future<void> _clearSetlist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Limpiar setlist',
          style: GoogleFonts.raleway(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de limpiar este setlist?',
          style: GoogleFonts.raleway(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.raleway()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Limpiar', style: GoogleFonts.raleway()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = user.uid;
      final setlistRef = FirebaseFirestore.instance.collection('setlists').doc(userId);
      final docSnapshot = await setlistRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final updatedSetlists = List<Map<String, dynamic>>.from(data['setlists'] ?? []);
        updatedSetlists[widget.setlistIndex]['songs'] = [];
        updatedSetlists[widget.setlistIndex]['lastModified'] = DateTime.now().toUtc().toIso8601String();
        await setlistRef.set({'setlists': updatedSetlists}, SetOptions(merge: true));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setlist limpiado')),
        );
      }
    }
  }

  Future<void> _sortSongs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;
    final setlistRef = FirebaseFirestore.instance.collection('setlists').doc(userId);
    final docSnapshot = await setlistRef.get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      final updatedSetlists = List<Map<String, dynamic>>.from(data['setlists'] ?? []);
      final songs = List<Map<String, dynamic>>.from(updatedSetlists[widget.setlistIndex]['songs'] ?? []);

      final sortOption = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Ordenar canciones',
            style: GoogleFonts.raleway(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Elige cómo quieres ordenar las canciones:',
            style: GoogleFonts.raleway(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'name'),
              child: Text('Por nombre', style: GoogleFonts.raleway()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'addedAt'),
              child: Text('Por orden de adición', style: GoogleFonts.raleway()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.raleway()),
            ),
          ],
        ),
      );

      if (sortOption == null) return;

      if (sortOption == 'name') {
        songs.sort((a, b) => a['title'].compareTo(b['title']));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Canciones ordenadas alfabéticamente')),
          );
        }
      } else if (sortOption == 'addedAt') {
        songs.sort((a, b) => a['addedAt'].compareTo(b['addedAt']));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Canciones ordenadas por orden de adición')),
          );
        }
      }

      updatedSetlists[widget.setlistIndex]['songs'] = songs;
      updatedSetlists[widget.setlistIndex]['lastModified'] = DateTime.now().toUtc().toIso8601String();
      await setlistRef.set({'setlists': updatedSetlists}, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginPage();

    final userId = user.uid;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.setlistName,
          style: GoogleFonts.raleway(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_by_alpha),
            onPressed: _sortSongs,
            tooltip: 'Ordenar canciones',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearSetlist,
            tooltip: 'Limpiar setlist',
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

          final List<Map<String, dynamic>> setlists;
          if (!snapshot.hasData || !snapshot.data!.exists) {
            setlists = [];
          } else {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            setlists = List<Map<String, dynamic>>.from(data['setlists'] ?? []);
          }

          if (setlists.isEmpty || widget.setlistIndex >= setlists.length) {
            return const Center(child: Text('Setlist no encontrado'));
          }

          final setlistSongs = List<Map<String, dynamic>>.from(setlists[widget.setlistIndex]['songs'] ?? []);

          if (setlistSongs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, size: 150, color: Color(0xFF6A1B9A).withOpacity(0.8)),
                  const SizedBox(height: 30),
                  Text(
                    '¡Este setlist está vacío!\nAñade canciones ahora.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.raleway(
                      fontSize: 22,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: setlistSongs.length,
            itemBuilder: (context, index) {
              final song = setlistSongs[index];
              return Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                margin: const EdgeInsets.only(bottom: 20),
                color: Colors.white.withOpacity(0.95),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
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
                  child: Container(
                    height: 80.0, // Altura fija de la tarjeta
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Color(0xFFEDE7F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.music_note, size: 30, color: Color(0xFF6A1B9A)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center, // Centrado vertical
                            crossAxisAlignment: CrossAxisAlignment.start, // Centrado horizontal
                            children: [
                              Text(
                                song['title'],
                                textAlign: TextAlign.center,
                                style: GoogleFonts.raleway(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 2, // Permitir hasta 2 líneas
                                overflow: TextOverflow.ellipsis, // Cortar con puntos suspensivos si es más largo
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.red),
                          onPressed: () async {
                            final docRef = FirebaseFirestore.instance.collection('setlists').doc(userId);
                            final docSnapshot = await docRef.get();
                            if (docSnapshot.exists) {
                              final data = docSnapshot.data() as Map<String, dynamic>;
                              final updatedSetlists = List<Map<String, dynamic>>.from(data['setlists'] ?? []);
                              final updatedSongs = List<Map<String, dynamic>>.from(
                                updatedSetlists[widget.setlistIndex]['songs'] ?? [],
                              );
                              updatedSongs.removeAt(index);
                              updatedSetlists[widget.setlistIndex]['songs'] = updatedSongs;
                              updatedSetlists[widget.setlistIndex]['lastModified'] =
                                  DateTime.now().toUtc().toIso8601String();
                              await docRef.set({'setlists': updatedSetlists}, SetOptions(merge: true));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddSongsPage(setlistIndex: widget.setlistIndex),
            ),
          );
        },
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add),
        label: Text(
          'Buscar canciones',
          style: GoogleFonts.raleway(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }
}