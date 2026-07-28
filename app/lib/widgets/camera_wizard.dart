import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Multi-step "Bring Your Own Camera" onboarding. Returns the new camera's
/// nickname on success, or null if cancelled.
Future<String?> showCameraWizard(BuildContext context) {
  return showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Dialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        side: BorderSide(color: AppColors.stroke),
      ),
      child: SizedBox(
        width: 540,
        child: _CameraWizardBody(),
      ),
    ),
  );
}

class _CameraWizardBody extends StatefulWidget {
  const _CameraWizardBody();

  @override
  State<_CameraWizardBody> createState() => _CameraWizardBodyState();
}

class _CameraWizardBodyState extends State<_CameraWizardBody> {
  int _step = 0;
  String _url = 'rtsp://';
  String _name = 'CCTV-새교차로';
  _TestState _test = _TestState.idle;
  Timer? _testTimer;

  @override
  void dispose() {
    _testTimer?.cancel();
    super.dispose();
  }

  void _runTest() {
    setState(() => _test = _TestState.running);
    _testTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      final ok = _url.startsWith('rtsp://') && _url.length > 10;
      setState(() => _test = ok ? _TestState.success : _TestState.failed);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt_outlined,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              const Text('카메라 추가 마법사',
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
          const SizedBox(height: 12),
          _Stepper(step: _step),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 220),
            child: _bodyForStep(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_step > 0)
                TextButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text('이전',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _canAdvance() ? _advance : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  disabledBackgroundColor:
                      AppColors.accent.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: Text(_step == 3 ? '완료' : '다음',
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bodyForStep() {
    switch (_step) {
      case 0:
        return _step1Url();
      case 1:
        return _step2Test();
      case 2:
        return _step3Roi();
      case 3:
        return _step4Save();
      default:
        return const SizedBox.shrink();
    }
  }

  bool _canAdvance() {
    switch (_step) {
      case 0:
        return _url.length > 7;
      case 1:
        return _test == _TestState.success;
      case 2:
        return true;
      case 3:
        return _name.isNotEmpty;
    }
    return false;
  }

  void _advance() {
    if (_step == 3) {
      Navigator.of(context).pop(_name);
      return;
    }
    setState(() => _step++);
    if (_step == 1 && _test == _TestState.idle) {
      _runTest();
    }
  }

  Widget _step1Url() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle('1단계 — 카메라 연결 정보',
            sub: 'RTSP/ONVIF URL을 입력하세요. 보안 카메라 표준을 지원합니다.'),
        const SizedBox(height: 14),
        const Text('RTSP URL',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: _url,
          autofocus: true,
          onChanged: (v) => setState(() => _url = v),
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()]),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'rtsp://192.168.1.100:554/stream1',
            hintStyle: const TextStyle(
                color: AppColors.textMuted, fontSize: 12),
            filled: true,
            fillColor: AppColors.panelAlt,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        _Hint(text: '인증이 필요한 경우: rtsp://user:pass@host:port/path 형식'),
      ],
    );
  }

  Widget _step2Test() {
    Color tone;
    IconData icon;
    String title, detail;
    switch (_test) {
      case _TestState.idle:
      case _TestState.running:
        tone = AppColors.accent;
        icon = Icons.wifi_tethering;
        title = '연결 테스트 중...';
        detail = '$_url 에서 응답을 기다리고 있습니다.';
        break;
      case _TestState.success:
        tone = AppColors.ok;
        icon = Icons.check_circle_outline;
        title = '연결 성공';
        detail = '스트림 응답이 확인되었습니다.';
        break;
      case _TestState.failed:
        tone = AppColors.danger;
        icon = Icons.error_outline;
        title = '연결 실패';
        detail = '응답이 없거나 인증이 거부되었습니다. URL을 확인해주세요.';
        break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle('2단계 — 연결 테스트',
            sub: '카메라가 응답하는지, 코덱과 해상도를 자동으로 감지합니다.'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tone.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            children: [
              if (_test == _TestState.running)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else
                Icon(icon, size: 22, color: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: tone,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(detail,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              if (_test == _TestState.failed)
                TextButton(
                  onPressed: _runTest,
                  child: const Text('재시도',
                      style: TextStyle(color: AppColors.danger)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _step3Roi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle('3단계 — 자동 영역 추정',
            sub: 'AI가 차로/정지선을 자동으로 인식해 검출 영역을 그렸습니다. 필요하면 나중에 수정할 수 있습니다.'),
        const SizedBox(height: 14),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
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
                        size: 50, color: AppColors.textMuted),
                  ),
                ),
                CustomPaint(
                  painter: _AutoRoiPainter(),
                  child: Container(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.auto_fix_high, size: 12, color: AppColors.accent),
            SizedBox(width: 4),
            Text('차로 4개 자동 인식 · 정지선 4곳 표시',
                style: TextStyle(color: AppColors.accent, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _step4Save() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle('4단계 — 카메라 이름',
            sub: '대시보드에 표시될 이름입니다. 위치 기반으로 짓는 것을 권장합니다.'),
        const SizedBox(height: 14),
        const Text('이름',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: _name,
          autofocus: true,
          onChanged: (v) => setState(() => _name = v),
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: '예: CCTV-동측, 정문 카메라',
            filled: true,
            fillColor: AppColors.panelAlt,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.ok.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: AppColors.ok.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            children: const [
              Icon(Icons.check_circle_outline,
                  size: 14, color: AppColors.ok),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '완료를 누르면 새 카메라가 즉시 운영에 추가됩니다. (대시보드 재시작 불필요)',
                  style:
                      TextStyle(color: AppColors.ok, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _TestState { idle, running, success, failed }

class _Stepper extends StatelessWidget {
  final int step;
  const _Stepper({required this.step});

  static const _labels = ['연결 정보', '연결 테스트', '영역 추정', '저장'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i == step
                  ? AppColors.accent
                  : (i < step
                      ? AppColors.accent.withValues(alpha: 0.4)
                      : AppColors.panelAlt),
              shape: BoxShape.circle,
              border: Border.all(
                  color: i <= step
                      ? AppColors.accent
                      : AppColors.stroke,
                  width: 1),
            ),
            child: i < step
                ? const Icon(Icons.check, size: 12, color: Colors.black)
                : Text('${i + 1}',
                    style: TextStyle(
                        color: i == step
                            ? Colors.black
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          Text(_labels[i],
              style: TextStyle(
                  color: i == step
                      ? AppColors.accent
                      : (i < step
                          ? AppColors.textSecondary
                          : AppColors.textMuted),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          if (i < _labels.length - 1)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                height: 1,
                color: i < step ? AppColors.accent : AppColors.stroke,
              ),
            ),
        ],
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  final String label;
  final String sub;
  const _StepTitle(this.label, {required this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(sub,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                height: 1.4)),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 11, color: AppColors.accent),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.accent, fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

class _AutoRoiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // mock auto-detected lanes
    final lanes = [
      Path()
        ..moveTo(size.width * 0.10, size.height * 0.30)
        ..lineTo(size.width * 0.45, size.height * 0.30)
        ..lineTo(size.width * 0.50, size.height * 0.50)
        ..lineTo(size.width * 0.05, size.height * 0.50)
        ..close(),
      Path()
        ..moveTo(size.width * 0.55, size.height * 0.30)
        ..lineTo(size.width * 0.90, size.height * 0.30)
        ..lineTo(size.width * 0.95, size.height * 0.50)
        ..lineTo(size.width * 0.50, size.height * 0.50)
        ..close(),
    ];

    for (final p in lanes) {
      canvas.drawPath(
        p,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.20)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        p,
        Paint()
          ..color = AppColors.accent
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }

    // stop line
    final stopY = size.height * 0.50;
    canvas.drawLine(
      Offset(size.width * 0.05, stopY),
      Offset(size.width * 0.95, stopY),
      Paint()
        ..color = AppColors.warn
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _AutoRoiPainter old) => false;
}
