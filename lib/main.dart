import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/ljod_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: LjodApp(),
    ),
  );
}

class LjodApp extends StatelessWidget {
  const LjodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ljod',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: LjodTheme.darkTheme,
      home: const LibraryScreenStub(),
    );
  }
}

class LibraryScreenStub extends StatelessWidget {
  const LibraryScreenStub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ljod Library (Flutter Rewrite)'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 64, color: Colors.deepPurpleAccent),
            const SizedBox(height: 16),
            const Text(
              'Modular, Secure & High Performance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Rewrite in progress...',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
