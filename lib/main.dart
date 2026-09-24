import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const PrintColorStudioApp());
}

class PrintColorStudioApp extends StatelessWidget {
  const PrintColorStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Print Color Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D0F12),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D8BFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const ColorStudioScreen(),
    );
  }
}

class ColorStudioScreen extends StatefulWidget {
  const ColorStudioScreen({super.key});

  @override
  State<ColorStudioScreen> createState() => _ColorStudioScreenState();
}

class _ColorStudioScreenState extends State<ColorStudioScreen> {
  Uint8List? _imageBytes;
  Uint8List? _originalBytes;

  String? _fileName;
  int? _imageWidth;
  int? _imageHeight;

  double _cyan = 0;
  double _magenta = 0;
  double _yellow = 0;
  double _black = 0;

  bool _showOriginal = false;

  Future<void> _openImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;

    Uint8List? bytes = file.bytes;

    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }

    if (bytes == null) {
      return;
    }

    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      return;
    }

    setState(() {
      _originalBytes = bytes;
      _imageBytes = bytes;
      _fileName = file.name;
      _imageWidth = decoded.width;
      _imageHeight = decoded.height;

      _cyan = 0;
      _magenta = 0;
      _yellow = 0;
      _black = 0;
      _showOriginal = false;
    });
  }

  void _reset() {
    setState(() {
      _cyan = 0;
      _magenta = 0;
      _yellow = 0;
      _black = 0;
      _showOriginal = false;
      _imageBytes = _originalBytes;
    });
  }

  void _setCmyk({
    double? cyan,
    double? magenta,
    double? yellow,
    double? black,
  }) {
    setState(() {
      if (cyan != null) {
        _cyan = cyan;
      }
      if (magenta != null) {
        _magenta = magenta;
      }
      if (yellow != null) {
        _yellow = yellow;
      }
      if (black != null) {
        _black = black;
      }
    });
  }

  Future<void> _saveImage() async {
    if (_imageBytes == null) {
      return;
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save corrected image',
      fileName: 'corrected_${_fileName ?? 'image'}.png',
      type: FileType.custom,
      allowedExtensions: ['png'],
    );

    if (path == null) {
      return;
    }

    await File(path).writeAsBytes(_imageBytes!);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image saved successfully'),
      ),
    );
  }

  Widget _buildSlider({
    required String name,
    required String shortName,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: Text(
                shortName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(
              width: 55,
              child: Text(
                value.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: -100,
          max: 100,
          divisions: 200,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPreview() {
    if (_imageBytes == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 90,
              color: Colors.white24,
            ),
            SizedBox(height: 18),
            Text(
              'No image loaded',
              style: TextStyle(
                fontSize: 22,
                color: Colors.white60,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Open an image to start color correction',
              style: TextStyle(
                color: Colors.white30,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 0.2,
            maxScale: 5,
            child: Center(
              child: Image.memory(
                _showOriginal && _originalBytes != null
                    ? _originalBytes!
                    : _imageBytes!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              child: Text(
                _showOriginal ? 'ORIGINAL' : 'CORRECTED',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: Color(0xFF15181D),
        border: Border(
          left: BorderSide(
            color: Color(0xFF292D33),
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CMYK CORRECTION',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Color adjustment',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 28),

                  _buildSlider(
                    name: 'Cyan',
                    shortName: 'C',
                    value: _cyan,
                    onChanged: (v) => _setCmyk(cyan: v),
                  ),

                  _buildSlider(
                    name: 'Magenta',
                    shortName: 'M',
                    value: _magenta,
                    onChanged: (v) => _setCmyk(magenta: v),
                  ),

                  _buildSlider(
                    name: 'Yellow',
                    shortName: 'Y',
                    value: _yellow,
                    onChanged: (v) => _setCmyk(yellow: v),
                  ),

                  _buildSlider(
                    name: 'Black',
                    shortName: 'K',
                    value: _black,
                    onChanged: (v) => _setCmyk(black: v),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  const Divider(
                    color: Colors.white12,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'IMAGE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _InfoRow(
                    label: 'File',
                    value: _fileName ?? '—',
                  ),

                  _InfoRow(
                    label: 'Resolution',
                    value: _imageWidth != null && _imageHeight != null
                        ? '${_imageWidth} × ${_imageHeight}'
                        : '—',
                  ),

                  const SizedBox(height: 20),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show original'),
                    value: _showOriginal,
                    onChanged: _imageBytes == null
                        ? null
                        : (value) {
                            setState(() {
                              _showOriginal = value;
                            });
                          },
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0xFF292D33),
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _imageBytes == null ? null : _saveImage,
                icon: const Icon(Icons.save),
                label: const Text('EXPORT IMAGE'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.palette_outlined),
            SizedBox(width: 12),
            Text(
              'PRINT COLOR STUDIO',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _openImage,
            icon: const Icon(Icons.folder_open),
            label: const Text('OPEN'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _imageBytes == null ? null : _saveImage,
            icon: const Icon(Icons.save_outlined),
            label: const Text('SAVE'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF111318),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF292D33),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildPreview(),
            ),
          ),
          _buildRightPanel(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        color: const Color(0xFF0A0C0F),
        child: Row(
          children: [
            const Icon(
              Icons.circle,
              size: 8,
              color: Colors.greenAccent,
            ),
            const SizedBox(width: 8),
            const Text(
              'READY',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white54,
              ),
            ),
            const Spacer(),
            Text(
              _imageBytes == null
                  ? 'No image'
                  : '${_imageWidth} × ${_imageHeight}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
