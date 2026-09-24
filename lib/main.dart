import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'models/correction_state.dart';
import 'services/cmyk_processor.dart';

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
  Uint8List? _originalBytes;
  Uint8List? _processedBytes;

  String? _fileName;
  int? _imageWidth;
  int? _imageHeight;

  CorrectionState _correction = CorrectionState.zero;

  final List<CorrectionState> _history = [
    CorrectionState.zero,
  ];

  int _historyIndex = 0;

  bool _showOriginal = false;
  bool _processing = false;

  bool get _canUndo => _historyIndex > 0;

  bool get _canRedo => _historyIndex < _history.length - 1;

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
      _processedBytes = bytes;

      _fileName = file.name;
      _imageWidth = decoded.width;
      _imageHeight = decoded.height;

      _correction = CorrectionState.zero;

      _history
        ..clear()
        ..add(CorrectionState.zero);

      _historyIndex = 0;

      _showOriginal = false;
      _processing = false;
    });
  }

  Future<void> _applyCorrection(
    CorrectionState newState, {
    bool addToHistory = true,
  }) async {
    if (_originalBytes == null) {
      return;
    }

    if (addToHistory) {
      if (_historyIndex < _history.length - 1) {
        _history.removeRange(
          _historyIndex + 1,
          _history.length,
        );
      }

      _history.add(newState);
      _historyIndex = _history.length - 1;
    }

    setState(() {
      _correction = newState;
      _processing = true;
    });

    final result = await CmykProcessor.apply(
      _originalBytes!,
      cyan: newState.cyan,
      magenta: newState.magenta,
      yellow: newState.yellow,
      black: newState.black,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      if (result != null) {
        _processedBytes = result;
      }

      _processing = false;
    });
  }

  Future<void> _changeCmyk({
    double? cyan,
    double? magenta,
    double? yellow,
    double? black,
  }) async {
    final next = CorrectionState(
      cyan: cyan ?? _correction.cyan,
      magenta: magenta ?? _correction.magenta,
      yellow: yellow ?? _correction.yellow,
      black: black ?? _correction.black,
    );

    await _applyCorrection(next);
  }

  Future<void> _undo() async {
    if (!_canUndo) {
      return;
    }

    final newIndex = _historyIndex - 1;
    final state = _history[newIndex];

    _historyIndex = newIndex;

    await _applyCorrection(
      state,
      addToHistory: false,
    );
  }

  Future<void> _redo() async {
    if (!_canRedo) {
      return;
    }

    final newIndex = _historyIndex + 1;
    final state = _history[newIndex];

    _historyIndex = newIndex;

    await _applyCorrection(
      state,
      addToHistory: false,
    );
  }

  Future<void> _reset() async {
    await _applyCorrection(
      CorrectionState.zero,
    );
  }

  Future<void> _saveImage() async {
    if (_processedBytes == null) {
      return;
    }

    final baseName =
        _fileName?.replaceFirst(
              RegExp(r'\.[^.]+$'),
              '',
            ) ??
            'image';

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save corrected image',
      fileName: '${baseName}_corrected.png',
      type: FileType.custom,
      allowedExtensions: ['png'],
    );

    if (path == null) {
      return;
    }

    await File(path).writeAsBytes(_processedBytes!);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Corrected image saved successfully'),
      ),
    );
  }

  Widget _slider({
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
              width: 36,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(7),
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
              child: Text(name),
            ),
            Text(
              value.toStringAsFixed(0),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: -100,
          max: 100,
          divisions: 200,
          onChanged:
              _originalBytes == null || _processing
                  ? null
                  : onChanged,
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final bytes =
        _showOriginal ? _originalBytes : _processedBytes;

    if (bytes == null) {
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
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _showOriginal ? 'ORIGINAL' : 'CORRECTED',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (_processing)
          Positioned(
            right: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Processing...'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel() {
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
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
                    'Adjust print channels',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _slider(
                    name: 'Cyan',
                    shortName: 'C',
                    value: _correction.cyan,
                    onChanged: (v) {
                      _changeCmyk(cyan: v);
                    },
                  ),

                  _slider(
                    name: 'Magenta',
                    shortName: 'M',
                    value: _correction.magenta,
                    onChanged: (v) {
                      _changeCmyk(magenta: v);
                    },
                  ),

                  _slider(
                    name: 'Yellow',
                    shortName: 'Y',
                    value: _correction.yellow,
                    onChanged: (v) {
                      _changeCmyk(yellow: v);
                    },
                  ),

                  _slider(
                    name: 'Black',
                    shortName: 'K',
                    value: _correction.black,
                    onChanged: (v) {
                      _changeCmyk(black: v);
                    },
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _canUndo &&
                                      !_processing
                                  ? _undo
                                  : null,
                          icon: const Icon(
                            Icons.undo,
                          ),
                          label: const Text('UNDO'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _canRedo &&
                                      !_processing
                                  ? _redo
                                  : null,
                          icon: const Icon(
                            Icons.redo,
                          ),
                          label: const Text('REDO'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _originalBytes == null ||
                                  _processing
                              ? null
                              : _reset,
                      icon: const Icon(
                        Icons.restart_alt,
                      ),
                      label: const Text(
                        'RESET CORRECTION',
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Divider(
                    color: Colors.white12,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'IMAGE INFORMATION',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _infoRow(
                    'File',
                    _fileName ?? '—',
                  ),

                  _infoRow(
                    'Resolution',
                    _imageWidth != null &&
                            _imageHeight != null
                        ? '${_imageWidth} × $_imageHeight'
                        : '—',
                  ),

                  const SizedBox(height: 16),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Show original',
                    ),
                    value: _showOriginal,
                    onChanged:
                        _originalBytes == null
                            ? null
                            : (value) {
                                setState(() {
                                  _showOriginal =
                                      value;
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
                onPressed:
                    _processedBytes == null ||
                            _processing
                        ? null
                        : _saveImage,
                icon: const Icon(Icons.save),
                label: const Text(
                  'EXPORT CORRECTED IMAGE',
                ),
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
          IconButton(
            tooltip: 'Undo',
            onPressed:
                _canUndo && !_processing
                    ? _undo
                    : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed:
                _canRedo && !_processing
                    ? _redo
                    : null,
            icon: const Icon(Icons.redo),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _openImage,
            icon: const Icon(
              Icons.folder_open,
            ),
            label: const Text('OPEN'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed:
                _processedBytes == null ||
                        _processing
                    ? null
                    : _saveImage,
            icon: const Icon(
              Icons.save_outlined,
            ),
            label: const Text('SAVE'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(
                16,
                16,
                0,
                16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF111318),
                borderRadius:
                    BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF292D33),
                ),
              ),
              clipBehavior:
                  Clip.antiAlias,
              child: _buildPreview(),
            ),
          ),
          _buildPanel(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 30,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
        ),
        color: const Color(0xFF0A0C0F),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 8,
              color: _processing
                  ? Colors.orangeAccent
                  : Colors.greenAccent,
            ),
            const SizedBox(width: 8),
            Text(
              _processing
                  ? 'PROCESSING'
                  : 'READY',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white54,
              ),
            ),
            const Spacer(),
            Text(
              _history.length > 1
                  ? 'History: ${_historyIndex + 1}/${_history.length}'
                  : 'No changes',
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
