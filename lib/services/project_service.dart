import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../models/print_project.dart';

class ProjectService {
  static Future<bool> saveProject(PrintProject project) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Print Color Studio Project',
      fileName: '${_safeName(project.fileName)}.pcs',
      type: FileType.custom,
      allowedExtensions: ['pcs'],
    );

    if (path == null || path.isEmpty) {
      return false;
    }

    final file = File(path);
    final json = const JsonEncoder.withIndent('  ').convert(
      project.toJson(),
    );

    await file.writeAsString(
      json,
      encoding: utf8,
    );

    return true;
  }

  static Future<PrintProject?> openProject() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pcs'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final selected = result.files.single;

    String content;

    if (selected.bytes != null) {
      content = utf8.decode(selected.bytes!);
    } else if (selected.path != null) {
      content = await File(selected.path!).readAsString(
        encoding: utf8,
      );
    } else {
      return null;
    }

    try {
      final json = jsonDecode(content);

      if (json is! Map<String, dynamic>) {
        throw const FormatException('Invalid project format');
      }

      return PrintProject.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static String _safeName(String name) {
    var result = name.trim();

    if (result.isEmpty) {
      result = 'print_project';
    }

    result = result.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    if (result.toLowerCase().endsWith('.pcs')) {
      result = result.substring(
        0,
        result.length - 4,
      );
    }

    return result;
  }
}
