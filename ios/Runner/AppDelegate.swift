import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BerkasMasuk") {
      BerkasMasuk.register(with: registrar)
    }
  }
}

/// Menerima PDF dan EPUB yang dibuka dari aplikasi lain — "Buka di…",
/// lembar bagikan, atau aplikasi Files.
///
/// Kontraknya sama persis dengan MainActivity.kt di Android, supaya
/// incoming_file.dart tidak perlu tahu sedang berjalan di mana: kanal
/// `readpaper/berkas-masuk`, `takeInitialPdf` menjawab jalur berkas yang
/// membuka aplikasi (atau nil, hanya sekali), dan `openPdf` dikirim ke Dart
/// dengan sebuah jalur berkas saat aplikasinya sudah berjalan.
///
/// Didaftarkan sebagai plugin, bukan ditulis di SceneDelegate, karena Flutter
/// sendiri yang meneruskan peristiwa scene ke plugin — termasuk opsi koneksi
/// saat aplikasi dibuka dari keadaan mati, yang diantar ulang begitu mesinnya
/// siap. SceneDelegate tidak bisa memanggil `super` untuk metode yang tidak
/// diumumkan FlutterSceneDelegate di header-nya, jadi menimpanya di sana
/// justru memutus penerusan itu.
final class BerkasMasuk: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private let channel: FlutterMethodChannel

  /// Berkas yang datang sebelum Dart sempat bertanya.
  private var pending: String?

  /// Dart sudah memanggil `takeInitialPdf`, artinya pendengar `openPdf`-nya
  /// sudah terpasang. Sebelum itu, mengirim `openPdf` sama dengan membuangnya.
  private var dartReady = false

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "readpaper/berkas-masuk", binaryMessenger: registrar.messenger())
    let instance = BerkasMasuk(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    // Dua jalur masuk: scene untuk iOS dengan UIScene (yang dipakai templat
    // ini), dan delegasi aplikasi untuk berjaga kalau scene dimatikan.
    registrar.addApplicationDelegate(instance)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    // Dipanggil sekali saat aplikasi siap: berkas yang membuka aplikasi
    // ini, kalau ada.
    case "takeInitialPdf":
      dartReady = true
      let path = pending
      pending = nil
      result(path)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Scene

  // Selektor ditulis eksplisit: metode protokol ini opsional, dan nama Swift
  // yang meleset sedikit saja tetap terkompilasi — lalu tidak pernah dipanggil.

  /// Aplikasi dibuka dari keadaan mati dengan sebuah berkas.
  @objc(scene:willConnectToSession:options:)
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let contexts = connectionOptions?.urlContexts else { return false }
    return receive(contexts)
  }

  /// Aplikasi sudah berjalan (atau tertidur) dan sebuah berkas dibuka.
  @objc(scene:openURLContexts:)
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    return receive(URLContexts)
  }

  // MARK: - Aplikasi tanpa scene

  @objc(application:openURL:options:)
  func application(
    _ application: UIApplication, open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let inPlace = options[.openInPlace] as? Bool ?? false
    guard let path = copyIncoming(url, inPlace: inPlace) else { return false }
    deliver(path)
    return true
  }

  // MARK: - Penyalinan

  private func receive(_ contexts: Set<UIOpenURLContext>) -> Bool {
    var handled = false
    for context in contexts where context.url.isFileURL {
      if let path = copyIncoming(context.url, inPlace: context.options.openInPlace) {
        deliver(path)
        handled = true
      }
    }
    return handled
  }

  /// Jalurnya dikirim langsung kalau Dart sudah mendengarkan; kalau belum,
  /// disimpan untuk jawaban `takeInitialPdf`.
  private func deliver(_ path: String) {
    if dartReady {
      channel.invokeMethod("openPdf", arguments: path)
    } else {
      pending = path
    }
  }

  /// Menyalin berkas masuk ke cache, mengembalikan jalurnya.
  ///
  /// Berkas yang dibuka di tempat (dari Files, iCloud Drive, penyedia lain)
  /// hanya boleh dibaca selama akses security-scoped-nya dibuka, dan bisa
  /// berubah atau hilang setelahnya — jadi isinya disalin, sama seperti
  /// Android menyalin `content://` URI. Yang bukan di tempat sudah lebih dulu
  /// disalin iOS ke Documents/Inbox; salinan itu dihapus setelah dipindah,
  /// kalau tidak ia menumpuk dan ikut terlihat di aplikasi Files.
  private func copyIncoming(_ url: URL, inPlace: Bool) -> String? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    let fm = FileManager.default
    guard let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else {
      return nil
    }
    let dir = caches.appendingPathComponent("masuk", isDirectory: true)
    var name = url.lastPathComponent
    if name.isEmpty || name == "/" { name = "dokumen" }
    // Akhirannya yang menentukan pembaca mana yang membuka berkasnya di sisi
    // Dart, jadi nama tanpa akhiran yang dikenal diberi akhiran dari tipenya —
    // sama seperti di Android, bukan selalu ".pdf".
    let ext = (name as NSString).pathExtension.lowercased()
    if ext != "pdf" && ext != "epub" { name += extensionFor(url) }
    let target = dir.appendingPathComponent(name)

    var copied = false
    // NSFileCoordinator menunggu berkas iCloud yang belum terunduh, alih-alih
    // menyalin berkas kosong.
    var coordinatorError: NSError?
    NSFileCoordinator().coordinate(
      readingItemAt: url, options: [.withoutChanges], error: &coordinatorError
    ) { readable in
      do {
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
        try fm.copyItem(at: readable, to: target)
        copied = true
      } catch {
        copied = false
      }
    }
    guard copied, coordinatorError == nil else { return nil }

    if !inPlace, isInOwnInbox(url) { try? fm.removeItem(at: url) }
    return target.path
  }

  private func extensionFor(_ url: URL) -> String {
    let type = (try? url.resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier
    return type == "org.idpf.epub-container" ? ".epub" : ".pdf"
  }

  /// Hanya salinan milik sendiri di Documents/Inbox yang boleh dihapus —
  /// bukan berkas asli di tempat lain yang kebetulan diserahkan sebagai salinan.
  private func isInOwnInbox(_ url: URL) -> Bool {
    guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    else { return false }
    let inbox = docs.appendingPathComponent("Inbox", isDirectory: true)
      .resolvingSymlinksInPath().path
    return url.resolvingSymlinksInPath().path.hasPrefix(inbox + "/")
  }
}
