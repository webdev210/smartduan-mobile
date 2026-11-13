import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kit.dart' show Appear;
import 'theme.dart' as c;

final introDelayProvider = NotifierProvider.autoDispose
    .family<IntroDelay, bool, Duration>(IntroDelay.new);

class IntroDelay extends Notifier<bool> {
  IntroDelay(this.duration);
  final Duration duration;
  @override
  bool build() {
    if (duration == Duration.zero) return false;
    final timer = Timer(duration, () {
      if (ref.mounted) state = false;
    });
    ref.onDispose(timer.cancel);
    return true;
  }
}

class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Semantics(
        label: 'Đang mở Smart Dự Án',
        excludeSemantics: true,
        child: Material(
          color: const Color(0xff0a0f1c),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/splash.webp',
                fit: BoxFit.cover,
                // The central towers remain visible in the narrow phone crop.
                alignment: Alignment.center,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, synchronous) =>
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: frame == null ? 0 : 1),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      builder: (_, opacity, child) =>
                          Opacity(opacity: opacity, child: child),
                      child: child,
                    ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // Protect sky/vegetation text while leaving the towers clear.
                    colors: [
                      Color(0xd90a0f1c),
                      Color(0x8c0a0f1c),
                      Color(0x260a0f1c),
                      Color(0x1f0a0f1c),
                      Color(0x260a0f1c),
                      Color(0xe00a0f1c),
                    ],
                    stops: [0, .3, .45, .5, .75, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: LayoutBuilder(
                    builder: (context, bounds) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: bounds.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              ConstrainedBox(
                                // Centre the brand at 18.5% of the full screen.
                                // Grow naturally for large text; short windows scroll.
                                constraints: BoxConstraints(
                                  minHeight:
                                      (media.size.height * .37 -
                                              media.padding.top * 2)
                                          .clamp(0.0, double.infinity),
                                ),
                                child: Center(
                                  child: Appear(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 440,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                            'assets/smartland-mark.png',
                                            width: 64,
                                            height: 64,
                                            color: c.gold,
                                            fit: BoxFit.contain,
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Smart Dự Án',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 32,
                                              height: 1.1,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -.5,
                                              decoration: TextDecoration.none,
                                              shadows: [
                                                Shadow(
                                                  color: Color(0x990a0f1c),
                                                  blurRadius: 12,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Bảng hàng & dự án bất động sản trong tay\u00a0bạn',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              height: 1.4,
                                              fontWeight: FontWeight.w400,
                                              decoration: TextDecoration.none,
                                              shadows: [
                                                Shadow(
                                                  color: Color(0x990a0f1c),
                                                  blurRadius: 12,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  value: reduceMotion ? 1 : null,
                                  color: c.gold,
                                  strokeWidth: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'SMARTLAND',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 4,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
