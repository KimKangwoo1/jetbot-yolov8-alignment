import 'package:flutter/material.dart';

import '../nav.dart';
import '../theme.dart';

class Intersection {
  final String id;
  final String name;       // e.g. "강남대로 사거리"
  final String district;   // e.g. "강남구"
  final String city;       // e.g. "서울특별시"
  final IntersectionStatus status;
  final int activeAlerts;
  /// YouTube video ID for the demo CCTV livestream. In production this is
  /// replaced by the real RTSP/HLS URL coming from the Jetson.
  final String? primaryYoutubeId;
  final String? subYoutubeId;
  const Intersection({
    required this.id,
    required this.name,
    required this.district,
    required this.city,
    required this.status,
    required this.activeAlerts,
    this.primaryYoutubeId,
    this.subYoutubeId,
  });
}

enum IntersectionStatus { ok, warn, danger, offline }

extension on IntersectionStatus {
  Color get color {
    switch (this) {
      case IntersectionStatus.ok:
        return AppColors.ok;
      case IntersectionStatus.warn:
        return AppColors.warn;
      case IntersectionStatus.danger:
        return AppColors.danger;
      case IntersectionStatus.offline:
        return AppColors.textMuted;
    }
  }

  String get label {
    switch (this) {
      case IntersectionStatus.ok:
        return '정상';
      case IntersectionStatus.warn:
        return '주의';
      case IntersectionStatus.danger:
        return '경보';
      case IntersectionStatus.offline:
        return '오프라인';
    }
  }
}

class IntersectionRegistry extends ChangeNotifier {
  IntersectionRegistry._() {
    _all = [
      // No demo locations. Sites are registered by the operator ("카메라 추가")
      // and, in production, supplied by the backend. One neutral placeholder
      // keeps the selector usable until a real camera/site is added.
      const Intersection(
        id: 'site-1',
        name: '현장 카메라 1',
        district: '현장',
        city: '',
        status: IntersectionStatus.offline,
        activeAlerts: 0,
      ),
    ];
    _selected = _all.first;
    for (final i in _all) {
      _primaryUrls[i.id] = i.primaryYoutubeId;
      _subUrls[i.id] = i.subYoutubeId;
    }
  }
  static final IntersectionRegistry instance = IntersectionRegistry._();

  late List<Intersection> _all;
  late Intersection _selected;
  /// Mutable per-intersection URL overrides set by the operator at runtime.
  final Map<String, String?> _primaryUrls = {};
  final Map<String, String?> _subUrls = {};

  List<Intersection> get all => List.unmodifiable(_all);
  Intersection get selected => _selected;

  String? primaryUrlFor(String id) => _primaryUrls[id];
  String? subUrlFor(String id) => _subUrls[id];

  String? get selectedPrimaryUrl => _primaryUrls[_selected.id];
  String? get selectedSubUrl => _subUrls[_selected.id];

  Map<String, List<Intersection>> get byDistrict {
    final m = <String, List<Intersection>>{};
    for (final i in _all) {
      m.putIfAbsent(i.district, () => []).add(i);
    }
    return m;
  }

  void select(Intersection i) {
    if (i.id == _selected.id) return;
    _selected = i;
    notifyListeners();
  }

  void setPrimaryUrl(String intersectionId, String? url) {
    _primaryUrls[intersectionId] = _normalizeYoutubeId(url);
    notifyListeners();
  }

  void setSubUrl(String intersectionId, String? url) {
    _subUrls[intersectionId] = _normalizeYoutubeId(url);
    notifyListeners();
  }

  /// Accept either a full YouTube URL or just the 11-char video ID.
  static String? _normalizeYoutubeId(String? input) {
    if (input == null) return null;
    final t = input.trim();
    if (t.isEmpty) return null;
    // youtu.be/<id>
    final beMatch = RegExp(r'youtu\.be/([A-Za-z0-9_-]{8,})').firstMatch(t);
    if (beMatch != null) return beMatch.group(1);
    // youtube.com/watch?v=<id>
    final wMatch = RegExp(r'[?&]v=([A-Za-z0-9_-]{8,})').firstMatch(t);
    if (wMatch != null) return wMatch.group(1);
    // youtube.com/live/<id>
    final liveMatch =
        RegExp(r'youtube\.com/live/([A-Za-z0-9_-]{8,})').firstMatch(t);
    if (liveMatch != null) return liveMatch.group(1);
    // youtube.com/embed/<id>
    final eMatch =
        RegExp(r'youtube\.com/embed/([A-Za-z0-9_-]{8,})').firstMatch(t);
    if (eMatch != null) return eMatch.group(1);
    // assume bare ID
    if (RegExp(r'^[A-Za-z0-9_-]{8,}$').hasMatch(t)) return t;
    return null;
  }
}

class IntersectionSelector extends StatefulWidget {
  const IntersectionSelector({super.key});

  @override
  State<IntersectionSelector> createState() => _IntersectionSelectorState();
}

class _IntersectionSelectorState extends State<IntersectionSelector> {
  @override
  void initState() {
    super.initState();
    IntersectionRegistry.instance.addListener(_on);
  }

  @override
  void dispose() {
    IntersectionRegistry.instance.removeListener(_on);
    super.dispose();
  }

  void _on() {
    if (mounted) setState(() {});
  }

  void _open() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const Dialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: AppColors.stroke),
        ),
        child: SizedBox(
          width: 480,
          child: _IntersectionPicker(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sel = IntersectionRegistry.instance.selected;
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.panelAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.stroke, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_outlined,
                size: 14, color: sel.status.color),
            const SizedBox(width: 6),
            Text(sel.district,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right,
                  size: 12, color: AppColors.textMuted),
            ),
            Text(sel.name,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            if (sel.activeAlerts > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.warn.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('알림 ${sel.activeAlerts}',
                    style: const TextStyle(
                        color: AppColors.warn,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.expand_more,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _IntersectionPicker extends StatefulWidget {
  const _IntersectionPicker();

  @override
  State<_IntersectionPicker> createState() => _IntersectionPickerState();
}

class _IntersectionPickerState extends State<_IntersectionPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final reg = IntersectionRegistry.instance;
    final byDist = reg.byDistrict;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              const Text('교차로 선택',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${reg.all.length}개 운영 중',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.textMuted, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v.trim()),
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: '교차로 / 행정구 검색...',
              hintStyle:
                  const TextStyle(color: AppColors.textMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.search,
                  size: 16, color: AppColors.textMuted),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              filled: true,
              fillColor: AppColors.panelAlt,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in byDist.entries) ...[
                    _DistrictHeader(
                      district: entry.key,
                      count: entry.value.length,
                    ),
                    for (final i in entry.value
                        .where((x) =>
                            _query.isEmpty ||
                            x.name.contains(_query) ||
                            x.district.contains(_query)))
                      _IntersectionTile(
                        item: i,
                        selected: i.id == reg.selected.id,
                        onTap: () {
                          reg.select(i);
                          Navigator.of(context).pop();
                          showActionSnack(context,
                              '${i.name} 으로 전환',
                              icon: Icons.location_on_outlined);
                        },
                      ),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.map_outlined,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              const Text('지도에서 선택은 다음 단계에서 지원될 예정',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close,
                    size: 12, color: AppColors.textSecondary),
                label: const Text('닫기',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistrictHeader extends StatelessWidget {
  final String district;
  final int count;
  const _DistrictHeader({required this.district, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
      child: Row(
        children: [
          const Icon(Icons.apartment,
              size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(district,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text('· $count곳',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _IntersectionTile extends StatelessWidget {
  final Intersection item;
  final bool selected;
  final VoidCallback onTap;
  const _IntersectionTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.10)
              : AppColors.panelAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.stroke,
              width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: item.status.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: item.status.color.withValues(alpha: 0.6),
                      blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item.name,
                  style: TextStyle(
                      color: selected
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500)),
            ),
            Text(item.status.label,
                style: TextStyle(
                    color: item.status.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            if (item.activeAlerts > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.warn.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${item.activeAlerts}건',
                    style: const TextStyle(
                        color: AppColors.warn,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check,
                  size: 14, color: AppColors.accent),
            ],
          ],
        ),
      ),
    );
  }
}
