import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Menggambar widget di luar layar menjadi PNG — untuk slide yang diubah ke
/// PDF. Tata letaknya sama persis dengan yang tampil di penampil, karena
/// widget yang dipakai juga sama.
///
/// Tema, huruf, dan MediaQuery diambil dari [context], supaya teks di
/// gambarnya sama dengan di layar.
class OffscreenRender {
  OffscreenRender(BuildContext context)
    : _themes = context,
      _media = MediaQuery.maybeOf(context) ?? const MediaQueryData();

  final BuildContext _themes;
  final MediaQueryData _media;

  /// PNG [child] berukuran [size] (piksel logis), dengan kerapatan [pixelRatio].
  Future<Uint8List?> png(Widget child, Size size, {double pixelRatio = 2}) async {
    final boundary = RenderRepaintBoundary();
    final view =
        ui.PlatformDispatcher.instance.implicitView ?? ui.PlatformDispatcher.instance.views.first;
    final renderView = RenderView(
      view: view,
      child: RenderPositionedBox(alignment: Alignment.topLeft, child: boundary),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        physicalConstraints: BoxConstraints.tight(size * pixelRatio),
        devicePixelRatio: pixelRatio,
      ),
    );
    final pipeline = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();
    final build = BuildOwner(focusManager: FocusManager());
    final tree = InheritedTheme.captureAll(
      _themes,
      MediaQuery(
        data: _media.copyWith(size: size, textScaler: TextScaler.noScaling),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 14),
            child: SizedBox.fromSize(size: size, child: child),
          ),
        ),
      ),
    );
    final root = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: tree,
    ).attachToRenderTree(build);

    void frame() {
      build
        ..buildScope(root)
        ..finalizeTree();
      pipeline
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();
    }

    // Gambar yang sudah ada di cache baru terpasang sesudah satu putaran
    // mikrotask; bingkai kedua memastikan gambarnya ikut tergambar.
    frame();
    await Future<void>.delayed(const Duration(milliseconds: 16));
    frame();
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    // Melepas pohonnya supaya State di dalamnya dibuang.
    RenderObjectToWidgetAdapter<RenderBox>(container: boundary).attachToRenderTree(build, root);
    build.finalizeTree();
    return data?.buffer.asUint8List();
  }
}
