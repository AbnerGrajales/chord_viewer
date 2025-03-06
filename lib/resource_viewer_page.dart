import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class ResourceViewerPage extends StatefulWidget {
  final String resourceUrl;
  final String resourceType;

  const ResourceViewerPage({
    super.key,
    required this.resourceUrl,
    required this.resourceType,
  });

  @override
  State<ResourceViewerPage> createState() => _ResourceViewerPageState();
}

class _ResourceViewerPageState extends State<ResourceViewerPage> {
  String? _localPath;

  @override
  void initState() {
    super.initState();
    if (widget.resourceType == 'pdf') {
      _downloadAndSaveFile();
    }
  }

  Future<void> _downloadAndSaveFile() async {
    try {
      final response = await http.get(Uri.parse(widget.resourceUrl));
      final bytes = response.bodyBytes;
      final tempDir = await Directory.systemTemp.createTemp();
      final file = File('${tempDir.path}/temp.${widget.resourceType}');
      await file.writeAsBytes(bytes);
      setState(() {
        _localPath = file.path;
      });
    } catch (e) {
      print('Error downloading file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chord Viewer')),
      body: widget.resourceType == 'pdf'
          ? _localPath != null
          ? PDFView(
        filePath: _localPath!,
        onError: (error) {
          print('Error loading PDF: $error');
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