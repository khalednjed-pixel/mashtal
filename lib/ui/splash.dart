import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Opening screen: the Mashtal mark and name over a strip of local plants,
/// held briefly when the app starts and then faded away to reveal [child].
/// On the web, web/index.html shows the same picture while the app loads.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});
  final Widget child;

  /// Widget tests turn this off so every test starts on the real screen.
  static bool enabled = true;

  static const hold = Duration(milliseconds: 1900);
  static const fade = Duration(milliseconds: 450);

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _visible = SplashGate.enabled;
  bool _gone = !SplashGate.enabled;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_visible) _timer = Timer(SplashGate.hold, () => setState(() => _visible = false));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: SplashGate.fade,
              curve: Curves.easeOut,
              onEnd: () => setState(() => _gone = true),
              child: const SplashView(),
            ),
          ),
        ),
      ],
    );
  }
}

/// The splash picture: the leaf mark (already on the web loading screen), then
/// the name written out quickly, "Mashtal" left to right and مشتل right to
/// left, over line drawings of plants. [animate] false shows it finished.
class SplashView extends StatefulWidget {
  const SplashView({super.key, this.animate = true});
  final bool animate;

  /// How long the name takes to write itself.
  static const write = Duration(milliseconds: 1250);

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: SplashView.write, value: widget.animate ? 0 : 1);

  // Latin name first, the Arabic name overlapping its end.
  late final Animation<double> _latin = CurvedAnimation(parent: _c, curve: const Interval(0.08, 0.72, curve: Curves.easeInOutCubic));
  late final Animation<double> _arabic = CurvedAnimation(parent: _c, curve: const Interval(0.5, 1, curve: Curves.easeInOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Same width as the app's content (role_shell caps it at 560), on the
    // app's page colour, so the splash fades into the shop without a jump.
    return ColoredBox(
      color: MashtalColors.page,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Stack(
            children: [
              // Line drawings of plants growing up from the bottom edge.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Image.asset('assets/brand/splash_garden.png', fit: BoxFit.fitWidth, alignment: Alignment.bottomCenter),
              ),
              Align(
                alignment: const Alignment(0, -0.18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/brand/logo_mark.png', height: 88),
                    const SizedBox(height: MashtalSpace.lg),
                    _Written(
                      progress: _latin,
                      rtl: false,
                      child: Image.asset('assets/brand/logo_wordmark.png', width: 200, semanticLabel: 'Mashtal'),
                    ),
                    const SizedBox(height: MashtalSpace.sm),
                    _Written(
                      progress: _arabic,
                      rtl: true,
                      child: const Text(
                        'مشتل',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: MashtalColors.forest,
                          height: 1.4,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reveals [child] in its writing direction with a soft pen edge, so a word
/// looks written out rather than faded in. Its size never changes, so nothing
/// around it moves.
class _Written extends AnimatedWidget {
  const _Written({required Animation<double> progress, required this.rtl, required this.child}) : super(listenable: progress);
  final bool rtl;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    if (t >= 1) return child;
    const edge = 0.12; // width of the soft edge, as a share of the word
    final front = -edge + t * (1 + edge);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
        end: rtl ? Alignment.centerLeft : Alignment.centerRight,
        colors: const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF), Color(0x00FFFFFF)],
        stops: [0, front.clamp(0.0, 1.0), (front + edge).clamp(0.0, 1.0), 1],
      ).createShader(rect),
      child: child,
    );
  }
}
