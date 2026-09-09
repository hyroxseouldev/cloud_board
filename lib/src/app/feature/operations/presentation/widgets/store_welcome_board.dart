import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';

class StoreWelcomeBoard extends StatelessWidget {
  const StoreWelcomeBoard({
    super.key,
    required this.brand,
    required this.now,
    this.nextClass,
    this.connected = true,
  });

  final BrandTemplate brand;
  final DateTime now;
  final String? nextClass;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final promotions = brand.promotionImageUrls;
    final promotion = promotions.isEmpty
        ? null
        : promotions[(now.millisecondsSinceEpoch ~/ 12000) % promotions.length];
    final clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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
                                  child: promotion == null
                                      ? Center(
                                          child: Text(
                                            clock,
                                            style: TextStyle(
                                              fontSize: 100,
                                              fontWeight: FontWeight.w300,
                                              color: Color(
                                                brand.primaryColorValue,
                                              ),
                                            ),
                                          ),
                                        )
                                      : AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 600,
                                          ),
                                          child: CachedNetworkImage(
                                            key: ValueKey(promotion),
                                            imageUrl: promotion,
                                            fit: BoxFit.contain,
                                            errorWidget: (_, _, _) => Center(
                                              child: Text(
                                                clock,
                                                style: const TextStyle(
                                                  fontSize: 90,
                                                ),
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
