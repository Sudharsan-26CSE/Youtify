import 'package:flutter/material.dart';

/// Animated shimmer wave container for skeleton loading
class ShimmerEffect extends StatefulWidget {
  final Widget child;

  const ShimmerEffect({super.key, required this.child});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor =
        isDark ? const Color(0xFF222222) : const Color(0xFFE2E2E2);
    final highlightColor =
        isDark ? const Color(0xFF383838) : const Color(0xFFF4F4F4);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.5, -0.3),
              end: const Alignment(1.5, 0.3),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value.clamp(0.0, 1.0),
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Generic rounded skeleton bone box
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final ShapeBorder? shape;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF252525) : const Color(0xFFE6E6E6);

    return Container(
      width: width,
      height: height,
      decoration: ShapeDecoration(
        color: color,
        shape: shape ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
      ),
    );
  }
}

/// Skeleton replica of VideoCard
class VideoCardSkeleton extends StatelessWidget {
  const VideoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 16:9 Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: const [
                  SkeletonBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: SkeletonBox(
                      width: 48,
                      height: 18,
                      borderRadius: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Avatar + Title & Meta lines
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(
                    width: 40,
                    height: 40,
                    shape: CircleBorder(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(
                          width: double.infinity,
                          height: 14,
                          borderRadius: 4,
                        ),
                        SizedBox(height: 6),
                        SkeletonBox(
                          width: 200,
                          height: 14,
                          borderRadius: 4,
                        ),
                        SizedBox(height: 8),
                        SkeletonBox(
                          width: 140,
                          height: 11,
                          borderRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const SkeletonBox(
                    width: 16,
                    height: 24,
                    borderRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact inline skeleton shown when loading more videos (pagination)
class CompactVideoSkeleton extends StatelessWidget {
  const CompactVideoSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const SkeletonBox(
              width: 110,
              height: 64,
              borderRadius: 8,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SkeletonBox(
                    width: double.infinity,
                    height: 12,
                    borderRadius: 4,
                  ),
                  SizedBox(height: 6),
                  SkeletonBox(
                    width: 140,
                    height: 12,
                    borderRadius: 4,
                  ),
                  SizedBox(height: 8),
                  SkeletonBox(
                    width: 90,
                    height: 10,
                    borderRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen skeleton for Shorts while initial videos load
class ShortsSkeleton extends StatelessWidget {
  const ShortsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF121212),
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 80),
        child: Stack(
          children: [
            // Bottom details
            Positioned(
              left: 0,
              right: 80,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Row(
                    children: [
                      SkeletonBox(width: 38, height: 38, shape: CircleBorder()),
                      SizedBox(width: 10),
                      SkeletonBox(width: 120, height: 14, borderRadius: 4),
                      SizedBox(width: 10),
                      SkeletonBox(width: 70, height: 26, borderRadius: 14),
                    ],
                  ),
                  SizedBox(height: 14),
                  SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
                  SizedBox(height: 6),
                  SkeletonBox(width: 180, height: 14, borderRadius: 4),
                  SizedBox(height: 10),
                  SkeletonBox(width: 140, height: 12, borderRadius: 4),
                ],
              ),
            ),
            // Right action bar
            Positioned(
              right: 0,
              bottom: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SkeletonBox(width: 42, height: 42, shape: CircleBorder()),
                  SizedBox(height: 18),
                  SkeletonBox(width: 42, height: 42, shape: CircleBorder()),
                  SizedBox(height: 18),
                  SkeletonBox(width: 42, height: 42, shape: CircleBorder()),
                  SizedBox(height: 18),
                  SkeletonBox(width: 42, height: 42, shape: CircleBorder()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
