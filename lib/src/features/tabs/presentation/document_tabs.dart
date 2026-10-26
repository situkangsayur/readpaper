import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/utils/layout_size.dart';

/// Tab dokumen seperti di Zotero: library selalu jadi tab pertama, setiap
/// dokumen yang dibuka jadi tab di sebelahnya, dan sebuah tab bisa dipindah
/// ke panel kanan supaya dua dokumen terbaca berdampingan.
///
/// Setiap tab punya Navigator-nya sendiri. Layar dokumen tetap layar biasa —
/// `Navigator.pop` dari tombol kembalinya, dari "Simpan", atau dari dialog
/// "buang perubahan?" menutup tabnya, dan layar yang ia buka sendiri tetap di
/// dalam tab itu. Di bawah layarnya ada satu rute kosong, supaya tombol
/// kembali dan [PopScope] miliknya bekerja persis seperti saat ia masih
/// didorong ke Navigator akar.

enum TabSide { left, right }

/// Satu tab dokumen.
class DocumentTab {
  DocumentTab({
    required this.id,
    required this.dedupeKey,
    required this.title,
    required this.icon,
    required this.side,
    required this.route,
    GlobalKey<NavigatorState>? navigatorKey,
    GlobalKey? subtreeKey,
  }) : navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>(),
       subtreeKey = subtreeKey ?? GlobalKey();

  final int id;

  /// Biasanya jalur berkasnya: membuka berkas yang sama dua kali memilih tab
  /// yang sudah ada, bukan membuat tab kembar.
  final String? dedupeKey;
  final String title;
  final IconData icon;
  final TabSide side;

  /// Rute layar dokumennya; `popped` selesai saat tab ini ditutup.
  final Route<Object?> route;

  final GlobalKey<NavigatorState> navigatorKey;

  /// Menjaga isi tab tetap hidup saat ia pindah panel.
  final GlobalKey subtreeKey;

  DocumentTab movedTo(TabSide to) => DocumentTab(
    id: id,
    dedupeKey: dedupeKey,
    title: title,
    icon: icon,
    side: to,
    route: route,
    navigatorKey: navigatorKey,
    subtreeKey: subtreeKey,
  );
}

/// Id tab library; selalu di panel kiri dan tidak bisa ditutup.
const int libraryTabId = 0;

@immutable
class DocumentTabsState {
  const DocumentTabsState({
    this.tabs = const <DocumentTab>[],
    this.activeLeft = libraryTabId,
    this.activeRight,
    this.focused = TabSide.left,
    this.split = 0.5,
    this.atBottom = false,
  });

  final List<DocumentTab> tabs;
  final int activeLeft;
  final int? activeRight;

  /// Panel yang terakhir disentuh; tab baru terbuka di sini.
  final TabSide focused;

  /// Lebar panel kiri sebagai bagian dari seluruh lebar.
  final double split;

  /// Bilah tab di bawah, bukan di atas.
  ///
  /// Saat layar tablet dibagikan lewat Google Meet, gelembung dan jendela
  /// kecil Meet menutupi pojok atas — persis tempat tab library dan tombol
  /// belah layar. Di bawah keduanya tetap terjangkau.
  final bool atBottom;

  Iterable<DocumentTab> on(TabSide side) => tabs.where((t) => t.side == side);

  bool get isSplit => tabs.any((t) => t.side == TabSide.right);

  int? activeOn(TabSide side) => side == TabSide.left ? activeLeft : activeRight;

  DocumentTab? byId(int id) => tabs.where((t) => t.id == id).firstOrNull;

  DocumentTabsState copyWith({
    List<DocumentTab>? tabs,
    int? activeLeft,
    int? Function()? activeRight,
    TabSide? focused,
    double? split,
    bool? atBottom,
  }) => DocumentTabsState(
    tabs: tabs ?? this.tabs,
    activeLeft: activeLeft ?? this.activeLeft,
    activeRight: activeRight == null ? this.activeRight : activeRight(),
    focused: focused ?? this.focused,
    split: split ?? this.split,
    atBottom: atBottom ?? this.atBottom,
  );
}

class DocumentTabsController extends Notifier<DocumentTabsState> {
  int _nextId = 1;

  /// Ada [DocumentTabsHost] yang sedang tampil; tanpa itu dokumen didorong ke
  /// Navigator biasa.
  bool hostMounted = false;

  @override
  DocumentTabsState build() => const DocumentTabsState();

  /// Dipanggil saat letak bilah tab dipilih dari menu tab, supaya pilihan
  /// itu bisa disimpan; dipasang oleh aplikasi.
  void Function(bool atBottom)? onBarPositionChanged;

  void setAtBottom(bool value) {
    if (state.atBottom != value) state = state.copyWith(atBottom: value);
  }

  void toggleBarPosition() {
    setAtBottom(!state.atBottom);
    onBarPositionChanged?.call(state.atBottom);
  }

  TabSide? _nextSide;
  DateTime? _nextSideAt;

  /// Dokumen berikutnya dibuka di panel [side] — dari menu "Buka di panel
  /// kanan", tanpa setiap layar pembuka perlu tahu tentang panel.
  ///
  /// Hanya berlaku sebentar: pilihan yang tidak berakhir dengan dokumen yang
  /// terbuka (berkas yang diserahkan ke aplikasi lain) tidak boleh diam-diam
  /// menentukan tempat dokumen yang dibuka jauh sesudahnya.
  void openNextOn(TabSide side) {
    _nextSide = side;
    _nextSideAt = DateTime.now();
  }

  TabSide? _takeNextSide() {
    final side = _nextSide;
    final at = _nextSideAt;
    _nextSide = null;
    _nextSideAt = null;
    if (side == null || at == null) return null;
    return DateTime.now().difference(at) < const Duration(seconds: 3) ? side : null;
  }

  /// Membuka [screen] di tab baru di panel yang sedang aktif.
  Future<T?> open<T>(
    Widget screen, {
    required String title,
    required IconData icon,
    String? dedupeKey,
  }) {
    final wanted = _takeNextSide();
    if (dedupeKey != null) {
      final existing = state.tabs.where((t) => t.dedupeKey == dedupeKey).firstOrNull;
      if (existing != null) {
        if (wanted != null && existing.side != wanted) {
          moveTo(existing.id, wanted);
        } else {
          activate(existing.id);
        }
        return existing.route.popped.then((value) => value is T ? value : null);
      }
    }
    final route = MaterialPageRoute<T>(builder: (_) => screen);
    final side = wanted ?? state.focused;
    final tab = DocumentTab(
      id: _nextId++,
      dedupeKey: dedupeKey,
      title: title,
      icon: icon,
      side: side,
      route: route,
    );
    state = state.copyWith(
      tabs: <DocumentTab>[...state.tabs, tab],
      activeLeft: side == TabSide.left ? tab.id : null,
      activeRight: side == TabSide.right ? () => tab.id : null,
      focused: side,
    );
    // Layarnya menutup dirinya sendiri (kembali, Simpan, …) atau ditutup
    // lewat [close]: keduanya lewat sini.
    route.popped.then((_) => _remove(tab.id));
    return route.popped;
  }

  void activate(int id) {
    if (id == libraryTabId) {
      state = state.copyWith(activeLeft: libraryTabId, focused: TabSide.left);
      return;
    }
    final tab = state.byId(id);
    if (tab == null) return;
    state = tab.side == TabSide.left
        ? state.copyWith(activeLeft: id, focused: TabSide.left)
        : state.copyWith(activeRight: () => id, focused: TabSide.right);
  }

  void focus(TabSide side) {
    if (state.focused != side) state = state.copyWith(focused: side);
  }

  void setSplit(double fraction) => state = state.copyWith(split: fraction.clamp(0.2, 0.8));

  /// Menutup tab [id] seperti menekan tombol kembali di layarnya: layar yang
  /// menolak (perubahan belum disimpan) tetap bisa bertanya dulu.
  Future<void> close(int id) async {
    final tab = state.byId(id);
    final navigator = tab?.navigatorKey.currentState;
    if (tab == null) return;
    if (navigator == null) {
      _remove(id);
      return;
    }
    navigator.popUntil((route) => route == tab.route || route.isFirst);
    await navigator.maybePop();
  }

  /// Tombol kembali sistem: mundur di dalam tab yang aktif.
  Future<bool> back() async {
    final id = state.activeOn(state.focused);
    final tab = id == null ? null : state.byId(id);
    final navigator = tab?.navigatorKey.currentState;
    if (navigator == null) return false;
    await navigator.maybePop();
    return true;
  }

  Future<void> closeOthers(int keep) async {
    for (final tab in List<DocumentTab>.of(state.tabs)) {
      if (tab.id != keep) await close(tab.id);
    }
  }

  void moveTo(int id, TabSide side) {
    final tab = state.byId(id);
    if (tab == null || tab.side == side) return;
    final moved = tab.movedTo(side);
    final tabs = <DocumentTab>[
      for (final t in state.tabs)
        if (t.id == id) moved else t,
    ];
    var next = state.copyWith(tabs: tabs);
    next = side == TabSide.right
        ? next.copyWith(
            activeRight: () => id,
            activeLeft: state.activeLeft == id ? _neighbour(next, TabSide.left, id) : null,
            focused: TabSide.right,
          )
        : next.copyWith(
            activeLeft: id,
            activeRight: () => state.activeRight == id
                ? _neighbourOrNull(next, TabSide.right, id)
                : state.activeRight,
            focused: TabSide.left,
          );
    state = next;
  }

  /// Ctrl+Tab: tab berikutnya di panel yang aktif.
  void cycle(int step) {
    final side = state.focused;
    final ids = <int>[if (side == TabSide.left) libraryTabId, for (final t in state.on(side)) t.id];
    if (ids.length < 2) return;
    final at = ids.indexOf(state.activeOn(side) ?? ids.first);
    activate(ids[(at + step) % ids.length]);
  }

  void _remove(int id) {
    final tab = state.byId(id);
    if (tab == null) return;
    final rest = <DocumentTab>[
      for (final t in state.tabs)
        if (t.id != id) t,
    ];
    var next = state.copyWith(tabs: rest);
    if (state.activeLeft == id) {
      next = next.copyWith(activeLeft: _neighbour(next, TabSide.left, id, from: state));
    }
    if (state.activeRight == id) {
      next = next.copyWith(
        activeRight: () => _neighbourOrNull(next, TabSide.right, id, from: state),
      );
    }
    if (!next.isSplit) next = next.copyWith(activeRight: () => null, focused: TabSide.left);
    state = next;
  }

  /// Tab yang dipilih sesudah [id] meninggalkan panelnya: yang di sebelah
  /// kirinya, seperti di peramban.
  int _neighbour(DocumentTabsState next, TabSide side, int id, {DocumentTabsState? from}) =>
      _neighbourOrNull(next, side, id, from: from) ?? libraryTabId;

  int? _neighbourOrNull(DocumentTabsState next, TabSide side, int id, {DocumentTabsState? from}) {
    final before = (from ?? state).on(side).map((t) => t.id).toList();
    final after = next.on(side).map((t) => t.id).toList();
    if (after.isEmpty) return null;
    final at = before.indexOf(id);
    if (at <= 0) return after.first;
    return after[(at - 1).clamp(0, after.length - 1)];
  }
}

final documentTabsProvider = NotifierProvider<DocumentTabsController, DocumentTabsState>(
  DocumentTabsController.new,
);

/// Membuka [screen] sebagai tab bila ada tempatnya, atau mendorongnya ke
/// Navigator seperti biasa di ponsel (satu panel, tidak ada ruang untuk bilah
/// tab).
Future<T?> openDocument<T>(
  BuildContext context,
  Widget screen, {
  required String title,
  IconData icon = Icons.description_outlined,
  String? dedupeKey,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final tabs = container.read(documentTabsProvider.notifier);
  if (!canUseTabs(context)) {
    tabs._takeNextSide();
    return Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => screen));
  }
  return tabs.open<T>(screen, title: title, icon: icon, dedupeKey: dedupeKey);
}

/// Dokumen terbuka sebagai tab di sini — bukan di ponsel, yang hanya punya
/// satu layar penuh. Menu "Buka di panel kanan" hanya ditawarkan bila ini
/// benar.
bool canUseTabs(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  return container.read(documentTabsProvider.notifier).hostMounted &&
      !LayoutSize.of(context).isCompact;
}

/// Membuka dokumen lewat [open] di panel kanan, berdampingan dengan yang
/// sudah terbuka.
void openOnRight(BuildContext context, void Function() open) {
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(documentTabsProvider.notifier).openNextOn(TabSide.right);
  open();
}

/// Menu buka di [position] — dari tekan lama atau klik kanan: di tab baru,
/// atau di panel kanan supaya berdampingan dengan yang sedang terbuka.
///
/// Dibutuhkan saat tombol di pojok layar tertutup gelembung berbagi layar,
/// dan sebagai jalan pintas ke panel kanan tanpa menyeret tab.
Future<void> showOpenMenu(
  BuildContext context,
  Offset position,
  void Function() open, {
  String? openLabel,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final tabs = canUseTabs(context);
  final chosen = await showMenu<int>(
    context: context,
    position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & overlay.size),
    items: <PopupMenuEntry<int>>[
      PopupMenuItem<int>(
        value: 0,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.open_in_new, size: 18),
          title: Text(openLabel ?? (tabs ? context.l10n.tabsOpenNew : context.l10n.tabsOpen)),
        ),
      ),
      if (tabs)
        PopupMenuItem<int>(
          value: 1,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.vertical_split_outlined, size: 18),
            title: Text(context.l10n.tabsOpenRight),
          ),
        ),
    ],
  );
  if (!context.mounted) return;
  if (chosen == 0) open();
  if (chosen == 1) openOnRight(context, open);
}

/// Bilah tab di atas, lalu satu atau dua panel di bawahnya.
class DocumentTabsHost extends ConsumerStatefulWidget {
  const DocumentTabsHost({required this.library, super.key});

  /// Isi tab library — layar beranda.
  final Widget library;

  @override
  ConsumerState<DocumentTabsHost> createState() => _DocumentTabsHostState();
}

class _DocumentTabsHostState extends ConsumerState<DocumentTabsHost> {
  final GlobalKey _libraryKey = GlobalKey();
  late final DocumentTabsController _controller = ref.read(documentTabsProvider.notifier);

  @override
  void initState() {
    super.initState();
    _controller.hostMounted = true;
  }

  @override
  void dispose() {
    _controller.hostMounted = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentTabsProvider);
    final controller = ref.read(documentTabsProvider.notifier);
    final library = KeyedSubtree(key: _libraryKey, child: widget.library);

    // Belum ada dokumen yang terbuka: beranda apa adanya, tanpa bilah tab
    // yang hanya berisi satu tab.
    if (state.tabs.isEmpty) return library;

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const dividerWidth = 6.0;
        final leftWidth = state.isSplit ? (width - dividerWidth) * state.split : width;
        final strip = SafeArea(
          // Bilah tab mengambil jarak bilah status (di atas) atau bilah
          // navigasi (di bawah); layar di panel tidak perlu menyisakannya lagi.
          top: !state.atBottom,
          bottom: state.atBottom,
          child: SizedBox(
            height: 38,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: state.isSplit ? leftWidth + dividerWidth / 2 : width,
                  child: _TabStrip(side: TabSide.left, showLibrary: true),
                ),
                if (state.isSplit)
                  Expanded(child: _TabStrip(side: TabSide.right, showLibrary: false)),
              ],
            ),
          ),
        );
        return Column(
          children: <Widget>[
            if (!state.atBottom) ...<Widget>[
              Material(color: Theme.of(context).colorScheme.surfaceContainer, child: strip),
              const Divider(height: 1),
            ],
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: !state.atBottom,
                removeBottom: state.atBottom,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: leftWidth,
                      child: _Pane(
                        side: TabSide.left,
                        children: <int, Widget>{
                          libraryTabId: library,
                          for (final tab in state.on(TabSide.left)) tab.id: _TabBody(tab: tab),
                        },
                        active: state.activeLeft,
                      ),
                    ),
                    if (state.isSplit) ...<Widget>[
                      _SplitHandle(
                        width: dividerWidth,
                        onDrag: (dx) =>
                            controller.setSplit((leftWidth + dx) / (width - dividerWidth)),
                      ),
                      Expanded(
                        child: _Pane(
                          side: TabSide.right,
                          children: <int, Widget>{
                            for (final tab in state.on(TabSide.right)) tab.id: _TabBody(tab: tab),
                          },
                          active: state.activeRight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (state.atBottom) ...<Widget>[
              const Divider(height: 1),
              Material(color: Theme.of(context).colorScheme.surfaceContainer, child: strip),
            ],
          ],
        );
      },
    );

    return PopScope(
      // Tombol kembali Android mundur di dalam tab yang aktif dulu; baru di
      // tab library ia keluar dari aplikasi.
      canPop: state.activeOn(state.focused) == libraryTabId,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.back();
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.tab, control: true): () => controller.cycle(1),
          const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true): () =>
              controller.cycle(-1),
          const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
            final id = state.activeOn(state.focused);
            if (id != null && id != libraryTabId) controller.close(id);
          },
        },
        child: Material(child: content),
      ),
    );
  }
}

/// Satu panel: isi semua tabnya tetap hidup, hanya yang aktif terlihat.
class _Pane extends ConsumerWidget {
  const _Pane({required this.side, required this.children, required this.active});

  final TabSide side;
  final Map<int, Widget> children;
  final int? active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = children.keys.toList();
    final index = active == null ? -1 : ids.indexOf(active!);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ref.read(documentTabsProvider.notifier).focus(side),
      child: LayoutBuilder(
        // Layar di dalam panel menata dirinya menurut lebar panel, bukan lebar
        // jendela: setengah layar desktop adalah tablet, bukan desktop.
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(size: Size(constraints.maxWidth, constraints.maxHeight)),
            child: index < 0
                ? _EmptyPane(side: side)
                : IndexedStack(
                    index: index,
                    sizing: StackFit.expand,
                    children: <Widget>[for (final id in ids) children[id]!],
                  ),
          );
        },
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.side});

  final TabSide side;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        context.l10n.tabsSplitHint,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

/// Isi satu tab: Navigator-nya sendiri, dengan rute kosong di bawah layar
/// dokumennya. Pesan (SnackBar) tampil di tab ini, bukan di semua panel.
class _TabBody extends StatelessWidget {
  const _TabBody({required this.tab});

  final DocumentTab tab;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: tab.subtreeKey,
    child: ScaffoldMessenger(
      child: HeroControllerScope.none(
        child: Navigator(
          key: tab.navigatorKey,
          onGenerateInitialRoutes: (_, _) => <Route<Object?>>[
            PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox.shrink()),
            tab.route,
          ],
        ),
      ),
    ),
  );
}

class _TabStrip extends ConsumerWidget {
  const _TabStrip({required this.side, required this.showLibrary});

  final TabSide side;
  final bool showLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentTabsProvider);
    final controller = ref.read(documentTabsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final focused = state.focused == side && state.isSplit;
    final barPosition = (
      state.atBottom ? context.l10n.tabsBarToTop : context.l10n.tabsBarToBottom,
      state.atBottom ? Icons.vertical_align_top : Icons.vertical_align_bottom,
      controller.toggleBarPosition,
    );
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => state.byId(details.data)?.side != side,
      onAcceptWithDetails: (details) => controller.moveTo(details.data, side),
      builder: (context, candidates, _) => Container(
        color: candidates.isNotEmpty
            ? scheme.primaryContainer
            : focused
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainer,
        child: Row(
          children: <Widget>[
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: <Widget>[
                    if (showLibrary)
                      _TabChip(
                        title: context.l10n.tabsLibrary,
                        icon: Icons.local_library_outlined,
                        selected: state.activeLeft == libraryTabId,
                        onTap: () => controller.activate(libraryTabId),
                        menu: <(String, IconData, VoidCallback)>[barPosition],
                      ),
                    for (final tab in state.on(side))
                      Draggable<int>(
                        data: tab.id,
                        axis: Axis.horizontal,
                        affinity: Axis.horizontal,
                        feedback: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(6),
                          child: _TabChip(
                            title: tab.title,
                            icon: tab.icon,
                            selected: true,
                            onTap: () {},
                          ),
                        ),
                        child: _TabChip(
                          title: tab.title,
                          icon: tab.icon,
                          selected: state.activeOn(side) == tab.id,
                          onTap: () => controller.activate(tab.id),
                          onClose: () => controller.close(tab.id),
                          menu: <(String, IconData, VoidCallback)>[
                            if (side == TabSide.left)
                              (
                                context.l10n.tabsMoveRight,
                                Icons.vertical_split_outlined,
                                () => controller.moveTo(tab.id, TabSide.right),
                              )
                            else
                              (
                                context.l10n.tabsMoveLeft,
                                Icons.vertical_split_outlined,
                                () => controller.moveTo(tab.id, TabSide.left),
                              ),
                            (
                              context.l10n.tabsCloseOthers,
                              Icons.tab_unselected,
                              () => controller.closeOthers(tab.id),
                            ),
                            (context.l10n.tabsClose, Icons.close, () => controller.close(tab.id)),
                            barPosition,
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Membelah layar tanpa harus tahu menu tab: tab yang aktif di kiri
            // pindah ke kanan.
            if (side == TabSide.left && !state.isSplit && state.activeLeft != libraryTabId)
              IconButton(
                tooltip: context.l10n.tabsMoveRight,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.vertical_split_outlined),
                onPressed: () => controller.moveTo(state.activeLeft, TabSide.right),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.onClose,
    this.menu = const <(String, IconData, VoidCallback)>[],
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClose;
  final List<(String, IconData, VoidCallback)> menu;

  Future<void> _showMenu(BuildContext context, Offset position) async {
    if (menu.isEmpty) return;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final chosen = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & overlay.size),
      items: <PopupMenuEntry<int>>[
        for (var i = 0; i < menu.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(menu[i].$2, size: 18),
              title: Text(menu[i].$1),
            ),
          ),
      ],
    );
    if (chosen != null) menu[chosen].$3();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.labelMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Listener(
        // Klik tengah menutup tab, seperti di peramban dan Zotero.
        onPointerDown: (event) {
          if (event.buttons == kMiddleMouseButton) onClose?.call();
        },
        child: Material(
          color: selected ? scheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            onSecondaryTapUp: (details) => _showMenu(context, details.globalPosition),
            onLongPress: () {
              final box = context.findRenderObject()! as RenderBox;
              _showMenu(context, box.localToGlobal(box.size.bottomLeft(Offset.zero)));
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Padding(
                padding: EdgeInsets.only(left: 10, right: onClose == null ? 10 : 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      icon,
                      size: 16,
                      color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Tooltip(
                        message: title,
                        waitDuration: const Duration(milliseconds: 600),
                        // Hanya saat tetikus diam di atasnya. Di layar sentuh
                        // tekan lama adalah menu tab; tooltip yang ikut
                        // menunggu tekan lama memenangkannya, dan menunya
                        // tidak pernah muncul.
                        triggerMode: TooltipTriggerMode.manual,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text?.copyWith(
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    if (onClose != null)
                      IconButton(
                        tooltip: context.l10n.tabsClose,
                        iconSize: 14,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(width: 26, height: 26),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close),
                        onPressed: onClose,
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

class _SplitHandle extends StatelessWidget {
  const _SplitHandle({required this.width, required this.onDrag});

  final double width;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      child: SizedBox(
        width: width,
        child: Center(child: VerticalDivider(width: 1, color: Theme.of(context).dividerColor)),
      ),
    ),
  );
}
