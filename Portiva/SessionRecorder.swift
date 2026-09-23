import Foundation
import Combine

/// Records received output only. Incomplete lines are held until inspected for password prompts.
final class SessionRecorder: ObservableObject {
    @Published private(set) var recording = false
    @Published private(set) var paused = false
    @Published private(set) var path: String?
    @Published var error: String?
    private var file: FileHandle?
    private var pending = Data()
    private let promptWords = ["password", "passphrase", "parola", "şifre", "verification code", "one-time", "otp:"]
    func start(at url: URL, privateInput: Bool) {
        stop()
        do {
            if !FileManager.default.fileExists(atPath: url.path) {
                guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw CocoaError(.fileWriteUnknown) }
            }
            file = try FileHandle(forWritingTo: url)
            try file?.truncate(atOffset: 0)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            recording = true; paused = privateInput; path = url.path; pending.removeAll()
            write("# Portiva • \(ISO8601DateFormatter().string(from: Date()))\n# Yalnızca cihaz çıktısı; gizli giriş/parola isteminde kayıt duraklatılır.\n")
        } catch { fail(error) }
    }
    func append(_ bytes: Data) {
        guard recording, !paused else { return }
        pending.append(bytes)
        // Check even partial prompts before flushing any line from this batch.
        let lower = String(decoding: pending, as: UTF8.self).lowercased()
        if promptWords.contains(where: lower.contains) { pause(); return }
        while let end = pending.firstIndex(of: 10) {
            let line = Data(pending[..<end]); pending.removeSubrange(...end)
            write(clean(line) + "\n")
        }
        if pending.count > 65536 { pause() }
    }
    func pause() {
        guard recording else { return }
        pending.removeAll()
        if !paused { write("\n# Kayıt duraklatıldı.\n") }
        paused = true
    }
    func resume() {
        guard recording else { return }
        pending.removeAll(); paused = false; write("\n# Kayıt devam ediyor.\n")
    }
    func stop() {
        if recording && !paused && !pending.isEmpty { write(clean(pending) + "\n") }
        pending.removeAll()
        do { try file?.synchronize(); try file?.close() } catch { self.error = error.localizedDescription }
        file = nil; recording = false; paused = false
    }
    private func clean(_ data: Data) -> String {
        var text = String(decoding: data, as: UTF8.self)
        text = text.replacingOccurrences(of: "\u{1b}\\[[0-?]*[ -/]*[@-~]", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\u{1b}\\][^\u{07}]*(?:\u{07}|\u{1b}\\\\)", with: "", options: .regularExpression)
        if text.hasSuffix("\r") { text.removeLast() }
        return text.components(separatedBy: "\r").last ?? ""
    }
    private func write(_ text: String) {
        do { try file?.write(contentsOf: Data(text.utf8)) } catch { fail(error) }
    }
    private func fail(_ error: Error) {
        self.error = "Oturum kaydı durdu: \(error.localizedDescription)"
        try? file?.close(); file = nil; recording = false; paused = false; pending.removeAll()
    }
    deinit { try? file?.close() }
}
