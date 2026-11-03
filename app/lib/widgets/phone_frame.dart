import 'package:flutter/material.dart';

import '../theme.dart';

enum _PhoneSpec {
  iphone15(
    label: 'iPhone 15 Pro (iOS)',
    width: 393,
    height: 852,
    radius: 48,
    isIos: true,
  ),
  pixel8(
    label: 'Pixel 8 (Android)',
    width: 412,
    height: 892,
    radius: 38,
    isIos: false,
  ),
  full(
    label: 'Toàn màn hình',
    width: 0,
    height: 0,
    radius: 0,
    isIos: false,
  );

  final String label;
  final double width;
  final double height;
  final double radius;
  final bool isIos;

  const _PhoneSpec({
    required this.label,
    required this.width,
    required this.height,
    required this.radius,
    required this.isIos,
  });
}

/// Wraps the app in an interactive iPhone / Android phone bezel when viewed
/// on a wide desktop or browser window. On real phones (narrow screens), it
/// renders [child] untouched.
class PhoneSimulatorFrame extends StatefulWidget {
  final Widget child;
  const PhoneSimulatorFrame({super.key, required this.child});

  @override
  State<PhoneSimulatorFrame> createState() => _PhoneSimulatorFrameState();
}

class _PhoneSimulatorFrameState extends State<PhoneSimulatorFrame> {
  _PhoneSpec _spec = _PhoneSpec.iphone15;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    // On actual mobile devices or narrow windows, render directly
    if (screen.width < 600 || _spec == _PhoneSpec.full) {
      if (screen.width < 600) return widget.child;
      return Stack(
        children: [
          widget.child,
          Positioned(
            top: 12,
            right: 16,
            child: _deviceSwitcher(),
          ),
        ],
      );
    }

    final availH = screen.height - 84;
    final scale = (availH / (_spec.height + 28)).clamp(0.65, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF090807),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _deviceSwitcher(),
          Expanded(
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: _spec.width + 24,
                  height: _spec.height + 24,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF23201E),
                    borderRadius: BorderRadius.circular(_spec.radius + 10),
                    border: Border.all(
                      color: const Color(0xFF4A423D),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        blurRadius: 60,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_spec.radius),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: Size(_spec.width, _spec.height),
                        padding: EdgeInsets.only(
                          top: _spec.isIos ? 50 : 36,
                          bottom: _spec.isIos ? 24 : 16,
                        ),
                      ),
                      child: Stack(
                        children: [
                          SizedBox(
                            width: _spec.width,
                            height: _spec.height,
                            child: widget.child,
                          ),
                          // Status bar + Dynamic Island / Camera punch-hole
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: _statusBar(_spec),
                            ),
                          ),
                          // Bottom home indicator
                          Positioned(
                            bottom: 6,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: Center(
                                child: Container(
                                  width: _spec.isIos ? 134 : 108,
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    color: Colors.white38,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
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
    );
  }

  Widget _deviceSwitcher() {
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smartphone_rounded,
                size: 16, color: AppColors.gold),
            const SizedBox(width: 8),
            for (final s in _PhoneSpec.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(s.label, style: const TextStyle(fontSize: 12)),
                  selected: _spec == s,
                  selectedColor: AppColors.primary.withValues(alpha: 0.3),
                  onSelected: (_) => setState(() => _spec = s),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusBar(_PhoneSpec spec) {
    return SizedBox(
      height: spec.isIos ? 46 : 34,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '9:41',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
            if (spec.isIos)
              Container(
                width: 112,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(18),
                ),
              )
            else
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.signal_cellular_alt_rounded,
                    size: 14, color: Colors.white),
                SizedBox(width: 4),
                Icon(Icons.wifi_rounded, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Icon(Icons.battery_full_rounded, size: 15, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
