import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum FileDialogs {
    static func saveText(_ text: String, name: String) throws {
        let panel = NSSavePanel(); panel.nameFieldStringValue = name; panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try Data(text.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    static func openText() throws -> String? {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let data = try handle.read(upToCount: 1_048_577) ?? Data()
        guard data.count <= 1_048_576, let value = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        return value
    }
}

struct ConnectionForm: View {
    @Binding var profile: ConnectionProfile
    var ports: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Profil adı", text: $profile.name)
            Picker("Bağlantı", selection: $profile.kind) {
                ForEach(ConnectionKind.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            if profile.kind == .serial {
                Picker("Port", selection: $profile.device) {
                    Text("Port seçin").tag("")
                    ForEach(ports, id: \.self) { Text($0.replacingOccurrences(of: "/dev/", with: "")).tag($0) }
                    if !profile.device.isEmpty && !ports.contains(profile.device) { Text("\(profile.device) • bulunamadı").tag(profile.device) }
                }
                HStack { Text("Baud"); TextField("115200", text: $profile.baud).font(.system(.body, design: .monospaced)) }
                Picker("Veri biti", selection: $profile.dataBits) { ForEach([5,6,7,8], id: \.self) { Text(String($0)).tag($0) } }
                Picker("Parity", selection: $profile.parity) { ForEach(["None","Even","Odd"], id: \.self) { Text($0).tag($0) } }
                Picker("Stop biti", selection: $profile.stopBits) { Text("1").tag(1); Text("2").tag(2) }
                Picker("Akış kontrolü", selection: $profile.flowControl) { ForEach(["None","RTS/CTS","XON/XOFF"], id: \.self) { Text($0).tag($0) } }
            } else {
                TextField("Sunucu / IP adresi", text: $profile.host)
                HStack {
                    TextField("Kullanıcı", text: $profile.username)
                    TextField("Port", text: $profile.sshPort).frame(width: 65)
                }
                HStack {
                    TextField("Özel anahtar dosyası (isteğe bağlı)", text: $profile.identityFile)
                    Button { chooseKey() } label: { Image(systemName: "folder") }.help("SSH anahtarını seç")
                }
                Text("Parola ve ilk sunucu anahtarı onayı terminalde sorulur. Anahtar dosyası seçmezseniz OpenSSH’nin varsayılan anahtarları kullanılır.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Picker("Cihaz ailesi", selection: $profile.family) { ForEach(DeviceFamily.allCases) { Text($0.rawValue).tag($0) } }
        }.textFieldStyle(.roundedBorder)
    }
    private func chooseKey() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.showsHiddenFiles = true
        if panel.runModal() == .OK, let url = panel.url { profile.identityFile = url.path }
    }
}

struct ProfilesView: View {
    @ObservedObject var library: LibraryStore
    var ports: [String]
    var open: (ConnectionProfile) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ConnectionProfile()
    @State private var saved = false
    var body: some View {
        VStack(spacing: 16) {
            HStack { Text("Bağlantı profilleri").font(.title2.bold()); Spacer(); Button("Bitti") { dismiss() } }
            HStack(alignment: .top, spacing: 20) {
                VStack {
                    List(library.profiles) { profile in
                        Button { draft = profile; saved = false } label: {
                            VStack(alignment: .leading) { Text(profile.name); Text(profile.kind.rawValue + " • " + profile.target).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                        }.buttonStyle(.plain)
                    }.frame(width: 235)
                    Button("Yeni profil") { draft = ConnectionProfile(); saved = false }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ConnectionForm(profile: $draft, ports: ports)
                        HStack {
                            Button("Kaydet") { saved = library.save(draft) }.disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                            Button("Sekmede aç") { open(draft); dismiss() }
                            Spacer()
                            Button("Sil", role: .destructive) { library.removeProfile(draft.id); draft = ConnectionProfile() }
                                .disabled(!library.profiles.contains(where: { $0.id == draft.id }))
                        }
                        if saved { Text("Profil kaydedildi.").foregroundStyle(.secondary) }
                        if let error = library.error { Text(error).foregroundStyle(.red) }
                    }.padding(4)
                }
            }
        }.padding(24).frame(width: 760, height: 570).preferredColorScheme(.dark)
    }
}

struct CommandsView: View {
    @ObservedObject var library: LibraryStore
    var canSend: Bool
    var send: (SavedCommand) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft = SavedCommand()
    @State private var saved = false
    var body: some View {
        VStack(spacing: 16) {
            HStack { Text("Komut kitaplığı").font(.title2.bold()); Spacer(); Button("Bitti") { dismiss() } }
            HStack(alignment: .top, spacing: 18) {
                VStack {
                    List(library.commands) { command in
                        Button { draft = command; saved = false } label: { Text(command.name) }.buttonStyle(.plain)
                    }.frame(width: 210)
                    Button("Yeni komut") { draft = SavedCommand(); saved = false }
                }
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Ad", text: $draft.name)
                    TextField("Açıklama", text: $draft.note)
                    TextEditor(text: $draft.text).font(.system(size: 13, design: .monospaced)).border(Color.white.opacity(0.12))
                    Text("Komutlar yerel dosyada saklanır. Parola veya özel anahtar eklemeyin. Göndermeden önce hedef ve metin önizlenir.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Kaydet") { saved = library.save(draft) }.disabled(draft.name.isEmpty || draft.text.isEmpty)
                        Button("Önizle ve gönder") { send(draft); dismiss() }.disabled(!canSend || draft.text.isEmpty)
                        Spacer()
                        Button("Sil", role: .destructive) { library.removeCommand(draft.id); draft = SavedCommand() }
                            .disabled(!library.commands.contains(where: { $0.id == draft.id }))
                    }
                    if saved { Text("Komut kaydedildi.").font(.caption).foregroundStyle(.secondary) }
                    if let error = library.error { Text(error).foregroundStyle(.red) }
                }.textFieldStyle(.roundedBorder)
            }
        }.padding(24).frame(width: 800, height: 530).preferredColorScheme(.dark)
    }
}

struct PreviewView: View {
    @ObservedObject var tab: SessionTab
    let preview: SendPreview
    @State private var text: String
    @Environment(\.dismiss) private var dismiss
    init(tab: SessionTab, preview: SendPreview) { self.tab = tab; self.preview = preview; _text = State(initialValue: preview.text) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(preview.title).font(.title2.bold())
            Label(tab.profile.name + " • " + tab.profile.target, systemImage: "arrow.right.circle").font(.callout).textSelection(.enabled)
            TextEditor(text: $text).font(.system(size: 13, design: .monospaced)).border(Color.white.opacity(0.12))
            Text("\(CommandText.lines(text).count) satır • Her satır Enter ile, 200 ms arayla gönderilir. Yanıt beklenmez; interaktif onay isteyen komutları ayrı çalıştırın. Metni burada düzenleyebilirsiniz.")
                .font(.caption).foregroundStyle(.secondary)
            if preview.generation != tab.connection.generation { Text("Bağlantı değişti. Önizlemeyi kapatıp yeniden açın.").foregroundStyle(.red) }
            HStack {
                Button("Vazgeç") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Satırları gönder") { tab.sendPreview(text, generation: preview.generation); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!tab.connection.connected || preview.generation != tab.connection.generation || CommandText.lines(text).isEmpty || text.utf8.count > 65536 || tab.sending)
            }
        }.padding(24).frame(width: 730, height: 470).preferredColorScheme(.dark)
    }
}

struct CompareView: View {
    var snapshot: String
    @Environment(\.dismiss) private var dismiss
    @State private var before = ""
    @State private var after = ""
    @State private var rows: [DiffRow] = []
    @State private var comparing = false
    @State private var error: String?
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Yapılandırma karşılaştırma").font(.title2.bold())
                Spacer()
                Button("Farkı kaydet") { do { try FileDialogs.saveText(ConfigDiff.export(rows), name: "Portiva-config-diff.txt") } catch { self.error = error.localizedDescription } }.disabled(rows.isEmpty)
                Button("Bitti") { dismiss() }
            }
            HStack {
                editor("Önce", text: $before)
                editor("Sonra", text: $after)
            }.frame(height: 210)
            HStack {
                Text("+\(rows.filter { $0.kind == .added }.count) eklenen   −\(rows.filter { $0.kind == .removed }.count) silinen").font(.caption.monospaced())
                Spacer()
                if comparing { ProgressView().controlSize(.small) }
                Button("Karşılaştır") { compare() }.disabled(comparing)
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        HStack(spacing: 12) {
                            Text(row.oldLine.map(String.init) ?? "").frame(width: 40, alignment: .trailing)
                            Text(row.newLine.map(String.init) ?? "").frame(width: 40, alignment: .trailing)
                            Text(row.kind.rawValue + " " + row.text).textSelection(.enabled)
                        }.font(.system(size: 12, design: .monospaced)).padding(.vertical, 3).padding(.horizontal, 8)
                            .foregroundStyle(row.kind == .added ? Color.green : row.kind == .removed ? Color.red : Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(row.kind == .same ? Color.clear : (row.kind == .added ? Color.green : Color.red).opacity(0.08))
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black.opacity(0.25))
        }.padding(22).frame(width: 940, height: 680).preferredColorScheme(.dark)
            .onChange(of: before) { _ in rows = [] }.onChange(of: after) { _ in rows = [] }
    }
    private func editor(_ name: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(name).font(.headline)
                Spacer()
                Button("Dosya aç") { do { if let value = try FileDialogs.openText() { text.wrappedValue = value } } catch { self.error = "UTF-8 metin dosyası seçin (en fazla 1 MB)." } }
                Button("Terminalden al") { text.wrappedValue = snapshot }
            }
            TextEditor(text: text).font(.system(size: 12, design: .monospaced)).border(Color.white.opacity(0.1))
        }
    }
    private func compare() {
        let a = before, b = after
        guard a.utf8.count <= 1_048_576, b.utf8.count <= 1_048_576,
              a.components(separatedBy: "\n").count <= 5000, b.components(separatedBy: "\n").count <= 5000 else {
            error = "Karşılaştırma her taraf için en fazla 1 MB / 5000 satır destekler."; return
        }
        comparing = true; error = nil
        Task {
            let result = await Task.detached { ConfigDiff.compare(a, b) }.value
            if before == a && after == b { rows = result }
            comparing = false
        }
    }
}
