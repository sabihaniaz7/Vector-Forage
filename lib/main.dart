// Vector Forge: 2D / 3D vector playground.
// No external packages. Replace lib/main.dart with this file and run.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: P.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const VectorForgeApp());
}

// ───────────────────────── Palette ─────────────────────────

class P {
  static const bg = Color(0xFF0C1317);
  static const surface = Color(0xFF111B21);
  static const surface2 = Color(0xFF16222A);
  static const line = Color(0xFF22323B);
  static const text = Color(0xFFEAF0F2);
  static const muted = Color(0xFF83959E);
  static const brass = Color(0xFFE0AE55); // vector A
  static const rose = Color(0xFFE27C9C); // vector B
  static const ice = Color(0xFFDDEBF1); // results
  static const ax = Color(0xFFC97B63);
  static const ay = Color(0xFF8DB58A);
  static const az = Color(0xFF7E9FD1);
}

Color al(Color c, double o) => c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

const _tab = [FontFeature.tabularFigures()];

String fmt(double v, {int d = 2, bool pretty = true, bool strip = true}) {
  var s = v.toStringAsFixed(d);
  if (strip && s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  if (s == '-0') s = '0';
  return pretty ? s.replaceFirst('-', '−') : s;
}

// ───────────────────────── Math ─────────────────────────

class V3 {
  final double x, y, z;
  const V3(this.x, this.y, this.z);
  static const zero = V3(0, 0, 0);
  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double k) => V3(x * k, y * k, z * k);
  double get len => math.sqrt(x * x + y * y + z * z);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
}

enum Op { add, sub, dot, cross }

extension OpX on Op {
  String get sym => switch (this) {
    Op.add => 'A + B',
    Op.sub => 'A − B',
    Op.dot => 'A · B',
    Op.cross => 'A × B',
  };
  String get label => switch (this) {
    Op.add => 'Add',
    Op.sub => 'Subtract',
    Op.dot => 'Dot',
    Op.cross => 'Cross',
  };
  String get title => switch (this) {
    Op.add => 'Addition',
    Op.sub => 'Subtraction',
    Op.dot => 'Dot product',
    Op.cross => 'Cross product',
  };
}

// ───────────────────────── App ─────────────────────────

class VectorForgeApp extends StatelessWidget {
  const VectorForgeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vector Forge',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: P.bg,
        colorScheme: const ColorScheme.dark(
          primary: P.brass,
          surface: P.surface,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const VectorForgePage(),
    );
  }
}

class VectorForgePage extends StatefulWidget {
  const VectorForgePage({super.key});
  @override
  State<VectorForgePage> createState() => _VectorForgePageState();
}

class _VectorForgePageState extends State<VectorForgePage> {
  Op _op = Op.add;
  bool _is3D = false;
  V3 _rawA = const V3(3, 4, 0);
  V3 _rawB = const V3(-2, 1.5, 0);
  bool _aOn = true, _bOn = true, _comp = false, _arc = true;

  double _zoom = 1;
  Offset _pan = Offset.zero;
  double _yaw = -0.62, _pitch = 0.38;

  late final List<TextEditingController> _ctl;
  Size _canvasSize = Size.zero;

  // gesture state
  int? _drag;
  double _baseZoom = 1;
  Offset _last = Offset.zero;
  int _lastCount = 1;

  V3 get _a => _is3D ? _rawA : V3(_rawA.x, _rawA.y, 0);
  V3 get _b => _is3D ? _rawB : V3(_rawB.x, _rawB.y, 0);
  bool get _both => _aOn && _bOn;

  double? get _theta {
    if (!_both) return null;
    final la = _a.len, lb = _b.len;
    if (la < 1e-9 || lb < 1e-9) return null;
    return math.acos((_a.dot(_b) / (la * lb)).clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  @override
  void initState() {
    super.initState();
    String t(double v) => fmt(v, d: 2, pretty: false);
    _ctl = [
      TextEditingController(text: t(_rawA.x)),
      TextEditingController(text: t(_rawA.y)),
      TextEditingController(text: t(_rawA.z)),
      TextEditingController(text: t(_rawB.x)),
      TextEditingController(text: t(_rawB.y)),
      TextEditingController(text: t(_rawB.z)),
    ];
  }

  @override
  void dispose() {
    for (final c in _ctl) {
      c.dispose();
    }
    super.dispose();
  }

  double _baseScale(Size s) =>
      (math.min(s.width, s.height) / 14).clamp(22.0, 64.0).toDouble();

  void _tick() => HapticFeedback.selectionClick();

  void _onField(int vec, int axis, String s) {
    final v = double.tryParse(s) ?? 0;
    setState(() {
      final c = vec == 0 ? _rawA : _rawB;
      final n = axis == 0
          ? V3(v, c.y, c.z)
          : axis == 1
          ? V3(c.x, v, c.z)
          : V3(c.x, c.y, v);
      if (vec == 0) {
        _rawA = n;
      } else {
        _rawB = n;
      }
    });
  }

  void _syncFields(int vec) {
    final v = vec == 0 ? _rawA : _rawB;
    _ctl[vec * 3].text = fmt(v.x, pretty: false);
    _ctl[vec * 3 + 1].text = fmt(v.y, pretty: false);
  }

  void _resetView() => setState(() {
    _zoom = 1;
    _pan = Offset.zero;
    _yaw = -0.62;
    _pitch = 0.38;
  });

  void _zoomBy(double k) =>
      setState(() => _zoom = (_zoom * k).clamp(0.4, 4.0).toDouble());

  // ───────────── gestures ─────────────

  void _onScaleStart(ScaleStartDetails d) {
    _baseZoom = _zoom;
    _last = d.localFocalPoint;
    _lastCount = d.pointerCount;
    _drag = null;
    if (!_is3D && d.pointerCount == 1) {
      final s = _baseScale(_canvasSize) * _zoom;
      final o = Offset(_canvasSize.width / 2, _canvasSize.height / 2) + _pan;
      double best = 36;
      for (var i = 0; i < 2; i++) {
        if (!(i == 0 ? _aOn : _bOn)) continue;
        final v = i == 0 ? _a : _b;
        final tip = Offset(o.dx + v.x * s, o.dy - v.y * s);
        final dist = (tip - d.localFocalPoint).distance;
        if (dist < best) {
          best = dist;
          _drag = i;
        }
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final delta = d.localFocalPoint - _last;
    _last = d.localFocalPoint;
    if (d.pointerCount != _lastCount) {
      _lastCount = d.pointerCount;
      _baseZoom = _zoom;
      if (d.pointerCount >= 2) _drag = null;
      return;
    }
    if (d.pointerCount >= 2) {
      setState(() {
        _zoom = (_baseZoom * d.scale).clamp(0.4, 4.0).toDouble();
        _pan += delta;
      });
    } else if (_drag != null) {
      final s = _baseScale(_canvasSize) * _zoom;
      final o = Offset(_canvasSize.width / 2, _canvasSize.height / 2) + _pan;
      final p = d.localFocalPoint;
      double snap(double v) =>
          ((v * 10).round() / 10).clamp(-50.0, 50.0).toDouble();
      final x = snap((p.dx - o.dx) / s);
      final y = snap(-(p.dy - o.dy) / s);
      setState(() {
        if (_drag == 0) {
          _rawA = V3(x, y, _rawA.z);
        } else {
          _rawB = V3(x, y, _rawB.z);
        }
        _syncFields(_drag!);
      });
    } else if (_is3D) {
      setState(() {
        _yaw += delta.dx * 0.008;
        _pitch = (_pitch + delta.dy * 0.006).clamp(-1.45, 1.45).toDouble();
      });
    } else {
      setState(() => _pan += delta);
    }
  }

  // ───────────── build ─────────────

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: P.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, box) {
            final w = box.maxWidth, h = box.maxHeight;
            final wide = w >= 760 || (w >= 600 && w > h * 1.2);
            if (wide) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _header(),
                          const SizedBox(height: 14),
                          _modeTabs(),
                          const SizedBox(height: 14),
                          Expanded(child: _canvasCard()),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: w >= 1100 ? 440 : 384,
                      child: SingleChildScrollView(child: _panel()),
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                children: [
                  if (!kb) ...[
                    _header(),
                    const SizedBox(height: 10),
                    _modeTabs(),
                    const SizedBox(height: 10),
                  ],
                  Expanded(child: _canvasCard()),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: h * (kb ? 0.55 : 0.36),
                    ),
                    child: SingleChildScrollView(child: _panel()),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF0C77E), Color(0xFFB07F36)],
              ),
            ),
            child: const Icon(
              Icons.north_east_rounded,
              color: Color(0xFF1B1507),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vector Forge',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: P.text,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                _op.title,
                style: const TextStyle(fontSize: 12, color: P.muted),
              ),
            ],
          ),
          const Spacer(),
          _dimSwitch(),
        ],
      ),
    );
  }

  Widget _dimSwitch() {
    Widget seg(String t, bool sel, bool to3D) => Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _tick();
          setState(() => _is3D = to3D);
        },
        child: Center(
          child: Text(
            t,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: sel ? P.brass : P.muted,
            ),
          ),
        ),
      ),
    );
    return Container(
      width: 116,
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: P.line),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: _is3D ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: al(P.brass, 0.16),
                  border: Border.all(color: al(P.brass, 0.55)),
                ),
              ),
            ),
          ),
          Row(children: [seg('2D', !_is3D, false), seg('3D', _is3D, true)]),
        ],
      ),
    );
  }

  Widget _modeTabs() {
    Widget tab(Op op) {
      final sel = _op == op;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            _tick();
            setState(() => _op = op);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 46,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: sel ? al(P.brass, 0.14) : P.surface,
              border: Border.all(color: sel ? al(P.brass, 0.6) : P.line),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    op.sym,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: sel ? P.brass : P.text,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  op.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: sel ? al(P.brass, 0.85) : P.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(children: [for (final o in Op.values) tab(o)]);
  }

  // ───────────── canvas ─────────────

  Widget _canvasCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: P.line),
        gradient: const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.05,
          colors: [Color(0xFF172830), Color(0xFF0B1216)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: LayoutBuilder(
          builder: (ctx, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            _canvasSize = size;
            final cam = _Cam(
              _is3D,
              size,
              _baseScale(size) * _zoom,
              _pan,
              _yaw,
              _pitch,
            );
            return Listener(
              onPointerSignal: (e) {
                if (e is PointerScrollEvent) {
                  _zoomBy(e.scrollDelta.dy > 0 ? 0.92 : 1.08);
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: (_) => _drag = null,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _VectorPainter(
                          cam: cam,
                          op: _op,
                          a: _a,
                          b: _b,
                          aOn: _aOn,
                          bOn: _bOn,
                          showComp: _comp,
                          showArc: _arc,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      top: 16,
                      width: math.max(80, size.width - 110),
                      child: IgnorePointer(child: _readout()),
                    ),
                    Positioned(right: 12, top: 12, child: _viewButtons()),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _vs(V3 v, {bool force3 = false}) => (_is3D || force3)
      ? '(${fmt(v.x)}, ${fmt(v.y)}, ${fmt(v.z)})'
      : '(${fmt(v.x)}, ${fmt(v.y)})';

  Widget _readout() {
    final a = _a, b = _b;
    String label, value;
    switch (_op) {
      case Op.add:
        label = 'Resultant, A + B';
        value = _both ? _vs(a + b) : '—';
      case Op.sub:
        label = 'Difference, A − B';
        value = _both ? _vs(a - b) : '—';
      case Op.dot:
        label = 'Dot product, A · B';
        value = _both ? fmt(a.dot(b), d: 3, strip: false) : '—';
      case Op.cross:
        label = 'Cross product, A × B';
        value = _both ? _vs(a.cross(b), force3: true) : '—';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: P.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w300,
              color: P.ice,
              fontFeatures: _tab,
            ),
          ),
        ),
        if (!_both) ...[
          const SizedBox(height: 4),
          Text(
            'Turn on both vectors to see the result',
            style: TextStyle(fontSize: 11.5, color: al(P.muted, 0.85)),
          ),
        ],
      ],
    );
  }

  Widget _viewButtons() {
    Widget btn(IconData i, VoidCallback f) => GestureDetector(
      onTap: f,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: al(P.bg, 0.8),
          border: Border.all(color: P.line),
        ),
        child: Icon(i, size: 19, color: P.text),
      ),
    );
    return btn(Icons.center_focus_strong_rounded, _resetView);
  }

  Widget _stats() {
    final a = _a, b = _b;
    final th = _theta;
    final tiles = <Widget>[
      _stat('|A|', _aOn ? a.len.toStringAsFixed(2) : '—', P.brass),
      _stat('|B|', _bOn ? b.len.toStringAsFixed(2) : '—', P.rose),
    ];
    switch (_op) {
      case Op.add:
        tiles.add(
          _stat('|R|', _both ? (a + b).len.toStringAsFixed(2) : '—', P.ice),
        );
      case Op.sub:
        tiles.add(
          _stat('|R|', _both ? (a - b).len.toStringAsFixed(2) : '—', P.ice),
        );
      case Op.cross:
        tiles.add(
          _stat(
            '|A × B|',
            _both ? a.cross(b).len.toStringAsFixed(2) : '—',
            P.ice,
          ),
        );
      case Op.dot:
        tiles.add(
          _stat(
            'B along A',
            _both && a.len > 1e-9 ? fmt(a.dot(b) / a.len, d: 2) : '—',
            P.ice,
          ),
        );
    }
    tiles.add(
      _stat('Angle', th != null ? '${th.toStringAsFixed(1)}°' : '—', P.ice),
    );
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }

  Widget _stat(String l, String v, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: P.surface2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: P.line),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            l,
            style: const TextStyle(
              fontSize: 11,
              color: P.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            v,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c,
              fontFeatures: _tab,
            ),
          ),
        ),
      ],
    ),
  );

  // ───────────── panel ─────────────

  Widget _panel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: P.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: P.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stats(),
          const SizedBox(height: 10),
          _vectorCard(0),
          const SizedBox(height: 10),
          _vectorCard(1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _toggleTile(
                  Icons.rule_rounded,
                  'Components',
                  _comp,
                  P.az,
                  () {
                    _tick();
                    setState(() => _comp = !_comp);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _toggleTile(
                  Icons.architecture_rounded,
                  'Arc',
                  _arc,
                  P.ice,
                  () {
                    _tick();
                    setState(() => _arc = !_arc);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _anglesCard(),
        ],
      ),
    );
  }

  Widget _vectorCard(int i) {
    final isA = i == 0;
    final color = isA ? P.brass : P.rose;
    final on = isA ? _aOn : _bOn;
    final eff = isA ? _a : _b;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        color: P.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: on ? al(color, 0.28) : P.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: on ? color : P.muted,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (on) BoxShadow(color: al(color, 0.6), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isA ? 'Vector A' : 'Vector B',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: P.text,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '|${isA ? 'A' : 'B'}| = ${eff.len.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: P.muted,
                  fontFeatures: _tab,
                ),
              ),
              const Spacer(),
              _PillSwitch(
                on: on,
                color: color,
                onTap: () {
                  _tick();
                  setState(() => isA ? _aOn = !_aOn : _bOn = !_bOn);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: on ? 1 : 0.5,
            child: Row(
              children: [
                Expanded(
                  child: _NumField(
                    controller: _ctl[i * 3],
                    axis: 'X',
                    color: P.ax,
                    enabled: true,
                    onChanged: (s) => _onField(i, 0, s),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumField(
                    controller: _ctl[i * 3 + 1],
                    axis: 'Y',
                    color: P.ay,
                    enabled: true,
                    onChanged: (s) => _onField(i, 1, s),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumField(
                    controller: _ctl[i * 3 + 2],
                    axis: 'Z',
                    color: P.az,
                    enabled: _is3D,
                    onChanged: (s) => _onField(i, 2, s),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleTile(
    IconData icon,
    String label,
    bool on,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: on ? al(color, 0.12) : P.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? al(color, 0.6) : P.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: on ? color : P.muted),
            const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: on ? P.text : P.muted,
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? color : Colors.transparent,
                border: Border.all(color: on ? color : P.muted, width: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _anglesCard() {
    String g(V3 v, double comp) {
      final l = v.len;
      if (l < 1e-9) return '—';
      return '${(math.acos((comp / l).clamp(-1.0, 1.0)) * 180 / math.pi).toStringAsFixed(1)}°';
    }

    Widget cell(String s, String v) => Expanded(
      child: Row(
        children: [
          Text(
            s,
            style: const TextStyle(
              fontSize: 14,
              color: P.muted,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              v,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: P.text,
                fontFeatures: _tab,
              ),
            ),
          ),
        ],
      ),
    );

    Widget row(String n, Color c, V3 v) => Row(
      children: [
        SizedBox(
          width: 26,
          child: Text(
            n,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
        ),
        cell('α', g(v, v.x)),
        cell('β', g(v, v.y)),
        cell('γ', g(v, v.z)),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: P.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Direction angles',
            style: TextStyle(
              fontSize: 12.5,
              color: P.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          row('A', P.brass, _a),
          const SizedBox(height: 8),
          row('B', P.rose, _b),
        ],
      ),
    );
  }
}

// ───────────────────────── Inputs ─────────────────────────

class _NumField extends StatefulWidget {
  final TextEditingController controller;
  final String axis;
  final Color color;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const _NumField({
    required this.controller,
    required this.axis,
    required this.color,
    required this.enabled,
    required this.onChanged,
  });
  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        widget.controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.controller.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _focus,
      builder: (context, _) {
        final f = _focus.hasFocus;
        return Opacity(
          opacity: widget.enabled ? 1 : 0.35,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: P.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: f ? widget.color : P.line,
                width: f ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  widget.axis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: widget.color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    onChanged: widget.onChanged,
                    cursorColor: widget.color,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^-?\d*\.?\d{0,3}'),
                      ),
                    ],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: P.text,
                      fontFeatures: _tab,
                    ),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PillSwitch extends StatelessWidget {
  final bool on;
  final Color color;
  final VoidCallback onTap;
  const _PillSwitch({
    required this.on,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 68,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: on ? al(color, 0.18) : P.bg,
          border: Border.all(color: on ? al(color, 0.7) : P.line),
        ),
        child: Stack(
          children: [
            Align(
              alignment: on ? Alignment.centerLeft : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  on ? 'On' : 'Off',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: on ? color : P.muted,
                  ),
                ),
              ),
            ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? color : P.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Camera ─────────────────────────

class _Cam {
  final bool is3D;
  final Size size;
  final double scale;
  final Offset pan;
  final double yaw, pitch;
  const _Cam(this.is3D, this.size, this.scale, this.pan, this.yaw, this.pitch);

  Offset get origin => Offset(size.width / 2, size.height / 2) + pan;

  Offset project(V3 v) {
    final o = origin;
    if (!is3D) return Offset(o.dx + v.x * scale, o.dy - v.y * scale);
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final x1 = v.x * cy + v.z * sy;
    final z1 = -v.x * sy + v.z * cy;
    final y2 = v.y * cp - z1 * sp;
    final z2 = v.y * sp + z1 * cp;
    final f = 42 / (42 - z2);
    return Offset(o.dx + x1 * scale * f, o.dy - y2 * scale * f);
  }
}

// ───────────────────────── Painter ─────────────────────────

TextPainter _tp(String s, TextStyle st) => TextPainter(
  text: TextSpan(text: s, style: st),
  textDirection: TextDirection.ltr,
)..layout();

class _VectorPainter extends CustomPainter {
  final _Cam cam;
  final Op op;
  final V3 a, b;
  final bool aOn, bOn, showComp, showArc;

  _VectorPainter({
    required this.cam,
    required this.op,
    required this.a,
    required this.b,
    required this.aOn,
    required this.bOn,
    required this.showComp,
    required this.showArc,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cam.is3D) {
      _grid3D(canvas);
      _axes3D(canvas);
    } else {
      _grid2D(canvas, size);
      _axes2D(canvas, size);
    }
    final both = aOn && bOn;
    final o = cam.origin;

    if (both) _geometry(canvas, size);
    if (showComp) {
      if (aOn) _components(canvas, a, P.brass);
      if (bOn) _components(canvas, b, P.rose);
    }
    if (both && showArc) _arcDraw(canvas, size);

    if (both && op != Op.dot && !(op == Op.cross && !cam.is3D)) {
      final r = op == Op.add ? a + b : (op == Op.sub ? a - b : a.cross(b));
      final tip = cam.project(r);
      if ((tip - o).distance > 2) {
        _arrow(canvas, o, tip, P.ice, 3);
        final name = op == Op.add ? 'A+B' : (op == Op.sub ? 'A−B' : 'A×B');
        _pill(canvas, size, tip, tip - o, [
          TextSpan(
            text: name,
            style: const TextStyle(
              color: P.ice,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]);
      }
    }
    if (aOn) _vec(canvas, size, a, P.brass, 'A');
    if (bOn) _vec(canvas, size, b, P.rose, 'B');
    canvas.drawCircle(o, 3.5, Paint()..color = P.ice);
  }

  // ── grid & axes ──

  void _grid2D(Canvas canvas, Size size) {
    final o = cam.origin, s = cam.scale;
    double step = 1;
    for (final c in const [1, 2, 5, 10, 20, 50]) {
      step = c.toDouble();
      if (step * s >= 30) break;
    }
    final minor = Paint()
      ..color = al(Colors.white, 0.045)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = al(Colors.white, 0.09)
      ..strokeWidth = 1;
    final xmin = -o.dx / s, xmax = (size.width - o.dx) / s;
    final ymin = -(size.height - o.dy) / s, ymax = o.dy / s;
    final lab = TextStyle(
      color: al(P.muted, 0.75),
      fontSize: 10,
      fontFeatures: _tab,
    );

    for (var i = (xmin / step).floor(); i <= (xmax / step).ceil(); i++) {
      final x = o.dx + i * step * s;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        i % 5 == 0 ? major : minor,
      );
      if (i != 0) {
        final t = _tp(fmt(i * step, d: 1), lab);
        t.paint(
          canvas,
          Offset(
            x - t.width / 2,
            (o.dy + 6).clamp(4.0, size.height - 16).toDouble(),
          ),
        );
      }
    }
    for (var j = (ymin / step).floor(); j <= (ymax / step).ceil(); j++) {
      final y = o.dy - j * step * s;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        j % 5 == 0 ? major : minor,
      );
      if (j != 0) {
        final t = _tp(fmt(j * step, d: 1), lab);
        t.paint(
          canvas,
          Offset(
            (o.dx - t.width - 6)
                .clamp(4.0, size.width - t.width - 4)
                .toDouble(),
            y - t.height / 2,
          ),
        );
      }
    }
  }

  void _axes2D(Canvas canvas, Size size) {
    final o = cam.origin;
    canvas.drawLine(
      Offset(0, o.dy),
      Offset(size.width, o.dy),
      Paint()
        ..color = al(P.ax, 0.7)
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(o.dx, 0),
      Offset(o.dx, size.height),
      Paint()
        ..color = al(P.ay, 0.7)
        ..strokeWidth = 1.5,
    );
    final tx = _tp(
      '+X',
      const TextStyle(color: P.ax, fontSize: 12, fontWeight: FontWeight.w800),
    );
    tx.paint(
      canvas,
      Offset(
        size.width - tx.width - 10,
        (o.dy - 22).clamp(4.0, size.height - 40).toDouble(),
      ),
    );
    final ty = _tp(
      '+Y',
      const TextStyle(color: P.ay, fontSize: 12, fontWeight: FontWeight.w800),
    );
    ty.paint(
      canvas,
      Offset((o.dx + 8).clamp(4.0, size.width - 30).toDouble(), 60),
    );
  }

  void _grid3D(Canvas canvas) {
    const n = 10;
    final minor = Paint()
      ..color = al(Colors.white, 0.05)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = al(Colors.white, 0.1)
      ..strokeWidth = 1;
    for (var i = -n; i <= n; i++) {
      final d = i.toDouble();
      final p = i % 5 == 0 ? major : minor;
      canvas.drawLine(cam.project(V3(d, 0, -10)), cam.project(V3(d, 0, 10)), p);
      canvas.drawLine(cam.project(V3(-10, 0, d)), cam.project(V3(10, 0, d)), p);
    }
  }

  void _axes3D(Canvas canvas) {
    void axis(V3 dir, Color col, String label) {
      const l = 9.0;
      canvas.drawLine(
        cam.project(dir * -l),
        cam.project(V3.zero),
        Paint()
          ..color = al(col, 0.22)
          ..strokeWidth = 1.2,
      );
      canvas.drawLine(
        cam.project(V3.zero),
        cam.project(dir * l),
        Paint()
          ..color = al(col, 0.85)
          ..strokeWidth = 1.6,
      );
      final t = _tp(
        '+$label',
        TextStyle(color: col, fontSize: 13, fontWeight: FontWeight.w800),
      );
      final p = cam.project(dir * (l + 0.8));
      t.paint(canvas, p - Offset(t.width / 2, t.height / 2));
    }

    axis(const V3(1, 0, 0), P.ax, 'X');
    axis(const V3(0, 1, 0), P.ay, 'Y');
    axis(const V3(0, 0, 1), P.az, 'Z');
  }

  // ── mode geometry ──

  void _geometry(Canvas c, Size size) {
    final o = cam.origin;
    final pa = cam.project(a), pb = cam.project(b);
    final dash = Paint()
      ..color = al(P.ice, 0.4)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = al(P.ice, 0.06);

    Path quad(Offset p1, Offset p2, Offset p3, Offset p4) => Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    switch (op) {
      case Op.add:
        final pr = cam.project(a + b);
        c.drawPath(quad(o, pa, pr, pb), fill);
        _dashed(c, pa, pr, dash);
        _dashed(c, pb, pr, dash);
      case Op.sub:
        _dashed(c, pb, pa, dash);
      case Op.dot:
        final aa = a.dot(a);
        if (aa < 1e-9) return;
        final pp = cam.project(a * (a.dot(b) / aa));
        c.drawLine(
          o,
          pp,
          Paint()
            ..color = al(P.ice, 0.5)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round,
        );
        _dashed(c, pb, pp, dash);
      case Op.cross:
        final pr = cam.project(a + b);
        c.drawPath(quad(o, pa, pr, pb), fill);
        if (!cam.is3D) {
          final r = a.cross(b);
          final ctr = cam.project((a + b) * 0.5);
          c.drawCircle(ctr, 14, Paint()..color = al(P.bg, 0.85));
          c.drawCircle(
            ctr,
            14,
            Paint()
              ..color = al(P.ice, 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6,
          );
          if (r.z >= 0) {
            c.drawCircle(ctr, 3.5, Paint()..color = P.ice);
          } else {
            final p = Paint()
              ..color = P.ice
              ..strokeWidth = 1.8
              ..strokeCap = StrokeCap.round;
            c.drawLine(ctr + const Offset(-5, -5), ctr + const Offset(5, 5), p);
            c.drawLine(ctr + const Offset(-5, 5), ctr + const Offset(5, -5), p);
          }
        }
    }
  }

  void _components(Canvas c, V3 v, Color col) {
    final p = Paint()
      ..color = al(col, 0.6)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = col;
    final tip = cam.project(v);
    if (!cam.is3D) {
      final px = cam.project(V3(v.x, 0, 0)), py = cam.project(V3(0, v.y, 0));
      _dashed(c, tip, px, p);
      _dashed(c, tip, py, p);
      c.drawCircle(px, 3.2, dot);
      c.drawCircle(py, 3.2, dot);
      final st = TextStyle(
        color: col,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        fontFeatures: _tab,
      );
      final tx = _tp(fmt(v.x, d: 1), st), ty = _tp(fmt(v.y, d: 1), st);
      tx.paint(
        c,
        Offset(px.dx + 6, v.y >= 0 ? px.dy - tx.height - 4 : px.dy + 4),
      );
      ty.paint(
        c,
        Offset(
          v.x >= 0 ? py.dx + 8 : py.dx - ty.width - 8,
          py.dy - ty.height - 4,
        ),
      );
    } else {
      final fl = cam.project(V3(v.x, 0, v.z));
      final fx = cam.project(V3(v.x, 0, 0));
      final fz = cam.project(V3(0, 0, v.z));
      _dashed(c, tip, fl, p);
      _dashed(c, fl, fx, p);
      _dashed(c, fl, fz, p);
      _dashed(c, cam.origin, fl, p);
      for (final q in [fl, fx, fz]) {
        c.drawCircle(q, 3, dot);
      }
    }
  }

  void _arcDraw(Canvas c, Size size) {
    final la = a.len, lb = b.len;
    if (la < 1e-6 || lb < 1e-6) return;
    final ua = a * (1 / la), ub = b * (1 / lb);
    final th = math.acos(ua.dot(ub).clamp(-1.0, 1.0));
    if (th < 0.02 || th > math.pi - 0.02) return;
    final r = (math.min(la, lb) * 0.4).clamp(0.7, 2.2).toDouble();
    const n = 48;
    final o = cam.origin;
    final pts = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final v =
          (ua * math.sin((1 - t) * th) + ub * math.sin(t * th)) *
          (1 / math.sin(th));
      pts.add(cam.project(v * r));
    }
    final path = Path()..moveTo(o.dx, o.dy);
    for (final p in pts) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    c.drawPath(path, Paint()..color = al(P.ice, 0.09));
    final stroke = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      stroke.lineTo(p.dx, p.dy);
    }
    c.drawPath(
      stroke,
      Paint()
        ..color = al(P.ice, 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── vectors ──

  void _vec(Canvas c, Size size, V3 v, Color col, String name) {
    final o = cam.origin;
    final tip = cam.project(v);
    if ((tip - o).distance < 2) return;
    _arrow(c, o, tip, col, 3.4);
    if (!cam.is3D) {
      c.drawCircle(tip, 15, Paint()..color = al(col, 0.12));
    }
    _pill(c, size, tip, tip - o, [
      TextSpan(
        text: name,
        style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    ], gap: cam.is3D ? 8 : 18);
  }

  void _arrow(Canvas c, Offset from, Offset to, Color col, double w) {
    final d = to - from;
    final len = d.distance;
    if (len < 1) return;
    final u = d / len;
    final n = Offset(-u.dy, u.dx);
    final hl = math.min(15.0, len * 0.5);
    const hw = 6.5;
    final base = to - u * hl;
    c.drawLine(
      from,
      base,
      Paint()
        ..color = al(col, 0.3)
        ..strokeWidth = w + 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    c.drawLine(
      from,
      base,
      Paint()
        ..color = col
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );
    final head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(base.dx + n.dx * hw, base.dy + n.dy * hw)
      ..lineTo(base.dx - n.dx * hw, base.dy - n.dy * hw)
      ..close();
    c.drawPath(head, Paint()..color = col);
  }

  void _dashed(
    Canvas c,
    Offset p1,
    Offset p2,
    Paint p, {
    double dash = 6,
    double gap = 5,
  }) {
    final d = p2 - p1;
    final len = d.distance;
    if (len < 1) return;
    final u = d / len;
    double t = 0;
    while (t < len) {
      final e = math.min(t + dash, len);
      c.drawLine(p1 + u * t, p1 + u * e, p);
      t += dash + gap;
    }
  }

  void _pill(
    Canvas c,
    Size size,
    Offset anchor,
    Offset dir,
    List<InlineSpan> spans, {
    double gap = 14,
  }) {
    final tp = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 16, h = tp.height + 8;
    final dl = dir.distance;
    final u = dl < 1 ? const Offset(0, -1) : dir / dl;
    final center = anchor + Offset(u.dx * (w / 2 + gap), u.dy * (h / 2 + gap));
    var r = Rect.fromCenter(center: center, width: w, height: h);
    final dx =
        (r.left < 6 ? 6 - r.left : 0) +
        (r.right > size.width - 6 ? size.width - 6 - r.right : 0);
    final dy =
        (r.top < 6 ? 6 - r.top : 0) +
        (r.bottom > size.height - 6 ? size.height - 6 - r.bottom : 0);
    r = r.shift(Offset(dx.toDouble(), dy.toDouble()));
    final rr = RRect.fromRectAndRadius(r, Radius.circular(h / 2));
    c.drawRRect(rr, Paint()..color = al(P.bg, 0.85));
    c.drawRRect(
      rr,
      Paint()
        ..color = P.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    tp.paint(c, Offset(r.left + 8, r.top + 4));
  }

  @override
  bool shouldRepaint(covariant _VectorPainter old) => true;
}
