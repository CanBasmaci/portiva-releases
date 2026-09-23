import Foundation
import AppKit
import Darwin
import SwiftTerm

func waitFor(_ label: String, _ condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(5)
    while !condition() && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
    precondition(condition(), "FAIL: \(label)")
    print("PASS: \(label)")
}
let app = NSApplication.shared
let session = TerminalSession()
let serial = SerialConnection()
session.bind(serial)
var master: Int32 = -1
var slave: Int32 = -1
var name = [CChar](repeating: 0, count: 1024)
precondition(openpty(&master, &slave, &name, nil, nil) == 0)
_ = fcntl(master, F_SETFL, O_NONBLOCK)
serial.connect(path: String(cString: name), baud: 115200)
waitFor("PTY connection") { serial.connected }

func deviceOutput(_ text: String) {
    let bytes = Array(text.utf8)
    let written = bytes.withUnsafeBytes { Darwin.write(master, $0.baseAddress, $0.count) }
    precondition(written == bytes.count)
}
func screenHas(_ text: String) -> Bool { session.text.contains(text) }

deviceOutput("\rCopying configuration: [/]\rCopying configuration: [-]\rCopying configuration: [Success]\r\nswitch#")
waitFor("real serial bytes render final progress") { screenHas("switch#") }
precondition(session.text.components(separatedBy: "Copying configuration:").count == 2)
precondition(screenHas("[Success]"))
print("PASS: spinner occupies one line")

deviceOutput("\r\n\u{1b}[31mRED\u{1b}[0m\r\nabcdef\rxy\u{1b}[")
deviceOutput("K\r\nTürkçe 界\r\nabc\u{08}X\r\nREADY")
waitFor("ANSI, erase, Unicode and backspace") { screenHas("READY") }
precondition(screenHas("RED") && screenHas("xy") && !screenHas("abcdef"))
precondition(screenHas("Türkçe 界") && screenHas("abX"))
precondition(!session.text.contains("\u{1b}"))
precondition(session.view.getTerminal().getCharData(col: 0, row: 2)?.attribute.fg == .ansi256(code: 1))
print("PASS: ANSI red stored as cell color")
let mainScreen = session.text

deviceOutput("\u{1b}[?1049h\u{1b}[2J\u{1b}[HFull screen\u{1b}[3;5HMENU")
waitFor("alternate screen and cursor position") { screenHas("MENU") }
precondition(!screenHas("Copying configuration"))
precondition(session.view.getTerminal().getCharData(col: 4, row: 2)?.getCharacter() == "M")
deviceOutput("\u{1b}[?1049l")
waitFor("restore main screen") { screenHas("Copying configuration") }
precondition(session.text == mainScreen)

func key(_ chars: String, code: UInt16, modifiers: NSEvent.ModifierFlags = []) {
    let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
        timestamp: 0, windowNumber: 0, context: nil, characters: chars,
        charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code)!
    session.view.keyDown(with: event)
}
key("\u{f700}", code: 126)
key("\t", code: 48)
key("\u{1b}", code: 53)
key("c", code: 8, modifiers: .control)
var sent = Data()
waitFor("arrow, Tab, Escape, Ctrl-C reach serial device") {
    var bytes = [UInt8](repeating: 0, count: 1024)
    let count = Darwin.read(master, &bytes, bytes.count)
    if count > 0 { sent.append(contentsOf: bytes.prefix(count)) }
    return sent.count >= 6
}
precondition(sent == Data([27, 91, 65, 9, 27, 3]), "Unexpected keyboard bytes: \(Array(sent))")
let before = session.text
serial.send("private-test-value\r")
RunLoop.main.run(until: Date().addingTimeInterval(0.1))
precondition(session.text == before, "Input must not be locally echoed")
print("PASS: typed secrets are not locally echoed")
serial.clear()
precondition(!session.hasOutput)
precondition(session.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
print("PASS: clear resets visible contents")
serial.disconnect()
waitFor("disconnect") { !serial.connected }
Darwin.close(slave); Darwin.close(master)
