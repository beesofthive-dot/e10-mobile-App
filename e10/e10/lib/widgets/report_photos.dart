import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api_session.dart';
import '../school_store.dart';
import 'popups.dart';
import '../theme.dart';

/// One daily-report photo: either already on the server ([url], plus its
/// media [id] so it can be removed) or just picked on this device ([bytes]).
class ReportPhoto {
  const ReportPhoto({this.id = '', this.url, this.bytes});

  final String id;
  final String? url;
  final Uint8List? bytes;
}

/// A server photo loaded with the signed-in user's token — daily-report
/// photos are served from `/api/...`, which rejects anonymous requests, so a
/// plain `Image.network` shows nothing (especially on web, where it can't
/// send headers).
class AuthImage extends StatefulWidget {
  const AuthImage({super.key, required this.url, this.fit = BoxFit.cover, this.width, this.height});

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  State<AuthImage> createState() => _AuthImageState();
}

class _AuthImageState extends State<AuthImage> {
  static final Map<String, Uint8List> _cache = {};
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bytes == null && !_failed) _load();
  }

  @override
  void didUpdateWidget(covariant AuthImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final resolved = SchoolScope.of(context).resolveApiFileUrl(widget.url) ?? widget.url;
    final cached = _cache[resolved];
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }
    try {
      final token = ApiSession.instance.token;
      final res = await http.get(Uri.parse(resolved), headers: {
        'Accept': 'image/*',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      });
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300 && res.bodyBytes.isNotEmpty) {
        _cache[resolved] = res.bodyBytes;
        setState(() => _bytes = res.bodyBytes);
      } else {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: widget.fit, width: widget.width, height: widget.height, gaplessPlayback: true);
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: _failed
            ? const Icon(Icons.broken_image_outlined, color: AppColors.slate400)
            : const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

Widget reportPhotoImage(ReportPhoto photo, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
  final bytes = photo.bytes;
  if (bytes != null) return Image.memory(bytes, fit: fit, width: width, height: height);
  return AuthImage(url: photo.url ?? '', fit: fit, width: width, height: height);
}

/// The daily-report photo block, as on the website: one large photo shown in
/// full (not cropped), a "+N" badge in the bottom-right corner when there
/// are more, thumbnails to switch between them, and a tap to open them all
/// full screen.
class ReportPhotoGallery extends StatefulWidget {
  const ReportPhotoGallery({super.key, required this.photos, this.height = 240});

  final List<ReportPhoto> photos;
  final double height;

  @override
  State<ReportPhotoGallery> createState() => _ReportPhotoGalleryState();
}

class _ReportPhotoGalleryState extends State<ReportPhotoGallery> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i < 0 || i >= widget.photos.length) return;
    _pages.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) return const SizedBox.shrink();
    final index = _index.clamp(0, photos.length - 1);
    final more = photos.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ColoredBox(
            color: const Color(0xFFF1F5F9),
            child: SizedBox(
              height: widget.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Swipe left or right to flip between photos (mouse drag
                  // works too, in the browser).
                  ScrollConfiguration(
                    behavior: const _DragAnyDevice(),
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: photos.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => showReportPhotoViewer(context, photos, initialIndex: i),
                        child: reportPhotoImage(photos[i], fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  if (photos.length > 1) ...[
                    if (index > 0)
                      Positioned(left: 6, top: 0, bottom: 0, child: Center(child: _Arrow(left: true, onTap: () => _go(index - 1)))),
                    if (index < photos.length - 1)
                      Positioned(right: 6, top: 0, bottom: 0, child: Center(child: _Arrow(left: false, onTap: () => _go(index + 1)))),
                  ],
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: GestureDetector(
                      onTap: () => showReportPhotoViewer(context, photos, initialIndex: index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.open_in_full_rounded, size: 13, color: Colors.white),
                            if (more > 0) ...[
                              const SizedBox(width: 4),
                              Text('${index + 1}/${photos.length}', style: AppText.body(size: 12, weight: FontWeight.w800, color: Colors.white)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (photos.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (context, i) => const SizedBox(width: 6),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _go(i),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: i == index ? AppColors.blue : Colors.transparent, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: reportPhotoImage(photos[i]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Lets a PageView be dragged with a mouse or trackpad as well as a finger.
class _DragAnyDevice extends MaterialScrollBehavior {
  const _DragAnyDevice();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.left, required this.onTap, this.size = 34});

  final bool left;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: Colors.white, size: size * 0.7),
        ),
      ),
    );
  }
}

/// Full-screen, swipeable, pinch-to-zoom view of the report photos.
Future<void> showReportPhotoViewer(BuildContext context, List<ReportPhoto> photos, {int initialIndex = 0}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    useSafeArea: false,
    builder: (_) => _PhotoViewer(photos: photos, initialIndex: initialIndex),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initialIndex});

  final List<ReportPhoto> photos;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i < 0 || i >= widget.photos.length) return;
    _pages.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            ScrollConfiguration(
              behavior: const _DragAnyDevice(),
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.photos.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(child: reportPhotoImage(widget.photos[i], fit: BoxFit.contain)),
                ),
              ),
            ),
            if (_index > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(child: _Arrow(left: true, size: 44, onTap: () => _go(_index - 1))),
              ),
            if (_index < widget.photos.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(child: _Arrow(left: false, size: 44, onTap: () => _go(_index + 1))),
              ),
            Positioned(
              left: 16,
              top: 12,
              child: Text(
                '${_index + 1} / ${widget.photos.length}',
                style: AppText.body(size: 13, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
            Positioned(
              right: 4,
              top: 0,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => closeRoute(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
