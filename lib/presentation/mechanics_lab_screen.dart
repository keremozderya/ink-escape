part of '../main.dart';

String _labText(String language, String tr, String en) =>
    language == 'tr' ? tr : en;

class InkMechanicsPicker extends StatefulWidget {
  const InkMechanicsPicker({
    super.key,
    required this.soundEnabled,
    required this.musicOn,
    required this.effectsOn,
  });
  final bool soundEnabled, musicOn, effectsOn;
  @override
  State<InkMechanicsPicker> createState() => _InkMechanicsPickerState();
}

class _InkMechanicsPickerState extends State<InkMechanicsPicker> {
  final _scroll = ScrollController();
  String _group = 'all';
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  final _previews = <String, InkSession>{};

  void _open(InkLabCase spec) {
    final store = MemoryStore();
    final sound = Soundscape(enabled: widget.soundEnabled)
      ..musicOn = widget.musicOn
      ..effectsOn = widget.effectsOn;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          key: ValueKey('ink-test-game-${spec.id}'),
          session: spec.createSession(),
          journal: SaveJournal(store, 'mechanics-${spec.id}'),
          store: store,
          sound: sound,
          labCase: spec,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = InkStrings.of(context).code;
    final cases = InkLabCase.all
        .where(
          (c) => switch (_group) {
            'plan' => c.family != null,
            'drawing' => c.momentum,
            'environment' => c.family == null && !c.momentum,
            _ => true,
          },
        )
        .toList();
    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        backgroundColor: paper,
        title: Text(
          _labText(language, 'Test Alanı', 'Test Area'),
          style: const TextStyle(fontFamily: 'Cormorant', fontSize: 30),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 32 - 4 * 8) / 5;
                final thumbnailHeight = (cardWidth * .64).clamp(48.0, 112.0);
                final titleHeight =
                    MediaQuery.textScalerOf(context).scale(12) * 1.2 * 3 + 22;
                return CustomScrollView(
                  key: const ValueKey('ink-mechanics-list'),
                  controller: _scroll,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _labText(
                                language,
                                'Bir parkur seç. Çizgilerini hazırla, sonra Dot’u yürüt.',
                                'Choose a course. Prepare your ink, then let Dot walk.',
                              ),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              key: const ValueKey('ink-test-filters'),
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final item in [
                                    (
                                      'all',
                                      'Tümü · ${InkLabCase.all.length}',
                                      'All · ${InkLabCase.all.length}',
                                    ),
                                    ('plan', 'PDF planı · 22', 'PDF plan · 22'),
                                    (
                                      'drawing',
                                      'Çizim tepkileri · 4',
                                      'Drawing reactions · 4',
                                    ),
                                    (
                                      'environment',
                                      'Yeni engeller · ${InkLabCase.all.where((c) => c.family == null && !c.momentum).length}',
                                      'New obstacles · ${InkLabCase.all.where((c) => c.family == null && !c.momentum).length}',
                                    ),
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        key: ValueKey(
                                          'ink-test-filter-${item.$1}',
                                        ),
                                        label: Text(
                                          _labText(language, item.$2, item.$3),
                                        ),
                                        selected: _group == item.$1,
                                        onSelected: (_) {
                                          setState(() => _group = item.$1);
                                          if (_scroll.hasClients) {
                                            _scroll.jumpTo(0);
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverGrid.builder(
                        key: const ValueKey('ink-mechanics-grid'),
                        itemCount: cases.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 10,
                          mainAxisExtent: thumbnailHeight + titleHeight,
                        ),
                        itemBuilder: (context, index) {
                          final spec = cases[index],
                              number = InkLabCase.all.indexOf(cases[index]) + 1;
                          final preview = _previews.putIfAbsent(
                            spec.id,
                            spec.createSession,
                          );
                          return Semantics(
                            button: true,
                            label: '$number. ${spec.title(language)}',
                            excludeSemantics: true,
                            child: Tooltip(
                              message: spec.tip(language),
                              child: Material(
                                color: const Color(0xfffaf5e9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                  side: const BorderSide(
                                    color: Color(0xffc7b99e),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  key: ValueKey('ink-test-${spec.id}'),
                                  onTap: () => _open(spec),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        height: thumbnailHeight,
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: InkMechanicsThumbnail(
                                                key: ValueKey(
                                                  'ink-test-preview-${spec.id}',
                                                ),
                                                session: preview,
                                              ),
                                            ),
                                            Positioned(
                                              left: 5,
                                              top: 5,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: inkColor,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 2,
                                                      ),
                                                  child: Text(
                                                    '$number',
                                                    style: const TextStyle(
                                                      color: paper,
                                                      fontSize: 10,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (spec.family != null)
                                              Positioned(
                                                right: 5,
                                                top: 5,
                                                child: Text(
                                                  spec.family!,
                                                  style: const TextStyle(
                                                    color: muted,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const Divider(
                                        height: 1,
                                        thickness: .7,
                                        color: Color(0xffd6c9af),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 8,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              spec.title(language),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                height: 1.2,
                                                fontWeight: FontWeight.w700,
                                                color: inkColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

extension _MechanicsLabControls on GameScreenState {
  Widget _labToolbar() {
    final lab = s.mechanics!;
    String text(String tr, String en) => _labText(strings.code, tr, en);
    final motion = switch (lab.motion) {
      InkLabMotion.entryHop => text('Atlayış', 'Entry hop'),
      InkLabMotion.sliding => text('Kayış', 'Sliding'),
      InkLabMotion.airborne => text('Uçuş', 'Airborne'),
      InkLabMotion.coasting => text('Yavaşlama', 'Coasting'),
      InkLabMotion.walking =>
        lab.holdDot
            ? text('Çizime hazır', 'Ready to draw')
            : text('Yürüyüş', 'Walking'),
    };
    return Material(
      color: const Color(0xf2f6f1e6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0x667f6b4c)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            children: [
              IconButton(
                tooltip: text('Testleri seç', 'Choose a test'),
                onPressed: _returnToMenu,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Text(
                '$motion${widget.labCase!.momentum ? ' · ${lab.speedRatio.toStringAsFixed(1)}×' : ''}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                key: const ValueKey('ink-test-walk'),
                style: FilledButton.styleFrom(minimumSize: const Size(90, 48)),
                onPressed: lab.motion == InkLabMotion.walking || lab.holdDot
                    ? () {
                        _changeLab(() => lab.holdDot = !lab.holdDot);
                      }
                    : null,
                icon: Icon(
                  lab.holdDot ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                label: Text(
                  lab.holdDot
                      ? text('Dot’u yürüt', 'Walk')
                      : text('Beklet', 'Hold'),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                key: const ValueKey('ink-test-guide'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(80, 48),
                ),
                onPressed: () => _changeLab(lab.cycleGuide),
                child: Text(
                  lab.showGuide
                      ? text(
                          'Örnek ${lab.guideRoute + 1}',
                          'Guide ${lab.guideRoute + 1}',
                        )
                      : text('Örnek çizgi', 'Guide'),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: text('Yeniden dene', 'Retry'),
                onPressed: () {
                  _retry();
                  _start();
                },
                icon: const Icon(Icons.replay_rounded),
              ),
              IconButton(
                tooltip: widget.labCase!.tip(strings.code),
                onPressed: () async {
                  final playing = s.phase == Phase.playing;
                  _pause();
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(widget.labCase!.title(strings.code)),
                      content: Text(widget.labCase!.tip(strings.code)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(text('Tamam', 'OK')),
                        ),
                      ],
                    ),
                  );
                  if (mounted && playing) _start();
                },
                icon: const Icon(Icons.help_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
