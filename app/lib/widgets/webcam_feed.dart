// 효준 노트북 카메라 수신 위젯 (정훈 Flutter Web)
// =================================================
//  ① MJPEG 영상  : <img>(HtmlElementView)로 표시 — 브라우저가 multipart 갱신 처리
//  ② 감지 이벤트 : WebSocket(web_socket_channel)으로 받아 "감지됨" 배지 점등
//
// 사용 예:
//   const WebcamFeed(
//     mjpegUrl: 'http://10.15.6.240:8080/stream',
//     wsUrl:    'ws://10.15.6.240:8765',
//   )
//
// 주의:
//  - 효준 노트북과 같은 와이파이여야 합니다.
//  - Flutter 페이지가 https면 http 스트림은 브라우저가 차단(mixed content)합니다.
//    개발 중 http(localhost) 환경에서는 문제없습니다.
//
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebcamFeed extends StatefulWidget {
  final String mjpegUrl;
  final String wsUrl;

  /// 감지 배지가 켜진 채 유지되는 시간.
  final Duration badgeHold;

  const WebcamFeed({
    super.key,
    required this.mjpegUrl,
    required this.wsUrl,
    this.badgeHold = const Duration(seconds: 3),
  });

  @override
  State<WebcamFeed> createState() => _WebcamFeedState();
}

class _WebcamFeedState extends State<WebcamFeed> {
  late final String _viewType;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  // 감지 상태
  String? _lastObject;
  double? _lastConf;
  DateTime? _lastSeen;
  Timer? _badgeTimer;
  bool _wsConnected = false;

  @override
  void initState() {
    super.initState();
    _registerVideoView();
    _connectWs();
  }

  void _registerVideoView() {
    // URL 단위로 고유 viewType — <img>가 MJPEG 멀티파트를 그대로 렌더링.
    _viewType = 'mjpeg-${widget.mjpegUrl.hashCode}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final img = html.ImageElement()
        ..src = widget.mjpegUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';
      return img;
    });
  }

  void _connectWs() {
    try {
      final ch = WebSocketChannel.connect(Uri.parse(widget.wsUrl));
      _channel = ch;
      _wsSub = ch.stream.listen(
        _onWsMessage,
        onError: (_) => _setWs(false),
        onDone: () {
          _setWs(false);
          // 끊기면 2초 뒤 재연결 시도
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _connectWs();
          });
        },
      );
      _setWs(true);
    } catch (_) {
      _setWs(false);
    }
  }

  void _setWs(bool v) {
    if (mounted && _wsConnected != v) setState(() => _wsConnected = v);
  }

  void _onWsMessage(dynamic raw) {
    try {
      final m = jsonDecode(raw as String) as Map<String, dynamic>;
      if (m['type'] != 'detection') return;
      setState(() {
        _lastObject = m['object'] as String?;
        _lastConf = (m['confidence'] as num?)?.toDouble();
        _lastSeen = DateTime.now();
      });
      _badgeTimer?.cancel();
      _badgeTimer = Timer(widget.badgeHold, () {
        if (mounted) setState(() => _lastSeen = null);
      });
    } catch (_) {/* 무시 */}
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  bool get _active => _lastSeen != null;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ① 영상
          HtmlElementView(viewType: _viewType),

          // 영상 위 어둡게(텍스트 가독성)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black26, Colors.transparent, Colors.black45],
              ),
            ),
          ),

          // 연결 상태 (좌상단)
          Positioned(
            top: 8,
            left: 8,
            child: _StatusChip(
              connected: _wsConnected,
              label: _wsConnected ? 'LIVE' : '연결 대기',
            ),
          ),

          // ② 감지됨 배지 (우상단)
          Positioned(
            top: 8,
            right: 8,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _active ? 1 : 0,
              child: _DetectBadge(object: _lastObject, conf: _lastConf),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool connected;
  final String label;
  const _StatusChip({required this.connected, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = connected ? const Color(0xFF22C55E) : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DetectBadge extends StatelessWidget {
  final String? object;
  final double? conf;
  const _DetectBadge({this.object, this.conf});

  @override
  Widget build(BuildContext context) {
    final pct = conf == null ? '' : ' ${(conf! * 100).toStringAsFixed(0)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x66EF4444), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.crisis_alert, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text('감지됨${object != null ? ' · $object' : ''}$pct',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
