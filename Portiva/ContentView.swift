import SwiftUI
import Combine
import AppKit

struct ContentView: View {
    @ObservedObject var workspace: WorkspaceModel
    @State private var closing: SessionTab?
    @AppStorage("privacy.hideInput") private var hideInput = false
    private let accent = Color(red: 0.91, green: 0.68, blue: 0.35)
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image("Logo").resizable().scaledToFit().frame(width: 30, height: 30)
                Text("Portiva").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(workspace.tabs) { tab in
                            HStack(spacing: 8) {
                                Button { workspace.activeID = tab.id } label: {
                                    HStack {
                                        Circle().fill(tab.connection.connected ? accent : Color.gray).frame(width: 6, height: 6)
                                        Text(tab.profile.name.isEmpty ? "Adsız oturum" : tab.profile.name).lineLimit(1)
                                        if tab.recorder.recording { Image(systemName: "record.circle").foregroundStyle(.red) }
                                    }
                                }
                                Button {
                                    if tab.connection.connected || tab.connection.busy { closing = tab }
                                    else { workspace.close(tab) }
                                } label: { Image(systemName: "xmark").font(.caption2) }.help("Sekmeyi kapat")
                            }.buttonStyle(.plain).padding(10)
                                .background(workspace.activeID == tab.id ? Color.white.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                Button { workspace.add() } label: { Image(systemName: "plus") }.help("Yeni oturum")
            }.padding(12)
            Divider()
            if let tab = workspace.tabs.first(where: { $0.id == workspace.activeID }) {
                SessionView(tab: tab, workspace: workspace).id(tab.id)
            }
        }.frame(minWidth: 1080, minHeight: 720)
            .background(Color(red: 0.078, green: 0.078, blue: 0.086)).preferredColorScheme(.dark).tint(accent)
            .alert("Açık oturum kapatılsın mı?", isPresented: Binding(get: { closing != nil }, set: { if !$0 { closing = nil } })) {
                Button("Vazgeç", role: .cancel) { closing = nil }
                Button("Bağlantıyı kes ve kapat", role: .destructive) { if let tab = closing { workspace.close(tab) }; closing = nil }
            }
            .alert("Bağlantı", isPresented: Binding(get: { workspace.error != nil }, set: { if !$0 { workspace.error = nil } })) {
                Button("Tamam") { workspace.error = nil }
            } message: { Text(workspace.error ?? "") }
            .onChange(of: hideInput) { value in
                for tab in workspace.tabs { tab.draft = ""; tab.preview = nil; if value { tab.recorder.pause() } }
            }
    }
}

private struct SessionView: View {
    @ObservedObject var tab: SessionTab
    @ObservedObject var workspace: WorkspaceModel
    @AppStorage("privacy.hideInput") private var hideInput = false
    @AppStorage("terminal.fontSize") private var fontSize = 13.0
    @State private var tool: Tool?
    @State private var queuedCommand: SavedCommand?
    private enum Tool: String, Identifiable { case profiles, commands, compare; var id: String { rawValue } }
    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                toolbar
                Divider()
                if let loss = tab.connection.lossMessage {
                    HStack {
                        Label(loss, systemImage: "exclamationmark.triangle").font(.caption)
                        Spacer()
                        Button("Yeniden bağlan") { workspace.connect(tab) }
                        Button { tab.connection.lossMessage = nil } label: { Image(systemName: "xmark") }
                    }.padding(12).background(Color.orange.opacity(0.12))
                }
                if tab.recorder.recording {
                    HStack {
                        Label(tab.recorder.paused ? "Kayıt duraklatıldı" : "Cihaz çıktısı kaydediliyor", systemImage: "record.circle")
                        Spacer()
                        Button(tab.recorder.paused ? "Kayda devam et" : "Duraklat") {
                            if tab.recorder.paused { tab.recorder.resume() } else { tab.recorder.pause() }
                        }.disabled(tab.recorder.paused && hideInput)
                        Button("Kaydı bitir") { tab.recorder.stop() }
                    }.font(.caption).padding(10).background(Color.red.opacity(0.08))
                }
                TerminalHost(session: tab.terminal, fontSize: fontSize).padding(10)
                    .overlay {
                        if !tab.terminal.hasOutput && !tab.connection.connected {
                            VStack(spacing: 12) {
                                Image(systemName: "terminal").font(.system(size: 32, weight: .ultraLight))
                                Text("Bağlantıya hazır").font(.title3)
                                Text("Soldan Serial veya SSH seçip bağlanın.").font(.callout).foregroundStyle(.secondary)
                            }.allowsHitTesting(false)
                        }
                    }
                commandBar
            }
        }
        .onAppear { tab.connection.serial.refreshPorts() }
        .onReceive(refresh) { _ in tab.connection.serial.refreshPorts() }
        .sheet(item: $tool, onDismiss: {
            if let command = queuedCommand { queuedCommand = nil; tab.requestPreview(command.text, title: command.name) }
        }) { item in
            switch item {
            case .profiles: ProfilesView(library: workspace.library, ports: tab.connection.serial.ports) { workspace.add($0) }
            case .commands: CommandsView(library: workspace.library, canSend: tab.connection.connected && !tab.sending) { queuedCommand = $0 }
            case .compare: CompareView(snapshot: tab.terminal.text)
            }
        }
        .sheet(item: $tab.preview) { PreviewView(tab: tab, preview: $0) }
        .alert("Portiva", isPresented: Binding(get: { tab.error != nil || tab.recorder.error != nil }, set: { if !$0 { tab.error = nil; tab.recorder.error = nil } })) {
            Button("Tamam") { tab.error = nil; tab.recorder.error = nil }
        } message: { Text(tab.error ?? tab.recorder.error ?? "") }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("BAĞLANTI").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                Spacer()
                Button { tool = .profiles } label: { Image(systemName: "square.stack") }.help("Bağlantı profilleri")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ConnectionForm(profile: $tab.profile, ports: tab.connection.serial.ports)
                        .disabled(tab.connection.connected || tab.connection.busy)
                    HStack {
                        Button("Profili kaydet") { if !workspace.library.save(tab.profile) { tab.error = workspace.library.error } }
                        Spacer()
                        Button { tab.connection.serial.refreshPorts() } label: { Image(systemName: "arrow.clockwise") }.help("Portları yenile")
                    }
                    Button {
                        if tab.connection.connected { tab.connection.disconnect() } else { workspace.connect(tab) }
                    } label: {
                        Label(tab.connection.connected ? "Bağlantıyı kes" : "Bağlan", systemImage: tab.connection.connected ? "stop.circle" : "bolt.horizontal.circle")
                            .frame(maxWidth: .infinity).padding(6)
                    }.buttonStyle(.borderedProminent)
                        .disabled(tab.connection.busy || (!tab.connection.connected && tab.profile.validationError != nil))
                    Text(tab.connection.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    Divider()
                    Text("ARAÇLAR").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                    Button { tool = .commands } label: { Label("Komut kitaplığı", systemImage: "text.book.closed") }
                    Button { tool = .compare } label: { Label("Yapılandırma karşılaştır", systemImage: "arrow.left.arrow.right") }
                    ForEach(tab.profile.family.readCommands, id: \.0) { command in
                        Button(command.0) { tab.requestPreview(command.1, title: command.0) }.disabled(!tab.connection.connected || tab.sending)
                    }
                    if tab.profile.family != .generic { Text("Sorgular önce önizlenir; sonuç terminalde gösterilir.").font(.caption).foregroundStyle(.secondary) }
                }.padding(2)
            }
            if #available(macOS 14, *) { SettingsLink { Label("Ayarlar", systemImage: "gearshape") } }
            else { Button("Ayarlar") { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) } }
            Text("PORTIVA / 0.6.1").font(.system(size: 9)).tracking(2).foregroundStyle(.tertiary)
        }.padding(20).frame(width: 290).background(Color.white.opacity(0.035))
    }
    private var toolbar: some View {
        HStack(spacing: 16) {
            Label(tab.profile.kind.rawValue + " Terminal", systemImage: "terminal").font(.headline)
            Spacer()
            Button { fontSize = max(10, fontSize - 1) } label: { Image(systemName: "textformat.size.smaller") }.help("Yazıyı küçült")
            Button { fontSize = min(22, fontSize + 1) } label: { Image(systemName: "textformat.size.larger") }.help("Yazıyı büyüt")
            Button {
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(tab.terminal.text, forType: .string)
            } label: { Image(systemName: "doc.on.doc") }.help("Terminal çıktısını kopyala")
            Button {
                do { try FileDialogs.saveText(tab.terminal.text, name: "Portiva-terminal.txt") } catch { tab.error = error.localizedDescription }
            } label: { Image(systemName: "square.and.arrow.up") }.help("Çıktıyı kaydet")
            Button(action: toggleRecording) { Image(systemName: tab.recorder.recording ? "stop.circle" : "record.circle") }
                .help("Oturum kaydı").disabled(!tab.connection.connected && !tab.recorder.recording)
            Button { tab.connection.clear() } label: { Image(systemName: "trash") }.help("Terminali temizle")
        }.buttonStyle(.plain).padding(18)
    }
    private var commandBar: some View {
        VStack(spacing: 10) {
            if tab.sending {
                HStack { ProgressView().controlSize(.small); Text("Komutlar gönderiliyor…"); Spacer(); Button("Gönderimi durdur") { tab.cancelBatch() } }.font(.caption)
            }
            HStack {
                Image(systemName: hideInput ? "lock" : "chevron.right").foregroundStyle(.secondary)
                Group {
                    if hideInput { SecureField("Gizli komut / parola", text: $tab.draft) }
                    else { TextField("Komut yazın veya terminale tıklayın", text: $tab.draft) }
                }.textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                    .onSubmit { tab.sendDraft(privateInput: hideInput) }
                Button { tab.sendDraft(privateInput: hideInput) } label: { Image(systemName: "arrow.turn.down.left") }.help("Gönder")
            }.padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
                .disabled(!tab.connection.connected || tab.sending)
            HStack {
                Button("Terminale odaklan") { tab.terminal.focus() }
                Button { tab.terminal.view.scroll(toPosition: 1) } label: { Image(systemName: "arrow.down.to.line") }.help("Son çıktıya git")
                Spacer()
                Picker("Satır sonu", selection: $tab.profile.lineEnding) { Text("CR").tag("\r"); Text("LF").tag("\n"); Text("CRLF").tag("\r\n") }.frame(width: 145).disabled(tab.sending)
                Button("Ctrl-C") { tab.cancelBatch(); tab.connection.send(Data([3])) }.disabled(!tab.connection.connected)
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(16)
    }
    private func toggleRecording() {
        if tab.recorder.recording { tab.recorder.stop(); return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Portiva-\(Int(Date().timeIntervalSince1970)).log"
        panel.message = "Yalnızca cihaz çıktısı kaydedilir. Parola istemlerinde kayıt duraklar; cihazın gösterdiği yapılandırma yine de hassas bilgi içerebilir."
        if panel.runModal() == .OK, let url = panel.url { tab.recorder.start(at: url, privateInput: hideInput) }
    }
}
