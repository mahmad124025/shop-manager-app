import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'calculator_overlay.dart';

const List<String> kSecurityQuestions = [
  'What was the name of your first pet? — آپ کے پہلے پالتو جانور کا نام کیا تھا؟',
  'What is the name of the street you grew up on? — جس گلی میں آپ پلے بڑھے اس کا نام کیا ہے؟',
  'What was your childhood best friend\'s name? — بچپن کے بہترین دوست کا نام کیا تھا؟',
  'What is your father\'s middle name (or a name only you know)? — آپ کے والد کا درمیانی نام؟',
  'What was the make/model of your first vehicle? — آپ کی پہلی گاڑی کا ماڈل کیا تھا؟',
  'What is the name of your primary school? — آپ کے پرائمری سکول کا نام؟',
];

class PinLockScreen extends StatefulWidget {
  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final Color screenColor = Color(0xFF00838F);
  final LocalAuthentication _auth = LocalAuthentication();
  String _enteredPin = '';
  String? _savedPin;
  bool _isSettingPin = false;
  String _firstPin = '';
  String _errorText = '';
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  bool _needsSecuritySetup = false;
  String? _chosenQuestion;
  final _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Calculator must stay OFF while this PIN screen is showing.
    CalculatorVisibility.visible.value = false;
    _loadPin();
    _checkBiometric();
  }

  Future<void> _loadPin() async {
    final prefs = await SharedPreferences.getInstance();
    String? pin = prefs.getString('app_pin');
    setState(() {
      _savedPin = pin;
      _isSettingPin = pin == null || pin.isEmpty;
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    });
  }

  Future<void> _checkBiometric() async {
    try {
      bool canCheck = await _auth.canCheckBiometrics;
      bool isSupported = await _auth.isDeviceSupported();
      setState(() => _biometricAvailable = canCheck && isSupported);
      // Only auto-prompt if user has enabled biometric in Settings AND already has a PIN set.
      if (_biometricAvailable && _biometricEnabled && !_isSettingPin) {
        _tryBiometric();
      }
    } catch (e) {
      setState(() => _biometricAvailable = false);
    }
  }

  Future<void> _tryBiometric() async {
    try {
      bool authenticated = await _auth.authenticate(
        localizedReason: 'Unlock Shop Manager — دکان منیجر کھولیں',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (authenticated) _goHome();
    } catch (e) {
      // fingerprint/face failed/cancelled — user can still use PIN
    }
  }

  void _goHome() {
    CalculatorVisibility.visible.value = true;
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _onDigit(String digit) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += digit;
      _errorText = '';
    });
    if (_enteredPin.length == 4) {
      Future.delayed(Duration(milliseconds: 150), () => _handleComplete());
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
  }

  Future<void> _handleComplete() async {
    if (_isSettingPin) {
      if (_firstPin.isEmpty) {
        setState(() {
          _firstPin = _enteredPin;
          _enteredPin = '';
          _errorText = '';
        });
      } else {
        if (_firstPin == _enteredPin) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('app_pin', _enteredPin);
          await prefs.setBool('pin_enabled', true);

          String? existingQuestion = prefs.getString('security_question');
          if (existingQuestion == null || existingQuestion.isEmpty) {
            setState(() {
              _needsSecuritySetup = true;
              _errorText = '';
            });
          } else {
            _goHome();
          }
        } else {
          setState(() {
            _errorText = 'PINs did not match. Try again — دوبارہ کوشش کریں';
            _firstPin = '';
            _enteredPin = '';
          });
        }
      }
    } else {
      if (_enteredPin == _savedPin) {
        _goHome();
      } else {
        setState(() {
          _errorText = 'Wrong PIN — غلط پن';
          _enteredPin = '';
        });
      }
    }
  }

  Future<void> _saveSecuritySetup() async {
    if (_chosenQuestion == null || _answerController.text.trim().isEmpty) {
      setState(() => _errorText = 'Please choose a question and answer it — سوال منتخب کریں اور جواب دیں');
      return;
    }
    if (_answerController.text.trim().length < 3) {
      setState(() => _errorText = 'Answer must be at least 3 characters — کم از کم 3 حروف کا جواب دیں');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('security_question', _chosenQuestion!);
    await prefs.setString('security_answer', _answerController.text.trim().toLowerCase());
    _goHome();
  }

  // ── FORGOT PIN FLOW ──
  // The security question is the ONLY way to reset the PIN from this screen.
  // If the user gets it wrong / doesn't remember it, nothing here can bypass
  // the lock — no "Clear Data" shortcut lives on this screen. That has to be
  // a deliberate action taken from the device's own Android Settings app,
  // which no casual/unauthorized person would stumble into by accident.
  void _showForgotPinFlow() async {
    final prefs = await SharedPreferences.getInstance();
    String? question = prefs.getString('security_question');
    String? answer = prefs.getString('security_answer');

    if (question == null || answer == null) {
      _showCannotRecoverDialog();
      return;
    }

    final answerController = TextEditingController();
    bool verified = false;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Security Check — حفاظتی سوال', style: TextStyle(color: screenColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: TextStyle(color: Colors.black87, fontSize: 14)),
            SizedBox(height: 12),
            TextField(
              controller: answerController,
              decoration: InputDecoration(
                labelText: 'Your Answer — آپ کا جواب',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: screenColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: screenColor)),
              ),
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showCannotRecoverDialog();
              },
              child: Text("I don't remember the answer — یاد نہیں", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () {
              if (answerController.text.trim().toLowerCase() == answer) {
                verified = true;
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Incorrect answer — غلط جواب'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: Text('Verify', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (verified) {
      await _showResetPinAfterVerification();
    }
  }

  // Purely informational. No button here does anything destructive or
  // bypasses the lock — the user must go to Android Settings themselves.
  Future<void> _showCannotRecoverDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Cannot Recover PIN — پن بازیافت ممکن نہیں', style: TextStyle(color: Colors.redAccent)),
        content: Text(
          'For security reasons, the PIN cannot be recovered without correctly answering your security question. This protects your business data from unauthorized access.\n\n'
          'If you are the shop owner and have completely forgotten both, the only remaining option is to clear the app\'s data from your device\'s own Settings app (Settings → Apps → Shop Manager → Clear Data). This will permanently erase ALL data — inventory, sales, customers, everything.\n\n'
          'حفاظتی وجوہات کی بنا پر، درست جواب کے بغیر پن بازیافت نہیں ہو سکتا۔ اگر آپ مکمل طور پر بھول گئے ہیں تو صرف فون کی سیٹنگز سے ایپ کا ڈیٹا صاف کرنا ہی واحد راستہ ہے، جس سے تمام معلومات ہمیشہ کے لیے ختم ہو جائیں گی۔',
          style: TextStyle(color: Colors.black87, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Understood — سمجھ گیا', style: TextStyle(color: screenColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetPinAfterVerification() async {
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Set New PIN — نیا پن', style: TextStyle(color: screenColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: InputDecoration(labelText: 'New PIN — نیا پن (4 digits)'),
            ),
            TextField(
              controller: confirmPinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Confirm New PIN — تصدیق کریں'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () async {
              if (newPinController.text.length != 4 || newPinController.text != confirmPinController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('PINs must be 4 digits and match!'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('app_pin', newPinController.text);
              Navigator.pop(context);
              setState(() {
                _savedPin = newPinController.text;
                _enteredPin = '';
                _errorText = '';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('PIN reset! Enter your new PIN — نیا پن درج کریں'), backgroundColor: Colors.green),
              );
            },
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_needsSecuritySetup) {
      return _buildSecuritySetupScreen();
    }

    String title = _isSettingPin
        ? (_firstPin.isEmpty ? 'Set a PIN — پن سیٹ کریں' : 'Confirm PIN — پن دوبارہ درج کریں')
        : 'Enter PIN — پن درج کریں';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              SizedBox(height: 30),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(color: screenColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.lock, color: screenColor, size: 48),
              ),
              SizedBox(height: 20),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              SizedBox(height: 8),
              if (_errorText.isNotEmpty)
                Text(_errorText, style: TextStyle(color: Colors.redAccent, fontSize: 13)),
              SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  bool filled = i < _enteredPin.length;
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 8),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? screenColor : Colors.transparent,
                      border: Border.all(color: screenColor, width: 2),
                    ),
                  );
                }),
              ),

              SizedBox(height: 30),

              _buildNumberGrid(),

              SizedBox(height: 16),

              if (_biometricAvailable && _biometricEnabled && !_isSettingPin)
                TextButton.icon(
                  onPressed: _tryBiometric,
                  icon: Icon(Icons.fingerprint, color: screenColor),
                  label: Text('Use Fingerprint / Face — فنگر پرنٹ / فیس استعمال کریں', style: TextStyle(color: screenColor)),
                ),

              if (!_isSettingPin)
                TextButton(
                  onPressed: _showForgotPinFlow,
                  child: Text('Forgot PIN? — پن بھول گئے؟',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberGrid() {
    List<List<String>> rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((k) {
              if (k == '') {
                return SizedBox(width: 70, height: 70);
              }
              return GestureDetector(
                onTap: () {
                  if (k == 'back') {
                    _onBackspace();
                  } else {
                    _onDigit(k);
                  }
                },
                child: Container(
                  width: 70,
                  height: 70,
                  margin: EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade100),
                  alignment: Alignment.center,
                  child: k == 'back'
                      ? Icon(Icons.backspace_outlined, color: Colors.black54)
                      : Text(k, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black87)),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSecuritySetupScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Icon(Icons.shield, color: screenColor, size: 48),
              SizedBox(height: 16),
              Text('Set a Security Question — حفاظتی سوال سیٹ کریں',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              SizedBox(height: 4),
              Text('This helps you recover your PIN if you forget it — یہ آپ کو پن بھولنے پر مدد کرے گا',
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
              SizedBox(height: 20),
              if (_errorText.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(_errorText, style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              ...kSecurityQuestions.map((q) => RadioListTile<String>(
                    value: q,
                    groupValue: _chosenQuestion,
                    activeColor: screenColor,
                    title: Text(q, style: TextStyle(fontSize: 13, color: Colors.black87)),
                    onChanged: (val) => setState(() => _chosenQuestion = val),
                  )),
              SizedBox(height: 12),
              TextField(
                controller: _answerController,
                decoration: InputDecoration(
                  labelText: 'Your Answer — آپ کا جواب',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: screenColor, padding: EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _saveSecuritySetup,
                  child: Text('Save & Continue — محفوظ کریں', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}