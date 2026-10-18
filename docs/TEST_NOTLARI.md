# Ink Escape 0.3 · Doğrulama

18 Ekim 2026. Flutter 3.47.5 / Dart 3.13.4.

- **23/23 otomatik test geçti.** 17 çekirdek/kayıt testi, 2 gerçek girdi testi, 3 animasyon testi ve 1 arayüz akışı testi.
- `dart analyze --fatal-infos`: **No issues found.**
- Telefon boyutunda dokunma: 390×844; masaüstünde fare: 1280×800. Her ikisinde de kenarın 25 dünya birimi altında başlayan, ekranda sabit koordinatları izleyen aşağı/sürükle/bırak olaylarıyla küçük titremeler içeren eğri köprü oluşturuldu. Kamera çizim sırasında sabit kaldı. Önceki test her hareketinde kameraya göre konumunu değiştiriyor ve sorunu gizliyordu. Bu boyutlar simülasyondur; fiziksel cihaz testi değildir.
- Eğriyi koruma, küçük titreme, fazla dik/uzun/ters/desteksiz çizgi, bırakmadan Ink kesilmemesi, iki çizgi sınırı ve destek emekliliği kontrol edildi.
- Dot girdi yokken beklemeden düşüyor. Çatı kırıntıyı kesiyor; çatı atlanırsa ölüm gerçekleşiyor. Bilye oluğu kapıyı açıyor; oluk atlanırsa kapı kapalı kalıyor.
- Ölüm ve tekrar deneme mevcut bölümün başlangıcına dönüyor. Gecikmiş eski kayıt, ölüm/sıfırlama işaretini aşamıyor. Yarım çizgi ve canlı nesneler korunuyor; yeniden açılışta dünya bekliyor.
- Yürüyüş pozu ve temas hızı iki ayak teması ve döngü sınırında sürekliliğini koruyor; yere basılı ayak dünya üzerinde kaymıyor. Ses her 14 kat edilen birimdeki gerçek ayak temasından tetikleniyor. Poz hesabı çarpışma gövdesini değiştirmiyor.
- Altı ayak örneği ve kalem döngüsünde WAV dosyaları, 44.1 kHz, kırpılmama ve sıfır başlangıç/bitiş kontrol edildi. Sesin öznel olarak istenen mürekkep hissini vermesi otomatik testle kanıtlanamaz; `ink_footsteps_preview.wav` dinlenebilir.

## Referans çözüm süreleri

| Akış | Aktif gerçek süre | Çizgi | Sonuç |
| --- | ---: | ---: | --- |
| Bölüm 1 | 300.308 sn | 19 | Başarılı |
| Bölüm 2 | 299.975 sn | 19 | Başarılı |
| İki bölüm, başlangıç Ink 0 | 600.283 sn | 38 | Başarılı |
| İki çizgi hücresi | 28.458 sn | 2 | Başarılı |
| Çatı hücresi | 31.583 sn | 2 | Başarılı; iki eşzamanlı çizgi |
| Bilye hücresi | 31.583 sn | 2 | Bilye yakalandı; kapı açıldı |

Çözücü, tasarımdaki noktaları herkese açık çizim API'si üzerinden bir gerçek saniye süresince girer. Bu sırada fizik saati ilerler. Oyuna doğrudan köprü enjekte edilmez. Makine çıktısı `route-verification.json` içindedir.

## Henüz doğrulanmayanlar

Android arm64 debug APK derlemesi tamamlandı (0.3.0+3). APK arşivi ve imzası kontrol edildi; içindeki tüm WAV dosyaları kaynaklarla byte düzeyinde karşılaştırıldı. IPA üretilmedi. Gerçek Android/iOS dokunması, ses cihazı gecikmesi ve FPS ölçülmedi. Animasyon ve sesin öznel kalitesi fiziksel cihazda değerlendirilmelidir.

300 bölümün tamamı motora aktarılmadı. İlk iki bölüm ve üç mekanik hücresi bu sürümün kapsamıdır. Referans çözümler, insanlarla zorluk ve eğlence testi anlamına gelmez.
