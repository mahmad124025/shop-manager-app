import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'month_cycle_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Color screenColor = Color(0xFF546E7A); // matches Settings icon color on home screen
  final LocalAuthentication _auth = LocalAuthentication();
  final _shopNameController = TextEditingController();
  final _shopNameUrduController = TextEditingController();
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _shopName = '';
  String _shopNameUrdu = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometricAvailability();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shopName = prefs.getString('shop_name') ?? '';
      _shopNameUrdu = prefs.getString('shop_name_urdu') ?? '';
      _pinEnabled = prefs.getBool('pin_enabled') ?? false;
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _shopNameController.text = _shopName;
      _shopNameUrduController.text = _shopNameUrdu;
    });
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      bool canCheck = await _auth.canCheckBiometrics;
      bool isSupported = await _auth.isDeviceSupported();
      setState(() => _biometricAvailable = canCheck && isSupported);
    } catch (e) {
      setState(() => _biometricAvailable = false);
    }
  }

  // Restarts the app flow so the new security setting is enforced immediately —
  // routes back through the splash/PIN-check logic instead of just updating state.
  void _restartAppFlow() {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  Future<void> _togglePin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_pinEnabled) {
      await prefs.remove('app_pin'); // clear any old pin, force fresh setup
      await prefs.remove('security_question');
      await prefs.remove('security_answer');
      await prefs.setBool('pin_enabled', true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PIN enabled! Restarting app to set it up — ایپ دوبارہ شروع ہو رہی ہے'), backgroundColor: Colors.green),
      );
    } else {
      await prefs.setBool('pin_enabled', false);
      await prefs.remove('app_pin');
      await prefs.remove('security_question');
      await prefs.remove('security_answer');
      // If PIN is turned off, biometric can't work standalone in this app's flow.
      await prefs.setBool('biometric_enabled', false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PIN disabled! Restarting app — ایپ دوبارہ شروع ہو رہی ہے'), backgroundColor: Colors.orange),
      );
    }
    await Future.delayed(Duration(milliseconds: 600));
    _restartAppFlow();
  }

  Future<void> _toggleBiometric() async {
    if (!_pinEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enable PIN Lock first — پہلے پن لاک آن کریں'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (!_biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fingerprint/face is set up on this device — اس ڈیوائس پر بائیو میٹرک سیٹ نہیں ہے'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    bool newValue = !_biometricEnabled;

    if (newValue) {
      // Verify biometric works before turning it on.
      try {
        bool authenticated = await _auth.authenticate(
          localizedReason: 'Confirm your fingerprint/face to enable it — فنگر پرنٹ/فیس کی تصدیق کریں',
          options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
        );
        if (!authenticated) return;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not verify biometric — بائیو میٹرک کی تصدیق ناکام'), backgroundColor: Colors.redAccent),
        );
        return;
      }
    }

    await prefs.setBool('biometric_enabled', newValue);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newValue
            ? 'Fingerprint/Face Lock enabled! Restarting app — ایپ دوبارہ شروع ہو رہی ہے'
            : 'Fingerprint/Face Lock disabled! Restarting app — ایپ دوبارہ شروع ہو رہی ہے'),
        backgroundColor: newValue ? Colors.green : Colors.orange,
      ),
    );
    await Future.delayed(Duration(milliseconds: 600));
    _restartAppFlow();
  }

  Future<void> _showResetPinFlow() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedPin = prefs.getString('app_pin');
    if (savedPin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No PIN is set yet.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final oldPinController = TextEditingController();
    bool oldVerified = false;

    // Step 1: verify old PIN
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Enter Old PIN — پرانا پن', style: TextStyle(color: screenColor)),
        content: TextField(
          controller: oldPinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: InputDecoration(labelText: 'Old PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () {
              if (oldPinController.text == savedPin) {
                oldVerified = true;
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Wrong PIN!'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: Text('Verify', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (!oldVerified) return;

    // Step 2: enter new PIN + confirm
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool newSaved = false;

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
              decoration: InputDecoration(labelText: 'New PIN (4 digits)'),
            ),
            TextField(
              controller: confirmPinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Confirm New PIN'),
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
              await prefs.setString('app_pin', newPinController.text);
              newSaved = true;
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newSaved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PIN reset! Please enter your new PIN.'), backgroundColor: Colors.green),
      );
      Navigator.pushReplacementNamed(context, '/pin');
    }
  }

  Future<void> _clearAllData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Clear All Data?', style: TextStyle(color: Colors.redAccent)),
        content: Text(
          'This will delete ALL data!\nتمام ڈیٹا حذف ہو جائے گا!',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('items');
              await prefs.remove('sales');
              await prefs.remove('customers');
              await prefs.remove('expenses');
              await prefs.remove('suppliers');
              await prefs.remove('month_history');
              await prefs.remove('active_year');
              await prefs.remove('year_list');
              await prefs.remove('app_pin');
              await prefs.remove('pin_enabled');
              await prefs.remove('biometric_enabled');
              await prefs.remove('security_question');
              await prefs.remove('security_answer');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('All data cleared!'),
                    backgroundColor: Colors.redAccent),
              );
            },
            child: Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFECEFF1), // light blue-grey tint matching icon theme
      appBar: AppBar(
        backgroundColor: screenColor,
        title: Text('Settings — ترتیبات',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(children: [

          // Shop Name
          _buildSection(
            title: 'Shop Name — دکان کا نام',
            child: Column(children: [
              TextField(
                controller: _shopNameController,
                style: TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Enter shop name (English)...',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: screenColor)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: screenColor)),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _shopNameUrduController,
                style: TextStyle(color: Colors.black87),
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'اردو نام لکھیں...',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: screenColor)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: screenColor)),
                ),
              ),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: screenColor),
                  onPressed: _saveShopName,
                  child: Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ),

          SizedBox(height: 16),

          // PIN Lock
          _buildSection(
            title: 'PIN Lock — پن لاک',
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_pinEnabled ? 'PIN is Enabled ✅' : 'PIN is Disabled',
                        style: TextStyle(color: Colors.black87, fontSize: 14)),
                    Text(_pinEnabled ? 'Works on Android APK' : 'Enable for security',
                        style: TextStyle(color: Colors.black45, fontSize: 12)),
                  ]),
                  Switch(
                    value: _pinEnabled,
                    onChanged: (_) => _togglePin(),
                    activeColor: screenColor,
                  ),
                ],
              ),
              if (_pinEnabled) ...[
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: screenColor),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: Icon(Icons.lock_reset, color: screenColor),
                    label: Text('Reset PIN — پن دوبارہ سیٹ کریں', style: TextStyle(color: screenColor)),
                    onPressed: _showResetPinFlow,
                  ),
                ),
              ],
            ]),
          ),

          SizedBox(height: 16),

          // Fingerprint / Face Lock
          _buildSection(
            title: 'Fingerprint / Face Lock — فنگر پرنٹ / فیس لاک',
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_biometricEnabled ? 'Biometric is Enabled ✅' : 'Biometric is Disabled',
                          style: TextStyle(color: Colors.black87, fontSize: 14)),
                      Text(
                        !_biometricAvailable
                            ? 'No fingerprint/face set up on this device'
                            : (!_pinEnabled
                                ? 'Enable PIN Lock first — پہلے پن لاک آن کریں'
                                : 'Unlock instantly with fingerprint or face'),
                        style: TextStyle(color: Colors.black45, fontSize: 12),
                      ),
                    ]),
                  ),
                  Switch(
                    value: _biometricEnabled,
                    onChanged: (_biometricAvailable && _pinEnabled) ? (_) => _toggleBiometric() : null,
                    activeColor: screenColor,
                  ),
                ],
              ),
            ]),
          ),

          SizedBox(height: 16),

          // Month Cycle
          _buildSection(
            title: 'Month & Year Cycle — ماہانہ چکر',
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: screenColor,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(Icons.calendar_month, color: Colors.white),
                label: Text('Manage Month/Year — ماہ/سال',
                    style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MonthCycleScreen()),
                ),
              ),
            ),
          ),

          SizedBox(height: 16),

          // App Info
          _buildSection(
            title: 'App Info — ایپ کی معلومات',
            child: Column(children: [
              _infoRow('App Name', 'Shop Manager'),
              _infoRow('Version', '1.0.0'),
              _infoRow('Language', 'Urdu + English'),
              _infoRow('FIFO', 'Enabled ✅'),
            ]),
          ),

          SizedBox(height: 16),

          // Danger Zone
          _buildSection(
            title: 'Danger Zone — خطرناک',
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _clearAllData,
                child: Text('Clear All Data — تمام ڈیٹا حذف کریں',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),

          SizedBox(height: 30),
        ]),
      ),
    );
  }

  Future<void> _saveShopName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_name', _shopNameController.text);
    await prefs.setString('shop_name_urdu', _shopNameUrduController.text);
    setState(() {
      _shopName = _shopNameController.text;
      _shopNameUrdu = _shopNameUrduController.text;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shop name saved! ✅'), backgroundColor: Colors.green),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: screenColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: screenColor,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.black45, fontSize: 13)),
        Text(value, style: TextStyle(color: Colors.black87, fontSize: 13)),
      ]),
    );
  }
}