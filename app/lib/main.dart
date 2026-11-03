import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/dict_db.dart';
import 'data/user_db.dart';
import 'screens/learn_home.dart';
import 'screens/notebook_home.dart';
import 'screens/search_screen.dart';
import 'screens/writing_home.dart';
import 'theme.dart';
import 'widgets/phone_frame.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const HanziApp());
}

class HanziApp extends StatelessWidget {
  const HanziApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Hán Tự',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (context, child) =>
            PhoneSimulatorFrame(child: child ?? const SizedBox.shrink()),
        home: const _Bootstrap(),
      );
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  String _status = 'Đang mở từ điển…';
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await DictDb.instance
          .init(onStatus: (s) => mounted ? setState(() => _status = s) : null);
      await UserDb.instance.init();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const HomeShell();
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('汉',
              style: TextStyle(
                  fontSize: 96,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          if (_error == null) ...[
            const SizedBox(
                width: 160,
                child: LinearProgressIndicator(color: AppColors.primary)),
            const SizedBox(height: 16),
            Text(_status, style: const TextStyle(color: AppColors.muted)),
          ] else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Lỗi khởi tạo: $_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error)),
            ),
        ]),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  final _notebook = GlobalKey<NotebookHomeState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        const SearchScreen(),
        const WritingHome(),
        const LearnHome(),
        NotebookHome(key: _notebook),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 3) _notebook.currentState?.refresh();
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.search_rounded), label: 'Tra cứu'),
          NavigationDestination(
              icon: Icon(Icons.draw_outlined),
              selectedIcon: Icon(Icons.draw_rounded),
              label: 'Luyện viết'),
          NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school_rounded),
              label: 'Học'),
          NavigationDestination(
              icon: Icon(Icons.bookmark_border_rounded),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: 'Sổ tay'),
        ],
      ),
    );
  }
}
