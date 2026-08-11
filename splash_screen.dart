import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'calculator_overlay.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Calculator bubble OFF while checking PIN status.
    CalculatorVisibility.visible.value = false;

    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    bool pinEnabled = prefs.getBool('pin_enabled') ?? false;

    // Keep the NATIVE splash (icon + "Shop Manager" + tagline) visible for
    // 3.5 seconds total before removing it and moving to the next screen.
    await Future.delayed(Duration(milliseconds: 3500));

    // Now dismiss the native splash — this is what actually controls its duration.
    FlutterNativeSplash.remove();

    if (!mounted) return;

    if (pinEnabled) {
      // Calculator stays OFF — PinLockScreen turns it ON only after unlock.
      Navigator.pushReplacementNamed(context, '/pin');
    } else {
      CalculatorVisibility.visible.value = true;
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // This is never actually visible — FlutterNativeSplash keeps the native
    // splash on top of this until we explicitly call remove() above.
    return Scaffold(
      backgroundColor: Color(0xFF0A1628),
      body: SizedBox.shrink(),
    );
  }
}