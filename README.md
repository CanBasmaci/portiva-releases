# Portiva

macOS için serial ve SSH console uygulaması. USB console bağlantıları, bağımsız oturum sekmeleri ve günlük ağ yönetimi işleri için geliştirilmiştir.

**[Son sürümü indir →](https://github.com/CanBasmaci/portiva-releases/releases/latest)**

## Gereksinimler

- macOS 13 veya üzeri; Apple Silicon veya Intel Mac.
- Seri bağlantı için cihazınıza uygun USB/console kablosu. Bazı kablolar üreticisinin macOS sürücüsünü gerektirebilir.
- SSH için erişilebilir bir sunucu/cihaz ve geçerli kullanıcı hesabı.

## Kurulum

1. Yukarıdaki bağlantıdan son sürümün **Assets** bölümünü açın.
2. `Portiva-0.6.1.dmg` dosyasını indirin. GitHub'ın otomatik oluşturduğu **Source code** arşivleri kurulum paketi değildir.
3. İndirdiğiniz DMG dosyasını açın.
4. **Portiva** uygulamasını aynı penceredeki **Applications / Uygulamalar** klasörüne sürükleyin.
5. Uygulamayı **Uygulamalar** klasöründen açın. Ardından Portiva disk imajını çıkarabilirsiniz.

## İlk seri bağlantı

1. Console kablosunu Mac'e ve cihazın console portuna takın.
2. Portiva'da **Serial** seçin ve **Port** alanından kablonuzu seçin. Görünmezse yenile düğmesini kullanın.
3. **Baud** değerini elle girin; veri biti, parity, stop biti ve akış kontrolünü cihazınızın belgelerine göre ayarlayın.
4. **Bağlan** düğmesine basın, terminale tıklayıp Enter gönderin.
5. İsterseniz bağlantıya ad vererek **Profili kaydet** ile ayarları saklayın.

## SSH bağlantısı

**SSH** seçin; adres, kullanıcı adı ve portu girin (varsayılan 22). Gerekirse özel anahtar dosyanızı seçin ve bağlanın. İlk sunucu anahtarı onayı ve parola istemi terminalde görünür; sunucu anahtarını güvenilir kaynaktan doğrulayın. Parolalar bağlantı profiline kaydedilmez. SSH işleminin çalışması kimlik doğrulamanın tamamlandığı anlamına gelmez; terminaldeki yanıtı kontrol edin. Gerçek cihazla SSH oturum açma testi henüz tamamlanmamıştır.

## Araçlar

- **+ düğmesi:** Bağımsız oturum sekmesi açar. Aynı seri port iki sekmede açılamaz.
- **Komut kitaplığı:** Sık kullanılan komutları yerel olarak saklar. Parola eklemeyin.
- **Çok satırlı gönderim:** Hedefi ve metni önizletir; onaydan sonra satırları 200 ms aralıkla gönderir. Cihaz yanıtını beklemez; etkileşimli onay isteyen komutları ayrı çalıştırın. Gönderimi durdurabilirsiniz.
- **Oturum kaydı:** Gelen cihaz çıktısını dosyaya kaydeder. Gizli girişte veya tanınan parola istemlerinde duraklar. Cihazın yazdırdığı yapılandırmalarda yine de hassas bilgiler bulunabilir.
- **Ayarlar → gizli giriş:** Alt komut/parola alanını maskeler. Cihazın geri gönderdiği metni gizlemez. Gizli giriş açıkken çok satırlı yapıştırma engellenir.
- **Yapılandırma karşılaştırma:** İki metin/dosya veya terminal çıktısı arasındaki satır farklarını gösterir ve dışa aktarır.
- **Cihaz ailesi:** Aruba AOS-CX, Cisco IOS/IOS-XE ve Juniper Junos için VLAN/interface/MAC sorgularını önizlemeyle sunar. Sonuçlar terminalde görünür. Diğer cihazlarda Genel seçilebilir.

## İndirme doğrulaması

Her sürümde `SHA256SUMS.txt` yayımlanır. DMG ve bu dosyayı aynı klasöre indirdikten sonra Terminal'de o klasörde `shasum -a 256 -c SHA256SUMS.txt` çalıştırabilirsiniz. Sonuç `OK` olmalıdır. Sağlama toplamı dosya bütünlüğünü kontrol eder; Apple notarization yerine geçmez.

## Kaynak kod ve geliştirme

Swift/SwiftUI kaynak kodu, Xcode projesi, testler ve paketleme betikleri bu depodadır.
`Portiva.xcodeproj` dosyasını Xcode ile açın; **Portiva / My Mac** hedefini seçin.
İmzalı yerel derleme için Signing & Capabilities bölümünde kendi Apple takımınızı seçin.
SwiftTerm bağımlılığı ve shader derlemesi için Xcode Metal Toolchain bileşeni gerekir.

Ayrıntılı derleme ve test adımları için [geliştirici belgesine](DEVELOPMENT.md) bakın.
Kurulum dosyaları [Releases](https://github.com/CanBasmaci/portiva-releases/releases) bölümündedir.
