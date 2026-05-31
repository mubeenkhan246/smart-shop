import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/app_providers.dart';
import 'database/local_database.dart';
import 'utils/formatters.dart';
import 'views/home_shell.dart';
import 'views/login_screen.dart';
import 'views/shop_selection_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = LocalDatabase();
  await database.initialize();
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const SmartShopApp(),
    ),
  );
}

class SmartShopApp extends ConsumerWidget {
  const SmartShopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final shop = ref.watch(selectedShopProvider);
    moneyFormat.setCurrency(shop?.currency ?? 'PKR');
    final seed = shop == null ? const Color(0xff0f766e) : Color(shop.themeSeed);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Shop',
      themeMode: ThemeMode.system,
      theme: _theme(seed, Brightness.light),
      darkTheme: _theme(seed, Brightness.dark),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: user == null
            ? const LoginScreen()
            : shop == null
            ? const ShopSelectionScreen()
            : const HomeShell(),
      ),
    );
  }

  ThemeData _theme(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
    );
  }
}
