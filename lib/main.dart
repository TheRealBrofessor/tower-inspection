import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/schema/schema_loader.dart';
import 'data/database.dart';
import 'data/inspection_repository.dart';
import 'domain/models.dart';
import 'features/inspections/inspection_bloc.dart';
import 'features/inspections/inspection_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final template = await SchemaLoader().load();
  final repository = InspectionRepository(AppDatabase());
  runApp(MyApp(template: template, repository: repository));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.template, required this.repository});

  final InspectionTemplate template;
  final InspectionRepository repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          InspectionBloc(template: template, repository: repository)
            ..initialize(),
      child: MaterialApp(
        title: 'Tower Inspection',
        debugShowCheckedModeBanner: false,
        theme: _theme,
        home: const InspectionListScreen(),
      ),
    );
  }
}

final ThemeData _theme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B2D45),
    primary: const Color(0xFF0B2D45),
    secondary: const Color(0xFFF2A900),
    surface: Colors.white,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFF3F6F7),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0B2D45),
    foregroundColor: Colors.white,
    centerTitle: false,
  ),
  cardTheme: const CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      side: BorderSide(color: Color(0xFFD4DDE2)),
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF0B2D45),
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF0B2D45),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  ),
  chipTheme: const ChipThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
    selectedColor: Color(0xFFFFD66B),
    side: BorderSide(color: Color(0xFFAAB8C0)),
  ),
);
