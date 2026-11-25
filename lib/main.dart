import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ui/core/caregiver_theme.dart';
import 'ui/view_models/caregiver_view_model.dart';
import 'ui/views/caregiver_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFF11161F),
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SecondSightCaregiverApp());
}

class SecondSightCaregiverApp extends StatefulWidget {
  final CaregiverViewModel? viewModel;

  const SecondSightCaregiverApp({super.key, this.viewModel});

  @override
  State<SecondSightCaregiverApp> createState() =>
      _SecondSightCaregiverAppState();
}

class _SecondSightCaregiverAppState extends State<SecondSightCaregiverApp> {
  late final CaregiverViewModel _vm;
  late final bool _ownsVm;

  @override
  void initState() {
    super.initState();
    _ownsVm = widget.viewModel == null;
    _vm = widget.viewModel ?? CaregiverViewModel();
    if (_ownsVm) {
      _vm.init();
    }
  }

  @override
  void dispose() {
    if (_ownsVm) {
      _vm.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecondSight Caregiver',
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi'),
      supportedLocales: const <Locale>[Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildCaregiverTheme(),
      home: CaregiverShell(vm: _vm),
    );
  }
}
