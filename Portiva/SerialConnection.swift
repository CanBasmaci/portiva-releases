import Foundation
import Combine
import Darwin

/// All descriptor operations run on one queue so disconnect cannot race reads/writes.
final class SerialConnection: ObservableObject, @unchecked Sendable {
    @Published private(set) var ports: [String] = []
    @Published private(set) var connected = false
    @Published private(set) var busy = false
    enum TerminalEvent { case reset, clear, bytes(Data) }
    let terminalEvents = PassthroughSubject<TerminalEvent, Never>()
    @Published private(set) var status = "Bağlı değil"
    private let queue = DispatchQueue(label: "Portiva.serial")
    private var descriptor: Int32 = -1
    private var reader: DispatchSourceRead?
    private var writer: DispatchSourceWrite?
    private var pending = Data()
    private var original: termios?

    func refreshPorts() {
        ports = ((try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? [])
            .filter { $0.hasPrefix("cu.") }.sorted().map { "/dev/" + $0 }
    }

    func connect(path: String, baud: Int, dataBits: Int = 8, parity: String = "None", stopBits: Int = 1, flowControl: String = "None") {
        guard !busy, !connected, path.hasPrefix("/dev/") else { return }
        guard baud > 0, (5...8).contains(dataBits), [1, 2].contains(stopBits),
              ["None", "Even", "Odd"].contains(parity),
              ["None", "RTS/CTS", "XON/XOFF"].contains(flowControl) else {
            fail("Geçersiz seri bağlantı ayarları"); return
        }
        busy = true
        queue.async { [self] in
            let fd = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
            guard fd >= 0 else { fail("Port açılamadı: \(errorText())"); return }
            var settings = termios()
            guard tcgetattr(fd, &settings) == 0 else {
                let message = errorText(); Darwin.close(fd); fail(message); return
            }
            let saved = settings
            cfmakeraw(&settings)
            Self.configure(&settings, dataBits: dataBits, parity: parity, stopBits: stopBits, flowControl: flowControl)
            guard cfsetispeed(&settings, speed_t(baud)) == 0,
                  cfsetospeed(&settings, speed_t(baud)) == 0,
                  tcsetattr(fd, TCSANOW, &settings) == 0 else {
                let message = errorText(); Darwin.close(fd); fail(message); return
            }
            descriptor = fd
            original = saved
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
            source.setEventHandler { [weak self] in self?.readAvailable() }
            reader = source
            source.resume()
            DispatchQueue.main.async {
                self.connected = true; self.busy = false
                self.status = "\(URL(fileURLWithPath: path).lastPathComponent) • \(baud) • \(dataBits)-\(parity.prefix(1))-\(stopBits) • \(flowControl)"
                self.terminalEvents.send(.reset)
            }
        }
    }

    static func configure(_ settings: inout termios, dataBits: Int, parity: String, stopBits: Int, flowControl: String) {
        settings.c_cflag &= ~tcflag_t(CSIZE | PARENB | PARODD | CSTOPB | CRTSCTS)
        let bits = [5: CS5, 6: CS6, 7: CS7, 8: CS8]
        settings.c_cflag |= tcflag_t(bits[dataBits] ?? CS8) | tcflag_t(CLOCAL | CREAD)
        settings.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY | INPCK | ISTRIP)
        if parity != "None" {
            settings.c_cflag |= tcflag_t(PARENB)
            settings.c_iflag |= tcflag_t(INPCK)
            if parity == "Odd" { settings.c_cflag |= tcflag_t(PARODD) }
        }
        if stopBits == 2 { settings.c_cflag |= tcflag_t(CSTOPB) }
        if flowControl == "RTS/CTS" { settings.c_cflag |= tcflag_t(CRTSCTS) }
        if flowControl == "XON/XOFF" { settings.c_iflag |= tcflag_t(IXON | IXOFF) }
    }

    func disconnect() {
        queue.async { [self] in closePort(message: "Bağlantı kesildi") }
    }

    func send(_ text: String) { send(Data(text.utf8)) }

    func send(_ data: Data) {
        queue.async { [self] in
            guard descriptor >= 0 else { return }
            pending.append(data)
            flushWrites()
        }
    }

    func clear() {
        terminalEvents.send(.clear)
    }

    private func readAvailable() {
        var buffer = [UInt8](repeating: 0, count: 8192)
        var received = Data()
        // Yield periodically so writes/disconnect cannot be starved by continuous output.
        while descriptor >= 0 && received.count < 65536 {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count > 0 {
                received.append(contentsOf: buffer.prefix(count))
            } else if count == 0 {
                closePort(message: "Cihaz bağlantısı kapandı"); break
            } else if errno == EINTR { continue
            } else if errno == EAGAIN || errno == EWOULDBLOCK { break
            } else { closePort(message: "Okuma hatası: \(errorText())"); break }
        }
        if !received.isEmpty {
            let chunk = received
            DispatchQueue.main.async { self.terminalEvents.send(.bytes(chunk)) }
        }
    }

    private func flushWrites() {
        while !pending.isEmpty && descriptor >= 0 {
            let count = pending.withUnsafeBytes { Darwin.write(descriptor, $0.baseAddress, $0.count) }
            if count > 0 { pending.removeFirst(count) }
            else if count < 0 && errno == EINTR { continue }
            else if count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) {
                if writer == nil {
                    let source = DispatchSource.makeWriteSource(fileDescriptor: descriptor, queue: queue)
                    source.setEventHandler { [weak self] in self?.flushWrites() }
                    writer = source; source.resume()
                }
                return
            } else { closePort(message: "Yazma hatası: \(errorText())"); return }
        }
        writer?.cancel(); writer = nil
    }

    private func closePort(message: String) {
        reader?.cancel(); reader = nil
        writer?.cancel(); writer = nil
        if descriptor >= 0 {
            if var saved = original { tcsetattr(descriptor, TCSANOW, &saved) }
            Darwin.close(descriptor); descriptor = -1
        }
        original = nil; pending.removeAll()
        DispatchQueue.main.async {
            self.connected = false; self.busy = false; self.status = message
        }
    }

    private func fail(_ message: String) {
        DispatchQueue.main.async { self.busy = false; self.status = message }
    }
    private func errorText() -> String { String(cString: strerror(errno)) }
}
