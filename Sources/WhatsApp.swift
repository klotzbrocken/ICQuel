import AppKit
import AVFoundation
import CoreImage.CIFilterBuiltins
import CryptoKit
import ImageIO

// MARK: protocol with the helper process (tools/wa-bridge): one JSON object per line on stdin / stdout
struct WAChat { var jid: String; var name: String; var group: Bool; var last: String; var date: Date }
struct WAMessage { var id: String; var jid: String; var from: String; var name: String; var text: String; var group: Bool; var date: Date; var fromMe: Bool; var files: [String] }
enum WAEvent {
    case qr(String), ready(String), closed(reason: String, loggedOut: Bool), message(WAMessage), chats([WAChat]), sent(id: String, ok: Bool, error: String)
}
enum WAProtocol {
    /// One stdout line of the helper -> event (pure: covered by SelfTest). Unknown or broken lines are ignored.
    static func parse(_ line: String) -> WAEvent? {
        guard let d = line.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let t = j["type"] as? String else { return nil }
        func s(_ k: String, _ o: [String: Any]? = nil) -> String { (o ?? j)[k] as? String ?? "" }
        switch t {
        case "qr": return .qr(s("data"))
        case "ready": return .ready(s("me"))
        case "closed": return .closed(reason: s("reason"), loggedOut: j["loggedOut"] as? Bool ?? false)
        case "sent": return .sent(id: s("id"), ok: j["ok"] as? Bool ?? false, error: s("error"))
        case "message":
            guard !s("jid").isEmpty else { return nil }
            return .message(WAMessage(id: s("id"), jid: s("jid"), from: s("from"), name: s("name"), text: s("text"), group: j["group"] as? Bool ?? false,
                                      date: Date(timeIntervalSince1970: (j["ts"] as? Double) ?? Date().timeIntervalSince1970), fromMe: j["fromMe"] as? Bool ?? false, files: j["files"] as? [String] ?? []))
        case "chats":
            return .chats(((j["chats"] as? [[String: Any]]) ?? []).compactMap { c in
                guard let jid = c["jid"] as? String else { return nil }
                return WAChat(jid: jid, name: s("name", c), group: c["group"] as? Bool ?? false, last: s("last", c), date: Date(timeIntervalSince1970: (c["ts"] as? Double) ?? 0))
            })
        default: return nil
        }
    }
    static func command(_ c: [String: Any]) -> Data { ((try? JSONSerialization.data(withJSONObject: c)) ?? Data()) + Data("\n".utf8) }
    /// "49151…@s.whatsapp.net" -> "+49151…"; groups and unknown forms stay as they are.
    static func number(_ jid: String) -> String { jid.hasSuffix("@s.whatsapp.net") ? "+" + jid.prefix { $0 != "@" && $0 != ":" } : jid }
}

// MARK: the helper process
final class WABridge: ObservableObject {
    static let shared = WABridge()
    enum State: Equatable { case off, needsNode, downloading, starting, waitingForScan, ready, failed(String) }
    @Published var state = State.off
    @Published var qr: NSImage?
    var statusText: String {
        switch state {
        case .off: return "Off"
        case .needsNode: return "Needs the Node.js runtime (downloaded once from nodejs.org)"
        case .downloading: return "Downloading the Node.js runtime…"
        case .starting: return "Starting…"
        case .waitingForScan: return "Waiting for you to scan the QR code with WhatsApp > Linked devices"
        case .ready: return "Connected to WhatsApp"
        case .failed(let r): return "Not connected: " + r
        }
    }

    // locations (the environment variables let SelfTest run the helper without a download)
    static var dir: URL { Persist.dir.appendingPathComponent("whatsapp", isDirectory: true) }
    static var nodeURL: URL { ProcessInfo.processInfo.environment["ICQ_WA_NODE"].map { URL(fileURLWithPath: $0) } ?? dir.appendingPathComponent("runtime/node") }
    static var scriptURL: URL? { ProcessInfo.processInfo.environment["ICQ_WA_SCRIPT"].map { URL(fileURLWithPath: $0) } ?? Bundle.main.url(forResource: "bridge", withExtension: "js", subdirectory: "wa") }
    static var nodeInstalled: Bool { FileManager.default.isExecutableFile(atPath: nodeURL.path) }

    private var proc: Process?, input: FileHandle?, stopping = false, restarts = 0
    private var pending: [String: (String?) -> Void] = [:], chatWaiters: [([WAChat]) -> Void] = []
    var onMessage: ((WAMessage) -> Void)?
    var extraArgs: [String] = []          // SelfTest: ["--selftest"]
    var events: [WAEvent] = []            // SelfTest: everything received

    func startIfEnabled() { if Store.shared.waEnabled { start() } }

    /// Starts the helper. `userInitiated`: may ask to download Node.js first.
    func start(userInitiated: Bool = false) {
        guard proc == nil else { return }
        guard WABridge.scriptURL != nil else { state = .failed("this build has no WhatsApp helper"); return }
        guard WABridge.nodeInstalled else {
            state = .needsNode
            if userInitiated { askDownload() }
            return
        }
        stopping = false; state = .starting
        try? FileManager.default.createDirectory(at: WABridge.dir, withIntermediateDirectories: true)
        let p = Process(), inp = Pipe(), out = Pipe(), err = Pipe()
        p.executableURL = WABridge.nodeURL
        p.arguments = [WABridge.scriptURL!.path] + (extraArgs.isEmpty ? [WABridge.dir.path] : extraArgs)
        p.standardInput = inp; p.standardOutput = out; p.standardError = err
        var buf = Data()
        out.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData; guard !d.isEmpty else { h.readabilityHandler = nil; return }
            buf.append(d)
            while let nl = buf.firstIndex(of: 10) {
                let line = String(decoding: buf[..<nl], as: UTF8.self); buf.removeSubrange(...nl)
                if let e = WAProtocol.parse(line) { DispatchQueue.main.async { self?.handle(e) } }
            }
        }
        err.fileHandleForReading.readabilityHandler = { h in if h.availableData.isEmpty { h.readabilityHandler = nil } }   // helper logs are dropped
        p.terminationHandler = { [weak self] pr in DispatchQueue.main.async { self?.exited(pr.terminationStatus) } }
        do { try p.run() } catch { state = .failed("could not start the helper"); return }
        proc = p; input = inp.fileHandleForWriting
    }
    func stop() {
        stopping = true
        write(["cmd": "quit"])
        let p = proc; proc = nil; input = nil
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { if p?.isRunning == true { p?.terminate() } }
        if state != .off { state = .off }; qr = nil
    }
    private func exited(_ code: Int32) {
        proc = nil; input = nil
        for (_, f) in pending { f("WhatsApp helper stopped") }; pending = [:]
        chatWaiters.forEach { $0([]) }; chatWaiters = []
        guard !stopping, Store.shared.waEnabled else { return }
        if code != 0, restarts < 3 { restarts += 1; state = .starting; DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self.start() } }
        else if state != .off { state = .failed("the helper stopped (\(code))") }
    }
    private func write(_ c: [String: Any]) { input?.write(WAProtocol.command(c)) }

    func handle(_ e: WAEvent) {
        events.append(e)
        switch e {
        case .qr(let s): state = .waitingForScan; qr = WABridge.qrImage(s)
        case .ready: state = .ready; qr = nil; restarts = 0
        case .closed(let reason, let loggedOut):
            qr = nil
            if loggedOut { Store.shared.waEnabled = false; Store.shared.save(); state = .off; notice("WhatsApp was unlinked (\(reason)). Switch it on again in Preferences > Privacy to link again.") }
            else { state = .failed(reason) }
        case .message(let m): onMessage?(m)
        case .chats(let c): let w = chatWaiters; chatWaiters = []; w.forEach { $0(c) }
        case .sent(let id, let ok, let err): pending.removeValue(forKey: id)?(ok ? nil : (err.isEmpty ? "send failed" : err))
        }
    }

    // commands
    private func command(_ c: [String: Any], done: @escaping (String?) -> Void) {
        guard state == .ready, input != nil else { done("WhatsApp is not connected. See Preferences > Privacy."); return }
        let id = UUID().uuidString; pending[id] = done
        var c = c; c["id"] = id; write(c)
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { self.pending.removeValue(forKey: id)?("WhatsApp did not answer in time") }
    }
    func send(_ text: String, to jid: String, done: @escaping (String?) -> Void) { command(["cmd": "send", "jid": jid, "text": text], done: done) }
    func sendFile(_ file: URL, to jid: String, done: @escaping (String?) -> Void) {
        if file.pathExtension.lowercased() == "gif" {   // WhatsApp wants video for animated GIFs
            DispatchQueue.global(qos: .userInitiated).async {
                let mp4 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
                do { try GifConverter.mp4(from: file, to: mp4) } catch { DispatchQueue.main.async { done("Could not convert the GIF: \(error.localizedDescription)") }; return }
                DispatchQueue.main.async { self.command(["cmd": "sendFile", "jid": jid, "path": mp4.path], done: done) }
            }
        } else { command(["cmd": "sendFile", "jid": jid, "path": file.path], done: done) }
    }
    func chats(done: @escaping ([WAChat]) -> Void) {
        guard state == .ready else { done([]); return }
        chatWaiters.append(done); write(["cmd": "chats"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { if !self.chatWaiters.isEmpty { let w = self.chatWaiters; self.chatWaiters = []; w.forEach { $0([]) } } }
    }
    func logout() { write(["cmd": "logout"]); Store.shared.waEnabled = false; Store.shared.save(); stop() }

    // Node.js runtime: downloaded once (about 45 MB, checksum from nodejs.org) so the app itself stays small
    private func askDownload() {
        retroBox("Download Node.js?", "WhatsApp needs the Node.js runtime. ICQuel downloads it once from nodejs.org (about 45 MB) into its own data folder and checks its checksum. Nothing else is installed.", icon: "question32", buttons: ["Download", "Cancel"]) { [weak self] i in
            if i == 0 { self?.downloadNode() } else { Store.shared.waEnabled = false; Store.shared.save(); self?.state = .off }
        }
    }
    func downloadNode() {
        state = .downloading
        Task {
            do {
                try await WABridge.fetchNode()
                await MainActor.run { self.start() }
            } catch { await MainActor.run { self.state = .failed("Node.js download failed: " + error.localizedDescription) } }
        }
    }
    static func fetchNode() async throws {
        #if arch(arm64)
        let arch = "arm64"
        #else
        let arch = "x64"
        #endif
        let base = "https://nodejs.org/dist/latest-v22.x/"
        let (sums, _) = try await URLSession.shared.data(from: URL(string: base + "SHASUMS256.txt")!)
        let suffix = "-darwin-\(arch).tar.gz"
        guard let line = String(decoding: sums, as: UTF8.self).split(separator: "\n").first(where: { $0.hasSuffix(suffix) }) else { throw AIChat.Failure(errorDescription: "no Node.js build for this Mac") }
        let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 2 else { throw AIChat.Failure(errorDescription: "unreadable checksum list") }
        let (tmp, _) = try await URLSession.shared.download(from: URL(string: base + parts[1])!)
        let data = try Data(contentsOf: tmp, options: .mappedIfSafe)
        guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == parts[0] else { throw AIChat.Failure(errorDescription: "checksum mismatch") }
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("icq-node-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let tar = Process(); tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tar.arguments = ["-xzf", tmp.path, "-C", work.path, "--strip-components=2", String(parts[1].dropLast(7)) + "/bin/node"]
        try tar.run(); tar.waitUntilExit()
        let node = work.appendingPathComponent("node")
        guard tar.terminationStatus == 0, FileManager.default.fileExists(atPath: node.path) else { throw AIChat.Failure(errorDescription: "could not unpack Node.js") }
        try FileManager.default.createDirectory(at: nodeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: nodeURL)
        try FileManager.default.moveItem(at: node, to: nodeURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: nodeURL.path)
        try? FileManager.default.removeItem(at: work)
    }

    /// The QR code of the pairing handshake as an image.
    static func qrImage(_ s: String) -> NSImage? {
        let f = CIFilter.qrCodeGenerator(); f.message = Data(s.utf8); f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 6, y: 6)) else { return nil }
        let rep = NSCIImageRep(ciImage: out); let img = NSImage(size: rep.size); img.addRepresentation(rep); return img
    }
}

// MARK: animated GIF -> MP4 (WhatsApp only plays GIFs as video)
enum GifConverter {
    static func mp4(from gif: URL, to out: URL) throws {
        guard let src = CGImageSourceCreateWithURL(gif as CFURL, nil), CGImageSourceGetCount(src) > 0 else { throw AIChat.Failure(errorDescription: "not a readable GIF") }
        let n = CGImageSourceGetCount(src)
        guard let first = CGImageSourceCreateImageAtIndex(src, 0, nil) else { throw AIChat.Failure(errorDescription: "no frames") }
        let scale = min(1, 480 / CGFloat(max(first.width, first.height)))
        let w = max(2, Int(CGFloat(first.width) * scale) / 2 * 2), h = max(2, Int(CGFloat(first.height) * scale) / 2 * 2)
        try? FileManager.default.removeItem(at: out)
        let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
        writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
        var t = 0.0
        func delay(_ i: Int) -> Double {
            let g = (CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any])?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let d = (g?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (g?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            return d < 0.02 ? 0.1 : d
        }
        func buffer(_ img: CGImage) -> CVPixelBuffer? {
            var pb: CVPixelBuffer?; CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, nil, &pb)
            guard let pb else { return nil }
            CVPixelBufferLockBaseAddress(pb, [])
            let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: w, height: h, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            ctx?.setFillColor(CGColor(gray: 1, alpha: 1)); ctx?.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx?.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            CVPixelBufferUnlockBaseAddress(pb, []); return pb
        }
        for i in 0..<n {
            guard let img = CGImageSourceCreateImageAtIndex(src, i, nil), let pb = buffer(img) else { continue }
            var waited = 0; while !input.isReadyForMoreMediaData && waited < 500 { usleep(10_000); waited += 1 }
            adaptor.append(pb, withPresentationTime: CMTime(seconds: t, preferredTimescale: 600)); t += delay(i)
        }
        input.markAsFinished(); writer.endSession(atSourceTime: CMTime(seconds: t, preferredTimescale: 600))
        let sem = DispatchSemaphore(value: 0); writer.finishWriting { sem.signal() }; sem.wait()
        guard writer.status == .completed else { throw writer.error ?? AIChat.Failure(errorDescription: "video encoding failed") }
    }
}
