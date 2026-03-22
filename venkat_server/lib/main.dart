import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';
import 'url_entry_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: kBg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const SysMonitorApp());
}

class SysMonitorApp extends StatelessWidget {
  const SysMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'venkat-server',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kGreen,
          secondary: kBlue,
          surface: kPanel,
        ),
        fontFamily: 'Courier',
        dividerColor: kBorder,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: kText, fontSize: 13),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(kBorder),
          radius: const Radius.circular(2),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: kGreen,
          linearTrackColor: Color(0x1000FFA0),
        ),
      ),
      home: const UrlEntryScreen(),
    );
  }
}
