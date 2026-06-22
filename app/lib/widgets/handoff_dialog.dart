import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../nav.dart';
import '../theme.dart';

/// Operator handoff modal — shift-change workflow with pending items list
/// and free-text note. Returns the receiver name on success.
Future<String?> showHandoffDialog(BuildContext context) {
  return showDialog<String?>(
    context: context,
    builder: (_) => const Dialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        side: BorderSide(color: AppColors.stroke),
      ),
      child: SizedBox(
        width: 560,
        child: _HandoffBody(),
      ),
    ),
  );
}

class _HandoffBody extends StatefulWidget {
  const _HandoffBody();

  @override
  State<_HandoffBody> createState() => _HandoffBodyState();
}

class _HandoffBodyState extends State<_HandoffBody> {
  String _receiver = '';
  String _note = '';
  final _items = <_PendingItem>[
    _PendingItem(
      time: '14:18',
      title: '동(E) 혼잡도 78% 지속 — 임계값 조정 검토',
      severity: AppColors.warn,
      checked: false,
    ),
    _PendingItem(
      time: '13:42',
      title: 'CCTV-B 노출 자동 보정 권장 카드 (대기 중)',
      severity: AppColors.violet,
      checked: false,
    ),
    _PendingItem(
      time: '12:55',
      title: '구급차 통과 후 신호 복구 시간 31초 — 평균 대비 +6초',
      severity: AppColors.danger,
      checked: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final f = DateFormat('yyyy.MM.dd HH:mm');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake_outlined,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              const Text('교대 인계',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.textMuted, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.panelAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.stroke, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(f.format(now),
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(width: 14),
                const Icon(Icons.person_outline,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                const Text('인계자: 관리자 (admin)',
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.assignment_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text('미해결 사건',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.warn.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${_items.where((x) => !x.checked).length}건',
                    style: const TextStyle(
                        color: AppColors.warn,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final it in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => setState(() => it.checked = !it.checked),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.panelAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: it.checked
                            ? AppColors.ok.withValues(alpha: 0.4)
                            : it.severity.withValues(alpha: 0.4),
                        width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        it.checked
                            ? Icons.check_box_outlined
                            : Icons.check_box_outline_blank,
                        size: 16,
                        color: it.checked
                            ? AppColors.ok
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: it.severity,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(it.time,
                          style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontFeatures: [
                                FontFeature.tabularFigures()
                              ])),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          it.title,
                          style: TextStyle(
                              color: it.checked
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                              fontSize: 12,
                              decoration: it.checked
                                  ? TextDecoration.lineThrough
                                  : null),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          const Text('인계 메모',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: _note,
            onChanged: (v) => _note = v,
            maxLines: 3,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: '예: 동쪽 차선이 오후 내내 평소보다 막힙니다. 17시 이후 추이를 확인해주세요.',
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
          const SizedBox(height: 10),
          const Text('인수자',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: _receiver,
            onChanged: (v) => setState(() => _receiver = v),
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: '예: 김운영 / shift-b@smartai.local',
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
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '인계 시 이벤트 ID와 서명이 시스템 로그에 보관됩니다.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: _receiver.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop(_receiver);
                        showActionSnack(context,
                            '$_receiver 에게 인계 완료 (서명 기록됨)',
                            icon: Icons.handshake_outlined);
                      },
                icon: const Icon(Icons.check, size: 14, color: Colors.black),
                label: const Text('인계',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  disabledBackgroundColor:
                      AppColors.accent.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingItem {
  final String time;
  final String title;
  final Color severity;
  bool checked;
  _PendingItem({
    required this.time,
    required this.title,
    required this.severity,
    required this.checked,
  });
}
