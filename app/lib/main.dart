import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'data/supabase_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.ensureInitialized();
  // Supabase realtime 구독 시작 → LiveData 로 흘려보냄.
  SupabaseService.instance.start();
  runApp(const SmartAIApp());
}

class SmartAIApp extends StatelessWidget {
  const SmartAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 스마트 교통 신호 제어 시스템',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AppShell(),
    );
  }
}
