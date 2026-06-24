import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'data/live_data.dart';
import 'nav.dart';
import 'theme.dart';
import 'web_helpers.dart';
import 'widgets.dart';
import 'widgets/handoff_dialog.dart';
import 'widgets/intersection_selector.dart';
import 'widgets/kiosk_view.dart';
import 'widgets/recommendation_panel.dart';
import 'widgets/timeline_scrub.dart';
import 'screens/emergency_screen.dart';
import 'screens/incidents_screen.dart';
import 'screens/monitor_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/signal_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/traffic_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _kiosk = false;

  void _toggleKiosk() => setState(() => _kiosk = !_kiosk);

  static const _navItems = <_NavItem>[
    _NavItem('실시간 모니터링', Icons.monitor_outlined),
    _NavItem('교통 현황', Icons.bar_chart_rounded),
    _NavItem('신호 제어', Icons.traffic_outlined),
    _NavItem('긴급차량 우선', Icons.local_hospital_outlined),
    _NavItem('사건 / 티켓', Icons.assignment_outlined),
    _NavItem('통계 분석', Icons.pie_chart_outline),
    _NavItem('시스템 설정', Icons.settings_outlined),
  ];

  Widget _bodyFor(int i) {
    return switch (i) {
      0 => const MonitorScreen(),
      1 => const TrafficScreen(),
      2 => const SignalScreen(),
      3 => const EmergencyScreen(),
      4 => const IncidentsScreen(),
      5 => const StatsScreen(),
      6 => const SettingsScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  void _go(int i) => setState(() => _index = i);

  Map<ShortcutActivator, VoidCallback> _bindings(BuildContext context) =>
      <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.digit1): () => _go(0),
        const SingleActivator(LogicalKeyboardKey.digit2): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.digit3): () => _go(2),
        const SingleActivator(LogicalKeyboardKey.digit4): () => _go(3),
        const SingleActivator(LogicalKeyboardKey.digit5): () => _go(4),
        const SingleActivator(LogicalKeyboardKey.digit6): () => _go(5),
        const SingleActivator(LogicalKeyboardKey.digit7): () => _go(6),
        const SingleActivator(LogicalKeyboardKey.keyK): _toggleKiosk,
        const SingleActivator(LogicalKeyboardKey.keyR): () {
          if (TimelineController.instance.replayMode) {
            TimelineController.instance.exitReplay();
          } else {
            TimelineController.instance.enterReplay();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyF): () async {
          await toggleFullscreen();
          if (context.mounted) {
            showActionSnack(
              context,
              isFullscreen() ? '전체화면 모드' : '전체화면 종료',
              icon: isFullscreen()
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
            );
          }
        },
        const SingleActivator(LogicalKeyboardKey.slash, shift: true): () =>
            showHelpDialog(context),
      };

  @override
  Widget build(BuildContext context) {
    return NavScope(
      goTo: _go,
      currentIndex: _index,
      child: Builder(
        builder: (context) => CallbackShortcuts(
          bindings: _bindings(context),
          child: Focus(
            autofocus: true,
            child: _kiosk
                ? KioskView(onExit: _toggleKiosk)
                : Scaffold(
              backgroundColor: AppColors.bg,
              body: Row(
                children: [
                  _Sidebar(
                    index: _index,
                    items: _navItems,
                    onSelect: _go,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const _Header(),
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(14, 10, 14, 14),
                            child: Column(
                              children: [
                                const ReplayBanner(),
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: kMotionFast,
                                    switchInCurve: kMotionCurve,
                                    switchOutCurve: Curves.easeIn,
                                    transitionBuilder: (child, anim) =>
                                        FadeTransition(
                                            opacity: anim, child: child),
                                    child: KeyedSubtree(
                                      key: ValueKey<int>(_index),
                                      child: _bodyFor(_index),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const TimelineScrubBar(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}

class _Sidebar extends StatelessWidget {
  final int index;
  final List<_NavItem> items;
  final ValueChanged<int> onSelect;
  const _Sidebar({required this.index, required this.items, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        border: Border(right: BorderSide(color: AppColors.stroke)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.hub, color: Colors.black, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'AI 스마트 신호',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < items.length; i++)
            _NavTile(
              item: items[i],
              selected: i == index,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: _SystemStatusCard(),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            if (selected)
              Positioned(
                left: 0,
                top: 6,
                bottom: 6,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: kMotionFast,
              curve: kMotionCurve,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? AppColors.accent.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(item.icon, size: 17, color: color),
                  const SizedBox(width: 10),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemStatusCard extends StatefulWidget {
  const _SystemStatusCard();
  @override
  State<_SystemStatusCard> createState() => _SystemStatusCardState();
}

class _SystemStatusCardState extends State<_SystemStatusCard> {
  late Timer _t;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(10),
      color: AppColors.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('시스템 상태',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 6),
          Builder(builder: (_) {
            final on = LiveData.instance.connected;
            return StatusDotPill(
              label: on ? '정상 운영 중' : '연결 대기 중',
              color: on ? AppColors.ok : AppColors.textMuted,
              dense: true,
            );
          }),
          const SizedBox(height: 6),
          Text(
            '마지막 업데이트\n${DateFormat('HH:mm:ss').format(_now)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatefulWidget {
  const _Header();
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late Timer _t;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: AppColors.bgAlt,
        border: Border(bottom: BorderSide(color: AppColors.stroke)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          const Text(
            'AI 스마트 교통 신호',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 14),
          const IntersectionSelector(),
          const Spacer(),
          Tooltip(
            message: '엣지 추론 (Jetson Nano) — 클라우드 의존성 없음',
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.violet.withValues(alpha: 0.4),
                    width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.shield_outlined,
                      size: 12, color: AppColors.violet),
                  SizedBox(width: 4),
                  Text('Edge AI · 100% 로컬',
                      style: TextStyle(
                          color: AppColors.violet,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          ListenableBuilder(
            listenable: LiveData.instance,
            builder: (context, _) {
              final on = LiveData.instance.connected;
              return InkWell(
                onTap: () => NavScope.of(context).goTo(6),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: StatusDotPill(
                    label: on ? 'Jetson 연결됨' : 'Jetson 연결 대기',
                    color: on ? AppColors.ok : AppColors.textMuted,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Text(
            DateFormat('HH:mm:ss').format(_now),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontFeatures: [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          const RecommendationIndicator(),
          const SizedBox(width: 12),
          const _NotificationsBell(),
          const SizedBox(width: 4),
          _IconBtn(
            icon: Icons.history,
            tooltip: '재현 모드',
            onTap: () {
              if (TimelineController.instance.replayMode) {
                TimelineController.instance.exitReplay();
              } else {
                TimelineController.instance.enterReplay();
              }
            },
          ),
          Builder(builder: (ctx) {
            final shell = ctx.findAncestorStateOfType<_AppShellState>();
            return _IconBtn(
              icon: Icons.tv_outlined,
              tooltip: '키오스크 모드 (K)',
              onTap: () => shell?._toggleKiosk(),
            );
          }),
          _IconBtn(
            icon: Icons.fullscreen,
            tooltip: '전체화면 (F)',
            onTap: () async {
              await toggleFullscreen();
              if (context.mounted) {
                showActionSnack(
                  context,
                  isFullscreen() ? '전체화면 모드' : '전체화면 종료',
                  icon: isFullscreen()
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                );
              }
            },
          ),
          _IconBtn(
            icon: Icons.help_outline,
            tooltip: '도움말',
            onTap: () => showHelpDialog(context),
          ),
          const SizedBox(width: 6),
          const _UserMenu(),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _NotificationsBell extends StatefulWidget {
  const _NotificationsBell();

  @override
  State<_NotificationsBell> createState() => _NotificationsBellState();
}

/// Plain-language alert payload — describes what's happening, why it matters,
/// and offers a single click action.
class _Alert {
  final String time;
  final String title;
  final String detail;
  final String? actionLabel;
  final IconData icon;
  final Color tone;
  const _Alert({
    required this.time,
    required this.title,
    required this.detail,
    this.actionLabel,
    required this.icon,
    required this.tone,
  });
}

class _NotificationsBellState extends State<_NotificationsBell> {
  // Notifications come from the backend event stream — empty until connected.
  static const _items = <_Alert>[];

  // ignore: unused_field
  static const _demoItems = <_Alert>[
    _Alert(
      time: '14:25',
      title: '구급차가 남쪽에서 접근 중',
      detail: '거리 520m · 1분 18초 후 도착 예정. 우선 신호가 자동으로 활성화되었습니다.',
      actionLabel: '경로 보기',
      icon: Icons.local_hospital_outlined,
      tone: AppColors.danger,
    ),
    _Alert(
      time: '14:18',
      title: '동쪽 차선이 평소보다 23% 더 막힙니다',
      detail: '대기 차량 31대 · 임계값 25대 초과. 5분 더 지속되면 신호를 5초 자동 조정합니다.',
      actionLabel: '지금 +5초 부여',
      icon: Icons.warning_amber_rounded,
      tone: AppColors.warn,
    ),
    _Alert(
      time: '14:11',
      title: '보조 카메라가 잠시 끊겼다 복구되었습니다',
      detail: 'CCTV-B 3초간 신호 손실 — 자동 재연결됨. 데이터 손실 없음.',
      icon: Icons.signal_wifi_bad,
      tone: AppColors.warn,
    ),
    _Alert(
      time: '13:54',
      title: '경찰차가 동쪽으로 통과했습니다',
      detail: '우선 신호 8초 사용 · 일반 운영으로 복귀 완료.',
      icon: Icons.local_police_outlined,
      tone: AppColors.violet,
    ),
    _Alert(
      time: '13:30',
      title: '오늘 신호 효율이 어제보다 좋아졌습니다',
      detail: '효율 지수 0.74 → 0.78 (+5%). 평균 대기시간 4초 단축.',
      actionLabel: '자세히',
      icon: Icons.auto_graph,
      tone: AppColors.ok,
    ),
  ];

  bool _readAll = false;
  int get _unread => _readAll ? 0 : _items.length;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: '알림',
      color: AppColors.panel,
      offset: const Offset(0, 32),
      onOpened: () => setState(() => _readAll = true),
      itemBuilder: (_) => [
        PopupMenuItem<int>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            width: 380,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.strokeDim)),
            ),
            child: Row(
              children: const [
                Icon(Icons.notifications_active,
                    size: 14, color: AppColors.accent),
                SizedBox(width: 6),
                Text('알림',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                Spacer(),
                Text('최근 24시간',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
        ),
        for (final a in _items)
          PopupMenuItem<int>(
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 380,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: a.tone.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(a.icon, size: 14, color: a.tone),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(a.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 6),
                              Text(a.time,
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ])),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(a.detail,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  height: 1.35)),
                          if (a.actionLabel != null) ...[
                            const SizedBox(height: 6),
                            Builder(builder: (ctx) {
                              return InkWell(
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  showActionSnack(context,
                                      '"${a.actionLabel}" 실행됨',
                                      icon: a.icon);
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        a.tone.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: a.tone.withValues(alpha: 0.5),
                                        width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt,
                                          size: 11, color: a.tone),
                                      const SizedBox(width: 3),
                                      Text(a.actionLabel!,
                                          style: TextStyle(
                                              color: a.tone,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
      child: Tooltip(
        message: '알림 ($_unread건 새 알림)',
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined,
                  size: 18, color: AppColors.textSecondary),
              if (_unread > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.bgAlt, width: 1.5),
                    ),
                    child: Text('$_unread',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1.0)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '사용자',
      color: AppColors.panel,
      offset: const Offset(0, 32),
      onSelected: (v) {
        switch (v) {
          case 'profile':
            showActionSnack(context, '프로필 페이지 (구현 예정)',
                icon: Icons.account_circle_outlined);
            break;
          case 'handoff':
            showHandoffDialog(context);
            break;
          case 'logout':
            showActionSnack(context, '로그아웃 (구현 예정)',
                icon: Icons.logout);
            break;
          case 'about':
            showAboutDialogPanel(context);
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('관리자',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('admin@smartai.local',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'profile',
          child: Row(children: [
            Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('프로필',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          ]),
        ),
        PopupMenuItem(
          value: 'handoff',
          child: Row(children: [
            Icon(Icons.handshake_outlined, size: 14, color: AppColors.accent),
            SizedBox(width: 8),
            Text('교대 인계',
                style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
        PopupMenuItem(
          value: 'about',
          child: Row(children: [
            Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('버전 정보',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          ]),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout, size: 14, color: AppColors.danger),
            SizedBox(width: 8),
            Text('로그아웃',
                style: TextStyle(color: AppColors.danger, fontSize: 12)),
          ]),
        ),
      ],
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.panelAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.stroke, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, Color(0xFF3B82F6)],
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('A',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 6),
            const Text('관리자',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down,
                size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

void showHelpDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.stroke),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      title: const Row(
        children: [
          Icon(Icons.help_outline, size: 16, color: AppColors.accent),
          SizedBox(width: 8),
          Text('도움말 — 단축키',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _ShortcutRow(keys: ['1'], desc: '실시간 모니터링'),
            _ShortcutRow(keys: ['2'], desc: '교통 현황'),
            _ShortcutRow(keys: ['3'], desc: '신호 제어'),
            _ShortcutRow(keys: ['4'], desc: '긴급차량 우선'),
            _ShortcutRow(keys: ['5'], desc: '사건 / 티켓'),
            _ShortcutRow(keys: ['6'], desc: '통계 분석'),
            _ShortcutRow(keys: ['7'], desc: '시스템 설정'),
            Divider(color: AppColors.strokeDim, height: 16),
            _ShortcutRow(keys: ['F'], desc: '전체화면 토글'),
            _ShortcutRow(keys: ['K'], desc: '키오스크 (공공 디스플레이) 모드'),
            _ShortcutRow(keys: ['R'], desc: '재현 모드 (Timeline Scrub)'),
            _ShortcutRow(keys: ['Space'], desc: '신호 정지/재개 (신호 제어 화면)'),
            _ShortcutRow(keys: ['?'], desc: '도움말 열기'),
            _ShortcutRow(keys: ['Esc'], desc: '모달/다이얼로그 닫기'),
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

void showAboutDialogPanel(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.stroke),
      ),
      title: const Text('AI 스마트 교통 신호 제어 시스템',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700)),
      content: const SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LogDetailRowPub(label: '버전', value: '1.0.0+1'),
            _LogDetailRowPub(label: '빌드', value: 'Flutter Web (CanvasKit)'),
            _LogDetailRowPub(label: '백엔드', value: 'Jetson Nano (예정)'),
            _LogDetailRowPub(label: '연결', value: 'ws://192.168.0.116:8765'),
            _LogDetailRowPub(label: '라이선스', value: 'Internal Use Only'),
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

class _ShortcutRow extends StatelessWidget {
  final List<String> keys;
  final String desc;
  const _ShortcutRow({required this.keys, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (final k in keys) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.panelAlt,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Text(k,
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
          ],
          const SizedBox(width: 6),
          Expanded(
            child: Text(desc,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _LogDetailRowPub extends StatelessWidget {
  final String label;
  final String value;
  const _LogDetailRowPub({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
