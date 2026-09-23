import SwiftUI

struct SettingsView: View {
    @AppStorage("privacy.hideInput") private var hideInput = false
    @AppStorage("terminal.fontSize") private var fontSize = 13.0

    var body: some View {
        Form {
            Section {
                Toggle("Komut / parola alanındaki yazıyı gizle", isOn: $hideInput)
                Text("Açıkken alt giriş alanında yazdıklarınız nokta olarak görünür. Gönderilen metin kaydedilmez. Terminale doğrudan yazarken yerel yankı yapılmaz; cihazın geri gönderdiği çıktı bu ayardan etkilenmez.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Label("Gizlilik", systemImage: "lock") }
            Section {
                HStack {
                    Text("Terminal yazı boyutu")
                    Slider(value: $fontSize, in: 10...22, step: 1)
                    Text("\(Int(fontSize)) pt").monospacedDigit().frame(width: 42)
                }
                Text("Terminale tıklayıp doğrudan yazabilirsiniz. Ok tuşları, Tab, Escape ve Ctrl kısayolları bağlı cihaza iletilir. ⌘C / ⌘V seçimi kopyalar ve yapıştırır.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Label("Terminal", systemImage: "terminal") }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 510, height: 330)
        .preferredColorScheme(.dark)
        .tint(Color(red: 231/255, green: 173/255, blue: 89/255))
    }
}
