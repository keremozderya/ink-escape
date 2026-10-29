import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../l10n/ink_strings.dart';

class StoryShot {
  const StoryShot(this.title, this.caption, this.seconds, this.source);
  final String title, caption;
  final int seconds;
  final Rect source;
}

// The illustrated sheet uses deliberately varied panel widths. Explicit source
// rectangles keep adjacent panels out of the moving camera window.
const openingShots = [
  StoryShot(
    'Boş bir sayfa',
    'Her şey, bir çizerin masasında başladı.',
    3,
    Rect.fromLTRB(3, 3, 504, 307),
  ),
  StoryShot(
    'İlk damla',
    'Önce Dot’u çizdi.',
    3,
    Rect.fromLTRB(512, 3, 765, 307),
  ),
  StoryShot(
    'Lumi',
    'Sonra, yanına Lumi’yi…',
    3,
    Rect.fromLTRB(773, 3, 1145, 307),
  ),
  StoryShot(
    'Aynı sayfada',
    'İki küçük çizgi, birbirini buldu.',
    3,
    Rect.fromLTRB(1153, 3, 1533, 307),
  ),
  StoryShot(
    'Beğenilmeyen çizim',
    'Ama çizer, yaptığını beğenmedi.',
    3,
    Rect.fromLTRB(3, 316, 386, 634),
  ),
  StoryShot(
    'Yırtık',
    'Kâğıdı tam ortasından yırttı.',
    3,
    Rect.fromLTRB(393, 316, 765, 634),
  ),
  StoryShot(
    'İki ayrı parça',
    'Aralarında artık koca bir boşluk vardı.',
    3,
    Rect.fromLTRB(773, 316, 1145, 634),
  ),
  StoryShot(
    'Çöp sepeti',
    'İki parçayı da çöpe attı.',
    3,
    Rect.fromLTRB(1153, 316, 1533, 634),
  ),
  StoryShot(
    'Unutulmuş kâğıtlar',
    'Eskizlerin, notların ve yarım kalmış mektupların arasına.',
    4,
    Rect.fromLTRB(3, 644, 380, 1021),
  ),
  StoryShot(
    'Uzakta bir çiçek',
    'Lumi hâlâ oradaydı.',
    3,
    Rect.fromLTRB(388, 644, 765, 1021),
  ),
  StoryShot(
    'İlk adım',
    'Dot, ona ulaşmak için yola çıktı.',
    3,
    Rect.fromLTRB(773, 644, 1145, 1021),
  ),
  StoryShot(
    'Senin çizgin',
    'Eksik yolu sen tamamlayacaksın.',
    3,
    Rect.fromLTRB(1153, 644, 1533, 1021),
  ),
];

class InkOpening extends StatefulWidget {
  const InkOpening({super.key, required this.art, required this.onComplete});
  final ui.Image art;
  final VoidCallback onComplete;
  @override
  State<InkOpening> createState() => _InkOpeningState();
}

class _InkOpeningState extends State<InkOpening>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  bool _finished = false;
  static final duration = openingShots.fold<int>(
    0,
    (sum, shot) => sum + shot.seconds,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock =
        AnimationController(
            vsync: this,
            duration: Duration(seconds: duration),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _finish();
          })
          ..forward();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _clock.stop();
    widget.onComplete();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_finished) return;
    if (state == AppLifecycleState.resumed) {
      _clock.forward();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xfff6f1e6),
    child: AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        var elapsed = _clock.value * duration;
        var index = 0;
        while (index < openingShots.length - 1 &&
            elapsed >= openingShots[index].seconds) {
          elapsed -= openingShots[index].seconds;
          index++;
        }
        final shot = openingShots[index];
        final progress = (elapsed / shot.seconds).clamp(0.0, 1.0).toDouble();
        final reduced = MediaQuery.of(context).disableAnimations;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 14, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'INK ESCAPE',
                        style: TextStyle(
                          fontFamily: 'Cormorant',
                          letterSpacing: 3,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _finish,
                    child: Text(InkStrings.of(context).t('Hikâyeyi atla')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Semantics(
                  label:
                      '${InkStrings.of(context).t(shot.title)}. ${InkStrings.of(context).t(shot.caption)}',
                  image: true,
                  child: CustomPaint(
                    painter: StoryFramePainter(
                      widget.art,
                      shot.source,
                      reduced ? .5 : progress,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Text(
                    InkStrings.of(context).t(shot.title),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Cormorant',
                      fontSize: 28,
                      color: Color(0xff38312a),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 68,
                    child: Text(
                      InkStrings.of(context).t(shot.caption),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Color(0xff756854),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      openingShots.length,
                      (i) => Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          color: i <= index
                              ? const Color(0xff78674e)
                              : const Color(0xffddd1bb),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class StoryFramePainter extends CustomPainter {
  StoryFramePainter(this.art, this.source, this.progress);
  final ui.Image art;
  final Rect source;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width,
      height: size.width / (source.width / source.height),
    );
    final bounded = rect.height > size.height
        ? Rect.fromCenter(
            center: size.center(Offset.zero),
            width: size.height * (source.width / source.height),
            height: size.height,
          )
        : rect;
    final t = Curves.easeInOut.transform(progress);
    final crop = Rect.fromCenter(
      center: source.center,
      width: source.width * (1 - .025 * t),
      height: source.height * (1 - .025 * t),
    );
    final sx = art.width / 1536, sy = art.height / 1024;
    canvas.drawImageRect(
      art,
      Rect.fromLTRB(
        crop.left * sx,
        crop.top * sy,
        crop.right * sx,
        crop.bottom * sy,
      ),
      bounded,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant StoryFramePainter old) =>
      old.progress != progress || old.source != source || old.art != art;
}
