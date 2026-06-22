import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../nav.dart';
import '../theme.dart';
import 'intersection_selector.dart';

/// Live CCTV panel.
///
/// In production this would render an HLS/MJPEG stream coming from the Jetson.
/// For now we accept an optional YouTube video ID so demos can use real public
/// livestreams (Hangang River, Shibuya, etc.) and the UI looks alive.
///
/// When [youtubeId] is null the previous styled placeholder is shown — keeping
/// the dashboard usable when offline.
class CctvPlayer extends StatefulWidget {
  final String? youtubeId;
  final List<Widget> overlays;
  final bool showPlaceholderWhenEmpty;
  final BorderRadius borderRadius;
  const CctvPlayer({
    super.key,
    required this.youtubeId,
    this.overlays = const [],
    this.showPlaceholderWhenEmpty = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<CctvPlayer> createState() => _CctvPlayerState();
}

class _CctvPlayerState extends State<CctvPlayer> {
  YoutubePlayerController? _ctrl;

  @override
  void initState() {
    super.initState();
    _spinUp(widget.youtubeId);
  }

  @override
  void didUpdateWidget(covariant CctvPlayer old) {
    super.didUpdateWidget(old);
    if (old.youtubeId != widget.youtubeId) {
      _ctrl?.close();
      _ctrl = null;
      _spinUp(widget.youtubeId);
    }
  }

  void _spinUp(String? id) {
    if (id == null || id.isEmpty) return;
    _ctrl = YoutubePlayerController.fromVideoId(
      videoId: id,
      autoPlay: true,
      params: const YoutubePlayerParams(
        mute: true,
        showControls: false,
        showFullscreenButton: false,
        strictRelatedVideos: true,
        enableCaption: false,
        loop: true,
        showVideoAnnotations: false,
        playsInline: true,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final has = _ctrl != null;
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (has)
            YoutubePlayer(
              controller: _ctrl!,
              aspectRatio: 16 / 9,
              backgroundColor: AppColors.bg,
            )
          else if (widget.showPlaceholderWhenEmpty)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.panelAlt, AppColors.panel],
                ),
              ),
              child: const Center(
                child: Icon(Icons.videocam_off_outlined,
                    size: 42, color: AppColors.textMuted),
              ),
            )
          else
            const SizedBox.shrink(),
          // tap-blocking overlay so YouTube clicks don't open YouTube.com
          if (has)
            Positioned.fill(
              child: AbsorbPointer(absorbing: true),
            ),
          ...widget.overlays,
        ],
      ),
    );
  }
}

/// Small chip-style button that opens a paste-URL dialog. Used on CCTV panels
/// so demos can swap in any public YouTube livestream URL on the fly.
class CctvUrlEditButton extends StatelessWidget {
  final bool isPrimary;
  const CctvUrlEditButton({super.key, this.isPrimary = true});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openEditor(context, isPrimary: isPrimary),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.panelAlt,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.stroke, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.edit_outlined,
                size: 11, color: AppColors.textSecondary),
            SizedBox(width: 3),
            Text('영상 URL',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

Future<void> _openEditor(BuildContext context,
    {required bool isPrimary}) async {
  final reg = IntersectionRegistry.instance;
  final intId = reg.selected.id;
  final current = isPrimary ? reg.primaryUrlFor(intId) : reg.subUrlFor(intId);
  final ctrl = TextEditingController(text: current ?? '');

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.stroke),
      ),
      title: Row(
        children: [
          const Icon(Icons.videocam_outlined,
              size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isPrimary ? '메인 CCTV — 영상 URL' : '보조 CCTV — 영상 URL',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${reg.selected.district} · ${reg.selected.name}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            const Text('YouTube URL 또는 영상 ID',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText:
                    'https://youtube.com/watch?v=... 또는 youtu.be/... 또는 영상 ID',
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
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
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.violet.withValues(alpha: 0.3),
                    width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 12, color: AppColors.violet),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '시연용 임시 영상입니다. 실 운영에서는 Jetson에서 RTSP/HLS 스트림으로 자동 연결됩니다.',
                      style: TextStyle(
                          color: AppColors.violet, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (isPrimary) {
              reg.setPrimaryUrl(intId, null);
            } else {
              reg.setSubUrl(intId, null);
            }
            Navigator.of(ctx).pop();
            showActionSnack(context, '영상 URL 제거됨', icon: Icons.videocam_off);
          },
          child: const Text('지우기',
              style: TextStyle(color: AppColors.danger)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('취소',
              style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () {
            if (isPrimary) {
              reg.setPrimaryUrl(intId, ctrl.text);
            } else {
              reg.setSubUrl(intId, ctrl.text);
            }
            Navigator.of(ctx).pop();
            showActionSnack(context, '영상 URL 저장됨',
                icon: Icons.videocam_outlined);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text('적용',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
