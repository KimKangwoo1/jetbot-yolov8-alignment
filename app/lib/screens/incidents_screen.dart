import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../nav.dart';
import '../theme.dart';
import '../widgets.dart';

enum IncidentSeverity { critical, high, medium, low, info }
enum IncidentStatus { newIncident, inProgress, resolved }

extension on IncidentSeverity {
  String get label => switch (this) {
        IncidentSeverity.critical => 'CRITICAL',
        IncidentSeverity.high => 'HIGH',
        IncidentSeverity.medium => 'MEDIUM',
        IncidentSeverity.low => 'LOW',
        IncidentSeverity.info => 'INFO',
      };
  Color get color => switch (this) {
        IncidentSeverity.critical => AppColors.danger,
        IncidentSeverity.high => AppColors.warn,
        IncidentSeverity.medium => AppColors.accent,
        IncidentSeverity.low => AppColors.textSecondary,
        IncidentSeverity.info => AppColors.textMuted,
      };
}

extension on IncidentStatus {
  String get label => switch (this) {
        IncidentStatus.newIncident => '신규',
        IncidentStatus.inProgress => '처리 중',
        IncidentStatus.resolved => '해결됨',
      };
  Color get color => switch (this) {
        IncidentStatus.newIncident => AppColors.danger,
        IncidentStatus.inProgress => AppColors.warn,
        IncidentStatus.resolved => AppColors.ok,
      };
  IconData get icon => switch (this) {
        IncidentStatus.newIncident => Icons.fiber_new,
        IncidentStatus.inProgress => Icons.engineering_outlined,
        IncidentStatus.resolved => Icons.check_circle_outline,
      };
}

class Incident {
  final String id;
  String title;
  String description;
  final IncidentSeverity severity;
  IncidentStatus status;
  final DateTime createdAt;
  String? assignee;
  String? resolution;
  Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.createdAt,
    this.assignee,
    this.resolution,
  });
}

/// Singleton-ish incident store. Mock data; later wires to backend.
class IncidentBoard extends ChangeNotifier {
  IncidentBoard._() {
    final now = DateTime.now();
    _items = <Incident>[];
    // Demo seed removed — real incidents arrive from the backend.
    // The reference shape is kept below (unused) for future wiring.
    // ignore: unused_local_variable
    final demoSeed = <Incident>[
      Incident(
        id: 'INC-2031',
        title: '동(E) 혼잡도 78% — 30분 지속',
        description: '평소 평균(58%) 대비 +20%p. 출퇴근 외 시간대.',
        severity: IncidentSeverity.high,
        status: IncidentStatus.newIncident,
        createdAt: now.subtract(const Duration(minutes: 12)),
      ),
      Incident(
        id: 'INC-2030',
        title: 'CCTV-B 야간 노이즈로 감지 신뢰도 0.62',
        description: '임계값 0.65 미달. 자동 보정 권장 카드 발생.',
        severity: IncidentSeverity.medium,
        status: IncidentStatus.newIncident,
        createdAt: now.subtract(const Duration(minutes: 28)),
      ),
      Incident(
        id: 'INC-2029',
        title: '구급차 통과 후 신호 복구 31초 (평균 +6초)',
        description: '남(S)→북(N) 전환 시 의도치 않은 지연 관찰됨.',
        severity: IncidentSeverity.low,
        status: IncidentStatus.inProgress,
        createdAt: now.subtract(const Duration(minutes: 65)),
        assignee: '김운영',
      ),
      Incident(
        id: 'INC-2028',
        title: '서(W) 직진 신호 주기 35초 — 사용률 28%',
        description: '7일 평균 대비 22% 낮음. 단축 조정 후보.',
        severity: IncidentSeverity.medium,
        status: IncidentStatus.inProgress,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 40)),
        assignee: '이현장',
      ),
      Incident(
        id: 'INC-2027',
        title: 'Jetson 임시 단절 (3초)',
        description: 'Wi-Fi 신호 약해짐 — 자동 재연결 성공. 데이터 손실 없음.',
        severity: IncidentSeverity.info,
        status: IncidentStatus.resolved,
        createdAt: now.subtract(const Duration(hours: 2, minutes: 18)),
        assignee: '자동',
        resolution: '자동 재연결 — 추가 조치 불필요',
      ),
      Incident(
        id: 'INC-2026',
        title: '경찰차 동(E) 통과 — 우선 신호 8초',
        description: '정상 운영. 일반 운영 즉시 복귀.',
        severity: IncidentSeverity.info,
        status: IncidentStatus.resolved,
        createdAt: now.subtract(const Duration(hours: 3, minutes: 6)),
        assignee: '자동',
        resolution: '정상 — 사후 분석 불필요',
      ),
      Incident(
        id: 'INC-2025',
        title: '북(N) 보행자 감지 임계값 미세조정',
        description: '횡단 후 차량 진입 감지 지연 0.4초 발견.',
        severity: IncidentSeverity.low,
        status: IncidentStatus.resolved,
        createdAt: now.subtract(const Duration(hours: 4, minutes: 22)),
        assignee: '박엔지',
        resolution: 'IoU 임계값 0.55 → 0.58 적용 — 14:02 검증 완료',
      ),
      Incident(
        id: 'INC-2024',
        title: '오전 출근 시간 대기시간 평균 +12초',
        description: '월요일 패턴 확인 필요. 신호 시간 재배분 검토.',
        severity: IncidentSeverity.medium,
        status: IncidentStatus.resolved,
        createdAt: now.subtract(const Duration(hours: 6, minutes: 11)),
        assignee: '김운영',
        resolution: '08:00-09:30 동(E) 신호 +3초 적용',
      ),
    ];
  }
  static final IncidentBoard instance = IncidentBoard._();
  late List<Incident> _items;

  List<Incident> get all => List.unmodifiable(_items);

  List<Incident> byStatus(IncidentStatus s) =>
      _items.where((x) => x.status == s).toList();

  void claim(Incident i, String assignee) {
    i.assignee = assignee;
    i.status = IncidentStatus.inProgress;
    notifyListeners();
  }

  void resolve(Incident i, String resolution) {
    i.status = IncidentStatus.resolved;
    i.resolution = resolution;
    notifyListeners();
  }

  void reopen(Incident i) {
    i.status = IncidentStatus.inProgress;
    i.resolution = null;
    notifyListeners();
  }

  void create({
    required String title,
    required String description,
    required IncidentSeverity severity,
  }) {
    final id =
        'INC-${(2032 + _items.where((x) => x.id.startsWith('INC-2')).length).toString()}';
    _items.insert(
        0,
        Incident(
          id: id,
          title: title,
          description: description,
          severity: severity,
          status: IncidentStatus.newIncident,
          createdAt: DateTime.now(),
        ));
    notifyListeners();
  }
}

class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    IncidentBoard.instance.addListener(_on);
  }

  @override
  void dispose() {
    IncidentBoard.instance.removeListener(_on);
    super.dispose();
  }

  void _on() {
    if (mounted) setState(() {});
  }

  bool _matches(Incident i) =>
      _query.isEmpty ||
      i.title.contains(_query) ||
      i.id.contains(_query) ||
      (i.assignee?.contains(_query) ?? false);

  Future<void> _openCreate() async {
    final res = await showDialog<_NewIncident?>(
      context: context,
      builder: (_) => const _CreateIncidentDialog(),
    );
    if (res != null && mounted) {
      IncidentBoard.instance.create(
        title: res.title,
        description: res.description,
        severity: res.severity,
      );
      if (mounted) {
        showActionSnack(context, '사건 등록됨: ${res.title}',
            icon: Icons.add_alert_outlined);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = IncidentBoard.instance;
    final newItems =
        board.byStatus(IncidentStatus.newIncident).where(_matches).toList();
    final progItems =
        board.byStatus(IncidentStatus.inProgress).where(_matches).toList();
    final resolvedItems =
        board.byStatus(IncidentStatus.resolved).where(_matches).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          totalNew: newItems.length,
          totalProgress: progItems.length,
          totalResolved: resolvedItems.length,
          onSearch: (v) => setState(() => _query = v.trim()),
          onCreate: _openCreate,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Column(
                  status: IncidentStatus.newIncident,
                  items: newItems,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Column(
                  status: IncidentStatus.inProgress,
                  items: progItems,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Column(
                  status: IncidentStatus.resolved,
                  items: resolvedItems,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  final int totalNew;
  final int totalProgress;
  final int totalResolved;
  final ValueChanged<String> onSearch;
  final VoidCallback onCreate;
  const _Toolbar({
    required this.totalNew,
    required this.totalProgress,
    required this.totalResolved,
    required this.onSearch,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined,
              size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          const Text('사건 / 티켓',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          _CountChip(
              label: '신규',
              count: totalNew,
              color: AppColors.danger),
          const SizedBox(width: 6),
          _CountChip(
              label: '처리 중',
              count: totalProgress,
              color: AppColors.warn),
          const SizedBox(width: 6),
          _CountChip(
              label: '해결됨',
              count: totalResolved,
              color: AppColors.ok),
          const SizedBox(width: 14),
          SizedBox(
            width: 240,
            child: TextField(
              onChanged: onSearch,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                hintText: '제목 / ID / 담당자 검색',
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
                prefixIcon: const Icon(Icons.search,
                    size: 14, color: AppColors.textMuted),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 30, minHeight: 30),
                filled: true,
                fillColor: AppColors.panelAlt,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 14, color: Colors.black),
            label: const Text('사건 만들기',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text('$count',
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  final IncidentStatus status;
  final List<Incident> items;
  const _Column({required this.status, required this.items});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(status.icon, size: 14, color: status.color),
              const SizedBox(width: 6),
              Text(status.label,
                  style: TextStyle(
                      color: status.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text('${items.length}',
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('해당 상태의 사건이 없습니다.',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) =>
                    _IncidentCard(item: items[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final Incident item;
  const _IncidentCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('MM-dd HH:mm');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.stroke, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: item.severity.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  item.severity.label,
                  style: TextStyle(
                      color: item.severity.color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5),
                ),
              ),
              const SizedBox(width: 6),
              Text(item.id,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const Spacer(),
              Text(timeFmt.format(item.createdAt),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          Text(item.title,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.35)),
          if (item.assignee != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 11, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text(item.assignee!,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 10)),
              ],
            ),
          ],
          if (item.resolution != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.ok.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                    color: AppColors.ok.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 10, color: AppColors.ok),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(item.resolution!,
                        style: const TextStyle(
                            color: AppColors.ok,
                            fontSize: 10,
                            height: 1.3)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          _ActionsForStatus(item: item),
        ],
      ),
    );
  }
}

class _ActionsForStatus extends StatelessWidget {
  final Incident item;
  const _ActionsForStatus({required this.item});

  @override
  Widget build(BuildContext context) {
    switch (item.status) {
      case IncidentStatus.newIncident:
        return Row(
          children: [
            Expanded(
              child: _MiniBtn(
                label: '내가 처리',
                icon: Icons.pan_tool_alt_outlined,
                tone: AppColors.accent,
                primary: true,
                onTap: () {
                  IncidentBoard.instance.claim(item, '관리자 (admin)');
                  showActionSnack(context, '${item.id} 클레임됨',
                      icon: Icons.pan_tool_alt_outlined);
                },
              ),
            ),
            const SizedBox(width: 4),
            _MiniBtn(
              label: '상세',
              icon: Icons.open_in_full,
              tone: AppColors.textSecondary,
              onTap: () => _showDetail(context, item),
            ),
          ],
        );
      case IncidentStatus.inProgress:
        return Row(
          children: [
            Expanded(
              child: _MiniBtn(
                label: '해결',
                icon: Icons.check,
                tone: AppColors.ok,
                primary: true,
                onTap: () => _showResolve(context, item),
              ),
            ),
            const SizedBox(width: 4),
            _MiniBtn(
              label: '상세',
              icon: Icons.open_in_full,
              tone: AppColors.textSecondary,
              onTap: () => _showDetail(context, item),
            ),
          ],
        );
      case IncidentStatus.resolved:
        return Row(
          children: [
            Expanded(
              child: _MiniBtn(
                label: '재개',
                icon: Icons.restart_alt,
                tone: AppColors.warn,
                onTap: () {
                  IncidentBoard.instance.reopen(item);
                  showActionSnack(context, '${item.id} 재개됨',
                      icon: Icons.restart_alt);
                },
              ),
            ),
            const SizedBox(width: 4),
            _MiniBtn(
              label: '상세',
              icon: Icons.open_in_full,
              tone: AppColors.textSecondary,
              onTap: () => _showDetail(context, item),
            ),
          ],
        );
    }
  }

  void _showDetail(BuildContext context, Incident i) {
    final timeFmt = DateFormat('yyyy.MM.dd HH:mm');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.stroke),
        ),
        title: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: i.severity.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(i.severity.label,
                  style: TextStyle(
                      color: i.severity.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
            const SizedBox(width: 8),
            Text(i.id,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i.title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(i.description,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.45)),
              const SizedBox(height: 14),
              StatLine(label: '상태', value: i.status.label),
              StatLine(label: '생성', value: timeFmt.format(i.createdAt)),
              if (i.assignee != null)
                StatLine(label: '담당', value: i.assignee!),
              if (i.resolution != null)
                StatLine(label: '해결', value: i.resolution!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  void _showResolve(BuildContext context, Incident i) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.stroke),
        ),
        title: const Text('사건 해결',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i.title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text('해결 내용 / 조치',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 4),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 3,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: '예: 동(E) +5초 적용 — 14:21 검증 완료',
                  hintStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                  filled: true,
                  fillColor: AppColors.panelAlt,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.stroke),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            icon: const Icon(Icons.check, size: 14, color: Colors.black),
            label: const Text('해결',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ok,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty) {
      IncidentBoard.instance.resolve(i, res);
      if (context.mounted) {
        showActionSnack(context, '${i.id} 해결 처리',
            icon: Icons.check_circle_outline);
      }
    }
  }
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color tone;
  final bool primary;
  final VoidCallback onTap;
  const _MiniBtn({
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
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: primary
              ? tone.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: tone.withValues(alpha: primary ? 0.5 : 0.3),
              width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 11, color: tone),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color: tone,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _NewIncident {
  final String title;
  final String description;
  final IncidentSeverity severity;
  _NewIncident(this.title, this.description, this.severity);
}

class _CreateIncidentDialog extends StatefulWidget {
  const _CreateIncidentDialog();

  @override
  State<_CreateIncidentDialog> createState() => _CreateIncidentDialogState();
}

class _CreateIncidentDialogState extends State<_CreateIncidentDialog> {
  String _title = '';
  String _desc = '';
  IncidentSeverity _sev = IncidentSeverity.medium;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.stroke),
      ),
      title: const Row(
        children: [
          Icon(Icons.add_alert_outlined, size: 16, color: AppColors.accent),
          SizedBox(width: 8),
          Text('사건 만들기',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('제목',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _title = v),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: _decoration(hint: '간단히 한 줄로'),
            ),
            const SizedBox(height: 10),
            const Text('상세 설명',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            TextField(
              maxLines: 3,
              onChanged: (v) => setState(() => _desc = v),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              decoration: _decoration(hint: '관찰된 현상, 영향 범위, 시각 등'),
            ),
            const SizedBox(height: 10),
            const Text('심각도',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final s in IncidentSeverity.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => setState(() => _sev = s),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _sev == s
                              ? s.color.withValues(alpha: 0.18)
                              : AppColors.panelAlt,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: _sev == s
                                  ? s.color.withValues(alpha: 0.6)
                                  : AppColors.stroke,
                              width: 1),
                        ),
                        child: Text(s.label,
                            style: TextStyle(
                                color: _sev == s
                                    ? s.color
                                    : AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소',
              style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: _title.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    _NewIncident(_title, _desc, _sev),
                  ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            disabledBackgroundColor:
                AppColors.accent.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text('등록',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  InputDecoration _decoration({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textMuted, fontSize: 11),
        isDense: true,
        filled: true,
        fillColor: AppColors.panelAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      );
}
