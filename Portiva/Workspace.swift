import Foundation
import Combine
import AppKit

enum ConnectionKind: String, Codable, CaseIterable, Identifiable {
    case serial = "Serial", ssh = "SSH"
    var id: String { rawValue }
}
enum DeviceFamily: String, Codable, CaseIterable, Identifiable {
    case generic = "Genel", aruba = "Aruba AOS-CX", cisco = "Cisco IOS / IOS-XE", juniper = "Juniper Junos"
    var id: String { rawValue }
    var readCommands: [(String, String)] {
        switch self {
        case .generic: return []
        case .aruba: return [("VLAN’lar", "show vlan"), ("Interface durumu", "show interface brief"), ("MAC tablosu", "show mac-address-table")]
        case .cisco: return [("VLAN’lar", "show vlan brief"), ("Interface durumu", "show interfaces status"), ("MAC tablosu", "show mac address-table")]
        case .juniper: return [("VLAN’lar", "show vlans"), ("Interface durumu", "show interfaces terse"), ("MAC tablosu", "show ethernet-switching table")]
        }
    }
}

struct ConnectionProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "Yeni bağlantı"
    var kind: ConnectionKind = .serial
    var family: DeviceFamily = .generic
    var device = ""
    var baud = "115200"
    var dataBits = 8
    var parity = "None"
    var stopBits = 1
    var flowControl = "None"
    var host = ""
    var username = ""
    var sshPort = "22"
    var identityFile = ""
    var lineEnding = "\r"
    var target: String { kind == .serial ? device : "\(username)@\(host):\(sshPort)" }
    var validationError: String? {
        if kind == .serial {
            guard device.hasPrefix("/dev/") else { return "Bir seri port seçin." }
            guard let value = Int(baud), value > 0, baud.utf8.allSatisfy({ (48...57).contains($0) }) else { return "Baud pozitif bir tam sayı olmalı." }
            guard (5...8).contains(dataBits), [1,2].contains(stopBits), ["None","Even","Odd"].contains(parity), ["None","RTS/CTS","XON/XOFF"].contains(flowControl) else { return "Seri bağlantı ayarları geçersiz." }
        } else {
            let allowedHost = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_:%")
            let allowedUser = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_@")
            guard !host.isEmpty, !host.hasPrefix("-"), host.unicodeScalars.allSatisfy({ allowedHost.contains($0) }) else { return "Geçerli bir SSH adresi girin." }
            guard !username.isEmpty, !username.hasPrefix("-"), username.unicodeScalars.allSatisfy({ allowedUser.contains($0) }) else { return "Geçerli bir SSH kullanıcı adı girin." }
            guard let port = Int(sshPort), (1...65535).contains(port) else { return "SSH portu 1–65535 arasında olmalı." }
            guard !identityFile.contains("\n"), !identityFile.contains("\0") else { return "Anahtar dosyası yolu geçersiz." }
        }
        return nil
    }
    func sshArguments() -> [String] {
        var args = ["-tt", "-p", sshPort, "-l", username,
                    "-o", "StrictHostKeyChecking=ask", "-o", "ConnectTimeout=15",
                    "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=3",
                    "-o", "ForwardAgent=no", "-o", "ForwardX11=no",
                    "-o", "ClearAllForwardings=yes", "-o", "PermitLocalCommand=no",
                    "-o", "RemoteCommand=none", "-o", "EscapeChar=none"]
        if !identityFile.isEmpty { args += ["-i", (identityFile as NSString).expandingTildeInPath] }
        return args + ["--", host]
    }
    static var initial: ConnectionProfile {
        let d = UserDefaults.standard
        if let data = d.data(forKey: "connection.lastProfile"), let profile = try? JSONDecoder().decode(ConnectionProfile.self, from: data) { return profile }
        var p = ConnectionProfile()
        p.device = d.string(forKey: "serial.port") ?? ""
        p.baud = String(d.object(forKey: "serial.baud") as? Int ?? 115200)
        p.dataBits = d.object(forKey: "serial.dataBits") as? Int ?? 8
        p.parity = d.string(forKey: "serial.parity") ?? "None"
        p.stopBits = d.object(forKey: "serial.stopBits") as? Int ?? 1
        p.flowControl = d.string(forKey: "serial.flowControl") ?? "None"
        return p
    }
}

struct SavedCommand: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "Yeni komut"
    var note = ""
    var text = ""
}
private struct WorkspaceData: Codable {
    var version = 1
    var profiles: [ConnectionProfile] = []
    var commands: [SavedCommand] = []
}

final class LibraryStore: ObservableObject {
    @Published private(set) var profiles: [ConnectionProfile] = []
    @Published private(set) var commands: [SavedCommand] = []
    @Published var error: String?
    private let url: URL
    private var failedLoad = false
    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Portiva/library.json")
        guard FileManager.default.fileExists(atPath: self.url.path) else { return }
        do {
            let data = try JSONDecoder().decode(WorkspaceData.self, from: Data(contentsOf: self.url))
            guard data.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
            profiles = data.profiles; commands = data.commands
        } catch { failedLoad = true; self.error = "Kütüphane okunamadı. Mevcut dosya korunuyor: \(error.localizedDescription)" }
    }
    @discardableResult func save(_ profile: ConnectionProfile) -> Bool {
        var next = profiles
        if let i = next.firstIndex(where: { $0.id == profile.id }) { next[i] = profile } else { next.append(profile) }
        return persist(profiles: next, commands: commands)
    }
    @discardableResult func save(_ command: SavedCommand) -> Bool {
        var next = commands
        if let i = next.firstIndex(where: { $0.id == command.id }) { next[i] = command } else { next.append(command) }
        return persist(profiles: profiles, commands: next)
    }
    func removeProfile(_ id: UUID) { _ = persist(profiles: profiles.filter { $0.id != id }, commands: commands) }
    func removeCommand(_ id: UUID) { _ = persist(profiles: profiles, commands: commands.filter { $0.id != id }) }
    private func persist(profiles: [ConnectionProfile], commands: [SavedCommand]) -> Bool {
        guard !failedLoad else { error = "Okunamayan kütüphane dosyasının üzerine yazılmadı."; return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(WorkspaceData(profiles: profiles, commands: commands))
            try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            self.profiles = profiles; self.commands = commands
            return true
        } catch { self.error = "Kayıt yapılamadı: \(error.localizedDescription)"; return false }
    }
}

struct SendPreview: Identifiable {
    let id = UUID()
    let generation: UUID
    var title: String
    var text: String
}
enum CommandText {
    static func clean(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return String(String.UnicodeScalarView(normalized.unicodeScalars.filter { $0.value == 9 || $0.value == 10 || ($0.value >= 32 && $0.value != 127) }))
    }
    static func lines(_ text: String) -> [String] {
        var lines = clean(text).components(separatedBy: "\n")
        while lines.last == "" { lines.removeLast() }
        return lines
    }
    static func requiresPreview(_ text: String) -> Bool { text.contains("\n") || text.contains("\r") || clean(text) != text }
}

struct DiffRow: Identifiable, Equatable {
    enum Kind: String { case same = " ", added = "+", removed = "−" }
    var id: Int
    var kind: Kind
    var text: String
    var oldLine: Int?
    var newLine: Int?
}
enum ConfigDiff {
    static func compare(_ before: String, _ after: String) -> [DiffRow] {
        let a = before.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        let b = after.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        let changes = b.difference(from: a)
        var removed = Set<Int>(), added = Set<Int>()
        for change in changes {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): added.insert(offset)
            }
        }
        var result: [DiffRow] = []; var i = 0; var j = 0
        while i < a.count || j < b.count {
            if i < a.count && removed.contains(i) {
                result.append(DiffRow(id: result.count, kind: .removed, text: a[i], oldLine: i + 1)); i += 1
            } else if j < b.count && added.contains(j) {
                result.append(DiffRow(id: result.count, kind: .added, text: b[j], newLine: j + 1)); j += 1
            } else if i < a.count && j < b.count {
                result.append(DiffRow(id: result.count, kind: .same, text: a[i], oldLine: i + 1, newLine: j + 1)); i += 1; j += 1
            } else { break }
        }
        return result
    }
    static func export(_ rows: [DiffRow]) -> String {
        rows.map { ($0.kind == .removed ? "-" : $0.kind.rawValue) + " " + $0.text }.joined(separator: "\n")
    }
}
