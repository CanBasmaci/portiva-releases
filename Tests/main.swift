import Foundation
import Darwin
import Combine

func waitUntil(_ label: String, _ condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(4)
    while !condition() && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
    guard condition() else { fatalError("FAIL: \(label)") }
    print("PASS: \(label)")
}
var master: Int32 = -1
var slave: Int32 = -1
var name = [CChar](repeating: 0, count: 1024)
precondition(openpty(&master, &slave, &name, nil, nil) == 0)
let path = String(cString: name)
_ = fcntl(master, F_SETFL, O_NONBLOCK)
let serial = SerialConnection()
var received = Data()
var resetCount = 0
var clearCount = 0
let subscription = serial.terminalEvents.sink { event in
    switch event {
    case .bytes(let data): received.append(data)
    case .reset: received.removeAll(); resetCount += 1
    case .clear: received.removeAll(); clearCount += 1
    }
}
serial.connect(path: path, baud: 115200)
waitUntil("connect at 115200") { serial.connected }
var settings = termios()
precondition(tcgetattr(slave, &settings) == 0)
precondition(cfgetospeed(&settings) == 115200)
precondition(settings.c_cflag & tcflag_t(CSIZE) == tcflag_t(CS8))
precondition(settings.c_cflag & tcflag_t(PARENB | CSTOPB | CRTSCTS) == 0)
print("PASS: 115200 / 8-N-1 / no flow control")
let response = Array("Aruba switch ready\r\n".utf8)
_ = response.withUnsafeBytes { Darwin.write(master, $0.baseAddress, $0.count) }
waitUntil("receive device output") { String(decoding: received, as: UTF8.self).contains("Aruba switch ready") }
serial.send("show version\r")
var data = Data()
waitUntil("send command and CR") {
    var bytes = [UInt8](repeating: 0, count: 1024)
    let count = Darwin.read(master, &bytes, bytes.count)
    if count > 0 { data.append(contentsOf: bytes.prefix(count)) }
    return String(decoding: data, as: UTF8.self) == "show version\r"
}
serial.clear()
waitUntil("clear output") { received.isEmpty && clearCount == 1 }
serial.disconnect()
waitUntil("disconnect") { !serial.connected }
serial.connect(path: path, baud: 9600)
waitUntil("reconnect at 9600") { serial.connected }
serial.disconnect()
waitUntil("second disconnect") { !serial.connected }
Darwin.close(slave); Darwin.close(master)
serial.connect(path: "/dev/cu.PortivaMissingTestPort", baud: 115200)
waitUntil("missing device error") { !serial.busy && serial.status.contains("Port açılamadı") }

// Check every selectable framing/flow combination without relying on PTY driver support.
for bits in 5...8 {
    for parity in ["None", "Even", "Odd"] {
        for stops in [1, 2] {
            for flow in ["None", "RTS/CTS", "XON/XOFF"] {
                var options = termios()
                options.c_cflag = tcflag_t(PARENB | PARODD | CRTSCTS | CSTOPB | CS8)
                options.c_iflag = tcflag_t(IXON | IXOFF | IXANY | INPCK | ISTRIP)
                SerialConnection.configure(&options, dataBits: bits, parity: parity, stopBits: stops, flowControl: flow)
                precondition(options.c_cflag & tcflag_t(CSIZE) == tcflag_t([5: CS5, 6: CS6, 7: CS7, 8: CS8][bits]!))
                precondition((options.c_cflag & tcflag_t(PARENB) != 0) == (parity != "None"))
                precondition((options.c_cflag & tcflag_t(PARODD) != 0) == (parity == "Odd"))
                precondition((options.c_cflag & tcflag_t(CSTOPB) != 0) == (stops == 2))
                precondition((options.c_cflag & tcflag_t(CRTSCTS) != 0) == (flow == "RTS/CTS"))
                precondition((options.c_iflag & tcflag_t(IXON | IXOFF) != 0) == (flow == "XON/XOFF"))
            }
        }
    }
}
print("PASS: all 72 serial framing/flow configurations")


precondition(resetCount == 2)
print("PASS: reconnect resets the terminal stream")
