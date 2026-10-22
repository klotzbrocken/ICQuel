import Foundation
import AppKit

/// A theme pack is a data-only folder (or .zip) with a `theme.json` manifest plus optional `img/*.png`, `sounds/*.wav`,
/// `dialogs.json` (dialog templates for the classic layout) and `icon.png` (Dock icon). It never contains code.
struct ThemePack: Codable {
    var id: String; var name: String
    var base: String?                 // "classic" (default) or "modern": which window style the pack decorates
    var author: String?; var version: String?
    var sounds: [String: String]?     // event -> sound file name (without .wav)
    var fanMade: Bool?                // shown as "Fan Made Theme"; themes whose name contains "ICQ" are always treated as fan made
    var isFanMade: Bool { fanMade ?? name.lowercased().contains("icq") }
}

enum Assets {
    static var packsDir: URL { Persist.dir.appendingPathComponent("Themes") }
    private static let key = "theme_pack"
    private static var cachedDialogs: (id: String, json: [String: Any])?

    // MARK: installed packs
    static func installed() -> [(pack: ThemePack, dir: URL)] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: packsDir, includingPropertiesForKeys: nil) else { return [] }
        return items.compactMap { dir in
            guard let d = try? Data(contentsOf: dir.appendingPathComponent("theme.json")), let p = try? JSONDecoder().decode(ThemePack.self, from: d) else { return nil }
            return (p, dir)
        }.sorted { $0.pack.name.lowercased() < $1.pack.name.lowercased() }
    }
    static var activeId: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { if let v = newValue { UserDefaults.standard.set(v, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) } }
    }
    static var active: (pack: ThemePack, dir: URL)? { activeId.flatMap { id in installed().first { $0.pack.id == id } } }

    // MARK: theme choices (built-in + installed)
    struct Choice: Identifiable { var id: String; var title: String }
    static func choices() -> [Choice] {
        Theme.allCases.map { Choice(id: $0.rawValue, title: $0.title) } + installed().map { Choice(id: "pack:" + $0.pack.id, title: $0.pack.name + ($0.pack.isFanMade ? " (Fan Made)" : "")) }
    }
    static func currentChoiceId() -> String { active.map { "pack:" + $0.pack.id } ?? Theme.current.rawValue }
    /// Applies a choice: built-in theme or an installed pack (which also decides the base window style).
    static func select(_ choice: String) {
        if choice.hasPrefix("pack:"), let p = installed().first(where: { "pack:" + $0.pack.id == choice }) {
            activeId = p.pack.id; Theme.current = Theme(rawValue: p.pack.base ?? "classic") ?? .classic
        } else { activeId = nil; Theme.current = Theme(rawValue: choice) ?? .classic }
        reload()
    }
    static func reload() { clearImageCache(); cachedDialogs = nil; applyIcon() }
    static func applyIcon() {
        if let a = active, let img = NSImage(contentsOf: a.dir.appendingPathComponent("icon.png")) { NSApp.applicationIconImage = img } else if let f = resource("", "icon.png"), let img = NSImage(contentsOfFile: f) { NSApp.applicationIconImage = img } else { NSApp.applicationIconImage = nil }
    }

    // MARK: lookup (pack first, then the built-in files)
    static func resource(_ sub: String, _ file: String) -> String? {
        let fm = FileManager.default
        var dirs: [String] = []
        if let a = active { dirs.append(a.dir.path + "/" + sub) }
        if let r = Bundle.main.resourcePath { dirs.append(r + "/" + sub) }
        return dirs.map { $0 + "/" + file }.first { fm.fileExists(atPath: $0) }
    }
    static func soundNames() -> [String] {
        let fm = FileManager.default
        var dirs: [String] = []
        if let a = active { dirs.append(a.dir.path + "/sounds") }
        if let r = Bundle.main.resourcePath { dirs.append(r + "/sounds") }
        var set = Set<String>()
        for d in dirs { for f in (try? fm.contentsOfDirectory(atPath: d)) ?? [] where f.lowercased().hasSuffix(".wav") { set.insert(String(f.dropLast(4)).lowercased()) } }
        return set.sorted()
    }
    /// Dialog templates exist only in packs; without them the built-in layouts are used.
    static func dialogs() -> [String: Any]? {
        guard let a = active else { return nil }
        if let c = cachedDialogs, c.id == a.pack.id { return c.json }
        guard let d = try? Data(contentsOf: a.dir.appendingPathComponent("dialogs.json")), let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { return nil }
        cachedDialogs = (a.pack.id, j); return j
    }

    // MARK: import / remove
    struct ImportError: LocalizedError { let errorDescription: String? }
    private static let allowed: Set<String> = ["png", "wav", "json", "txt", "md"]

    @discardableResult static func importPack(from src: URL) throws -> ThemePack {
        let fm = FileManager.default
        var root = src, temp: URL?
        defer { if let t = temp { try? fm.removeItem(at: t) } }
        if src.pathExtension.lowercased() == "zip" {
            let t = fm.temporaryDirectory.appendingPathComponent("icquel-import-\(UUID().uuidString)")
            try fm.createDirectory(at: t, withIntermediateDirectories: true); temp = t
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto"); p.arguments = ["-x", "-k", src.path, t.path]
            try p.run(); p.waitUntilExit()
            guard p.terminationStatus == 0 else { throw ImportError(errorDescription: "The zip file could not be unpacked.") }
            root = t
            if !fm.fileExists(atPath: t.appendingPathComponent("theme.json").path), let sub = try? fm.contentsOfDirectory(at: t, includingPropertiesForKeys: nil).first(where: { fm.fileExists(atPath: $0.appendingPathComponent("theme.json").path) }) { root = sub }
        }
        guard let d = try? Data(contentsOf: root.appendingPathComponent("theme.json")), let pack = try? JSONDecoder().decode(ThemePack.self, from: d) else {
            throw ImportError(errorDescription: "No valid theme.json found. A theme needs a theme.json with at least \"id\" and \"name\".")
        }
        let id = pack.id.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." }
        guard !id.isEmpty, !id.hasPrefix("."), id == pack.id else { throw ImportError(errorDescription: "The theme id may only contain letters, digits, - _ and .") }
        // copy only plain data files; no links, no code, size limited
        let dest = packsDir.appendingPathComponent(id)
        try? fm.removeItem(at: dest)
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        var total = 0
        guard let en = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]) else { throw ImportError(errorDescription: "The folder could not be read.") }
        for case let f as URL in en {
            let v = try f.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard v.isSymbolicLink != true, v.isRegularFile == true, allowed.contains(f.pathExtension.lowercased()) else { continue }
            total += v.fileSize ?? 0
            guard total < 80_000_000 else { try? fm.removeItem(at: dest); throw ImportError(errorDescription: "The theme is larger than 80 MB.") }
            let rel = String(f.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))
            guard !rel.contains("..") else { continue }
            let target = dest.appendingPathComponent(rel)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: f, to: target)
        }
        return pack
    }
    static func removePack(id: String) {
        try? FileManager.default.removeItem(at: packsDir.appendingPathComponent(id))
        if activeId == id { select("classic") }
    }
}
