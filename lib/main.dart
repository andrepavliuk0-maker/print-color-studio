import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'models/correction_state.dart';
import 'models/print_project.dart';
import 'services/cmyk_processor.dart';
import 'services/project_service.dart';

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
        colorSchemeSeed: Colors.blue,
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

    final file = result.files.single;

    Uint8List? bytes = file.bytes;

    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }

    if (bytes == null) {
      _showMessage('Не удалось прочитать изображение.');
      return;
    }

    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      _showMessage('Файл не является поддерживаемым изображением.');
      return;
    }

    setState(() {
      _originalBytes = bytes;
      _processedBytes = bytes;
      _fileName = file.name;
      _sourcePath = file.path;
      _imageWidth = decoded.width;
      _imageHeight = decoded.height;

      _correction = CorrectionState.zero;

      _history
        ..clear()
        ..add(CorrectionState.zero);

      _historyIndex = 0;
      _showOriginal = false;
    });
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
        _showMessage('Не удалось открыть проект.');
        return;
      }

      Uint8List? imageBytes;

      if (project.sourcePath != null &&
          project.sourcePath!.isNotEmpty) {
        final sourceFile = File(project.sourcePath!);

        if (await sourceFile.exists()) {
          imageBytes = await sourceFile.readAsBytes();
        }
      }

      if (imageBytes == null) {
        _showMessage(
          'Проект открыт, но исходное изображение не найдено.\n'
          'Путь к файлу: ${project.sourcePath ?? "не указан"}',
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

      final decoded = img.decodeImage(imageBytes);

      if (decoded == null) {
        _showMessage('Исходное изображение повреждено.');
        return;
      }

      final correction = CorrectionState(
        cyan: project.cyan,
        magenta: project.magenta,
        yellow: project.yellow,
        black: project.black,
      );

      setState(() {
        _originalBytes = imageBytes;
        _fileName = project.fileName;
        _sourcePath = project.sourcePath;
        _imageWidth = decoded.width;
        _imageHeight = decoded.height;

        _correction = correction;

        _history
          ..clear()
          ..add(correction);

        _historyIndex = 0;
        _showOriginal = false;
      });

      await _applyCorrection(
        correction,
        addToHistory: false,
      );

      _showMessage('Проект открыт.');
    } finally {
      if (mounted) {
        setState(() {
          _openingProject = false;
        });
      }
    }
  }

  Future<void> _saveProject() async {
    if (_fileName == null ||
        _imageWidth == null ||
        _imageHeight == null) {
      _showMessage('Сначала откройте изображение.');
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
        _showMessage('Проект сохранён.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingProject = false;
        });
      }
    }
  }

  Future<void> _applyCorrection(
    CorrectionState correction, {
    bool addToHistory = true,
  }) async {
    if (_originalBytes == null) {
      return;
    }

    setState(() {
      _processing = true;
    });

    final result = await Future<Uint8List?>(() {
      return CmykProcessor.apply(
        _originalBytes!,
        cyan: correction.cyan,
        magenta: correction.magenta,
        yellow: correction.yellow,
        black: correction.black,
      );
    });

    if (!mounted) {
      return;
    }

    if (result != null) {
      setState(() {
        _processedBytes = result;
        _correction = correction;

        if (addToHistory) {
          if (_historyIndex < _history.length - 1) {
            _history.removeRange(
              _historyIndex + 1,
              _history.length,
            );
          }

          _history.add(correction);
          _historyIndex = _history.length - 1;
        }

        _processing = false;
      });
    } else {
      setState(() {
        _processing = false;
      });

      _showMessage('Ошибка обработки изображения.');
    }
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
    if (_historyIndex <= 0 || _processing) {
      return;
    }

    final index = _historyIndex - 1;
    final correction = _history[index];

    setState(() {
      _historyIndex = index;
    });

    await _applyCorrection(
      correction,
      addToHistory: false,
    );
  }

  Future<void> _redo() async {
    if (_historyIndex >= _history.length - 1 ||
        _processing) {
      return;
    }

    final index = _historyIndex + 1;
    final correction = _history[index];

    setState(() {
      _historyIndex = index;
    });

    await _applyCorrection(
      correction,
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
      _showMessage('Сначала откройте изображение.');
      return;
    }

    final baseName = _fileName == null
        ? 'corrected_image'
        : _fileName!.replaceFirst(
            RegExp(r'\.[^.]+$'),
            '',
          );

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save corrected image',
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

    _showMessage('Изображение сохранено.');
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
        ),
      );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.print,
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
          const Spacer(),
          IconButton(
            tooltip: 'Undo',
            onPressed:
                _historyIndex > 0 && !_processing
                    ? _undo
                    : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed:
                _historyIndex < _history.length - 1 &&
                        !_processing
                    ? _redo
                    : null,
            icon: const Icon(Icons.redo),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed:
                _openingProject ? null : _openProject,
            icon: _openingProject
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.folder_open),
            label: const Text('Open Project'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed:
                _savingProject ? null : _saveProject,
            icon: _savingProject
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
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
            onPressed:
                _processedBytes == null
                    ? null
                    : _saveImage,
            icon: const Icon(Icons.download),
            label: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_originalBytes == null) {
      return Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 90,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 20),
            const Text(
              'Open an image to begin',
              style: TextStyle(
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PNG, JPG, JPEG and other supported formats',
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    final bytes = _showOriginal
        ? _originalBytes!
        : (_processedBytes ?? _originalBytes!);

    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 0.1,
            maxScale: 8,
            child: Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        if (_processing)
          const Positioned(
            top: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text('Processing...'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                value.toStringAsFixed(0),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(-100, 100),
          min: -100,
          max: 100,
          divisions: 200,
          onChanged: _processing
              ? null
              : onChanged,
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'CMYK Correction',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildSlider(
            label: 'Cyan',
            value: _correction.cyan,
            color: Colors.cyan,
            onChanged: (value) {
              _changeCmyk(cyan: value);
            },
          ),
          _buildSlider(
            label: 'Magenta',
            value: _correction.magenta,
            color: Colors.pink,
            onChanged: (value) {
              _changeCmyk(magenta: value);
            },
          ),
          _buildSlider(
            label: 'Yellow',
            value: _correction.yellow,
            color: Colors.yellow,
            onChanged: (value) {
              _changeCmyk(yellow: value);
            },
          ),
          _buildSlider(
            label: 'Black',
            value: _correction.black,
            color: Colors.grey.shade300,
            onChanged: (value) {
              _changeCmyk(black: value);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _processing ? null : _reset,
                  icon: const Icon(
                    Icons.restart_alt,
                  ),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Preview',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show original'),
            value: _showOriginal,
            onChanged: _originalBytes == null
                ? null
                : (value) {
                    setState(() {
                      _showOriginal = value;
                    });
                  },
          ),
          const SizedBox(height: 12),
          if (_fileName != null)
            Text(
              _fileName!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade400,
              ),
            ),
          if (_imageWidth != null &&
              _imageHeight != null)
            Padding(
              padding:
                  const EdgeInsets.only(top: 6),
              child: Text(
                '${_imageWidth} × $_imageHeight px',
                style: TextStyle(
                  color: Colors.grey.shade500,
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
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      clipBehavior:
                          Clip.antiAlias,
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF111111),
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white12,
                        ),
                      ),
                      child: _buildPreview(),
                    ),
                  ),
                  const VerticalDivider(
                    width: 1,
                  ),
                  _buildControls(),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Icon(
                    _originalBytes == null
                        ? Icons.circle_outlined
                        : Icons.check_circle,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _originalBytes == null
                        ? 'No image loaded'
                        : 'Image loaded',
                  ),
                  const Spacer(),
                  Text(
                    'C ${_correction.cyan.toStringAsFixed(0)}  '
                    'M ${_correction.magenta.toStringAsFixed(0)}  '
                    'Y ${_correction.yellow.toStringAsFixed(0)}  '
                    'K ${_correction.black.toStringAs
