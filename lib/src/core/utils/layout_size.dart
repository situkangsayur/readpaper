import 'dart:io';

import 'package:flutter/material.dart';

/// How much room the window has, in the spirit of Material's window size
/// classes but cut where this app's three panes actually stop fitting.
///
/// The pane widths are what set the thresholds: the collection tree wants
/// ~300dp and the item list ~360dp, so a third pane only earns its place once
/// the detail pane can still be wider than the list.
enum LayoutSize {
  /// Phone portrait: one pane at a time.
  compact,

  /// Phone landscape and tablet portrait: item list beside the detail pane,
  /// with the collection tree in a drawer.
  medium,

  /// Tablet landscape and desktop: collections, list and detail side by side.
  expanded;

  static const double mediumMin = 600;
  static const double expandedMin = 1100;

  static LayoutSize of(BuildContext context) => fromWidth(MediaQuery.sizeOf(context).width);

  static LayoutSize fromWidth(double width) {
    if (width >= expandedMin) return LayoutSize.expanded;
    if (width >= mediumMin) return LayoutSize.medium;
    return LayoutSize.compact;
  }

  bool get isCompact => this == LayoutSize.compact;

  /// True while the collection tree has to live in a drawer.
  bool get treeInDrawer => this != LayoutSize.expanded;

  /// True when the item list and the detail pane are both on screen.
  bool get showsListAndDetail => this != LayoutSize.compact;
}

/// True on devices driven by fingers rather than a mouse.
///
/// Used for hit-target sizes and to leave long-press to text selection, which
/// is how a touch user selects a passage in the reader.
bool get isTouchPlatform => Platform.isAndroid || Platform.isIOS;

/// Vertical size of one row in the collection tree.
///
/// 30dp is comfortable with a mouse but misses often with a thumb, so touch
/// devices get a row that clears Material's 48dp minimum target.
double get treeRowHeight => isTouchPlatform ? 48 : 30;

/// Icon button size for the workspace bar and panes.
double get barIconSize => isTouchPlatform ? 22 : 20;
