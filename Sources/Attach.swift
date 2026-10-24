import AppKit
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Attachments for the Classic chat windows: file, Photos library picture, Giphy GIF. They wait in `Store.attachments` until Send.
enum Attach {
    static var typeSound: Bool { get { UserDefaults.standard.object(forKey: "typeSound") as? Bool ?? true } set { UserDefaults.standard.set(newValue, forKey: "typeSound") } }
    static let sizes: [CGFloat] = [10.5, 12.5, 15]
    static var sizeIndex: Int { get { min(2, max(0, UserDefaults.standard.integer(forKey: "msgSize"))) } set { UserDefaults.standard.set(newValue, forKey: "msgSize") } }

    /// Folder for downloaded pictures; Messages can read files from here (not from /tmp).
    private static var outDir: URL {
        let d = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0].appendingPathComponent("ICQuel", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true); return d
    }
    /// Messages refuses attachments above ~100 MB.
    static let maxBytes = 100 * 1_000_000
    static func add(_ uin: String, _ u: URL) {
        let size = (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        DispatchQueue.main.async {
            if size > maxBytes { notice("\(u.lastPathComponent) is larger than 100 MB and cannot be sent."); return }
            Store.shared.attachments[uin, default: []].append(u)
        }
    }

    static func pickFile(_ uin: String) {
        let p = NSOpenPanel(); p.canChooseFiles = true; p.canChooseDirectories = false; p.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        if p.runModal() == .OK, let u = p.url { add(uin, u) }
    }

    private static var picker: (NSWindow, PickDelegate)?
    private final class PickDelegate: NSObject, PHPickerViewControllerDelegate {
        let uin: String; init(_ u: String) { uin = u }
        func picker(_ p: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let uin = self.uin
            defer { Attach.picker?.0.close(); Attach.picker = nil }
            guard let r = results.first else { return }
            r.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                guard let url else { return }
                let dst = outDir.appendingPathComponent(UUID().uuidString.prefix(6) + "-" + url.lastPathComponent)
                if (try? FileManager.default.copyItem(at: url, to: dst)) != nil { add(uin, dst) }
            }
        }
    }
    static func pickPhoto(_ uin: String) {
        var cfg = PHPickerConfiguration(); cfg.filter = .images; cfg.selectionLimit = 1
        let vc = PHPickerViewController(configuration: cfg), d = PickDelegate(uin); vc.delegate = d
        let w = NSWindow(contentViewController: vc); w.title = "Photos"; w.setContentSize(NSSize(width: 560, height: 440)); w.center()
        picker = (w, d); NSApp.activate(ignoringOtherApps: true); w.makeKeyAndOrderFront(nil)
    }

    /// Giphy picker window (needs a free API key from developers.giphy.com, bundled as GiphyKey in Info.plist).
    static var giphyKey: String? {
        let k = UserDefaults.standard.string(forKey: "giphyKey") ?? (Bundle.main.object(forInfoDictionaryKey: "GiphyKey") as? String)
        return (k?.isEmpty ?? true) ? nil : k
    }
    static func giphy(_ uin: String) {
        guard giphyKey != nil else {
            ICQ.askText("Giphy", "Enter your free Giphy API key (developers.giphy.com). It is stored on this Mac only:") { UserDefaults.standard.set($0, forKey: "giphyKey"); giphy(uin) }; return
        }
        WinMgr.shared.close("gif")
        WinMgr.shared.open("gif", "Insert GIF (Giphy)", GifPicker.size.width, GifPicker.size.height) { GifPicker(uin: uin) }
    }
    struct GifHit: Identifiable { let id: String; let thumb: URL; let full: URL }
    static func search(_ q: String) async throws -> [GifHit] {
        guard let key = giphyKey else { return [] }
        var c = URLComponents(string: q.isEmpty ? "https://api.giphy.com/v1/gifs/trending" : "https://api.giphy.com/v1/gifs/search")!
        c.queryItems = [.init(name: "api_key", value: key), .init(name: "limit", value: "12"), .init(name: "rating", value: "pg-13")] + (q.isEmpty ? [] : [.init(name: "q", value: q)])
        let (d, _) = try await URLSession.shared.data(from: c.url!)
        return try parseHits(d)
    }
    /// Hits of a Giphy search/trending response; throws the API error (pure: covered by SelfTest). A rejected key is forgotten.
    static func parseHits(_ d: Data) throws -> [GifHit] {
        let root = try JSONSerialization.jsonObject(with: d) as? [String: Any]
        if let st = (root?["meta"] as? [String: Any])?["status"] as? Int, st != 200 {
            if st == 401 || st == 403 { UserDefaults.standard.removeObject(forKey: "giphyKey") }
            throw NSError(domain: "Giphy", code: st, userInfo: [NSLocalizedDescriptionKey: st == 401 || st == 403 ? "Giphy rejected the API key (\(st))." : "Giphy error \(st): \((root?["meta"] as? [String: Any])?["msg"] as? String ?? "")"])
        }
        func url(_ g: [String: Any], _ k: String) -> URL? { (((g["images"] as? [String: Any])?[k] as? [String: Any])?["url"] as? String).flatMap { URL(string: $0) } }
        return ((root?["data"] as? [[String: Any]]) ?? []).compactMap { g in
            guard let id = g["id"] as? String, let t = url(g, "fixed_width_small"), let f = url(g, "downsized") else { return nil }
            return GifHit(id: id, thumb: t, full: f)
        }
    }
    static func take(_ hit: GifHit, _ uin: String) {
        Task {
            do {
                let (g, _) = try await URLSession.shared.data(from: hit.full)
                let dst = outDir.appendingPathComponent("giphy-" + hit.id + ".gif"); try g.write(to: dst); add(uin, dst)
                DispatchQueue.main.async { WinMgr.shared.close("gif") }
            } catch { DispatchQueue.main.async { notice("Giphy failed: \(error.localizedDescription)") } }
        }
    }

    /// Entries of the first "More" button / "More Functions" menu of the Classic chat windows.
    static func moreItems(_ uin: String, openSend: Bool = false) -> [NSMenuItem] {
        func go(_ f: @escaping () -> Void) -> () -> Void { { if openSend { ICQ.openSend(uin) }; f() } }
        let n = Store.shared.attachments[uin]?.count ?? 0
        var m: [NSMenuItem] = [MItem("Generate New AI Answer", enabled: Store.shared.aiEnabled, fn: go { if let c = Store.shared.contact(uin) { Store.shared.prepareDraft(for: c, force: true) } }),
                 MItem("Insert GIF (Giphy)…", fn: go { giphy(uin) }),
                 MItem("Insert Picture (Photos)…", fn: go { pickPhoto(uin) }),
                 MItem("Insert File…", fn: go { pickFile(uin) })]
        if n > 0 { m += [NSMenuItem.separator(), MItem("Remove \(n) Attachment" + (n == 1 ? "" : "s")) { Store.shared.attachments[uin] = nil }] }
        return m
    }
}

/// Animated GIF thumbnail.
private struct GifThumb: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView(); v.animates = true; v.imageScaling = .scaleProportionallyUpOrDown
        Task { if let (d, _) = try? await URLSession.shared.data(from: url), let img = NSImage(data: d) { await MainActor.run { v.image = img } } }
        return v
    }
    func updateNSView(_ v: NSImageView, context: Context) {}
}

struct GifPicker: View {
    let uin: String
    @State private var q = ""
    @State private var hits: [Attach.GifHit] = []
    @State private var busy = false
    static let size = CGSize(width: 400, height: 420)
    private func load() {
        busy = true
        Task {
            do { let h = try await Attach.search(q.trimmingCharacters(in: .whitespaces)); await MainActor.run { hits = h; busy = false } }
            catch { await MainActor.run { busy = false; notice(error.localizedDescription) } }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                RField(placeholder: "Search Giphy (empty: trending)", text: $q)
                RButton(title: "Search", isDefault: true) { load() }
            }.frame(height: 24)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(hits) { h in
                        GifThumb(url: h.thumb).frame(height: 96).background(Color.black.opacity(0.06)).overlay(Rectangle().stroke(Color.gray.opacity(0.5)))
                            .contentShape(Rectangle()).onTapGesture { Attach.take(h, uin) }
                    }
                }
                if hits.isEmpty && !busy { Text("No results.").foregroundColor(.hint).padding(.top, 20) }
            }
            HStack { Text(busy ? "Loading…" : "Click a GIF to attach it.").foregroundColor(.hint); Spacer(); Text("Powered by GIPHY").underline().foregroundColor(.hint).onTapGesture { NSWorkspace.shared.open(URL(string: "https://giphy.com")!) }.help("giphy.com"); Spacer(); RButton(title: "Cancel") { WinMgr.shared.close("gif") } }
        }.padding(12).frame(width: GifPicker.size.width, height: GifPicker.size.height, alignment: .topLeading).onAppear { load() }
    }
}

/// Pictures / GIFs shown inline, other files as a clickable file row (icon + name).
struct AttachList: View {
    let files: [String]; var maxW: CGFloat = 240
    private static let cache = NSCache<NSString, NSImage>()
    /// Decoded pictures are kept: chat windows redraw often.
    static func image(_ path: String) -> NSImage? {
        if let i = cache.object(forKey: path as NSString) { return i }
        guard let i = NSImage(contentsOfFile: path) else { return nil }
        cache.setObject(i, forKey: path as NSString); return i
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(files, id: \.self) { f in
                let u = URL(fileURLWithPath: f), img = AttachList.image(f)
                if let img, (UTType(filenameExtension: u.pathExtension)?.conforms(to: .image) ?? false), img.size.width > 0 {
                    let w = min(maxW, img.size.width), h = w * img.size.height / img.size.width
                    InlineImage(path: f).frame(width: w, height: min(h, 260)).onTapGesture { NSWorkspace.shared.open(u) }
                } else {
                    HStack(spacing: 6) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: f)).resizable().frame(width: 20, height: 20)
                        Text(FileManager.default.fileExists(atPath: f) ? u.lastPathComponent : u.lastPathComponent + " (not available)").lineLimit(1).truncationMode(.middle)
                    }.padding(4).overlay(Rectangle().stroke(Color.gray.opacity(0.6))).contentShape(Rectangle()).onTapGesture { NSWorkspace.shared.open(u) }
                }
            }
        }
    }
}
private struct InlineImage: NSViewRepresentable {
    let path: String
    func makeNSView(context: Context) -> NSImageView { let v = NSImageView(image: NSImage(contentsOfFile: path) ?? NSImage()); v.animates = true; v.imageScaling = .scaleProportionallyUpOrDown; return v }
    func updateNSView(_ v: NSImageView, context: Context) {}
}
