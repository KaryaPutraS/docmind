// ============================================================
// DocMind Flutter — App entry point
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  timeago.setLocaleMessages('id', timeago.IdMessages());
  runApp(
    const ProviderScope(
      child: DocMindApp(),
    ),
  );
}

class DocMindApp extends StatelessWidget {
  const DocMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4F6EF7),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FC),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      builder: (context, child) {
        ErrorWidget.builder = (errorDetails) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    errorDetails.exceptionAsString().length > 200
                        ? '${errorDetails.exceptionAsString().substring(0, 200)}...'
                        : errorDetails.exceptionAsString(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        };
        return child!;
      },
      home: const HomeScreen(),
    );
  }
}
