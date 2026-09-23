import SwiftUI
import AppKit
import Combine
import SwiftTerm

final class SafeTerminalView: TerminalView {
    var onPasteRequest: ((String) -> Void)?
    override func paste(_ sender: Any) {
        if let text = NSPasteboard.general.string(forType: .string),
           text.contains("\n") || text.contains("\r") || text.unicodeScalars.contains(where: { ($0.value < 32 && $0.value != 9) || $0.value == 127 }) {
            onPasteRequest?(text)
        } else { super.paste(sender) }
    }
}

final class TerminalSession: NSObject, ObservableObject, TerminalViewDelegate {
    let view: SafeTerminalView
    @Published private(set) var hasOutput = false
    private weak var serial: SerialConnection?
    var beforeUserInput: (() -> Void)?
    private var sender: ((Data) -> Void)?
    private var resizer: ((Int, Int) -> Void)?
    private var subscription: AnyCancellable?
    var text: String { String(decoding: view.getTerminal().getBufferAsData(), as: UTF8.self) }

    override init() {
        var options = TerminalOptions.default
        options.scrollback = 5000
        options.enableSixelReported = false
        options.kittyImageCacheLimitBytes = 0
        view = SafeTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 500),
                            font: .monospacedSystemFont(ofSize: 13, weight: .regular), options: options)
        super.init()
        view.terminalDelegate = self
        view.nativeBackgroundColor = NSColor(srgbRed: 20/255, green: 20/255, blue: 22/255, alpha: 1)
        view.nativeForegroundColor = NSColor(srgbRed: 228/255, green: 225/255, blue: 220/255, alpha: 1)
        view.caretColor = NSColor(srgbRed: 231/255, green: 173/255, blue: 89/255, alpha: 1)
        view.selectedTextBackgroundColor = NSColor(srgbRed: 0.42, green: 0.32, blue: 0.19, alpha: 1)
        view.backspaceSendsControlH = true
        view.setAccessibilityLabel("Portiva seri terminal")
    }

    func bind(_ serial: SerialConnection) {
        guard self.serial !== serial else { return }
        self.serial = serial
        attach(events: serial.terminalEvents, send: { [weak serial] data in
            guard let serial, serial.connected else { return }; serial.send(data)
        })
    }

    func attach(events: PassthroughSubject<SerialConnection.TerminalEvent, Never>,
                send: @escaping (Data) -> Void, resize: ((Int, Int) -> Void)? = nil) {
        sender = send; resizer = resize
        subscription = events.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .reset:
                self.view.getTerminal().resetToInitialState()
                self.view.clearScrollback()
                self.view.feed(text: "\u{1b}[2J\u{1b}[H")
                self.hasOutput = false
            case .clear:
                self.view.clearScrollback()
                self.view.feed(text: "\u{1b}[2J\u{1b}[H")
                self.hasOutput = false
            case .bytes(let data):
                self.view.feed(byteArray: Array(data)[...])
                if !self.hasOutput { self.hasOutput = true }
            }
        }
    }

    func focus() { view.window?.makeFirstResponder(view) }
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        beforeUserInput?()
        sender?(Data(data))
    }
    // Serial lines have no standard terminal-size negotiation. Do not send vendor commands.
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) { resizer?(newCols, newRows) }
    func setTerminalTitle(source: TerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func scrolled(source: TerminalView, position: Double) {}
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
    func clipboardCopy(source: TerminalView, content: Data) {}
    func clipboardRead(source: TerminalView) -> Data? { nil }
}

struct TerminalHost: NSViewRepresentable {
    let session: TerminalSession
    let fontSize: Double
    func makeNSView(context: Context) -> TerminalView { session.view }
    func updateNSView(_ view: TerminalView, context: Context) {
        if view.font.pointSize != fontSize {
            view.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
    }
}
