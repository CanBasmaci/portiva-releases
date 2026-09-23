import Foundation
import Combine
import AppKit
import SwiftTerm
import Darwin

final class SSHTransport: LocalProcessDelegate {
    private(set) var process: LocalProcess!
    var onData: ((Data) -> Void)?
    var onExit: ((Int32?) -> Void)?
    var cols = 80, rows = 25
    init() { process = LocalProcess(delegate: self) }
    func start(profile: ConnectionProfile) {
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["LC_CTYPE"] = "UTF-8"
        process.startProcess(executable: "/usr/bin/ssh", args: profile.sshArguments(), environment: environment.map { "\($0.key)=\($0.value)" })
    }
    func resize(cols: Int, rows: Int) {
        self.cols = cols; self.rows = rows
        guard process.running else { return }
        var size = getWindowSize()
        _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: process.childfd, windowSize: &size)
    }
    func getWindowSize() -> winsize { winsize(ws_row: UInt16(clamping: rows), ws_col: UInt16(clamping: cols), ws_xpixel: 0, ws_ypixel: 0) }
    func dataReceived(slice: ArraySlice<UInt8>) { onData?(Data(slice)) }
    func processTerminated(_ source: LocalProcess, exitCode: Int32?) { onExit?(exitCode) }
    deinit { if process.running { process.terminate() } }
}

final class ConnectionSession: ObservableObject {
    @Published private(set) var connected = false
    @Published private(set) var busy = false
    @Published private(set) var status = "Bağlı değil"
    @Published var lossMessage: String?
    @Published private(set) var generation = UUID()
    let terminalEvents = PassthroughSubject<SerialConnection.TerminalEvent, Never>()
    let serial = SerialConnection()
    private var ssh: SSHTransport?
    private var kind: ConnectionKind = .serial
    private var intentional = false
    private var seenConnection = false
    private var columns = 80, rows = 25
    private var subscriptions = Set<AnyCancellable>()
    init() {
        serial.$ports.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        serial.$connected.sink { [weak self] value in
            guard let self, self.kind == .serial else { return }
            self.connected = value
            if value { self.seenConnection = true }
            else if self.seenConnection {
                self.seenConnection = false
                if !self.intentional { self.lost("Seri bağlantı kesildi. Kabloyu kontrol edip yeniden bağlanın.") }
            }
        }.store(in: &subscriptions)
        serial.$busy.sink { [weak self] value in if self?.kind == .serial { self?.busy = value } }.store(in: &subscriptions)
        serial.$status.sink { [weak self] value in if self?.kind == .serial { self?.status = value } }.store(in: &subscriptions)
        serial.terminalEvents.sink { [weak self] event in if self?.kind == .serial { self?.terminalEvents.send(event) } }.store(in: &subscriptions)
    }
    func connect(_ profile: ConnectionProfile) {
        guard !connected, !busy else { return }
        if let error = profile.validationError { status = error; return }
        if let data = try? JSONEncoder().encode(profile) { UserDefaults.standard.set(data, forKey: "connection.lastProfile") }
        generation = UUID(); kind = profile.kind; intentional = false; lossMessage = nil
        if kind == .serial {
            serial.connect(path: profile.device, baud: Int(profile.baud)!, dataBits: profile.dataBits, parity: profile.parity, stopBits: profile.stopBits, flowControl: profile.flowControl)
        } else {
            terminalEvents.send(.reset)
            busy = true
            let token = generation
            let transport = SSHTransport()
            ssh = transport
            transport.onData = { [weak self] data in
                guard let self, self.generation == token else { return }
                self.terminalEvents.send(.bytes(data))
            }
            transport.onExit = { [weak self] code in
                guard let self, self.generation == token else { return }
                self.connected = false; self.busy = false
                self.status = code == 0 ? "SSH oturumu sona erdi" : "SSH kapandı (\(code.map(String.init) ?? "I/O")); terminal çıktısını kontrol edin."
                if !self.intentional { self.lost(self.status) }
            }
            transport.cols = columns; transport.rows = rows
            transport.start(profile: profile)
            connected = transport.process.running; busy = false
            status = connected ? "SSH başlatıldı • kimlik doğrulama terminalde" : "SSH başlatılamadı"
        }
    }
    func disconnect() {
        intentional = true
        if kind == .serial { serial.disconnect() }
        else {
            ssh?.process.terminate(); ssh = nil
            connected = false; busy = false; status = "Bağlantı kesildi"
        }
    }
    func send(_ data: Data) {
        guard connected else { return }
        if kind == .serial { serial.send(data) } else { ssh?.process.send(data: Array(data)[...]) }
    }
    func clear() { terminalEvents.send(.clear) }
    func resize(cols: Int, rows: Int) { columns = cols; self.rows = rows; ssh?.resize(cols: cols, rows: rows) }
    private func lost(_ message: String) {
        generation = UUID(); lossMessage = message
        NSApp?.requestUserAttention(.informationalRequest)
    }
}

final class SessionTab: ObservableObject, Identifiable {
    let id = UUID()
    @Published var profile: ConnectionProfile
    let connection = ConnectionSession()
    let terminal = TerminalSession()
    let recorder = SessionRecorder()
    @Published var draft = ""
    @Published var preview: SendPreview?
    @Published var sending = false
    @Published var error: String?
    private var batch: Task<Void, Never>?
    private var batchID = UUID()
    private var subscriptions = Set<AnyCancellable>()
    init(profile: ConnectionProfile) {
        self.profile = profile
        terminal.bind(connection)
        terminal.view.onPasteRequest = { [weak self] text in guard let self else { return }
            if UserDefaults.standard.bool(forKey: "privacy.hideInput") {
                self.recorder.pause(); self.error = "Gizli giriş açıkken çok satırlı yapıştırma kapalıdır."
            } else { self.requestPreview(text, title: "Yapıştırma önizlemesi") } }
        connection.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &subscriptions)
        recorder.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &subscriptions)
        connection.terminalEvents.sink { [weak self] event in
            if case .bytes(let data) = event { self?.recorder.append(data) }
        }.store(in: &subscriptions)
        connection.$connected.dropFirst().sink { [weak self] value in
            guard let self else { return }
            self.draft = ""
            if !value { self.cancelBatch(); self.recorder.stop() }
        }.store(in: &subscriptions)
        terminal.beforeUserInput = { [weak self] in
            if UserDefaults.standard.bool(forKey: "privacy.hideInput") { self?.recorder.pause() }
        }
    }
    func requestPreview(_ text: String, title: String) {
        guard connection.connected, !sending else { return }
        guard text.utf8.count <= 65536 else { error = "Tek gönderim en fazla 64 KB olabilir."; return }
        preview = SendPreview(generation: connection.generation, title: title, text: CommandText.clean(text))
    }
    func sendDraft(privateInput: Bool) {
        guard connection.connected, !sending else { return }
        if privateInput { recorder.pause() }
        if CommandText.requiresPreview(draft) {
            // Never show a secret draft in a plaintext preview.
            if privateInput { error = "Gizli giriş tek satır olmalı."; return }
            requestPreview(draft, title: "Komut önizlemesi")
        } else { connection.send(Data((draft + profile.lineEnding).utf8)); draft = "" }
    }
    func sendPreview(_ text: String, generation: UUID) {
        guard connection.connected, connection.generation == generation, !sending else { error = "Oturum değişti; komutu yeniden önizleyin."; return }
        let lines = CommandText.lines(text)
        guard text.utf8.count <= 65536, !lines.isEmpty else { return }
        if UserDefaults.standard.bool(forKey: "privacy.hideInput") { recorder.pause() }
        sending = true; preview = nil; draft = ""
        let token = UUID(); batchID = token
        let ending = profile.lineEnding
        batch = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if self.batchID == token { self.sending = false; self.batch = nil } }
            for line in lines {
                guard !Task.isCancelled, self.connection.connected, self.connection.generation == generation else { return }
                self.connection.send(Data((line + ending).utf8))
                do { try await Task.sleep(nanoseconds: 200_000_000) } catch { return }
            }
        }
    }
    func cancelBatch() { batchID = UUID(); batch?.cancel(); batch = nil; sending = false }
    func close() { cancelBatch(); recorder.stop(); connection.disconnect() }
}

final class WorkspaceModel: ObservableObject {
    @Published var tabs: [SessionTab] = []
    @Published var activeID: UUID?
    @Published var error: String?
    let library = LibraryStore()
    private var observers: [UUID: AnyCancellable] = [:]
    var hasActiveConnection: Bool { tabs.contains { $0.connection.connected || $0.connection.busy } }
    init() { add(.initial) }
    func add(_ profile: ConnectionProfile = ConnectionProfile()) {
        let tab = SessionTab(profile: profile)
        observers[tab.id] = tab.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        tabs.append(tab); activeID = tab.id
    }
    func close(_ tab: SessionTab) {
        tab.close(); tabs.removeAll { $0.id == tab.id }; observers[tab.id] = nil
        if activeID == tab.id { activeID = tabs.last?.id }
        if tabs.isEmpty { add() }
    }
    func connect(_ tab: SessionTab) {
        if tab.profile.kind == .serial && tabs.contains(where: { $0.id != tab.id && ($0.connection.connected || $0.connection.busy) && $0.profile.kind == .serial && $0.profile.device == tab.profile.device }) {
            error = "Bu seri port başka bir sekmede açık."; return
        }
        tab.connection.connect(tab.profile)
    }
    func stopAll() { tabs.forEach { $0.close() } }
}


extension TerminalSession {
    func bind(_ connection: ConnectionSession) {
        attach(events: connection.terminalEvents, send: { [weak connection] data in connection?.send(data) },
               resize: { [weak connection] cols, rows in connection?.resize(cols: cols, rows: rows) })
    }
}
