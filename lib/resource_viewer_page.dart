import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';

enum ResourceType { pdf, image }

class ResourceViewerPage extends StatefulWidget {
  final String resourceUrl;
  final ResourceType resourceType;
  final String songTitle;

  const ResourceViewerPage({
    super.key,
    required this.resourceUrl,
    required this.resourceType,
    required this.songTitle,
  });

  @override
  State<ResourceViewerPage> createState() => _ResourceViewerPageState();
}

class _ResourceViewerPageState extends State<ResourceViewerPage> {
  String? _localPath;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.resourceType == ResourceType.pdf) {
      _downloadAndSaveFile();
    }
  }

  Future<void> _downloadAndSaveFile() async {
    try {
      final response = await http.get(Uri.parse(widget.resourceUrl)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timed out while downloading the PDF');
        },
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
      final bytes = response.bodyBytes;
      final tempDir = await Directory.systemTemp.createTemp();
      final file = File('${tempDir.path}/temp.pdf');
      await file.writeAsBytes(bytes);
      if (mounted) {
        setState(() {
          _localPath = file.path;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading PDF: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_localPath != null) {
      final file = File(_localPath!);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.songTitle,
          style: GoogleFonts.raleway(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: widget.resourceType == ResourceType.pdf
          ? _hasError
          ? const Center(child: Text('Error loading PDF'))
          : _localPath != null
          ? PDFView(
        filePath: _localPath!,
        onError: (error) {
          if (mounted) {
            setState(() {
              _hasError = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading PDF: $error')),
            );
          }
        },
      )
          : const Center(child: CircularProgressIndicator())
          : Image.network(
        widget.resourceUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Text('Error loading image'));
        },
      ),
    );
  }
}