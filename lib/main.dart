import 'package:flutter/material.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const StudioHomePage(),
    );
  }
}

class StudioHomePage extends StatelessWidget {
  const StudioHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PRINT COLOR STUDIO',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open file',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.save),
            tooltip: 'Save',
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(12),
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
                      size: 80,
                      color: Colors.white38,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No image loaded',
                      style: TextStyle(
                        fontSize: 22,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Open a print file to begin',
                      style: TextStyle(
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 320,
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white12,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CMYK CORRECTION',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text('Cyan'),
                  Slider(
                    value: 0,
                    min: -100,
                    max: 100,
                    onChanged: null,
                  ),
                  Text('Magenta'),
                  Slider(
                    value: 0,
                    min: -100,
                    max: 100,
                    onChanged: null,
                  ),
                  Text('Yellow'),
                  Slider(
                    value: 0,
                    min: -100,
                    max: 100,
                    onChanged: null,
                  ),
                  Text('Black'),
                  Slider(
                    value: 0,
                    min: -100,
                    max: 100,
                    onChanged: null,
                  ),
                  Spacer(),
                  Divider(),
                  SizedBox(height: 12),
                  Text(
                    'STATUS: READY',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
