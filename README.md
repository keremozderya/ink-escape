# Ink Escape 0.3.1

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

Güncel doğrulama (29 Ekim 2026): Flutter 3.47.2 / Dart 3.13.2; **173/173 test**, temiz statik analiz ve **5/5 referans rota**. [Çizim, animasyon, ses ve dil güncellemesinin kanıtı](docs/UX_2026-10-29.md). Gerçek Android/iOS cihazda ses, dokunma ergonomisi ve uzun oturum doğrulaması açık. Önceki kayıt/öğretici tesliminin [142 testlik tarihsel raporu](docs/TEST_2026-10-29.md) korunur.

İlk çizim için güvenli üç adımlı öğretici ve tutunmada bas–çek açıklaması var. Yeni yolculuk mesafeyi tamamen sıfırlar; efektler kapalıyken de ölüm/tamamlanma müziği durur. Kayıtlar çift yuva ve yeni üst bilgi checksum korumasıyla yüklenir.

## İçerik

Yenilenmiş karakter animasyonu, zeminle aynı hızda kayan ve zemine oturan çevre çizimleri, seyrek ders notu/mektup ayrıntıları ve atlanabilir 37 saniyelik açılış animatiği. Yatay oyun alanı pencereyi doldurur; zemin ekranın alt kenarına yakındır. Mevcut iki oynanabilir bölüm yaklaşık 2,5 dakika sürer. Üç mekanik laboratuvarı geliştirme parametresiyle açılır. 300 bölümün tamamı bu pakette yoktur.

Eski sürümün kayıtlarında tamamlanan bölümler korunur; değişen parkur nedeniyle mevcut bölüm başlangıcından devam edilir. Yeni sürüm kendi 5 saniyelik kayıt konumundan devam eder.

Kaynaklar lib/; görseller, sesler, fontlar ve bölüm verileri assets/; platform projeleri android/ ve ios/; otomatik kontroller test/ altındadır. Font lisansları assets/fonts/ içindedir.

## Çizim, animasyon ve dil güncellemesi

Dokunmatik çizimde parmağın üstünde 1,75× büyüteç, hedef işareti ve canlı mürekkep maliyeti gösterilir. Çizim gerçek dokunma konumunu kullanır. Doğal kâğıdın açık kenarında 12 birime kadar yükseltilmiş mürekkep çizgisine basılabilir; baş üstündeki çizgiler zemine dönüştürülmez. Yürüme, düşme ve tutunma geçişleri yumuşatılmış, gövde esnemesi azaltılmıştır. Altı kısa ıslak mürekkep adım sesi eklenmiştir.

**Ayarlar → Dil**: Türkçe, İngilizce, Almanca, Fransızca, İspanyolca, Portekizce, Rusça, Basitleştirilmiş Çince, Japonca, Korece, Arapça ve Endonezce. İlk açılışta cihaz dili önerilir; desteklenmeyen diller İngilizceye düşer. Seçim kalıcıdır ve oyunu sıfırlamaz. Arayüz, öğretici, hikâye altyazıları ve hata nedenleri çevrilmiştir. Arka plan ders notu ve mektup metinleri bütün dillerde İngilizcedir. Storyboard'un 12 sahnesi ve 37 saniyelik akışı korunur.

105 metin `lib/l10n/catalog.dart` içindedir. Arapça/CJK font alt kümeleri çevrimdışı paketlenir; OFL metinleri `assets/fonts/`, kaynak ve hash'ler [font manifestinde](docs/localization-font-sources.json) bulunur. Yeni çeviri karakterleri eklenirse font alt kümeleri `scripts/subset_localization_fonts.py` ile yeniden üretilmelidir. Adım sesleri `python scripts/make_ink_steps.py` ile yeniden üretilebilir.
