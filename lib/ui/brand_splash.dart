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

/// Màn mở app — giống RN main (aa6bc54): ảnh thành phố của Smartland (trời sáng,
/// dải đỏ/vàng ở đáy) + logo và tên app ở khoảng trời trống.
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Semantics(
      label: 'Đang mở Smart Dự Án',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Bám đáy: máy dài hay ngắn thì dải đỏ và hàng toà nhà vẫn nằm trọn,
            // chỉ phần trời bị cắt.
            Image.asset(
              'assets/splash-bg.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              excludeFromSemantics: true,
            ),
            LayoutBuilder(
              builder: (context, bounds) => Padding(
                padding: EdgeInsets.only(
                  top: bounds.maxHeight * .26,
                  left: 24,
                  right: 24,
                ),
                child: Appear(
                  child: Align(
                    alignment: Alignment.topCenter,
                    // Short or large-text screens shrink the whole block, one-line name like RN.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/smartland-mark.png',
                            width: 96,
                            height: 96,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Smart Dự Án',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.brandDeep,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.8,
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
          ],
        ),
      ),
    ),
  );
}
