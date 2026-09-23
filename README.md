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

**İmza durumu:** Bu sürüm Apple Development sertifikasıyla imzalı bir test paketidir. Developer ID imzası ve Apple notarization içermez. Başka Mac'lerde Gatekeeper uyarısı veya açılış engeli olabilir; herkesin Mac'inde sorunsuz kurulum henüz garanti edilmez. Açılmazsa macOS sürümüyle birlikte hata mesajını [Issues](https://github.com/CanBasmaci/portiva-releases/issues) bölümünde paylaşabilirsiniz. Parola veya cihaz yapılandırmanızdaki gizli bilgileri paylaşmayın.

## İlk seri bağlantı

1. Console kablosunu Mac'e ve cihazın console portuna takın.
2. Portiva'da **Serial** seçin ve **Port** alanından kablonuzu seçin. Görünmezse yenile düğmesini kullanın.
3. **Baud** değerini elle girin; veri biti, parity, stop biti ve akış kontrolünü cihazınızın belgelerine göre ayarlayın.
4. **Bağlan** düğmesine basın, terminale tıklayıp Enter gönderin.
5. İsterseniz bağlantıya ad vererek **Profili kaydet** ile ayarları saklayın.

Aruba 6100 için bu projede kullanılan ayarlar: **115200 baud, 8 veri biti, parity None, 1 stop biti, akış kontrolü None**. Diğer modellerde cihazın kendi ayarlarını kullanın. Kullanıcı tarafından Aruba 6100 üzerinde VLAN yapılandırması test edilmiştir; tüm switch modelleri test edilmemiştir.

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

## Yeni sürüme geçiş

Portiva otomatik güncelleme denetlemez veya indirme yapmaz. Yeni sürümü **Releases** sayfasından indirin; açık bağlantıları kapatıp Portiva'dan çıkın. Yeni DMG içindeki uygulamayı Uygulamalar klasörüne sürükleyip mevcut uygulamayı değiştirin. Aynı uygulama kimliğiyle ayarlar korunur; profiller ve komutlar `~/Library/Application Support/Portiva/` altında tutulur.

## İndirme doğrulaması

Her sürümde `SHA256SUMS.txt` yayımlanır. DMG ve bu dosyayı aynı klasöre indirdikten sonra Terminal'de o klasörde `shasum -a 256 -c SHA256SUMS.txt` çalıştırabilirsiniz. Sonuç `OK` olmalıdır. Sağlama toplamı dosya bütünlüğünü kontrol eder; Apple notarization yerine geçmez.

Bu depo kurulum paketlerini, kullanım açıklamalarını ve sürüm notlarını dağıtır.
