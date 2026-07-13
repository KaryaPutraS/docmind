// ============================================================
// DocMind Flutter — App entry point with Bottom Navigation
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'providers/document_providers.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

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
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF4F6EF7).withOpacity(0.1);
              }
              return null;
            }),
          ),
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
                  Icon(Icons.error_outline,
                      size: 48, color: Colors.red.shade300),
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
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        };
        return child!;
      },
      home: const MainShell(),
    );
  }
}

/// Root shell with bottom navigation bar.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(bottomNavIndexProvider);

    final screens = const [
      HomeScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: navIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (i) =>
            ref.read(bottomNavIndexProvider.notifier).state = i,
        backgroundColor: Colors.white,
        elevation: 2,
        indicatorColor: const Color(0xFF4F6EF7).withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded,
                color: Color(0xFF4F6EF7)),
            label: 'Documents',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded,
                color: Color(0xFF4F6EF7)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
