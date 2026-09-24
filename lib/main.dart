import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'models/correction_state.dart';
import 'models/print_project.dart';
import 'services/cmyk_processor.dart';
import 'services/project_service.dart';
import 'widgets/cmyk_channel_control.dart';

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
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const ColorStudioPage(),
    );
  }
}

class ColorStudioPage extends StatefulWidget {
  const ColorStudioPage({super.key});

  @override
  State<ColorStudioPage> createState() => _ColorStudioPageState();
}

class _ColorStudioPageState extends State<ColorStudioPage> {
  Uint8List? _originalBytes;
  Uint8List? _processedBytes;

  String? _fileName;
  String? _sourcePath;

  int? _imageWidth;
  int? _imageHeight;

  CorrectionState _correction = CorrectionState.zero;

  final List<CorrectionState> _history = [
    CorrectionState.zero,
  ];

  int _historyIndex = 0;

  bool _showOriginal = false;
  bool _processing = false;
  bool _savingProject = false;
  bool _openingProject = false;

  Future<void> _openImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final selected = result.files.single;

    Uint8List? bytes = selected.bytes;

    if (bytes == null && selected.path != null) {
      bytes = await File(selected.path!).readAsBytes();
    }

    if (bytes == null) {
      _showMessage('Не удалось открыть изображение');
      return;
    }

    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      _showMessage('Файл изображения повреждён или не поддерживается');
      return;
    }

    setState(() {
      _originalBytes = bytes;
      _processedBytes = bytes;
      _fileName = selected.name;
      _sourcePath = selected.path;
      _imageWidth = decoded.width;
      _imageHeight = decoded.height;

      _correction = CorrectionState.zero;
      _history
        ..clear()
        ..add(CorrectionState.zero);

      _historyIndex = 0;
      _showOriginal = false;
    });

    _showMessage('Изображение загружено');
  }

  Future<void> _openProject() async {
    if (_openingProject) {
      return;
    }

    setState(() {
      _openingProject = true;
    });

    try {
      final project = await ProjectService.openProject();

      if (project == null) {
        return;
      }

      Uint8List? bytes;

      if (project.sourcePath != null) {
        final file = File(project.sourcePath!);

        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

      if (bytes == null) {
        _showMessage(
          'Проект открыт, но исходное изображение не найдено',
        );

        setState(() {
          _fileName = project.fileName;
          _sourcePath = project.sourcePath;
          _imageWidth = project.width;
          _imageHeight = project.height;

          _correction = CorrectionState(
            cyan: project.cyan,
            magenta: project.magenta,
            yellow: project.yellow,
            black: project.black,
          );

          _history
            ..clear()
            ..add(_correction);

          _historyIndex = 0;
        });

        return;
      }

      final decoded = img.decodeImage(bytes);

      setState(() {
        _originalBytes = bytes;
        _processedBytes = bytes;

        _fileName = project.fileName;
        _sourcePath = project.sourcePath;

        _imageWidth = decoded?.width ?? project.width;
        _imageHeight = decoded?.height ?? project.height;

        _correction = CorrectionState(
          cyan: project.cyan,
          magenta: project.magenta,
          yellow: project.yellow,
          black: project.black,
        );

        _history
          ..clear()
          ..add(_correction);

        _historyIndex = 0;
        _showOriginal = false;
      });

      await _applyCorrection();

      _showMessage('Проект открыт');
    } finally {
      if (mounted) {
        setState(() {
          _openingProject = false;
        });
      }
    }
  }  Future<void> _saveProject() async {
    if (_fileName == null ||
        _imageWidth == null ||
        _imageHeight == null) {
      _showMessage('Сначала откройте изображение');
      return;
    }

    if (_savingProject) {
      return;
    }

    setState(() {
      _savingProject = true;
    });

    try {
      final project = PrintProject(
        fileName: _fileName!,
        sourcePath: _sourcePath,
        width: _imageWidth!,
        height: _imageHeight!,
        cyan: _correction.cyan,
        magenta: _correction.magenta,
        yellow: _correction.yellow,
        black: _correction.black,
        createdAt: DateTime.now(),
      );

      final saved = await ProjectService.saveProject(project);

      if (saved) {
        _showMessage('Проект сохранён');
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingProject = false;
        });
      }
    }
  }

  Future<void> _applyCorrection() async {
    if (_originalBytes == null) {
      return;
    }

    setState(() {
      _processing = true;
    });

    final result = CmykProcessor.apply(
      _originalBytes!,
      cyan: _correction.cyan,
      magenta: _correction.magenta,
      yellow: _correction.yellow,
      black: _correction.black,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _processedBytes = result;
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

    if (next.cyan == _correction.cyan &&
        next.magenta == _correction.magenta &&
        next.yellow == _correction.yellow &&
        next.black == _correction.black) {
      return;
    }

    setState(() {
      _correction = next;

      if (_historyIndex < _history.length - 1) {
        _history.removeRange(
          _historyIndex + 1,
          _history.length,
        );
      }

      _history.add(next);
      _historyIndex = _history.length - 1;
    });

    await _applyCorrection();
  }

  Future<void> _undo() async {
    if (_historyIndex <= 0) {
      return;
    }

    setState(() {
      _historyIndex--;
      _correction = _history[_historyIndex];
    });

    await _applyCorrection();
  }

  Future<void> _redo() async {
    if (_historyIndex >= _history.length - 1) {
      return;
    }

    setState(() {
      _historyIndex++;
      _correction = _history[_historyIndex];
    });

    await _applyCorrection();
  }

  Future<void> _reset() async {
    await _changeCmyk(
      cyan: 0,
      magenta: 0,
      yellow: 0,
      black: 0,
    );
  }

  Future<void> _resetCyan() async {
    await _changeCmyk(cyan: 0);
  }

  Future<void> _resetMagenta() async {
    await _changeCmyk(magenta: 0);
  }

  Future<void> _resetYellow() async {
    await _changeCmyk(yellow: 0);
  }

  Future<void> _resetBlack() async {
    await _changeCmyk(black: 0);
  }

  Future<void> _saveImage() async {
    if (_processedBytes == null || _fileName == null) {
      _showMessage('Сначала откройте изображение');
      return;
    }

    final baseName = _fileName!.contains('.')
        ? _fileName!.substring(
            0,
            _fileName!.lastIndexOf('.'),
          )
        : _fileName!;

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export corrected image',
      fileName: '${baseName}_corrected.png',
      type: FileType.custom,
      allowedExtensions: ['png'],
    );

    if (path == null || path.isEmpty) {
      return;
    }

    await File(path).writeAsBytes(
      _processedBytes!,
      flush: true,
    );

    _showMessage('Изображение экспортировано');
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: const Border(
          bottom: BorderSide(
            color: Colors.white12,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.colorize,
            size: 28,
          ),
          const SizedBox(width: 10),
          const Text(
            'Print Color Studio',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 28),
          IconButton(
            tooltip: 'Undo',
            onPressed: _historyIndex > 0 ? _undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed:
                _historyIndex < _history.length - 1 ? _redo : null,
            icon: const Icon(Icons.redo),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _openingProject ? null : _openProject,
            icon: const Icon(Icons.folder_open),
            label: const Text('Open Project'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _savingProject ? null : _saveProject,
            icon: const Icon(Icons.save),
            label: const Text('Save Project'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _openImage,
            icon: const Icon(Icons.image),
            label: const Text('Open Image'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _processedBytes == null ? null : _saveImage,
            icon: const Icon(Icons.download),
            label: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_originalBytes == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white12,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_outlined,
                size: 72,
                color: Colors.white38,
              ),
              SizedBox(height: 18),
              Text(
                'Open an image to begin',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'PNG, JPG, JPEG and other supported formats',
                style: TextStyle(
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bytes = _showOriginal
        ? _originalBytes!
        : (_processedBytes ?? _originalBytes!);

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.1,
              maxScale: 8,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          if (_processing)
            const Positioned(
              top: 12,
              right: 12,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
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
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: const Border(
          left: BorderSide(
            color: Colors.white12,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CMYK Correction',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Adjust print colors',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 24),
            CmykChannelControl(
              label: 'Cyan',
              value: _correction.cyan,
              color: Colors.cyan,
              onChanged: (value) {
                _changeCmyk(cyan: value);
              },
              onReset: _resetCyan,
            ),
            const SizedBox(height: 18),
            CmykChannelControl(
              label: 'Magenta',
              value: _correction.magenta,
              color: Colors.pink,
              onChanged: (value) {
                _changeCmyk(magenta: value);
              },
              onReset: _resetMagenta,
            ),
            const SizedBox(height: 18),
            CmykChannelControl(
              label: 'Yellow',
              value: _correction.yellow,
              color: Colors.yellow,
              onChanged: (value) {
                _changeCmyk(yellow: value);
              },
              onReset: _resetYellow,
            ),
            const SizedBox(height: 18),
            CmykChannelControl(
              label: 'Black',
              value: _correction.black,
              color: Colors.black,
              onChanged: (value) {
                _changeCmyk(black: value);
              },
              onReset: _resetBlack,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset All Channels'),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 18),
            const Text(
              'Preview',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Original'),
              subtitle: const Text(
                'Compare original and corrected image',
              ),
              value: _showOriginal,
              onChanged: _originalBytes == null
                  ? null
                  : (value) {
                      setState(() {
                        _showOriginal = value;
                      });
                    },
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 18),
            const Text(
              'File Information',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow(
              'File',
              _fileName ?? 'No image',
            ),
            _infoRow(
              'Size',
              _imageWidth != null && _imageHeight != null
                  ? '${_imageWidth!} × ${_imageHeight!} px'
                  : '—',
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 14),
            _buildStatusRow(),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 55,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        Expanded(
          child: _statusValue(
            'C',
            _correction.cyan,
          ),
        ),
        Expanded(
          child: _statusValue(
            'M',
            _correction.magenta,
          ),
        ),
        Expanded(
          child: _statusValue(
            'Y',
            _correction.yellow,
          ),
        ),
        Expanded(
          child: _statusValue(
            'K',
            _correction.black,
          ),
        ),
      ],
    );
  }

  Widget _statusValue(String label, double value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${value >= 0 ? '+' : ''}${value.toStringAsFixed(0)}%',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: _buildPreview(),
                    ),
                  ),
                  _buildControls(),
                ],
              ),
            ),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white12,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Print Color Studio',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white38,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _processing
                        ? 'Processing...'
                        : _originalBytes == null
                            ? 'Ready'
                            : 'Ready',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
