import 'package:flutter/material.dart';

import 'theme.dart';

/// Index map for the sidebar:
///   0 = 실시간 모니터링, 1 = 교통 현황, 2 = 신호 제어,
///   3 = 긴급차량 우선, 4 = 통계 분석, 5 = 시스템 설정.
class NavScope extends InheritedWidget {
  final void Function(int) goTo;
  final int currentIndex;
  const NavScope({
    super.key,
    required this.goTo,
    required this.currentIndex,
    required super.child,
  });

  static NavScope of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<NavScope>();
    assert(w != null, 'NavScope not found above this widget.');
    return w!;
  }

  @override
  bool updateShouldNotify(NavScope oldWidget) =>
      currentIndex != oldWidget.currentIndex;
}

/// Show a full event-detail dialog for a log row.
Future<void> showLogDetail(
  BuildContext context, {
  required String time,
  required String message,
  required Color tone,
  String? cause,
  String? action,
  String? operator,
  String category = '시스템',
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.stroke),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      title: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(category,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          Text(time,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: tone.withValues(alpha: 0.4), width: 1),
              ),
              child: Text(message,
                  style: TextStyle(
                      color: tone,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            if (cause != null) _LogDetailRow(label: '원인', value: cause),
            if (action != null) _LogDetailRow(label: '조치', value: action),
            if (operator != null)
              _LogDetailRow(label: '담당', value: operator),
            _LogDetailRow(label: '이벤트 ID',
                value: 'evt-${time.replaceAll(':', '')}-${tone.toARGB32().toRadixString(16).substring(2)}'),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(ctx).pop(),
          icon: const Icon(Icons.close,
              size: 14, color: AppColors.textSecondary),
          label: const Text('닫기',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    ),
  );
}

class _LogDetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _LogDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

/// Show a brief snackbar confirmation for actions without backends yet.
void showActionSnack(BuildContext context, String message, {IconData? icon}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(icon ?? Icons.check_circle_outline,
              size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12)),
          ),
        ],
      ),
      backgroundColor: AppColors.panelAlt,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.stroke),
      ),
    ));
}
