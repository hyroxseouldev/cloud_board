import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';

import 'package:cloud_board/src/app/feature/operations/presentation/widgets/standby_slideshow.dart';

import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';

class StoreWelcomeBoard extends StatelessWidget {
  const StoreWelcomeBoard({
    super.key,
    required this.brand,
    required this.now,
    this.nextClass,
    this.connected = true,
    this.displayPreferences = const DisplayPreferences(),
  });

  final BrandTemplate brand;
  final DateTime now;
  final String? nextClass;
  final bool connected;
  final DisplayPreferences displayPreferences;
  DisplayPreferences get preferences => displayPreferences.enabled
      ? displayPreferences
      : const DisplayPreferences();

  @override
  Widget build(BuildContext context) {
    final clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (brand.standbyFullscreen && brand.promotionImageUrls.isNotEmpty) {
      final adjusted = preferences.enabled
          ? brand.copyWith(
              standbyImageFit: preferences.cover
                  ? StandbyImageFit.cover
                  : StandbyImageFit.contain,
            )
          : brand;
      final align = switch (brand.standbyTextPosition) {
        'topLeft' => Alignment.topLeft,
        'center' => Alignment.center,
        _ => Alignment.bottomLeft,
      };
      return Scaffold(
        backgroundColor: Color(brand.standbyBackgroundColor),
        body: LayoutBuilder(
          builder: (context, c) {
            final scale = math.min(c.maxWidth / 1280, c.maxHeight / 720);
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRect(
                  child: Transform.translate(
                    offset: Offset(
                      c.maxWidth * preferences.offsetX,
                      c.maxHeight * preferences.offsetY,
                    ),
                    child: Transform.scale(
                      scale: preferences.zoom,
                      child: StandbySlideshow(
                        brand: adjusted,
                        now: now,
                        fallback: ColoredBox(
                          color: Color(brand.standbyBackgroundColor),
                          child: Center(
                            child: Text(
                              '잠시 후 수업이 시작됩니다',
                              style: TextStyle(
                                color:
                                    Color(brand.standbyBackgroundColor)
                                            .computeLuminance() >
                                        .4
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 28 * scale,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (brand.standbyShowText)
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            40 * scale + c.maxWidth * preferences.safeInset,
                        vertical:
                            32 * scale + c.maxHeight * preferences.safeInset,
                      ),
                      child: Align(
                        alignment: align,
                        child: Container(
                          padding: EdgeInsets.all(24 * scale),
                          decoration: BoxDecoration(
                            color:
                                Color(brand.standbyTextColor)
                                        .computeLuminance() >
                                    .4
                                ? Colors.black54
                                : Colors.white70,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DefaultTextStyle(
                            style: TextStyle(
                              color: Color(brand.standbyTextColor),
                              fontFamily: 'Pretendard',
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (brand.logoUrl?.isNotEmpty ?? false)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: 12 * scale,
                                    ),
                                    child: SizedBox(
                                      width: 200 * scale,
                                      height: 64 * scale,
                                      child: WorkoutImage(
                                        source: brand.logoUrl!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                Text(
                                  brand.storeName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 48 * scale,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 12 * scale),
                                Text(
                                  brand.standbyMessage,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 28 * scale),
                                ),
                                SizedBox(height: 12 * scale),
                                Text(
                                  '${now.year}.${now.month}.${now.day}  $clock',
                                  style: TextStyle(fontSize: 20 * scale),
                                ),
                                if (nextClass != null)
                                  Text(
                                    'NEXT  $nextClass',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 22 * scale),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!connected)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      color: Colors.black87,
                      padding: const EdgeInsets.all(8),
                      child: const Text(
                        '오프라인 · 저장된 화면',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }
    final shift = now.minute % 4;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      body: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 1280,
            height: 720,
            child: AnimatedContainer(
              duration: const Duration(seconds: 2),
              transform: Matrix4.translationValues(
                shift.isEven ? -4 : 4,
                shift < 2 ? -3 : 3,
                0,
              ),
              padding: const EdgeInsets.all(48),
              child: DefaultTextStyle(
                style: const TextStyle(color: Color(0xFF171717)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Welcome to',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  brand.storeName,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 64,
                                    height: 1.08,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  brand.standbyMessage,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 40),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (brand.logoUrl != null)
                                  SizedBox(
                                    height: 90,
                                    width: 240,
                                    child: CachedNetworkImage(
                                      imageUrl: brand.logoUrl!,
                                      fit: BoxFit.contain,
                                      errorWidget: (_, _, _) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                Expanded(
                                  child: StandbySlideshow(
                                    brand: brand,
                                    now: now,
                                    fallback: Center(
                                      child: Text(
                                        clock,
                                        style: TextStyle(
                                          fontSize: 100,
                                          fontWeight: FontWeight.w300,
                                          color: Color(brand.primaryColorValue),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (nextClass != null)
                      Text(
                        'NEXT  $nextClass',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const Divider(color: Colors.black54, height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            brand.storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!connected)
                          const Text(
                            '오프라인 · 저장된 화면',
                            style: TextStyle(fontSize: 16),
                          ),
                        const SizedBox(width: 24),
                        Text(clock, style: const TextStyle(fontSize: 28)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
