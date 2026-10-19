# Ink Escape 0.3

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

Doğrulama ortamı: Flutter 3.47.7, Dart 3.13.5. Android/iOS cihaz testi yapılmadı. APK bu pakette bulunmaz.

## İçerik

Yenilenmiş karakter animasyonu, yürüyüşe bağlı parallax çevre, seyrek ders notu/mektup ayrıntıları ve atlanabilir 37 saniyelik açılış animatiği. Mevcut iki oynanabilir bölüm yaklaşık 2,5 dakika sürer. Üç mekanik laboratuvarı geliştirme parametresiyle açılır. 300 bölümün tamamı bu pakette yoktur.

Eski sürümün kayıtlarında tamamlanan bölümler korunur; değişen parkur nedeniyle mevcut bölüm başlangıcından devam edilir. Yeni sürüm kendi 5 saniyelik kayıt konumundan devam eder.

Kaynaklar lib/; görseller, sesler, fontlar ve bölüm verileri assets/; platform projeleri android/ ve ios/; otomatik kontroller test/ altındadır. Font lisansları assets/fonts/ içindedir.
