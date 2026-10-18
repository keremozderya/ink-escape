# Ink Escape · Flutter + Flame

Android ve iOS için doğrudan açılıp çalıştırılabilen Flutter projesi. Sürüm **0.2.0+2**, 18 Ekim 2026.

## Bilgisayarında çalıştır

Flutter SDK ve Android Studio/Android SDK kurulu olmalı. Projeyi ZIP'ten çıkar; `pubspec.yaml` bulunan **ink-escape** klasöründe terminal aç:

```powershell
flutter pub get
flutter devices
flutter run
```

Birden fazla cihaz varsa `flutter run -d CIHAZ_ID` kullan. Android telefonunda geliştirici seçenekleri ve USB hata ayıklama açık olmalı. İlk Gradle derlemesi internet bağlantısıyla bağımlılık indirir.

Doğrulanan SDK: Flutter **3.47.5**, Dart **3.13.4**. Projenin asgari bağımlılık gereksinimi Flutter 3.41 / Dart 3.11; kilit dosyası pakete dahildir. Native cihaz derlemesi ve fiziksel cihaz testi bu ortamda yapılmadı; Android SDK bulunmuyor. iOS çalıştırma/derleme için macOS ve Xcode gerekir.

```powershell
flutter test
flutter analyze
flutter build apk --debug
```

APK komutunun yerel çıktı yolu: `build/app/outputs/flutter-apk/app-debug.apk`. Teslimde önceden derlenmiş APK/IPA yoktur.

## GitHub'a push — Windows PowerShell

GitHub reponda **Code → HTTPS** adresini kopyala. `GITHUB_REPO_URL` yerine o adresi yaz. Aşağıdaki komutu `pubspec.yaml` bulunan klasörde çalıştır:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\push_to_github.ps1 -RepoUrl "GITHUB_REPO_URL"
```

Komut repoyu yan klasöre (`ink-escape-github`) klonlar, proje dosyalarını içine kopyalar, commit oluşturur ve `main` dalına push eder. Mevcut başlangıç commit'i korunur; force push yapılmaz. GitHub'ın giriş ekranı açılırsa kendi hesabınla tamamla. Hedef klasör zaten varsa üzerine yazmaz; farklı bir konum için `-CheckoutPath "C:\Projects\ink-escape-github"` ekleyebilirsin.

Script yerine elle yapmak için:

```powershell
git clone "GITHUB_REPO_URL" ink-escape-github
cd ink-escape-github
```

Sonra ZIP'teki `ink-escape` klasörünün **içindekileri** klonlanan klasörün içine kopyala; `pubspec.yaml` ve `.gitignore` burada olmalı. Ardından:

```powershell
git checkout -B main
git add .
git commit -m "Create native Ink Escape Flutter and Flame prototype"
git push -u origin main
```

Git ad/e-posta ayarı isterse kendi bilgilerini kullan: `git config --global user.name "ADIN"` ve `git config --global user.email "EPOSTAN"`.

## Bu sürümdeki düzeltmeler

- Küçük el titremeleri kısa segmentlerde fazla dik algılanıp bütün çizgiyi reddedebiliyordu. Çizgi artık eşit aralıklarla örneklenip dar bir toleransla yumuşatılıyor; kasıtlı kemer yoğun noktalarıyla korunuyor. Gerçek diklik, uzunluk, iki sabit uç ve Ink kuralları devam ediyor.
- Çizim fare ve dokunma olaylarıyla gerçek Flutter arayüzünden test ediliyor; yalnızca çekirdeğe doğrudan çizgi gönderen testlerle yetinilmiyor.
- İlk çizimde başlangıç/bitiş kenarları işaretleniyor. Mürekkep bedeli parmak kalkana kadar kesilmiyor.
- Dot'un gövdesi aynı detaylı görseli koruyor; ayaklar sürekli hareket ediyor. Ayak kaldırma ease-in-out cubic, gövdede yumuşak esneme ve salınım var. Ses ayak temasına bağlı.
- Altı farklı ıslak mürekkep adımı: yumuşak basma, sıvı sıkışması, küçük kabarcıklar ve yapışarak ayrılma. Eski kısa tiz ayak sesleri değiştirildi. Kâğıt, kapı, çizgi bitişi, silinme ve toplama efektleri de malzeme hissine göre yenilendi.
- Ayak seslerini oyunsuz dinlemek için `docs/ink_footsteps_preview.wav` dosyasını aç. Sesler hâlâ özgün sentetik foley taslaklarıdır; son cihazdaki algısı ayrıca değerlendirilmeli.

## Oyun kapsamı ve kurallar

Bu ilk üretim sürümü, 300 bölümün tasarımından alınan **ilk iki bölüm** ve üç kısa mekanik denemesini içerir. Normal hikâyede bölüm/mod seçimi yoktur. İlk iki bölüm yaklaşık beşer dakika sürer; ikinci bölüm sonunda prototip tamamlanır. Lumi bu erken bölümlerde görünmez.

Dot kendi yürür ve kenarda beklemez. Bir sabit kâğıt yüzeyinden diğerine soldan sağa çiz. Yerel eğim en fazla 0.70, çizgi uzunluğu en fazla 220; en fazla iki çizgi aynı anda görev yapabilir. Bir çizginin üstündeyken destek kaldırılmaz. Dot bütün gövdesiyle doğal zemine geçince tamamlanan yol çözünür. Güvenli doğal zeminde Ink 10/oyun saniyesi yenilenir; çizgi, hava ve duraklamada yenilenmez.

Çizim sırasında yavaşlama son altı aktif gerçek saniyede toplam iki saniye ile sınırlıdır. Duraklatma fiziği ve çizimi dondurur. Oturum beş aktif gerçek saniyede bir kaydedilir. Yeniden açılışta **Devam et** beklenir; yarım çizgi varsa ucuna yeniden dokunularak sürdürülür. Ölüm, mevcut bölümün başlangıcına döndürür. Bölüm içinde kontrol noktası yoktur.

Geliştirme denemeleri, normal oyuncu menüsüne eklenmeden derleme parametresiyle açılır:

```powershell
flutter run --dart-define=INK_LAB=two
flutter run --dart-define=INK_LAB=roof
flutter run --dart-define=INK_LAB=ball
```

VS Code'da aynı seçenekler `.vscode/launch.json` içinde hazırdır.

## Dosyalar

| Konum | İşlev |
| --- | --- |
| `lib/main.dart` | Uygulama, dokunma, başlangıç, kayıt ve duraklatma akışı |
| `lib/core/ink_model.dart` | Çizim, yumuşatma, fizik, Ink, görevler ve tam oturum durumu |
| `lib/core/save_journal.dart` | Sağlama toplamlı iki yuvalı kayıt; ölüm/sıfırlama işareti |
| `lib/ink_game.dart` | Gerçek oyun çizimi ve kamera |
| `lib/presentation/ink_motion.dart` | Fizikten bağımsız akıcı yürüyüş pozu |
| `lib/soundscape.dart` | Altı ayak örneği, kalem, olay sesleri ve müzik |
| `assets/data/prototype_levels.json` | İlk iki bölümün ve mekanik hücrelerinin gerçek koordinatları |
| `assets/images` | Dot/Lumi, çevre ve nesne taslakları |
| `assets/audio` | Uygulamaya gömülü müzik ve efektler |
| `test` | Fizik, kayıt, gerçek dokunma/fare ve animasyon kontrolleri |
| `docs` | Test notları ve ses dinleme örneği |

## Görsel ve ses kaynakları

Görseller bu proje için Imagegen ile hazırlanmış ilk taslaklardır; nihai karakter onayı sayılmaz. Gövde/atlaslar Flutter Canvas ile çalışma anında kullanılır. Sesler özgün sentezdir. `scripts/make_ink_foley.py` efektleri, `scripts/make_music.py` hafif 58 BPM müziği üretir; bu üretim scriptleri Python/numpy/scipy/ffmpeg gerektirir. **Oyunu çalıştırmak için Python veya ffmpeg gerekmez.** Nunito ve Cormorant Garamond fontlarının SIL OFL lisansları `assets/fonts` içindedir.

Reklam SDK'sı ve mağaza yayını bu sürüme dahil edilmedi. Başarıyla geçen otomatik referans çözümler, insanlarla zorluk/eğlence testi veya 300 bölümün motor içinde doğrulandığı anlamına gelmez.
