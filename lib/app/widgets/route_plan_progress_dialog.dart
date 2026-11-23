import 'package:flutter/material.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';

/// Animated progress dialog shown while generating the weekly route plan.
class RoutePlanProgressDialog extends StatefulWidget {
  const RoutePlanProgressDialog({
    super.key,
    required this.onGenerate,
  });

  final Future<({int stops, int days, double km, int minutes})> Function(
    void Function(double progress, String stage) onStageUpdate,
  ) onGenerate;

  @override
  State<RoutePlanProgressDialog> createState() =>
      _RoutePlanProgressDialogState();
}

class _RoutePlanProgressDialogState extends State<RoutePlanProgressDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  double _progress = 0.12;
  String _stageText = 'Consolidating store stops & anchors...';
  bool _completed = false;
  ({int stops, int days, double km, int minutes})? _summary;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _runGeneration();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runGeneration() async {
    final result = await widget.onGenerate((progress, stage) {
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _stageText = stage;
      });
    });
    if (!mounted) return;
    setState(() {
      _progress = 1.0;
      _completed = true;
      _summary = result;
      _stageText =
          '${result.stops} stops across ${result.days} days · ~${result.km.toStringAsFixed(1)} km';
    });
    _pulseController.stop();
    await Future.delayed(const Duration(milliseconds: 850));
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppColors.surface,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = (_completed || reduceMotion)
                      ? 1.0
                      : 0.94 + (_pulseController.value * 0.10);
                  return Transform.scale(scale: scale, child: child);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: _completed
                        ? AppColors.successTint
                        : AppColors.primaryTint,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _completed
                          ? AppColors.successBorder
                          : AppColors.primaryBorder,
                      width: 2,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      _completed
                          ? Icons.check_circle_rounded
                          : Icons.alt_route_rounded,
                      key: ValueKey(_completed),
                      size: 32,
                      color:
                          _completed ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _completed ? 'Weekly Plan Ready!' : 'Optimizing Weekly Route',
                textAlign: TextAlign.center,
                style: AppTypography.title.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  _stageText,
                  key: ValueKey(_stageText),
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    fontSize: 14.5,
                    color: _completed
                        ? AppColors.success
                        : AppColors.inkSecondary,
                    fontWeight:
                        _completed ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: _progress),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _completed ? AppColors.success : AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
              if (_summary != null && _completed) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Opening Home route list...',
                  style: AppTypography.monoRef.copyWith(
                    fontSize: 12.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
