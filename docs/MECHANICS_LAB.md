# Mekanik test alanı ve köşe teması

Temel: GitHub `f45a018` + `ink_escape_surf_titreme_ve_serbest_cizim.patch` +
`ink_escape_serbest_cizgi_govde_temasi_duzeltmesi.patch`.
Bu yama son serbest çizgi / gövde teması düzeltmesinin üzerine uygulanır.

Ana menü → Test Alanı → parkur → Parkuru aç. Toplam **36 parkur** vardır.
Bölümler her sırada **beş kutucuk** olarak aşağı kaydırılır. Her kutucukta
sabit bölüm numarası, başlık ve o parkurun gerçek zemin/örnek rota/engel
verisinden çizilmiş küçük haritası vardır. Görseller yalnız görünür kartlar
için hazırlanır; oyun motoru, resim indirme veya canlı animasyon çalıştırılmaz.
Filtreler: Tümü, PDF planı, Çizim tepkileri, Yeni engeller. Filtre değişince
sayfanın başına dönülür, bölüm numaraları değişmez; tam ipucu uzun basarak görülebilir.
Başlangıçta Dot bekler. Örnek çizgi düğmesi yalnız kesik kılavuzu gösterir;
kendiliğinden çizgi üretmez, mürekkep veya çizgi yuvası kullanmaz.
Çizgini hazırla ve Dot’u yürüt. Beklet, yardım ve yeniden dene kullanılabilir.

## Serbest başlangıç ve kâğıt teması

Çizim herhangi bir noktadan başlayabilir. Onay bırakma anında verilir: çizginin
başının, sonunun veya aradaki herhangi bir parçasının gerçek kâğıt yüzeyine
değmesi yeterlidir. İki uç da havada kalabilir. Kalem örnekleri arasındaki
kesişimler de denetlenir; yalnız kayıtlı noktalar kontrol edilmez. Görünür
mürekkep kenarı için 2,1 dünya birimlik temas payı kullanılır ve temas noktası
kâğıda oturtulur. İçerideki keskin bir temas yumuşatılırken kaybolmaz.
Önizleme, çarpışma ve ücretlendirilen çizgi aynı noktaları kullanır.

Kâğıda hiç değmeyen çizim bırakıldığında uyarıyla reddedilir; mürekkep ve yuva
harcanmaz. Başka bir mürekkep çizgisine değmek kâğıt desteği sayılmaz. 12–220
birim uzunluk, gerçek mürekkep maliyeti ve iki etkin çizgi sınırı korunur.
Çatı/oluk türü gerçek temas yüzeyinden belirlenir. Katlama, çizimin kâğıttaki
parçalarını yine dönüştürür. Havadaki yarım taslak duraklatılıp kaydedilebilir;
devam ederken son noktasına dokunularak tamamlanır. İlk dersin metinleri ve
12 dilin karakter alt kümeleri yeni kurala göre güncellenmiştir.

### Serbest ucun gövde ve ayak teması

Havada başlayan, platforma ortasından değen alçalan çizgi önceki sürümde
onaylanıyordu; yürüyüş yalnız ayak desteğini aradığı için Dot platformda
ilerlerken çizginin alçak girişini gövdesinin içinden geçirebiliyordu. Bu durum
normal ve ters çizimle yeniden üretildi.

Güncel geometri önbelleği, yürünebilir çizgilerin kâğıda hâlâ bağlı kalan
konturlarındaki serbest girişleri de tutar. Dot yaklaşırken, serbest uç mevcut
ayak yüksekliğinin en fazla 36 dünya birimi üzerindeyse kısa otomatik sıçrama
ile çıkar. Yandan gövde teması yükseliş bitene kadar ilerlemeyi sınırlar;
ayaklar çizgiye basınca aynı kontur yürüyüş zemini olur. Zemine tekrar
kavuştuğunda gerideki alçalan parça Dot’u durdurmaz. Ulaşılamayan alçak bir
engel gövdeyi geçirip ışınlamak yerine mevcut takılma kuralını kullanır.

Çizim zaten yürüyen Dot’un gövdesi üzerinde tamamlanmışsa, yakın alçak parçaya
aynı sıçrama ile toparlanır. Havadayken ikinci sıçrama verilmez. Üst çatı rolü
ve kâğıttan kopmuş parçalar bu giriş yardımına girmez. Silme, emeklilik ve
katlama geometri önbelleğini yeniler. Sıçrama mevcut konum/hız kayıtlarıyla
duraklatılıp sürdürülebilir.

## Dikenli kâğıt ve duvardaki döner bıçak

Ana menü → Test Alanı → Yeni engeller içinde **Dikenli zemin** ve
**Duvardaki döner bıçak** kartları bulunur. İkisinin de gerçek engelleri gösteren
küçük haritası, örnek çizgisi, Beklet kontrolü ve yeniden denemesi vardır.
Kampanya bölüm verisi değiştirilmez; aynı engeller normal bölüm verisinde de
kullanılabilen `Level` modelleridir.

- Dikenler platformun üstündeki iki ayrı şerittir. Dişler ufak yükseklik/açı
  farkları ve taramalarla mürekkep çizimine benzer. Çizilen üçgenler aynı zamanda
  temas geometrisidir. Üzerlerine basmak öldürür; yalnız onaylanmış bir çizgi
  bulunması koruma sağlamaz. Ayakları dişlerin üstünde tutacak bir kemer gerekir.
- Döner bıçak gerçek kâğıt bankının dik yüzündeki yuvadan çıkar. Gizli → işaret →
  çıkış → açık → geri çekiliş sırasını izler. Varsayılan döngü 5,6 saniyedir;
  kısa sıcak renkli mürekkep işaretleri çıkışı haber verir. Dişler kâğıdın
  arkasında çizilmez ve bıçak tamamen gizliyken temas vermez.
- Bıçağın üstünden geçen yüksek çizgi her fazda güvenlidir. Daha az mürekkepli
  alçak rampa zamanlamayla da geçilebilir: testte başlangıçtaki iki saniyelik
  bekleme bu rotayı geçirirken beklemeden geçiş bıçağa çarpar.
- Temas yalnız kare sonuna bakmaz: dikenlerde süpürülen gövde/üçgen testi,
  bıçakta gövde ile hareketli kesici çemberin göreli hareketi kullanılır. Böylece
  hızlı kayış ve bekleyen Dot’a yaklaşan bıçak atlanmaz. Fizik gövdesi mevcut
  24×32 dünya birimlik sınırları kullanır.
- Bıçak konumu ve dönüşü `gameTime` ile hesaplanır. Duraklatma her ikisini
  dondurur, yeniden deneme başlangıca alır; normal bölüm kaydı aynı fazı yükler.
  Test alanındaki Beklet ise Dot’u bekletir, çevrenin döngüsü devam eder.

Bölümün kökünde veya bir hücrede isteğe bağlı alanlar kullanılabilir. Hücrede
x koordinatlarına `offset_x` eklenir; `offset` ise bıçağın saniye cinsinden
faz farkıdır. Bıçak yuvası gerçek bir dik kâğıt yüzüne yerleştirilmelidir:

```json
{
  "spikes": [{"id": "spikes-a", "left": 175, "right": 215, "y": 0}],
  "wallSaws": [{"id": "saw-a", "mount": [300, 32], "direction": -1,
    "radius": 16, "reach": 34, "period": 5.6, "offset": 0}]
}
```

`direction: -1` sola, `1` sağa açılır. Eski bölüm dosyalarında bu alanlar
olmadığında engel üretilmez. Ölüm açıklamaları 12 dilde paketlidir; yeni
karakterler için yazı tipi alt kümeleri de güncellenmiştir.

## PDF ile eşleştirme

Kaynak: *Ink Escape — 300 bölüm, tek bir yol*, Tasarım 1.2 / 30 Ekim 2026,
mekanik sözlüğü (s. 3–4). PDF’te 22 engel/etkileşim ailesi ve 10 hikâye alanı
vardır. 300 bölüm kampanyaya aktarılmaz; her aile ayrı kısa parkurda sınanır.
İptal edilen L tutunması yerine aynı kodda ayak teması parkuru bulunur.

| Kod | Parkur | Sınanan karar |
| --- | --- | --- |
| G | Açık yarık | İki kıyı arasına yol çizme, kıyıda yuva boşaltma |
| R | Yükselen kıyı | Yürünebilir eğimle yükselme |
| D | Alçalan kıyı | Kontrollü iniş ve kıyı teması |
| S | Kısa basamaklar | Otomatik sıçrama ve sonraki yarığa hazırlık |
| L | Köşede ayak teması | Düşük biten yol, öndeki/arkadaki ayağın desteği; tutunma yerine geçer |
| H | Keskin uçlar | Alt lekenin üstünden kemer |
| K | Alçak tavan | Alt ve üst tehlike arasına alçak yol |
| T | İki yarık | Adalı iki köprü ve iki çizgi sınırı |
| N | Dar ada | Kısa iniş alanında ikinci çizime hazırlık |
| A | Emici kâğıt | Yenilenme olmadan adadaki damlayı bekleme |
| C | Silgi yağmuru | Gerçek kırıntıları kesen koruyucu çatı |
| U | Çatı ve köprü | İlk damladan sonra ikinci çizim |
| B | Bilyeli kapı | Oluktan çiçekli yuvaya bilye gönderme |
| V | Bilye ve köprü | Bilye işi ile yerdeki yolu birlikte çözme |
| W | Bilye ve yağmur | Oluk ve çatıyı iki yuvada koruma |
| Q | Üç iş, iki yuva | Bilye yakalanınca boşalan yuvaya köprü çizme |
| E | Korumalı kemer | Çatı, ara dolum ve alt kemer |
| F | Emici şekil çifti | Kemer ile alçak yolu ortak mürekkebe sığdırma |
| J | Çatı altında yuva devri | İlk kemer silinince dar adadan ikinci kemeri çizme |
| M | Tavanlı yükseliş | Alt lekeden ve üst sınırdan kaçınarak yükselme |
| Y | Bilyeli alçak geçit | Oluk ve çatıdan sonra alçak yol |
| Z | Bilyeli korumalı kemer | Oluk ve çatıdan sonra alt kemer |

Çatı ve oluk başlangıçları görünür, sabit kâğıt parçalarıdır. Bilye, yağmur,
kapı, mürekkep, iki yuva ve çizginin emekli olması oyunun gerçek kurallarını
kullanır. `InkLabTask` yalnız örnek rotanın hazırlık sırasını tarif eder;
oyuncuya çizgi eklemez, kapı açmaz veya kaynak vermez. Oyuncu farklı bir yol
çizebilir. Birleşik parkurların ipuçlarında çizim sırası belirtilir.

A/F/J gibi parkurlarda bütün çizgileri başta çizmeye çalışma. Ara damlayı alıp
Beklet ile hazırlanabilirsin. Q/Y/Z’de bilye yakalanınca oluğun yuvası boşalır;
J’de ilk kemer adada geride kalınca emekli olur. Üç iş aynı anda üç çizgi
anlamına gelmez. İki çizgi, 220 birim tek çizgi ve 240 depo sınırları korunur.

## Çizim ve çevre için 14 deney

- Çizim tepkileri: Kaydırak ve hız, Rampa ve sıçrama, İniş yolunu çiz, Alçak çıkış.
- Yeni engeller: Gezinen silgi, Düğmeli katlanan kâğıt, Katın arkasındaki mürekkep,
  Makaralı köprü, Çatlayan platform, Ağırlık ve düğme, İki farklı yol, Eksik bağlantı.

Kaydırak gerçek ayak teması ve önündeki kısa iniş parçasının 60°’den dikleşmesi
ile başlar. Kısa düz giriş, dikey parça ve 2,4 birime kadar küçük yatay titreme
kabul edilir. Belirgin döngüler aynen korunur ve kaydırak sayılmaz. Başlangıç
kıyıya sabitlenince oluşan kazara ters kanca yalnız baskı gerçekten kıyının
içinden başladıysa temizlenir; görüntü ve çarpışma aynı çizgiyi kullanır.

Bir çizgide giriş atlayışı bir kez olur. Ardından yükseklik farkı ve sürtünme
hızı belirler; hız en fazla 240 u/sn olur. Yeterli hızla yukarı kıvrımdan uçulur.
Bitmiş bir çizgiye tekrar bağlanılıp sıfır zamanlı iniş döngüsüne girilmez.
Silinen mürekkep destek olmaz. Her bağlantılı parçanın uzunluk tablosu
geometri revizyonu değişene kadar saklanır; silinmiş boşluk boyunca kayılmaz.

## Bölgesel silgi ve mürekkep surf tahtası

Gezinen silgi yalnız dokunduğu bölümleri kaldırır. Silginin ekranda görülen
28×20 boyutlu, 3 birim yuvarlatılmış ve 0,12 radyan döndürülmüş gövdesi,
silme alanıyla aynı geometridir. Silinen aralıklar çizginin dünya konturundan
kırpılır; kalan parçaların arasına bağlantı eklenmez. Kaynak çizim ve ödenen
mürekkep maliyeti değişmez. Parçalar tek çizim kimliğinde, tek yuvada kalır.
Tamamı silinince yuva boşalır; mürekkep iade edilmez. Yürüme, kayma ve çizimin
görünüşü aynı kalan parçaları kullanır. Tekrarlanan boş temas geometriyi
tekrar üretmez. Silgi temasında küçük mürekkep kırıntıları görünür.

Dik çizgiye atlayış tamamlanınca Dot’un iki ayağının altında ufak, kâğıt
renginde içi ve mürekkep kenarı olan bir surf tahtası çizilir. Tahta ve
ayaklar aynı dönüşümü paylaşır; bacak boyları değişmez. Görsel açı, tahtanın
altındaki 20 dünya birimlik konturdan örneklenir ve en kısa yönde, kare hızından
bağımsız olarak yumuşatılır. Küçük kalem kırıkları tahtayı aniden çevirmez.
Fizik, hız ve sıçrama hesabı özgün çizginin gerçek teğetini kullanır. Tamamlanan
tahta konturu önbellektedir; her karede yeniden ölçülmez. Kayışın her
7 dünya biriminde iki küçük mürekkep zerresi geriye savrulur; yoğunluk kare
hızına değil gerçek mesafeye bağlıdır ve en fazla 32 zerre saklanır.

Çizgi bittiğinde, silindiğinde ya da destekten ayrıldığında tahta bağımsız bir
görsel olarak ayrılır. İlk uçuş yönü Dot’un gerçek çıkış hızından **8°**
farklıdır. Biraz daha yavaş ve hafifçe dönerek uçar, **0,95 saniyede** solar.
Sonraki bir çizgiye inişte yeni tahta çizilebilir. Tahta/zerreler çarpışma,
hız, ivme veya mürekkep maliyeti oluşturmaz. Oyun zamanı durunca donarlarken,
yeniden denemede tamamen temizlenirler. Aynı anda en fazla üç ayrılmış tahta
saklanır; geçmiş birikmez.

## Düğmeli kâğıt katlama

İki ayrı parkur vardır. Yerdeki plaka, Dot yürürken ayağıyla bastığında bir
kez tetiklenir. İlk anda kâğıt açık kalır; hazırlanırken süre geçmesi sayfayı
hareket ettirmez. Basıldıktan sonra 0,95 saniyede yumuşakça hedef kata geçer.

- **Katlanan kâğıt:** Önce alt kıyıdan sola köprü hazırlanır. Sağ üst köşenin
  içine ikinci bir çizim de yapılabilir. Düğme, geniş sayfanın üçgen köşesini
  çapraz kat izinden içeri kapatır. Düz üst kenar alçalan bir eğime dönüşür;
  katlanan bölgedeki çizim önce kâğıtla taşınır, sonra arkada kalır. Öbür
  kıyıdaki köprü yerinde durur. Köprü çizilmezse sonraki açıklık geçilemez.
- **Katın arkasındaki mürekkep:** Sağ sayfanın içine çizim yapılır. Düğme
  sayfayı sola kapatır, sayfanın arkası aralığı örter. Ön yüzün çizimi arka
  tarafta kaldığından görünmez ve yürünebilir destek olmaktan çıkar.
- **Makaralı köprü:** Önceki inip kalkan menteşeli köprü ayrı parkurdur.
  İp, iki makara ve karşı ağırlık hareketin kaynağını gösterir. Üzerindeki
  ayağı taşır. Çizginin bu platforma temas etmesi de onay için yeterlidir.

Referans: Paper Fold’un Google Play mağaza görsellerindeki içeri kapanan
kâğıt kenarları (https://play.google.com/store/apps/details?id=com.game.foldpuzzle).
Bizde katlanan parça bir 3B köprü değil, parkurun kâğıt yüzeyidir. Dönüşüm
kat izine dik koordinatı aynı düzlemde tersine çevirir. Son konum tam bir
ayna yansımasıdır; uzunluklar korunur, kat izindeki noktalar yerinde kalır.
Perspektif kaldıracı veya yapay yukarı yükselme yoktur. Sabit kısım, katlanan
kısım, kâğıt lifleri, silik bitki baskısı ve farklı tondaki arka yüz katı
gösterir. Yürünebilir yüzey kâğıdın yeni üst dış sınırından üretilir; alt
kenarlar hayalet zemin oluşturmaz. Kamera yüksekliği tüm sayfayı gösterir.
Oyun akışı düğmede durmaz.

Bağlı çizim malzeme koordinatlarında tutulur. Gerçek katlanan çokgenin dışındaki çizim
yerinde kalır; içindeki parça dönüşür. Sonsuz bir yarı düzlem kullanılıp
başka kıyıya ait çizimler taşınmaz. Önizleme ve yürünebilen
kontur da aynı dönüşümü kullanır. Arkaya geçen parça veya üstü kapanan sabit
çizgi hem resimden hem çarpışmadan kırpılır; iki görünür parça arasına gizli
bir bağlantı eklenmez. Tamamen örtülen çizgi yuvasını boşaltır, maliyeti geri
verilmez. Açığa çıkan arka yüze sonradan yeni mürekkep çizilebilir.

Ücretlendirilen kaynak noktalar ve mürekkep maliyeti sabittir. Değişen dünya
konturları ayrı tutulur; geometri revizyonu zemin önbelleğini geçersiz kılar.
Kat bitince konturlar tekrar hesaplanmaz. Etkin bir çizim devam ederken sayfa
hareketi kalem bırakılana kadar bekler; pause ve yeniden dene durumları korunur.
Bu katlama oturumları diğer testler gibi geçicidir; hikâye verisine eklenmez.

## Çatlayan kâğıt platform

Platformun gövdesi 6 yerine **26 dünya birimi** kalınlığında çizilir. Açık
kâğıt tonu, katman lifleri ve küçük kenar çentikleri kırılgan zemini önceden
gösterir. Gerçek ayak basışıyla başlayan 0,9 saniyelik süre korunur; havadan
geçmek tetiklemez. Çatlaklar ilk temas noktasından uzaklıklarına göre yayılır,
büyüyüp dallanır. Çökünce altı farklı genişlikte parça, aynı çatlak
kenarlarından ayrılıp dönerek düşer; küçük kâğıt lifleri dağılır. Bütün
platformu bir anda silip alakasız kareler üretmez. Bu parkurun kamerası,
kalın gövdeyi ve düşen parçaları göstermek için biraz yukarı alınmıştır.

## Ortak köşe teması

Bu düzeltme test alanıyla birlikte normal hikâyede de geçerlidir.

- Gövde merkezi kenarı geçse bile ayak açıklığı içindeki gerçek yüzey destek
  olur. Son ayak da zemini terk edince normal düşüş başlar. Süreye bağlı
  havada bekleme veya ileri ışınlanma kullanılmaz.
- Öndeki ayak açık kâğıt köşesine ulaştığında en fazla **4 dünya birimi**
  aşağıdaki küçük fark düzeltilebilir. Dünya ölçeği sabittir; bu ekran ölçeğine
  göre birkaç piksele karşılık gelir. Yalnız yatay hareket kadar ilerlenir.
- Düşey hız aşağı yönde 64 u/sn’den fazlaysa bu düzeltme uygulanmaz. Daha
  aşağıdaki temas gerçek yan yüz çarpışması ve düşüş olarak kalır.
- Baş boşluğu kontrol edilir; köşe düzeltmesi tavandan geçiremez. Emekli
  mürekkep ve uzaktaki yüzeyler ayak desteği sayılmaz.
- Yürüme, kayma ve ivmeli uçuş aynı köşe kontrolünü kullanır. İvmeli geçişte
  yükseklik düzeltmesinin enerji bedeli düşülür; hız sıfırlanmaz.
- Yükseltilmiş bir çizgi kâğıt dudağında hazırsa o yol, arkadaki ayağın
  desteğinden önce seçilir. Dot çizilmiş yolun altından yürümeye devam etmez.
- Ayak örnekleri gerçek temas noktasını ve en fazla 12 birim açıklığı izler;
  gövdeyi bütün konturla kaydırıp bacakları uzatan bir poz eklenmez.

Yeni oyun akışında eski el tutunması / beş dokunuş mekaniği başlatılmaz.
Önceden o durumda kaydedilmiş oturumları bitirebilmek için kayıt uyumluluğu
korunur; ilgili eski testler bu uyumluluk durumunu açıkça oluşturur.

## Oturum ve doğrulama

Testler her girişte yeni geçici oturum açar, hikâye kaydını değiştirmez.
Yardım/pause bütün dünyayı durdurur; Beklet yalnız Dot’u tutar. Bilye henüz
bırakılmamışsa Beklet hazırlık süresini korur. Silgi ve çevre hareket etmeyi
sürdürebilir. Yeniden dene deney durumunu baştan kurar.

Flutter 3.47.9 / Dart 3.13.7, Linux x64:
**505 test**, temiz analiz ve **5 mevcut referans rota**.

- İki yeni parkur 30/60/120 FPS’te tamamlanır. Çizgisiz diken ölümü, alçak
  çizginin korunmaması, güvenli kemer, bıçağın fazları, gizliyken güvenlik,
  hızlı/geçişli temas, yüksek rota, zamanlanmış alçak rota, pause/retry,
  kayıt yükleme, iki duvar yönü ve hücre ofsetleri sınanır. İki ekran boyutunda
  yeni kartlar açılır ve gerçek pointer ile çizilen çözümler oynanır.
- Serbest başlangıç, son/orta temas, seyrek örnekler arasında kesişim, ters/dikey
  çizim, sivri V temasının korunması, temassız ret, maliyet/yuva sınırları ve
  yarım taslağın kayıt sonrası devamı sınanır. Gerçek pointer ile iki ucu açık
  çizim tamamlanır; önizleme ile ücretlendirilen kontur karşılaştırılır.
- Görseldeki serbest alçalan giriş normal/ters gerçek çizimle 30/60/120 FPS’te
  sınanır. Gövde içinden geçmeme, çizgi üstünde yürüyüş ve zemine dönüş,
  hareket sırasında biten çizim, ulaşılamayan uç, silinen temas ve sıçramanın
  kayıttan devamı denetlenir. Gerçek InkGame render yolu da kontrol edilir.
- Tahta açısı 30/60/120 FPS’te ve ±π geçişinde sınanır. Pürüzlü bir raydaki
  görsel açı değişiminin tek segmentlik teğete göre azalması doğrulanır.
- 36 parkur gerçek begin/move/end API’si ile 30/60/120 FPS’te tamamlanır.
- Her PDF parkurunda gerekli çizimlerden her biri tek tek atlanarak
  başarısızlık doğrulanır. A/F/J kaynak ve Q/Y/Z/J yuva devri ayrıca sınanır.
- 30/73/144 FPS’te 0,2–3,5 birim düşük köşe temasları, hızlı düşüş, gerçek
  boşluk, düşük tavan ve emekli destek için olumlu/olumsuz kontroller vardır.
- Yürüme, kayma, ivmeli iniş ve arkadaki ayağın desteği kontrol edilir.
- 568×320 ve 960×540’ta kategori filtresi, rampa çizimi, üç işli Q parkurunun
  gerçek pointer ile tamamlanması ve hikâyenin korunması sınanır.
- Katlama için düğme, sabit/hareketli parça, arka yüzde gizlenme, görünmez
  çarpışma bırakmama, yeni arka yüz çizimi, kalem sürerken bekleme ve sıfırlama
  kontrolleri vardır. İki katlama parkuru iki ekran boyutunda gerçek pointer ile geçilir.
- Beş sütun, sonraki satır, son bölüm, filtreler ve parkura özgü küçük haritalar
  iki ekran boyutunda denetlenir. Çatlama için temas, süre, pause ve sıfırlama sınanır.
- Bölgesel silme; uçların ve ücretin korunması, eğri/dikey konturlar, tek yuva,
  gerçek silgi sınırı ve kesilen zeminin desteği için sınanır. Kayarken önde,
  arkada ve ayak altında kesilen çizgiler ayrı ayrı denenir. 8° ayrılış,
  parçacık sınırı, pause/yeniden dene ve gerçek oyun render yolu denetlenir.
- Bütün parkurlar açılır/yeniden denenir. Gerçek InkGame render yolu ve
  köşedeki normal yürüme pozları da denetlenir.

Native Android/iOS/Windows derlemesi ve fiziksel cihaz performans ölçümü bu
ortamda yapılmadı. Kampanyanın 300 bölümünün canlı oyuna entegrasyonu bu
mekanik test yamasının kapsamı değildir.
