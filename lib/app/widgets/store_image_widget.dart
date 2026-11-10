import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Renders a store/customer photo from RavaMate's S3/legacy servers,
/// with automatic candidate fallbacks and a final fallback to the default store design.
class StoreImageWidget extends StatefulWidget {
  final String? imageUrl;
  final String? custCode;
  final String? distCode;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final Widget fallback;
  final bool enablePreview;

  const StoreImageWidget({
    super.key,
    this.imageUrl,
    this.custCode,
    this.distCode,
    this.width = 58,
    this.height = 58,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    required this.fallback,
    this.enablePreview = false,
  });

  @override
  State<StoreImageWidget> createState() => _StoreImageWidgetState();
}

class _StoreImageWidgetState extends State<StoreImageWidget> {
  int _currentCandidateIndex = 0;
  List<String> _candidates = [];

  @override
  void initState() {
    super.initState();
    _initCandidates();
  }

  @override
  void didUpdateWidget(covariant StoreImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.custCode != widget.custCode ||
        oldWidget.distCode != widget.distCode) {
      _initCandidates();
    }
  }

  void _initCandidates() {
    _currentCandidateIndex = 0;
    final list = <String>[];
    final img = (widget.imageUrl ?? '').trim();
    final code = (widget.custCode ?? '').trim();
    final dist = (widget.distCode ?? 'SANDBOX01').trim();

    if (img.isNotEmpty && img.startsWith('http')) {
      list.add(img);
    }
    if (code.isNotEmpty) {
      final s3Lower =
          'https://filezsystem.sgp1.vultrobjects.com/STOREIMAGE/MNC/$dist/${code.toLowerCase()}_1.jpg';
      final s3Upper =
          'https://filezsystem.sgp1.vultrobjects.com/STOREIMAGE/MNC/$dist/${code.toUpperCase()}_1.jpg';
      final legacy =
          'https://fastdevs-api.com/FASTSOSYO/download/image/v2Mybuddystores_images/${code}_1.jpg';

      if (!list.contains(s3Lower)) list.add(s3Lower);
      if (!list.contains(s3Upper)) list.add(s3Upper);
      if (!list.contains(legacy)) list.add(legacy);
    }
    _candidates = list;
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty || _currentCandidateIndex >= _candidates.length) {
      return widget.fallback;
    }

    final currentUrl = _candidates[_currentCandidateIndex];

    Widget imageWidget = ClipRRect(
      borderRadius: widget.borderRadius,
      child: Image.network(
        currentUrl,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _currentCandidateIndex < _candidates.length) {
              setState(() {
                _currentCandidateIndex++;
              });
            }
          });
          return widget.fallback;
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return widget.fallback;
        },
      ),
    );

    if (widget.enablePreview) {
      return GestureDetector(
        onTap: () => _showImagePreview(context, currentUrl),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  void _showImagePreview(BuildContext context, String url) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  padding: const EdgeInsets.all(6),
                ),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: true,
    );
  }
}

