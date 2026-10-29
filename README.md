# Ink Escape 0.3.2

Flutter + Flame mobil oyun projesi.

## Çalıştırma

Bu dosyanın ve pubspec.yaml dosyasının bulunduğu klasörde:

```powershell
flutter pub get
flutter run
```

Test ve statik kontrol:

```powershell
flutter test
flutter analyze
```

Güncel doğrulama (29 Ekim 2026): Flutter 3.47.2 / Dart 3.13.2; **209/209 test**, temiz statik analiz ve **5/5 referans rota**. [Duvar teması, otomatik zıplama ve okunur menü kanıtı](docs/JUMP_MENU_2026-10-29.md). Gerçek Android/iOS cihazda ses, dokunma ergonomisi ve uzun oturum doğrulaması açık. Önceki [173 testlik çizim/dil](docs/UX_2026-10-29.md) ve [142 testlik kayıt/öğretici](docs/TEST_2026-10-29.md) raporları tarihsel olarak korunur.

İlk çizim için güvenli üç adımlı öğretici ve tutunmada bas–çek açıklaması var. Yeni yolculuk mesafeyi tamamen sıfırlar; efektler kapalıyken de ölüm/tamamlanma müziği durur. Kayıtlar çift yuva ve yeni üst bilgi checksum korumasıyla yüklenir.

## İçerik

Yenilenmiş karakter animasyonu, zeminle aynı hızda kayan ve zemine oturan çevre çizimleri, seyrek ders notu/mektup ayrıntıları ve atlanabilir 37 saniyelik açılış animatiği. Yatay oyun alanı pencereyi doldurur; zemin ekranın alt kenarına yakındır. Mevcut iki oynanabilir bölüm yaklaşık 2,5 dakika sürer. Üç mekanik laboratuvarı geliştirme parametresiyle açılır. 300 bölümün tamamı bu pakette yoktur.

Eski sürümün kayıtlarında tamamlanan bölümler korunur; değişen parkur nedeniyle mevcut bölüm başlangıcından devam edilir. Yeni sürüm kendi 5 saniyelik kayıt konumundan devam eder.

Kaynaklar lib/; görseller, sesler, fontlar ve bölüm verileri assets/; platform projeleri android/ ve ios/; otomatik kontroller test/ altındadır. Font lisansları assets/fonts/ içindedir.

## Çizim, animasyon ve dil güncellemesi

Dokunmatik çizimde parmağın üstünde 1,75× büyüteç, hedef işareti ve canlı mürekkep maliyeti gösterilir. Çizim gerçek dokunma konumunu kullanır. Doğal kâğıdın açık kenarında 12 birime kadar yükseltilmiş mürekkep çizgisine basılabilir; baş üstündeki çizgiler zemine dönüştürülmez. Yürüme, düşme ve tutunma geçişleri yumuşatılmış, gövde esnemesi azaltılmıştır. Altı kısa ıslak mürekkep adım sesi eklenmiştir.

**Ayarlar → Dil**: Türkçe, İngilizce, Almanca, Fransızca, İspanyolca, Portekizce, Rusça, Basitleştirilmiş Çince, Japonca, Korece, Arapça ve Endonezce. İlk açılışta cihaz dili önerilir; desteklenmeyen diller İngilizceye düşer. Seçim kalıcıdır ve oyunu sıfırlamaz. Arayüz, öğretici, hikâye altyazıları ve hata nedenleri çevrilmiştir. Arka plan ders notu ve mektup metinleri bütün dillerde İngilizcedir. Storyboard'un 12 sahnesi ve 37 saniyelik akışı korunur.

105 metin `lib/l10n/catalog.dart` içindedir. Arapça/CJK font alt kümeleri çevrimdışı paketlenir; OFL metinleri `assets/fonts/`, kaynak ve hash'ler [font manifestinde](docs/localization-font-sources.json) bulunur. Yeni çeviri karakterleri eklenirse font alt kümeleri `scripts/subset_localization_fonts.py` ile yeniden üretilmelidir. Adım sesleri `python scripts/make_ink_steps.py` ile yeniden üretilebilir.

## Duvar teması, zıplama ve menü

Karşı kıyıya biraz aşağıdan bağlanan çizgide Dot artık dolu kâğıt duvarın içine yürümez. Doğal kıyı veya dik çizgide, ayak hizasından **gövde boyunun 3/4'üne (24 u)** kadar olan kısa yükseltiyi otomatik zıplayarak aşar. Havalanma ve iniş fizik üzerinden ilerler; daha yüksek engellerde mevcut tutunma/takılma kuralları geçerlidir. Önceki 32 u dik yürüyüş sınırının yerine 24 u otomatik zıplama gelir; normal 55° yokuşlar değişmez. Zıplarken pause ve kayıt yükleme aynı konumu/hızı sürdürür.

Ana ve ara menü butonları opak mürekkep/kâğıt yüzey, çerçeve ve hafif gölge kullanır. Bütün menü butonları en az 48 dp yüksekliğindedir; küçük ekranda menü kaydırılabilir. [Doğrulama ve ekran görüntüleri](docs/JUMP_MENU_2026-10-29.md).

## Oynanış yükü

HUD değerleri artık yalnız HUD alt ağacını yeniler; Flame görünümü aynı widget olarak korunur. Yerel uygulamada beş saniyelik kayıtların JSON/checksum kodlaması arka plandaki isolate üzerinde çalışır. İki kayıt yuvası, yazma sırası, reset fence ve eski kayıt formatı korunur. Bu değişiklikler bilinen yükleri azaltır; fiziksel cihazda kare süresi ölçümü yapılmadan bütün takılmaların çözüldüğü söylenmez. [Önce/sonra kanıtı](docs/JUMP_MENU_2026-10-29.md).
