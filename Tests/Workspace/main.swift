import Foundation
import AppKit
import Darwin
import SwiftTerm

func check(_ value: @autoclosure () -> Bool, _ label: String) { precondition(value(), label); print("PASS: \(label)") }
func wait(_ label: String, _ condition: () -> Bool) {
    let end = Date().addingTimeInterval(5)
    while !condition() && Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    check(condition(), label)
}
let app = NSApplication.shared
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
let url = root.appendingPathComponent(UUID().uuidString + ".json")
let store = LibraryStore(url: url)
var profile = ConnectionProfile(); profile.name = "Lab"; profile.device = "/dev/test"
check(store.save(profile), "save profile")
profile.baud = "9600"; check(store.save(profile), "update profile")
var command = SavedCommand(); command.name = "VLAN"; command.text = "show vlan"
check(store.save(command), "save command")
let reloaded = LibraryStore(url: url)
check(reloaded.profiles == [profile] && reloaded.commands == [command], "reload persisted library")
reloaded.removeProfile(profile.id); reloaded.removeCommand(command.id)
check(LibraryStore(url: url).profiles.isEmpty && LibraryStore(url: url).commands.isEmpty, "delete persistence")
try Data("corrupt".utf8).write(to: url)
check(!LibraryStore(url: url).save(profile), "corrupt library is not overwritten")
let corrupt = try String(contentsOf: url, encoding: .utf8)
check(corrupt == "corrupt", "corrupt bytes preserved")
profile.kind = .ssh; profile.host = "127.0.0.1"; profile.username = "test"
check(profile.validationError == nil, "valid SSH profile")
check(profile.sshArguments().suffix(2) == ["--", "127.0.0.1"], "SSH target is a separate argument")
profile.host = "-oProxyCommand=bad"; check(profile.validationError != nil, "reject option injection")
profile.host = "host; touch bad"; check(profile.validationError != nil, "reject shell syntax")
check(CommandText.clean("a\r\nb\u{03}\u{7f}\r") == "a\nb\n", "normalize pasted controls")
check(CommandText.lines("a\nb\n") == ["a","b"], "no extra trailing Enter")
let diff = ConfigDiff.compare("a\nb\na", "a\nc\na")
check(diff.filter { $0.kind == .removed }.map(\.text) == ["b"], "diff removes correct repeated context")
check(diff.filter { $0.kind == .added }.map(\.text) == ["c"], "diff inserts correct line")
check(ConfigDiff.compare("a\r\nb", "a\nb").allSatisfy { $0.kind == .same }, "CRLF comparison")
let recorder = SessionRecorder(); let log = root.appendingPathComponent(UUID().uuidString + ".log")
recorder.start(at: log, privateInput: false)
recorder.append(Data("normal\nPass".utf8)); recorder.append(Data("word: ".utf8))
check(recorder.paused, "split password prompt pauses recording")
recorder.append(Data("secret\n".utf8)); recorder.stop()
let recorded = try String(contentsOf: log, encoding: .utf8)
check(recorded.contains("normal") && !recorded.contains("secret") && !recorded.contains("Password:"), "prompt and secret excluded")
let permissions = try FileManager.default.attributesOfItem(atPath: log.path)[.posixPermissions] as? NSNumber
check(permissions?.intValue == 0o600, "private log permissions")
recorder.start(at: log, privateInput: true); check(recorder.paused, "private mode starts paused"); recorder.stop()

func pty() -> (Int32, Int32, String) {
    var m: Int32 = -1, s: Int32 = -1; var name = [CChar](repeating: 0, count: 1024)
    precondition(openpty(&m, &s, &name, nil, nil) == 0); _ = fcntl(m, F_SETFL, O_NONBLOCK)
    return (m, s, String(cString: name))
}
let first = pty(), second = pty()
let workspace = WorkspaceModel(); let tab = workspace.tabs[0]
tab.profile.device = first.2
workspace.connect(tab); wait("first serial tab connects") { tab.connection.connected }
var other = ConnectionProfile(); other.device = second.2
workspace.add(other); let tab2 = workspace.tabs[1]
workspace.connect(tab2); wait("second serial tab connects") { tab2.connection.connected }
workspace.add(tab.profile); workspace.connect(workspace.tabs[2]); check(workspace.error != nil, "duplicate serial port blocked")
func output(_ text: String, _ fd: Int32) { let bytes = Array(text.utf8); _ = bytes.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) } }
output("ONE\r\n", first.0); output("TWO\r\n", second.0)
wait("independent terminal buffers") { tab.terminal.text.contains("ONE") && tab2.terminal.text.contains("TWO") }
check(!tab.terminal.text.contains("TWO"), "no cross-session output")
func read(_ fd: Int32) -> Data { var b = [UInt8](repeating: 0, count: 4096); let n = Darwin.read(fd, &b, b.count); return n > 0 ? Data(b.prefix(n)) : Data() }
tab.requestPreview("show vlan\nshow version", title: "Test")
check(tab.preview != nil && read(first.0).isEmpty, "preview sends no bytes")
tab.sendPreview("wrong", generation: UUID()); check(read(first.0).isEmpty, "stale preview blocked")
tab.sendPreview("show vlan\nshow version", generation: tab.connection.generation)
var sent = Data()
wait("paced batch finishes") { sent.append(read(first.0)); return !tab.sending && !sent.isEmpty }
check(String(decoding: sent, as: UTF8.self) == "show vlan\rshow version\r", "exact batch framing")
tab.sendPreview("one\ntwo\nthree", generation: tab.connection.generation)
var started = false
wait("batch starts") { started = started || !read(first.0).isEmpty; return started }
tab.cancelBatch(); RunLoop.main.run(until: Date().addingTimeInterval(0.4)); check(read(first.0).isEmpty, "batch cancellation stops remaining lines")
workspace.close(tab2); check(tab.connection.connected, "closing one tab preserves another")
Darwin.close(first.0)
wait("disconnect detected") { !tab.connection.connected && tab.connection.lossMessage != nil }
workspace.stopAll(); Darwin.close(first.1); Darwin.close(second.0); Darwin.close(second.1)
let ssh = ConnectionSession(); var sshProfile = ConnectionProfile(); sshProfile.kind = .ssh; sshProfile.host = "127.0.0.1"; sshProfile.username = "portiva-test"; sshProfile.sshPort = "1"
ssh.connect(sshProfile)
wait("SSH refused connection terminates cleanly") { !ssh.connected && !ssh.busy }
print("Workspace tests completed")
