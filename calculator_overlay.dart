import 'package:flutter/material.dart';

// Global flag: calculator hidden until splash screen finishes.
class CalculatorVisibility {
  static final ValueNotifier<bool> visible = ValueNotifier<bool>(false);
}

class CalculatorOverlay extends StatefulWidget {
  final Widget child;
  const CalculatorOverlay({Key? key, required this.child}) : super(key: key);

  @override
  State<CalculatorOverlay> createState() => _CalculatorOverlayState();
}

class _CalculatorOverlayState extends State<CalculatorOverlay> {
  bool _open = false;
  Offset? _bubblePosition;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_bubblePosition == null) {
      double safeY = screenHeight - bottomPadding - 130;
      if (safeY < 60) safeY = 60;
      _bubblePosition = Offset(16, safeY);
    }

    return ValueListenableBuilder<bool>(
      valueListenable: CalculatorVisibility.visible,
      builder: (context, isVisible, _) {
        return Stack(
          children: [
            widget.child,

            if (isVisible)
              Positioned(
                left: _bubblePosition!.dx,
                top: _bubblePosition!.dy,
                child: GestureDetector(
                  onTap: () => setState(() => _open = !_open),
                  onPanUpdate: (details) {
                    setState(() {
                      double newX = _bubblePosition!.dx + details.delta.dx;
                      double newY = _bubblePosition!.dy + details.delta.dy;
                      newX = newX.clamp(0, screenWidth - 44);
                      newY = newY.clamp(0, screenHeight - 44);
                      _bubblePosition = Offset(newX, newY);
                    });
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF00838F),
                      boxShadow: [
                        BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Icon(_open ? Icons.close : Icons.calculate, color: Colors.white, size: 22),
                  ),
                ),
              ),

            if (isVisible && _open)
              Positioned(
                left: (_bubblePosition!.dx + 250 > screenWidth)
                    ? screenWidth - 246
                    : _bubblePosition!.dx,
                top: (_bubblePosition!.dy - 360 < 0)
                    ? _bubblePosition!.dy + 50
                    : _bubblePosition!.dy - 360,
                child: _CalculatorPanel(onClose: () => setState(() => _open = false)),
              ),
          ],
        );
      },
    );
  }
}

class _CalculatorPanel extends StatefulWidget {
  final VoidCallback onClose;
  const _CalculatorPanel({required this.onClose});

  @override
  State<_CalculatorPanel> createState() => _CalculatorPanelState();
}

class _CalculatorPanelState extends State<_CalculatorPanel> {
  String _expression = '';
  String _display = '0';
  bool _justEvaluated = false;

  void _onNumber(String num) {
    setState(() {
      if (_justEvaluated) {
        _expression = '';
        _display = '0';
        _justEvaluated = false;
      }
      if (_display == '0') {
        _display = num;
      } else {
        _display += num;
      }
    });
  }

  void _onDecimal() {
    setState(() {
      if (_justEvaluated) {
        _expression = '';
        _display = '0.';
        _justEvaluated = false;
      } else if (!_display.contains('.')) {
        _display += '.';
      }
    });
  }

  void _onOperator(String op) {
    setState(() {
      _justEvaluated = false;
      _expression += '$_display $op ';
      _display = '0';
    });
  }

  void _onPercent() {
    setState(() {
      double val = double.tryParse(_display) ?? 0;
      double percentVal = val / 100;
      _display = percentVal % 1 == 0 ? percentVal.toStringAsFixed(0) : percentVal.toStringAsFixed(4);
    });
  }

  void _onEquals() {
    setState(() {
      String fullExpr = _expression + _display;
      double result = _evaluate(fullExpr);
      _expression = '$fullExpr =';
      _display = result % 1 == 0 ? result.toStringAsFixed(0) : result.toStringAsFixed(2);
      _justEvaluated = true;
    });
  }

  double _evaluate(String expr) {
    List<String> tokens = expr.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty) return 0;
    double result = double.tryParse(tokens[0]) ?? 0;
    int i = 1;
    while (i < tokens.length - 1) {
      String op = tokens[i];
      double next = double.tryParse(tokens[i + 1]) ?? 0;
      switch (op) {
        case '+':
          result += next;
          break;
        case '-':
          result -= next;
          break;
        case '×':
          result *= next;
          break;
        case '÷':
          result = next == 0 ? 0 : result / next;
          break;
      }
      i += 2;
    }
    return result;
  }

  void _onClear() {
    setState(() {
      _expression = '';
      _display = '0';
      _justEvaluated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 230,
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: Color(0xFF0A1628), borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Calculator', style: TextStyle(color: Color(0xFF00BCD4), fontWeight: FontWeight.bold, fontSize: 13)),
                GestureDetector(onTap: widget.onClose, child: Icon(Icons.close, color: Colors.white54, size: 18)),
              ],
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Color(0xFF0D1F3C), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_expression.isNotEmpty)
                    Text(
                      _expression,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  SizedBox(height: 4),
                  Text(_display, textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            SizedBox(height: 8),
            _buildRow(['7', '8', '9', '÷']),
            SizedBox(height: 6),
            _buildRow(['4', '5', '6', '×']),
            SizedBox(height: 6),
            _buildRow(['1', '2', '3', '-']),
            SizedBox(height: 6),
            _buildRow(['C', '0', '.', '+']),
            SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: _onPercent,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                      child: Text('%', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF00BCD4), padding: EdgeInsets.symmetric(vertical: 12)),
                    onPressed: _onEquals,
                    child: Text('=', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      children: keys.map((k) {
        bool isOp = ['÷', '×', '-', '+'].contains(k);
        bool isClear = k == 'C';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () {
                if (isClear) {
                  _onClear();
                } else if (isOp) {
                  _onOperator(k);
                } else if (k == '.') {
                  _onDecimal();
                } else {
                  _onNumber(k);
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isOp ? Color(0xFF00BCD4) : isClear ? Colors.redAccent : Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(k, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}