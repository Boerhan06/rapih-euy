import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'theme/app_theme.dart';
import 'views/main_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const RapihEuyApp(),
    ),
  );
}

class RapihEuyApp extends StatelessWidget {
  const RapihEuyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rapih Euy - Manajemen & Pembersih File',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainLayout(),
    );
  }
}
