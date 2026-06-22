import 'package:flutter/material.dart';

import '../nav.dart';
import '../theme.dart';

/// One AI-driven recommendation card payload.
class Recommendation {
  final String id;
  final String title;            // e.g. "동(E) 직진 +5초 부여 권장"
  final String reason;           // 근거: "78% 혼잡, 대기 31대, 트렌드 ↑"
  final String expectedEffect;   // 예상 효과: "평균 대기 -8초"
  final double confidence;       // 0..1
  final String category;         // 신호 제어, 긴급, 카메라 등
  final IconData icon;
  final Color tone;
  Recommendation({
    required this.id,
    required this.title,
    required this.reason,
    required this.expectedEffect,
    required this.confidence,
    required this.category,
    required this.icon,
    required this.tone,
  });
}

/// Singleton-ish controller backing the recommendation queue. Mock data for
/// now; once Jetson is wired up, replace with the AI engine's stream.
class RecommendationQueue extends ChangeNotifier {
  RecommendationQueue._() {
    _items = _seed();
  }
  static final RecommendationQueue instance = RecommendationQueue._();

  late List<Recommendation> _items;

  List<Recommendation> get items => List.unmodifiable(_items);
  int get pendingCount => _items.length;

  static List<Recommendation> _seed() => const [];

  // Demo seed removed — real recommendations arrive from the AI engine.
  // ignore: unused_element
  static List<Recommendation> _demoSeed() => [
        Recommendation(
          id: 'r1',
          title: '동(E) 직진 +5초 부여 권장',
          reason: '혼잡 78% · 대기 31대 · 직전 5분 트렌드 상승',
          expectedEffect: '평균 대기 -8초 · 처리량 +12%',
          confidence: 0.87,
          category: '신호 제어',
          icon: Icons.swap_horiz,
          tone: AppColors.warn,
        ),
        Recommendation(
          id: 'r2',
          title: '구급차 우선 신호 지속 (잔여 12초)',
          reason: '남(S) 방향 520m 접근 · ETA 1분 18초',
          expectedEffect: '교차로 무정차 통과 가능',
          confidence: 0.96,
          category: '긴급차량',
          icon: Icons.local_hospital_outlined,
          tone: AppColors.danger,
        ),
        Recommendation(
          id: 'r3',
          title: '서(W) 주기 -3초 단축 검토',
          reason: '평균 사용률 35% · 7일 평균 대비 낮음',
          expectedEffect: '북(N)·동(E) 여유 시간 +6초',
          confidence: 0.71,
          category: '신호 효율',
          icon: Icons.tune,
          tone: AppColors.accent,
        ),
        Recommendation(
          id: 'r4',
          title: 'CCTV-B 노출 자동 보정 권장',
          reason: '감지 신뢰도 0.62 · 임계값 0.65 · 야간 노이즈 증가',
          expectedEffect: '감지 정확도 +9%p',
          confidence: 0.78,
          category: '카메라',
          icon: Icons.camera_alt_outlined,
          tone: AppColors.violet,
        ),
      ];

  void accept(String id, BuildContext context) {
    final r = _items.firstWhere((x) => x.id == id);
    _items.removeWhere((x) => x.id == id);
    notifyListeners();
    showActionSnack(context, '"${r.title}" 적용 완료',
        icon: Icons.check_circle_outline);
  }

  void reject(String id, BuildContext context) {
    final r = _items.firstWhere((x) => x.id == id);
    _items.removeWhere((x) => x.id == id);
    notifyListeners();
    showActionSnack(context, '"${r.title}" 거부',
        icon: Icons.cancel_outlined);
  }

  void snooze(String id, BuildContext context) {
    final r = _items.firstWhere((x) => x.id == id);
    _items.removeWhere((x) => x.id == id);
    notifyListeners();
    showActionSnack(context, '"${r.title}" 10분 보류',
        icon: Icons.schedule);
  }

  void reset() {
    _items = _seed();
    notifyListeners();
  }
}

/// Header indicator + slide-in side drawer for the queue.
class RecommendationIndicator extends StatefulWidget {
  const RecommendationIndicator({super.key});

  @override
  State<RecommendationIndicator> createState() =>
      _RecommendationIndicatorState();
}

class _RecommendationIndicatorState extends State<RecommendationIndicator> {
  @override
  void initState() {
    super.initState();
    RecommendationQueue.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    RecommendationQueue.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _open() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AI 권장',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, a, b) => const _RecommendationDrawer(),
      transitionBuilder: (ctx, anim, b, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = RecommendationQueue.instance.pendingCount;
    return Tooltip(
      message: 'AI 권장 ($count건 대기)',
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: count > 0
                ? AppColors.accent.withValues(alpha: 0.12)
                : AppColors.panelAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: count > 0
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.stroke,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome,
                  size: 13,
                  color:
                      count > 0 ? AppColors.accent : AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(
                count > 0 ? 'AI 권장 $count건' : 'AI 권장 없음',
                style: TextStyle(
                    color: count > 0
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationDrawer extends StatefulWidget {
  const _RecommendationDrawer();

  @override
  State<_RecommendationDrawer> createState() => _RecommendationDrawerState();
}

class _RecommendationDrawerState extends State<_RecommendationDrawer> {
  @override
  void initState() {
    super.initState();
    RecommendationQueue.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    RecommendationQueue.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = RecommendationQueue.instance.items;
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 420,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.panel,
            border: Border(left: BorderSide(color: AppColors.stroke)),
          ),
          child: Column(
            children: [
              _DrawerHeader(count: items.length),
              if (items.isEmpty)
                const Expanded(child: _EmptyState())
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    itemCount: items.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _RecommendationCard(item: items[i]),
                  ),
                ),
              const _DrawerFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final int count;
  const _DrawerHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.bgAlt,
        border: Border(bottom: BorderSide(color: AppColors.stroke)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome,
              size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          const Text('AI 권장 사항',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.bgAlt,
        border: Border(top: BorderSide(color: AppColors.stroke)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined,
              size: 12, color: AppColors.textMuted),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              '모든 권장 사항은 운영자 승인 시에만 적용됩니다.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              RecommendationQueue.instance.reset();
              showActionSnack(context, '권장 사항 새로고침',
                  icon: Icons.refresh);
            },
            icon: const Icon(Icons.refresh,
                size: 14, color: AppColors.textSecondary),
            label: const Text('새로고침',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final Recommendation item;
  const _RecommendationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final pct = (item.confidence * 100).round();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.stroke, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // header strip
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            decoration: BoxDecoration(
              color: item.tone.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
              border: Border(
                bottom: BorderSide(
                    color: item.tone.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 14, color: item.tone),
                const SizedBox(width: 6),
                Text(item.category,
                    style: TextStyle(
                        color: item.tone,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                _ConfidenceBadge(percent: pct, tone: item.tone),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _ReasonRow(label: '근거', value: item.reason),
                const SizedBox(height: 4),
                _ReasonRow(
                    label: '예상 효과',
                    value: item.expectedEffect,
                    accent: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionBtn(
                        label: '수락',
                        icon: Icons.check,
                        tone: AppColors.ok,
                        primary: true,
                        onTap: () => RecommendationQueue.instance
                            .accept(item.id, context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ActionBtn(
                        label: '거부',
                        icon: Icons.close,
                        tone: AppColors.danger,
                        onTap: () => RecommendationQueue.instance
                            .reject(item.id, context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ActionBtn(
                        label: '10분 보류',
                        icon: Icons.snooze,
                        tone: AppColors.textSecondary,
                        onTap: () => RecommendationQueue.instance
                            .snooze(item.id, context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  const _ReasonRow({
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                color: accent ? AppColors.ok : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: accent ? FontWeight.w600 : FontWeight.w500,
              )),
        ),
      ],
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final int percent;
  final Color tone;
  const _ConfidenceBadge({required this.percent, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined, size: 10, color: tone),
          const SizedBox(width: 3),
          Text('신뢰도 $percent%',
              style: TextStyle(
                  color: tone, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color tone;
  final bool primary;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.tone,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: primary
              ? tone.withValues(alpha: 0.18)
              : AppColors.panel,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: primary
                ? tone.withValues(alpha: 0.6)
                : tone.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: tone),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: tone,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 36, color: AppColors.ok),
          const SizedBox(height: 12),
          const Text('모든 권장 사항이 처리되었습니다.',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('AI 엔진이 새 권장 사항을 모니터링하고 있습니다.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => RecommendationQueue.instance.reset(),
            icon: const Icon(Icons.refresh,
                size: 14, color: AppColors.accent),
            label: const Text('새로고침',
                style: TextStyle(color: AppColors.accent, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
