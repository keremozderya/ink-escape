part of 'ink_model.dart';

/// Isolated encounters from the plan's dictionary, with the cancelled ledge
/// pull replaced by ordinary foot contact. These never edit campaign data.
const _planLabCases = [
  InkLabCase(
    'plan-G',
    'Açık yarık',
    'Open gap',
    'İki kıyı arasına bir yol çiz. Diğer kıyıya basınca çizgi yuvası boşalır.',
    'Draw a bridge. Reaching the far bank releases its ink slot.',
    family: 'G',
  ),
  InkLabCase(
    'plan-R',
    'Yükselen kıyı',
    'Raised bank',
    'Üst kıyıya yumuşak bir eğim çiz. Dik duvar Dot’u durdurur.',
    'Draw a gentle climb to the raised bank. A steep wall stops Dot.',
    family: 'R',
  ),
  InkLabCase(
    'plan-D',
    'Alçalan kıyı',
    'Lower bank',
    'Alt kıyıya kontrollü bir iniş çiz; bitişi kâğıda yaklaştır.',
    'Draw a controlled descent and finish close to the lower bank.',
    family: 'D',
  ),
  InkLabCase(
    'plan-S',
    'Kısa basamaklar',
    'Short steps',
    'Dot kısa basamakları kendisi aşar. Sonraki yarığın yolunu önceden hazırla.',
    'Dot hops over short steps. Prepare the bridge after them.',
    family: 'S',
  ),
  InkLabCase(
    'plan-L',
    'Köşede ayak teması',
    'Foot contact at the rim',
    'Tutunma yerine ayak desteği: yolu örnekteki gibi kıyının biraz altında bitir; yakın köşeden yürüyerek geç.',
    'Foot support replaces ledge pulling. End just below the bank and walk across the near rim.',
    family: 'L',
  ),
  InkLabCase(
    'plan-H',
    'Keskin uçlar',
    'Sharp tips',
    'Alt lekenin üstüne kemer çiz. Hem ayaklara hem gövdeye açıklık bırak.',
    'Arch over the lower stain, leaving room for feet and body.',
    family: 'H',
  ),
  InkLabCase(
    'plan-K',
    'Alçak tavan',
    'Low ceiling',
    'Alt ve üst leke arasına alçak bir yol çiz. Yüksek kemer başını tavana vurur.',
    'Draw low between the stains. A tall arch hits the ceiling.',
    family: 'K',
  ),
  InkLabCase(
    'plan-T',
    'İki yarık',
    'Two gaps',
    'Aradaki doğal adayı kullanarak iki ayrı köprü çiz. Aynı anda iki çizgi var.',
    'Use the middle island and draw two bridges within the two-slot limit.',
    family: 'T',
  ),
  InkLabCase(
    'plan-N',
    'Dar ada',
    'Narrow island',
    'Dar adaya varmadan ikinci köprüyü hazırla. İniş ve sonraki adımı birlikte planla.',
    'Prepare the second bridge before reaching the narrow island.',
    family: 'N',
  ),
  InkLabCase(
    'plan-A',
    'Emici kâğıt',
    'Absorbent paper',
    'Dolum yok. İlk köprüyü çiz, adadaki damlayı al, sonra ikinci köprüyü tamamla.',
    'Ink does not regenerate. Draw the first bridge, collect the island drop, then draw the second.',
    family: 'A',
  ),
  InkLabCase(
    'plan-C',
    'Silgi yağmuru',
    'Eraser rain',
    'Üst kâğıt uçlarına koruyucu çatı çiz. Kırıntılar için yerdeki yol yetmez.',
    'Draw a roof between the upper anchors to stop the falling crumbs.',
    family: 'C',
  ),
  InkLabCase(
    'plan-U',
    'Çatı ve köprü',
    'Roof and bridge',
    'Önce çatı. Başlangıçtaki damlayı alınca alttaki köprüyü çiz.',
    'Draw the roof first. Collect the starting drop, then draw the bridge.',
    family: 'U',
  ),
  InkLabCase(
    'plan-B',
    'Bilyeli kapı',
    'Ball gate',
    'Üst oluğu çiz. Bilye çiçekli yuvaya ulaşınca kapı açılır.',
    'Draw the upper rail. The ball opens the gate when it reaches the cup.',
    family: 'B',
  ),
  InkLabCase(
    'plan-V',
    'Bilye ve köprü',
    'Ball and bridge',
    'Bilyeyi yuvaya gönder; kapıdan önceki yarık için ayrıca köprü çiz.',
    'Send the ball into the cup and bridge the gap before the gate.',
    family: 'V',
  ),
  InkLabCase(
    'plan-W',
    'Bilye ve yağmur',
    'Ball and rain',
    'Oluğu çiz. İlk damlayı aldıktan sonra çatıyı da kur; iki işi birlikte koru.',
    'Draw the rail, collect the first drop, then add the roof. Both jobs are needed.',
    family: 'W',
  ),
  InkLabCase(
    'plan-Q',
    'Üç iş, iki yuva',
    'Three jobs, two slots',
    'Oluk → ilk damla → çatı. Bilye yakalanınca boşalan yuvaya, ikinci damlayla köprü çiz.',
    'Rail → first drop → roof. After capture, use the freed slot and second drop for the bridge.',
    family: 'Q',
  ),
  InkLabCase(
    'plan-E',
    'Korumalı kemer',
    'Sheltered arch',
    'Çatı → ilk damla → alt kemer. Yağmur ve alt leke iki ayrı çizimi gerektirir.',
    'Roof → first drop → arch. Rain and the lower stain need separate drawings.',
    family: 'E',
  ),
  InkLabCase(
    'plan-F',
    'Emici şekil çifti',
    'Two shapes, one budget',
    'İlk kemeri ekonomik çiz. Adadaki damladan sonra ikinci alçak yolu kur; yenilenme yok.',
    'Draw an economical first arch, collect the island drop, then build the low passage.',
    family: 'F',
  ),
  InkLabCase(
    'plan-J',
    'Çatı altında yuva devri',
    'Slot handover under a roof',
    'Çatı → ilk damla → ilk kemer. Dar adada ilk kemer silinince ikinci kemeri çiz.',
    'Roof → first drop → first arch. On the narrow island, wait for its slot to clear before drawing the second.',
    family: 'J',
  ),
  InkLabCase(
    'plan-M',
    'Tavanlı yükseliş',
    'Climb below a ceiling',
    'Alt lekeden yüksek, tavandan alçak kalacak bir eğimle üst kıyıya ulaş.',
    'Climb above the lower stain while staying below the ceiling.',
    family: 'M',
  ),
  InkLabCase(
    'plan-Y',
    'Bilyeli alçak geçit',
    'Ball and low passage',
    'Oluk ve çatıdan sonra bilyenin yuvasını bekle. İkinci damlayla tavan altına düz yol çiz.',
    'Use the rail and roof, wait for capture, then spend the second drop on a low bridge.',
    family: 'Y',
  ),
  InkLabCase(
    'plan-Z',
    'Bilyeli korumalı kemer',
    'Ball and sheltered arch',
    'Oluk ve çatıdan sonra bilye yakalansın. Boşalan yuvaya alt lekeyi aşan kemeri çiz.',
    'Capture the ball while keeping the roof, then use its freed slot to arch over the stain.',
    family: 'Z',
  ),
];

/// Guide metadata is also the public test route. The game never commits it.
class InkLabTask {
  const InkLabTask(
    this.points, {
    this.pickup,
    this.captured = false,
    this.cueX = 0,
  });
  final List<V> points;
  final String? pickup;
  final bool captured;
  final double cueX;
  bool ready(InkSession s) =>
      s.x >= cueX &&
      (pickup == null || s.collected.contains(pickup)) &&
      (!captured || s.level.balls.every((ball) => ball.captured)) &&
      s.activeLines < 2 &&
      s.ink + 1e-6 >= pathLength(points);
}

extension _PlanCourses on MechanicsLab {
  void _planFloor(String id, double ax, double ay, double bx, double by) =>
      _floor('plan-$id', ax, ay, bx, by);

  void _planAnchor(String id, V p, String role) {
    final left = id.endsWith('-a');
    final pad = Surface(
      'plan-$id',
      left ? p - const V(18, 0) : p,
      left ? p : p + const V(18, 0),
      tag: role,
    );
    session.level.anchors.add(pad);
    session.level.terrain.add(pad);
  }

  void _planDrop(String id, double x, double value) =>
      session.level.pickups.add(Pickup(id, V(x, 16), value));

  void _planInk(double amount) {
    session.ink = session.entryInk = amount;
    session.level.noRegen.add([-1000, 2000]);
  }

  void _planTask(
    List<V> p, {
    String? pickup,
    bool captured = false,
    double cueX = 0,
  }) =>
      tasks.add(InkLabTask(p, pickup: pickup, captured: captured, cueX: cueX));

  List<V> _arch(double a, double b, {double height = 34}) => [
    V(a, 0),
    V(a + (b - a) * .28, height),
    V(a + (b - a) * .68, height),
    V(b, 0),
  ];

  void _planRoof(double a, double b, double y, {String? pickup}) {
    final p = [V(a, y), V(b, y)];
    _planAnchor('roof-a', p.first, 'roof');
    _planAnchor('roof-b', p.last, 'roof');
    _planTask(p, pickup: pickup);
  }

  void _planBall() {
    const a = V(170, 112), b = V(270, 82);
    _planAnchor('ball-a', a, 'object');
    _planAnchor('ball-b', b, 'object');
    session.level.balls.add(
      Ball('plan-ball', a + const V(0, 8), b + const V(0, 8), 0, 1.4, 24, 2)
        ..position = a + const V(0, 8),
    );
    _planTask([a, b]);
  }

  void _preparePlan() {
    final s = session, code = spec.family!;
    s.level.terrain.clear();
    _planFloor('start', -160, 0, 150, 0);
    switch (code) {
      case 'G':
      case 'R':
      case 'D':
      case 'L':
      case 'H':
      case 'K':
      case 'M':
        final endX = code == 'L'
            ? 255.0
            : code == 'G' || code == 'R' || code == 'D'
            ? 245.0
            : 275.0;
        final endY = code == 'R' || code == 'M'
            ? 34.0
            : code == 'D'
            ? -40.0
            : 0.0;
        _planFloor('bank', endX, endY, 410, endY);
        _planFloor('return', 410, endY, 500, 0);
        _planFloor('finish', 500, 0, 860, 0);
        if (code == 'H') {
          s.level.hazards.add([188, -12, 238, 10]);
          _planTask(_arch(150, 275));
        } else if (code == 'K') {
          s.level.hazards.addAll([
            [184, -30, 240, -5],
            [184, 40, 240, 100],
          ]);
          _planTask([const V(150, 0), V(endX, endY)]);
        } else if (code == 'M') {
          s.level.hazards.addAll([
            [190, -10, 230, 4],
            [195, 69, 244, 110],
          ]);
          _planTask([
            const V(150, 0),
            const V(185, 10),
            const V(235, 26),
            const V(275, 34),
          ]);
        } else {
          _planTask([
            const V(150, 0),
            code == 'L' ? const V(235, -3) : V(endX, endY),
          ]);
        }
      case 'S':
        s.level.terrain.clear();
        _planFloor('start', -160, 0, 130, 0);
        for (var i = 0; i < 3; i++) {
          _planFloor(
            'step-$i',
            130 + i * 60,
            (i + 1) * 18,
            190 + i * 60,
            (i + 1) * 18,
          );
        }
        _planFloor('descent', 310, 54, 380, 0);
        _planFloor('bank', 380, 0, 410, 0);
        _planFloor('finish', 490, 0, 860, 0);
        _planTask([const V(410, 0), const V(490, 0)]);
      case 'T':
      case 'N':
      case 'A':
      case 'F':
        final narrow = code == 'N', absorb = code == 'A', shapes = code == 'F';
        final first = shapes
            ? 275.0
            : absorb
            ? 260.0
            : 240.0;
        final second = narrow
            ? 282.0
            : shapes
            ? 470.0
            : absorb
            ? 410.0
            : 400.0;
        final end = narrow
            ? 372.0
            : shapes
            ? 580.0
            : absorb
            ? 535.0
            : 490.0;
        _planFloor('island', first, 0, second, 0);
        _planFloor('finish', end, 0, 860, 0);
        if (absorb || shapes) {
          _planInk(absorb ? 212 : 220);
          _planDrop('island-drop', absorb ? 320 : 370, absorb ? 40 : 60);
        }
        if (shapes) {
          s.level.hazards.addAll([
            [188, -12, 238, 10],
            [493, 40, 558, 100],
          ]);
        }
        _planTask(shapes ? _arch(150, first) : [const V(150, 0), V(first, 0)]);
        _planTask([
          V(second, 0),
          V(end, 0),
        ], pickup: absorb || shapes ? 'island-drop' : null);
      case 'C':
      case 'U':
      case 'E':
        _planInk(
          code == 'E'
              ? 220
              : code == 'U'
              ? 210
              : 240,
        );
        if (code == 'C') {
          _planFloor('path', 150, 0, 860, 0);
        } else {
          _planFloor('finish', 275, 0, 860, 0);
        }
        s.level.rain.add(Rain('plan-rain', 185, 265));
        _planRoof(145, 305, 96);
        if (code != 'C') {
          _planDrop('first-drop', 80, code == 'E' ? 120 : 100);
          if (code == 'E') s.level.hazards.add([188, -12, 238, 10]);
          _planTask(
            code == 'E' ? _arch(150, 275) : [const V(150, 0), const V(275, 0)],
            pickup: 'first-drop',
          );
        }
      case 'J':
        _planInk(240);
        _planFloor('island', 220, 0, 255, 0);
        _planFloor('finish', 325, 0, 860, 0);
        s.level.rain.add(Rain('plan-rain', 174, 300));
        s.level.hazards.addAll([
          [178, -12, 195, 8],
          [280, -12, 300, 8],
        ]);
        _planDrop('first-drop', 80, 100);
        _planDrop('island-drop', 238, 60);
        _planRoof(145, 340, 96);
        _planTask(_arch(150, 220, height: 25), pickup: 'first-drop');
        _planTask(
          _arch(255, 325, height: 25),
          pickup: 'island-drop',
          cueX: 233,
        );
      case 'B':
      case 'V':
      case 'W':
      case 'Q':
      case 'Y':
      case 'Z':
        final rain = code == 'W' || code == 'Q' || code == 'Y' || code == 'Z';
        final bridge = code == 'V' || code == 'Q' || code == 'Y' || code == 'Z';
        s.level.terrain.clear();
        _planFloor('start', -160, 0, bridge ? 365 : 860, 0);
        if (bridge) _planFloor('finish', 465, 0, 800, 0);
        _planBall();
        s.level.gates.add(Gate('plan-gate', bridge ? 520 : 410, ['plan-ball']));
        if (rain) {
          _planInk(240);
          _planDrop('first-drop', 80, 100);
          s.level.rain.add(Rain('plan-rain', 300, 325));
          _planRoof(145, 350, 70, pickup: 'first-drop');
        }
        if (bridge) {
          if (rain) _planDrop('second-drop', 340, 125);
          if (code == 'Y') {
            s.level.hazards.addAll([
              [388, 42, 440, 110],
              [388, -30, 440, -5],
            ]);
          }
          if (code == 'Z') s.level.hazards.add([396, -12, 434, 10]);
          _planTask(
            code == 'Z' ? _arch(365, 465) : [const V(365, 0), const V(465, 0)],
            pickup: rain ? 'second-drop' : null,
            captured: rain,
          );
        }
      default:
        throw StateError('Unknown plan family $code');
    }
    guides.add([for (final task in tasks) task.points]);
  }
}
