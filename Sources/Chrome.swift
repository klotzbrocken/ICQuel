import SwiftUI
import AppKit

// MARK: Windows-98 window chrome (borderless NSWindow, custom title bar and 3D frame)
final class ChromeWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
final class WinInfo: ObservableObject {
    @Published var title: String; @Published var key = true; let icon: String; let small: Bool
    @Published var client: CGSize
    init(title: String, icon: String, small: Bool = false, client: CGSize) { self.title = title; self.icon = icon; self.small = small; self.client = client }
}
private final class DragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { window?.makeKeyAndOrderFront(nil); window?.performDrag(with: event) }
}
private struct DragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragNSView() }
    func updateNSView(_ v: NSView, context: Context) {}
}
private struct TBtnStyle: ButtonStyle {
    var w: CGFloat = 16, h: CGFloat = 14
    func makeBody(configuration c: Configuration) -> some View {
        c.label.frame(width: w, height: h).background(ButtonBG(pressed: c.isPressed))
            .offset(x: c.isPressed ? 1 : 0, y: c.isPressed ? 1 : 0)
    }
}
private struct TitleBar: View {
    @ObservedObject var info: WinInfo; let close: () -> Void; let mini: () -> Void
    var body: some View {
        let sm = info.small, bw: CGFloat = sm ? 13 : 16, bh: CGFloat = sm ? 11 : 14, k: CGFloat = sm ? 0.8 : 1
        HStack(spacing: 2) {
            if !info.icon.isEmpty { Pix(name: info.icon, w: 16) }
            Text(info.title).font(rf(11, bold: !sm)).foregroundColor(info.key ? .white : Color(white: 0.75)).lineLimit(1).padding(.leading, sm ? 2 : 0)
            Spacer(minLength: 0)
            Button(action: mini) { Canvas { c, _ in c.fill(Path(CGRect(x: 4 * k, y: 9 * k, width: 6 * k, height: 2)), with: .color(.black)) } }.buttonStyle(TBtnStyle(w: bw, h: bh))
            Color.clear.frame(width: 2, height: 1)
            Button(action: close) {
                Canvas { c, _ in
                    var p = Path(); p.move(to: .init(x: 4 * k, y: 3 * k)); p.addLine(to: .init(x: 11 * k, y: 10 * k)); p.move(to: .init(x: 11 * k, y: 3 * k)); p.addLine(to: .init(x: 4 * k, y: 10 * k))
                    c.stroke(p, with: .color(.black), lineWidth: sm ? 1.4 : 1.8)
                }
            }.buttonStyle(TBtnStyle(w: bw, h: bh))
        }.padding(.horizontal, 2).frame(height: sm ? 15 : 18)
            .background(info.key ? Color(red: 0, green: 0, blue: 128 / 255) : Color(white: 0.5))
    }
}
struct ChromeView<C: View>: View {
    @ObservedObject var info: WinInfo; let close: () -> Void; let mini: () -> Void; var zoom: () -> Void = {}
    @ViewBuilder var content: C
    var body: some View {
        let th: CGFloat = info.small ? 15 : 18, skin = Theme.skin
        let frame = VStack(spacing: 0) {
            Group {
                switch skin {
                case .win98: TitleBar(info: info, close: close, mini: mini)
                case .platinum: PlatinumTitleBar(info: info, close: close, mini: mini)
                case .aqua: AquaTitleBar(info: info, close: close, mini: mini, zoom: zoom)
                }
            }.padding(.top, skin == .aqua ? 0 : 4).padding(.horizontal, skin == .aqua ? 0 : 4)
            content.frame(width: info.client.width, height: info.client.height + (skin == .aqua ? 4 : 0), alignment: .topLeading).padding(.horizontal, 4).padding(.bottom, skin == .aqua ? 0 : 4)
        }.frame(width: info.client.width + 8, height: info.client.height + 8 + th, alignment: .topLeading)
            .background(Color.gray98).overlay(Bevel(raised: true, win: true))
        if skin == .aqua { frame.clipShape(RoundedRectangle(cornerRadius: 6)) } else { frame }
    }
}

/// Hosting view that turns a click on the title bar (but not on its buttons) into a window drag.
final class ChromeHost<V: View>: NSHostingView<V> {
    var dragBottom: CGFloat = 0, dragExcludeRight: CGFloat = 0, dragExcludeLeft: CGFloat = 0
    required init(rootView: V) { super.init(rootView: rootView) }
    @MainActor required dynamic init?(coder: NSCoder) { fatalError() }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    private var dragFrom: NSPoint?, winFrom: NSPoint = .zero
    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let fromTop = isFlipped ? p.y : bounds.height - p.y
        if fromTop <= dragBottom && p.x < bounds.width - dragExcludeRight && p.x > dragExcludeLeft {
            window?.makeKeyAndOrderFront(nil); dragFrom = NSEvent.mouseLocation; winFrom = window?.frame.origin ?? .zero
        } else { dragFrom = nil; super.mouseDown(with: event) }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let d = dragFrom, let w = window else { super.mouseDragged(with: event); return }
        let now = NSEvent.mouseLocation
        w.setFrameOrigin(NSPoint(x: winFrom.x + now.x - d.x, y: winFrom.y + now.y - d.y))
    }
    override func mouseUp(with event: NSEvent) { if dragFrom != nil { dragFrom = nil } else { super.mouseUp(with: event) } }
}
struct WinRoot<C: View>: View {
    @ObservedObject var info: WinInfo; let k: CGFloat; let close: () -> Void; let mini: () -> Void; var zoom: () -> Void = {}
    @ViewBuilder var content: C
    var body: some View {
        let th: CGFloat = info.small ? 15 : 18
        ChromeView(info: info, close: close, mini: mini, zoom: zoom) { content }
            .scaleEffect(k, anchor: .topLeading)
            .frame(width: (info.client.width + 8) * k, height: (info.client.height + 8 + th) * k, alignment: .topLeading)
    }
}

final class WinMgr: NSObject, NSWindowDelegate {
    static let shared = WinMgr()
    private var wins: [String: NSWindow] = [:]
    private var infos: [String: WinInfo] = [:]
    private var scales: [String: CGFloat] = [:]   // per-window scale (UI.scale, reduced when the window would not fit the screen)
    func open<V: View>(_ id: String, _ title: String, _ w: CGFloat, _ h: CGFloat, at: NSPoint? = nil, icon: String = "online", small: Bool = false, resizable: Bool = false, activate: Bool = true, _ content: () -> V) {
        if let win = wins[id] { if activate { win.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }; return }
        if Theme.isModern {
            var mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]; if resizable { mask.insert(.resizable) }
            let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: w, height: h), styleMask: mask, backing: .buffered, defer: false)
            win.contentView = NSHostingView(rootView: content())
            win.title = brand(title); win.identifier = NSUserInterfaceItemIdentifier(id); win.isReleasedWhenClosed = false; win.delegate = self
            if let p = at { win.setFrameTopLeftPoint(p) } else { win.center(); win.setFrameOrigin(NSPoint(x: win.frame.minX + .random(in: -30...30), y: win.frame.minY + .random(in: -30...30))) }
            wins[id] = win
            if activate { win.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) } else { win.orderFront(nil) }
            return
        }
        let th: CGFloat = small ? 15 : 18, title = brand(title), k = UI.fit(w, h, th)
        let info = WinInfo(title: title, icon: icon, small: small, client: CGSize(width: w, height: h))
        let win = ChromeWindow(contentRect: NSRect(x: 0, y: 0, width: ceil((w + 8) * k), height: ceil((h + 8 + th) * k)), styleMask: resizable ? [.borderless, .closable, .miniaturizable, .resizable] : [.borderless, .closable, .miniaturizable], backing: .buffered, defer: false)
        if resizable { win.contentMinSize = NSSize(width: ceil((w + 8) * k), height: ceil((h + 8 + th) * k)) }
        let host = ChromeHost(rootView: WinRoot(info: info, k: k, close: { [weak win] in win?.close() }, mini: { [weak win] in win?.miniaturize(nil) }, zoom: { [weak win] in win?.zoom(nil) }) { content().win98() })
        host.sizingOptions = []; host.dragBottom = (4 + th + 1) * k
        switch Theme.skin {
        case .win98: host.dragExcludeRight = (small ? 40 : 46) * k
        case .platinum: host.dragExcludeLeft = 22 * k; host.dragExcludeRight = 22 * k
        case .aqua: host.dragExcludeLeft = 60 * k
        }
        win.contentView = host
        win.title = title; win.identifier = NSUserInterfaceItemIdentifier(id)
        win.appearance = NSAppearance(named: .aqua); win.hasShadow = true
        if Theme.skin == .aqua { win.backgroundColor = .clear; win.isOpaque = false } else { win.backgroundColor = NSColor(Color.gray98); win.isOpaque = true }
        win.isReleasedWhenClosed = false; win.delegate = self
        if let p = at { win.setFrameTopLeftPoint(p) } else {
            win.center(); win.setFrameOrigin(NSPoint(x: win.frame.minX + .random(in: -30...30), y: win.frame.minY + .random(in: -30...30)))
        }
        wins[id] = win; infos[id] = info; scales[id] = k; win.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    /// Change the client size of an open window (keeps its top-left corner).
    func resize(_ id: String, _ w: CGFloat, _ h: CGFloat) {
        guard let win = wins[id] else { return }
        if Theme.isModern { win.setContentSize(NSSize(width: w, height: h)); return }
        guard let info = infos[id] else { return }
        let k = scales[id] ?? UI.scale, th: CGFloat = info.small ? 15 : 18, top = win.frame.maxY, left = win.frame.minX
        info.client = CGSize(width: w, height: h)
        let nw = ceil((w + 8) * k), nh = ceil((h + 8 + th) * k)
        if win.styleMask.contains(.resizable) { win.contentMinSize = NSSize(width: nw, height: nh) }
        win.setFrame(NSRect(x: left, y: top - nh, width: nw, height: nh), display: true)
        if let host = win.contentView as? NSView { host.needsLayout = true }
    }
    /// Debug aid (ICQ_SNAPSHOT=<dir>): writes every open window's contents to PNG, without touching the screen.
    func snapshot(to dir: String, prefix: String = "") {
        for (id, w) in wins {
            // composited image of this one window (own window id only), so native AppKit controls are included
            if w.windowNumber > 0, let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(w.windowNumber), [.boundsIgnoreFraming, .bestResolution]) {
                try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(prefix)\(id).png")); continue
            }
            guard let v = w.contentView, let r = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { continue }
            v.cacheDisplay(in: v.bounds, to: r)
            try? r.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(prefix)\(id).png"))
        }
    }
    func has(_ id: String) -> Bool { wins[id] != nil }
    func frame(_ id: String) -> NSRect? { wins[id]?.frame }
    /// Debug: class of the view that would receive a click at (x, y) points from the window's top-left.
    func hitClass(_ id: String, x: CGFloat, y: CGFloat) -> String? {
        guard let w = wins[id], let v = w.contentView else { return nil }
        let p = NSPoint(x: x * UI.scale, y: v.bounds.height - y * UI.scale)
        return v.hitTest(v.convert(p, from: nil)).map { String(describing: type(of: $0)) }
    }
    func close(_ id: String) { wins[id]?.close() }
    private var bulk = false
    func closeAll() { bulk = true; Array(wins.values).forEach { $0.close() }; bulk = false }
    func setTitle(_ id: String, _ t: String) { infos[id]?.title = brand(t); wins[id]?.title = brand(t) }
    func setLevel(_ id: String, _ level: NSWindow.Level) { wins[id]?.level = level }
    func levelRaw(_ id: String) -> Int? { wins[id]?.level.rawValue }
    func minimize(_ id: String) { wins[id]?.miniaturize(nil) }
    func front(_ id: String) { wins[id]?.makeKeyAndOrderFront(nil) }
    func windowWillClose(_ n: Notification) {
        if let w = n.object as? NSWindow, let id = w.identifier?.rawValue { wins[id] = nil; infos[id] = nil; scales[id] = nil; if id == "main" { if !bulk { ICQ.toMenuOnly() }; ICQ.refreshTray() } }
    }
    func windowDidResize(_ n: Notification) {
        guard !Theme.isModern, let w = n.object as? NSWindow, let id = w.identifier?.rawValue, let info = infos[id], w.styleMask.contains(.resizable) else { return }
        let k = scales[id] ?? UI.scale, th: CGFloat = info.small ? 15 : 18
        let cw = w.frame.width / k - 8, ch = w.frame.height / k - 8 - th   // exact values: no rounding, so no feedback into the window size
        if abs(cw - info.client.width) > 0.01 || abs(ch - info.client.height) > 0.01 { info.client = CGSize(width: cw, height: ch) }
    }
    func windowDidBecomeKey(_ n: Notification) { if let id = (n.object as? NSWindow)?.identifier?.rawValue { infos[id]?.key = true } }
    func windowDidResignKey(_ n: Notification) { if let id = (n.object as? NSWindow)?.identifier?.rawValue { infos[id]?.key = false } }
}

// MARK: Windows-98 popup menus
struct RMItem {
    var title = ""; var icon: String?; var checked = false; var enabled = true; var sep = false; var header = false; var bold = false
    var children: [RMItem]?; var fn: (() -> Void)?
}
final class MenuWindow: NSWindow {
    var level_ = 0
    override var canBecomeKey: Bool { false }
}
enum RMenu {
    static var wins: [MenuWindow] = []
    static var monitors: [Any] = []
    static let font = NSFont(name: "Helvetica", size: 11) ?? .systemFont(ofSize: 11)
    static func width(_ items: [RMItem]) -> CGFloat {
        let t = items.filter { !$0.sep }.map { ($0.title as NSString).size(withAttributes: [.font: font]).width + ($0.header ? 0 : 0) }.max() ?? 40
        return ceil(t) + 26 + 20 + 6 + (items.contains { $0.header } ? 10 : 0)
    }
    static func height(_ items: [RMItem]) -> CGFloat { items.reduce(6) { $0 + ($1.sep ? 6 : ($1.header ? 16 : 18)) } }

    static func show(_ items: [RMItem], at p: NSPoint, level: Int = 0) {
        if level == 0 { dismiss() } else { closeFrom(level) }
        let w = ceil(width(items) * UI.scale), h = ceil(height(items) * UI.scale)
        let win = MenuWindow(contentRect: NSRect(x: 0, y: 0, width: w, height: h), styleMask: [.borderless], backing: .buffered, defer: false)
        win.level_ = level; win.level = .popUpMenu; win.hasShadow = true; win.isOpaque = true; win.backgroundColor = NSColor(Color.gray98)
        win.appearance = NSAppearance(named: .aqua); win.isReleasedWhenClosed = false
        win.contentView = NSHostingView(rootView: RMenuView(items: items, level: level, menuWidth: width(items)).scaleEffect(UI.scale, anchor: .topLeading).frame(width: w, height: h, alignment: .topLeading))
        var o = NSPoint(x: p.x, y: p.y - h)
        if let sc = NSScreen.screens.first(where: { $0.frame.contains(p) }) ?? NSScreen.main {
            o.x = min(o.x, sc.visibleFrame.maxX - w - 2); o.y = max(o.y, sc.visibleFrame.minY + 2)
        }
        win.setFrameOrigin(o); win.orderFrontRegardless(); wins.append(win)
        if level == 0 { install() }
    }
    static func closeFrom(_ level: Int) { wins.filter { $0.level_ >= level }.forEach { $0.orderOut(nil) }; wins.removeAll { $0.level_ >= level } }
    static func dismiss() {
        wins.forEach { $0.orderOut(nil) }; wins.removeAll()
        monitors.forEach { NSEvent.removeMonitor($0) }; monitors.removeAll()
    }
    private static func install() {
        let down: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let m = NSEvent.addLocalMonitorForEvents(matching: down.union(.keyDown), handler: { e in
            if e.type == .keyDown { if e.keyCode == 53 { dismiss(); return nil }; return e }
            if !wins.contains(where: { $0 === e.window }) { dismiss() }
            return e
        }) { monitors.append(m) }
        if let g = NSEvent.addGlobalMonitorForEvents(matching: down, handler: { _ in dismiss() }) { monitors.append(g) }
    }
}
private struct RMenuView: View {
    let items: [RMItem]; let level: Int; let menuWidth: CGFloat
    @State private var hover: Int?
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                if it.sep { VStack(spacing: 0) { Color.shade.frame(height: 1); Color.white.frame(height: 1) }.frame(height: 6).padding(.horizontal, 2) }
                else if it.header {
                    HStack(spacing: 3) {
                        VStack(spacing: 0) { Color.shade.frame(height: 1); Color.white.frame(height: 1) }.frame(maxWidth: .infinity)
                        Text(it.title).font(rf()).foregroundColor(.black).fixedSize()
                        VStack(spacing: 0) { Color.shade.frame(height: 1); Color.white.frame(height: 1) }.frame(maxWidth: .infinity)
                    }.frame(height: 16).padding(.horizontal, 3)
                }
                else {
                    let hot = hover == i && it.enabled
                    HStack(spacing: 0) {
                        ZStack {
                            if it.checked { Text("✓").font(rf(10, bold: true)).foregroundColor(hot ? .white : .black) }
                            else if let ic = it.icon { Pix(name: ic, w: 16) }
                        }.frame(width: 26)
                        Text(brand(it.title)).font(rf(10.5, bold: it.bold)).foregroundColor(!it.enabled ? Color.shade : (hot ? .white : .black)).shadow(color: it.enabled ? .clear : .white, radius: 0, x: 1, y: 1)
                        Spacer(minLength: 0)
                        if it.children != nil { Text("▶").font(rf(7)).foregroundColor(hot ? .white : .black).padding(.trailing, 6) }
                    }.frame(height: 18).background(hot ? Color.navy : Color.clear).contentShape(Rectangle())
                        .background(Color.clear.onChange(of: hover) { h in
                            guard h == i else { return }
                            guard let kids = it.children, it.enabled, let win = RMenu.wins.first(where: { $0.level_ == level }) else { RMenu.closeFrom(level + 1); return }
                            let above = items.prefix(i).reduce(CGFloat(3)) { $0 + ($1.sep ? 6 : ($1.header ? 16 : 18)) }
                            RMenu.show(kids, at: NSPoint(x: win.frame.maxX - 3 * UI.scale, y: win.frame.maxY - above * UI.scale + 3 * UI.scale), level: level + 1)
                        })
                        .onHover { inside in if inside { hover = i; if it.children == nil { RMenu.closeFrom(level + 1) } } else if hover == i { hover = nil } }
                        .onTapGesture { guard it.enabled, it.children == nil else { return }; let f = it.fn; RMenu.dismiss(); DispatchQueue.main.async { f?() } }
                }
            }
        }.padding(.vertical, 3).padding(.horizontal, 2).frame(width: menuWidth).background(Color.gray98).overlay(Bevel(raised: true, win: true))
    }
}
func convert(_ items: [NSMenuItem]) -> [RMItem] {
    items.map { it in
        if it.isSeparatorItem { return RMItem(sep: true) }
        let m = it as? MItem
        return RMItem(title: it.title, icon: m?.iconName, checked: it.state == .on, enabled: it.isEnabled, children: it.submenu.map { convert($0.items) }, fn: m?.fn)
    }
}
func popMenu(_ items: [NSMenuItem]) { popRMenu(convert(items)) }
func popRMenu(_ items: [RMItem]) {
    if Theme.isModern { nativeMenu(items).popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil) } else { RMenu.show(items, at: NSEvent.mouseLocation) }
}

final class MItem: NSMenuItem {
    var fn: (() -> Void)?; var iconName: String?
    init(_ title: String, icon: String? = nil, checked: Bool = false, enabled: Bool = true, fn: (() -> Void)? = nil) {
        super.init(title: title, action: nil, keyEquivalent: "")
        self.fn = fn; iconName = icon; isEnabled = enabled; state = checked ? .on : .off
        target = self; action = #selector(fire)
    }
    required init(coder: NSCoder) { fatalError() }
    @objc func fire() { fn?() }
}
func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
    let it = NSMenuItem(title: title, action: nil, keyEquivalent: ""); let m = NSMenu(); items.forEach { m.addItem($0) }; it.submenu = m; return it
}

// MARK: right-click (control-click) without the native context menu
struct RightClick: NSViewRepresentable {
    let action: () -> Void
    final class V: NSView {
        var action: () -> Void = {}
        override func hitTest(_ p: NSPoint) -> NSView? { let e = NSApp.currentEvent; return (e?.type == .rightMouseDown || (e?.type == .leftMouseDown && e?.modifierFlags.contains(.control) == true)) ? self : nil }
        override func rightMouseDown(with e: NSEvent) { action() }
        override func mouseDown(with e: NSEvent) { action() }
    }
    func makeNSView(context: Context) -> V { let v = V(); v.action = action; return v }
    func updateNSView(_ v: V, context: Context) { v.action = action }
}

// MARK: Windows-98 message boxes
private var boxCount = 0
func retroBox(_ title: String, _ text: String, icon: String = "info32", buttons: [String] = ["OK"], _ choose: @escaping (Int) -> Void = { _ in }) {
    if Theme.isModern { choose(nativeAlert(title, text, icon: icon, buttons: buttons)); return }
    boxCount += 1; let id = "box\(boxCount)"
    let font = NSFont(name: "Helvetica", size: 11) ?? .systemFont(ofSize: 11), tw: CGFloat = 250
    let th = ceil((text as NSString).boundingRect(with: NSSize(width: tw, height: 1000), options: .usesLineFragmentOrigin, attributes: [.font: font]).height)
    let bw = CGFloat(buttons.count) * 81 - 6
    let w = max(bw + 24, 12 + 32 + 12 + tw + 12), h = 12 + max(32, th) + 16 + 23 + 12
    WinMgr.shared.open(id, title, w, h) {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Pix(name: icon, w: 32)
                Text(text).font(rf()).foregroundColor(.black).fixedSize(horizontal: false, vertical: true).frame(width: tw, alignment: .leading).padding(.top, 2)
                Spacer(minLength: 0)
            }.padding(.horizontal, 12).padding(.top, 12)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach(Array(buttons.enumerated()), id: \.offset) { i, b in
                    PushBtn(label: b, isDefault: i == 0, isCancel: i == buttons.count - 1 && buttons.count > 1) { WinMgr.shared.close(id); choose(i) }.frame(width: 75, height: 23)
                }
            }.padding(.bottom, 12)
        }
    }
}
func confirm(_ title: String, _ text: String, ok: String = "Yes", cancel: String = "No", _ yes: @escaping () -> Void) {
    retroBox(title, text, icon: "question32", buttons: [ok, cancel]) { if $0 == 0 { yes() } }
}
func notice(_ text: String) { retroBox(App.name, text) }
func comingSoon() { notice("Coming soon.") }

/// Global UI scale of the classic theme: the 1999 pixel layout is enlarged uniformly (1.0 = original size, default 1.05; 1.5 = exactly 3 device pixels per original pixel on Retina).
enum UI {
    static var scale: CGFloat {
        get {
            if let e = ProcessInfo.processInfo.environment["ICQ_SCALE"], Persist.testMode, let d = Double(e) { return CGFloat(d) }   // self-test only
            let v = UserDefaults.standard.double(forKey: "ui_scale"); return v >= 1 ? CGFloat(v) : 1.05
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: "ui_scale") }
    }
    /// The chosen scale, reduced so that a window of this client size still fits on the screen (buttons stay reachable).
    static func fit(_ w: CGFloat, _ h: CGFloat, _ th: CGFloat) -> CGFloat {
        let v = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1400, height: 900)
        return max(0.75, min(scale, (v.height - 8) / (h + 8 + th), (v.width - 8) / (w + 8)))
    }
}
