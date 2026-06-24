import 'dart:convert';

import 'package:flutter/material.dart';

import '../nav.dart';
import '../theme.dart';
import '../web_helpers.dart';
import '../widgets.dart';
import '../widgets/camera_wizard.dart';
import 'roi_editor.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // mutable state for the form controls
  String _resolution = '1920×1080';
  String _fps = '30';
  String _exposure = '자동';
  double _confidence = 0.65;
  double _maxAge = 0.4;
  double _iou = 0.55;
  double _greenN = 35, _greenE = 45, _greenS = 40, _greenW = 30;
  double _yellow = 3;
  bool _emergencyPriority = true;
  bool _detectAmbulance = true;
  bool _detectFire = true;
  bool _detectPolice = false;
  bool _alertSound = true;
  bool _alertPush = true;
  bool _alertEmail = false;
  String _retention = '30일';
  bool _backupEnabled = true;
  String _wsUrl = 'ws://192.168.0.116:8765';
  String _aiMode = '균형';
  bool _dirty = false;

  String _apiToken = '미발급';
  String _webhookUrl = '';
  bool _evtCongestion = true;
  bool _evtEmergency = true;
  bool _evtSignal = false;
  bool _evtSystem = true;

  void _regenerateToken() {
    final rnd = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    _set(() => _apiToken = 'sai_${rnd}_${rnd.split('').reversed.join()}');
    showActionSnack(context, 'API 토큰 재발급 완료', icon: Icons.vpn_key_outlined);
  }

  void _copyToken() {
    showActionSnack(context, 'API 토큰이 클립보드에 복사되었습니다',
        icon: Icons.content_copy);
  }

  void _testWebhook() {
    showActionSnack(context, '테스트 이벤트 전송 대기 — 백엔드 미연결',
        icon: Icons.send_outlined);
  }

  void _downloadOpenApi() {
    const spec = '{\n  "openapi": "3.0.0",\n  "info": {\n    "title": "SmartAI Traffic API",\n    "version": "1.0.0"\n  }\n}\n';
    downloadFile('smartai-openapi.json', spec,
        mime: 'application/json;charset=utf-8');
    showActionSnack(context, 'OpenAPI 스펙 다운로드 완료',
        icon: Icons.file_download_outlined);
  }

  /// All form mutations should go through this so dirty flips to true.
  void _set(VoidCallback fn) {
    setState(() {
      fn();
      _dirty = true;
    });
  }

  void _save() {
    setState(() => _dirty = false);
    showActionSnack(context, '설정이 저장되었습니다.', icon: Icons.save_outlined);
  }

  void _cancel() {
    setState(() => _dirty = false);
    showActionSnack(context, '변경사항을 취소했습니다.', icon: Icons.close);
  }

  Map<String, Object?> _settingsAsMap() => {
        'camera': {
          'resolution': _resolution,
          'fps': _fps,
          'exposure': _exposure,
        },
        'detection': {
          'confidence': _confidence,
          'iou': _iou,
          'tracker_max_age': _maxAge,
          'classes': {
            'ambulance': _detectAmbulance,
            'fire_truck': _detectFire,
            'police': _detectPolice,
          },
        },
        'signal_timing': {
          'green_n': _greenN.round(),
          'green_e': _greenE.round(),
          'green_s': _greenS.round(),
          'green_w': _greenW.round(),
          'yellow': _yellow.round(),
        },
        'emergency': {'priority_auto': _emergencyPriority},
        'alerts': {
          'sound': _alertSound,
          'push': _alertPush,
          'email': _alertEmail,
        },
        'storage': {
          'retention': _retention,
          'backup_enabled': _backupEnabled,
        },
        'network': {'ws_url': _wsUrl},
        'ai_mode': _aiMode,
      };

  void _exportJson() {
    final json = const JsonEncoder.withIndent('  ').convert(_settingsAsMap());
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    downloadFile('smartai-config-$ts.json', json,
        mime: 'application/json;charset=utf-8');
    showActionSnack(context, '설정 JSON 다운로드 완료',
        icon: Icons.file_download_outlined);
  }

  void _exportCsv() {
    final m = _settingsAsMap();
    final rows = <String>['key,value'];
    void walk(String prefix, Object? v) {
      if (v is Map) {
        v.forEach((k, vv) => walk(prefix.isEmpty ? '$k' : '$prefix.$k', vv));
      } else {
        rows.add('"$prefix","${v.toString().replaceAll('"', '""')}"');
      }
    }
    walk('', m);
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    downloadFile('smartai-config-$ts.csv', rows.join('\n'),
        mime: 'text/csv;charset=utf-8');
    showActionSnack(context, '설정 CSV 다운로드 완료',
        icon: Icons.file_download_outlined);
  }

  Future<void> _openRoiEditor() async {
    final result = await Navigator.of(context).push<List<Offset>>(
      MaterialPageRoute(
        builder: (_) => const RoiEditor(),
        fullscreenDialog: true,
      ),
    );
    if (result != null && mounted) {
      _set(() {});
      showActionSnack(context, '검출 영역 ${result.length}개 점 저장됨',
          icon: Icons.crop_square);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 420,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _cameraPanel()),
                const SizedBox(width: 10),
                Expanded(child: _cctvPreviewPanel()),
                const SizedBox(width: 10),
                Expanded(child: _detectionPanel()),
                const SizedBox(width: 10),
                Expanded(child: _aiPanel()),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 360,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _signalTimePanel()),
                const SizedBox(width: 10),
                Expanded(child: _emergencyPanel()),
                const SizedBox(width: 10),
                Expanded(child: _networkPanel()),
                const SizedBox(width: 10),
                Expanded(child: _storagePanel()),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _apiPanel(),
          const SizedBox(height: 10),
          _saveBar(),
        ],
      ),
    );
  }

  // ==================== panels ====================

  Widget _cameraPanel() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(
              title: '카메라 설정', icon: Icons.videocam_outlined),
          const SizedBox(height: 10),
          _DropdownField(
            label: '해상도',
            value: _resolution,
            items: const ['1280×720', '1920×1080', '2560×1440'],
            onChanged: (v) => _set(() => _resolution = v),
          ),
          const SizedBox(height: 10),
          _DropdownField(
            label: '프레임 레이트',
            value: _fps,
            items: const ['15', '24', '30', '60'],
            onChanged: (v) => _set(() => _fps = v),
            suffix: 'fps',
          ),
          const SizedBox(height: 10),
          _DropdownField(
            label: '노출 모드',
            value: _exposure,
            items: const ['자동', '수동', '야간'],
            onChanged: (v) => _set(() => _exposure = v),
          ),
          const SizedBox(height: 10),
          _SliderField(
            label: '게인',
            value: 0.5,
            onChanged: (_) {},
            valueLabel: '50%',
          ),
          const SizedBox(height: 10),
          _SliderField(
            label: '감마',
            value: 0.7,
            onChanged: (_) {},
            valueLabel: '0.7',
          ),
        ],
      ),
    );
  }

  Widget _cctvPreviewPanel() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(
            title: 'CCTV 미리보기',
            icon: Icons.preview_outlined,
            trailing: LiveBadge(),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.panelAlt, AppColors.panel],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.videocam_off_outlined,
                      size: 36, color: AppColors.textMuted),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Icon(Icons.crop_din, size: 13, color: AppColors.accent),
              SizedBox(width: 6),
              Text('검출 영역',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
              Spacer(),
              Text('자동',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MutedBtn(
                  label: '영역 설정',
                  icon: Icons.edit_outlined,
                  onTap: _openRoiEditor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MutedBtn(
                  label: '리셋',
                  icon: Icons.refresh,
                  onTap: () {
                    _set(() {});
                    showActionSnack(context, '검출 영역을 기본값으로 초기화',
                        icon: Icons.refresh);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final name = await showCameraWizard(context);
              if (!mounted || name == null) return;
              _set(() {});
              if (mounted) {
                showActionSnack(context, '카메라 "$name" 추가됨',
                    icon: Icons.camera_alt_outlined);
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    width: 1),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 14, color: AppColors.accent),
                  SizedBox(width: 4),
                  Text('카메라 추가 (RTSP/ONVIF)',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detectionPanel() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(
              title: '감지 / 인식 설정', icon: Icons.center_focus_strong),
          const SizedBox(height: 10),
          _SliderField(
            label: 'Confidence Threshold',
            value: _confidence,
            onChanged: (v) => _set(() => _confidence = v),
            valueLabel: _confidence.toStringAsFixed(2),
          ),
          const SizedBox(height: 8),
          _SliderField(
            label: 'IoU Threshold',
            value: _iou,
            onChanged: (v) => _set(() => _iou = v),
            valueLabel: _iou.toStringAsFixed(2),
          ),
          const SizedBox(height: 8),
          _SliderField(
            label: 'Tracker Max Age',
            value: _maxAge,
            onChanged: (v) => _set(() => _maxAge = v),
            valueLabel: '${(_maxAge * 100).round()} fr',
          ),
          const SizedBox(height: 12),
          const Text('감지 클래스',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          _SwitchRow(
            label: '구급차',
            value: _detectAmbulance,
            onChanged: (v) => _set(() => _detectAmbulance = v),
          ),
          _SwitchRow(
            label: '소방차',
            value: _detectFire,
            onChanged: (v) => _set(() => _detectFire = v),
          ),
          _SwitchRow(
            label: '경찰차',
            value: _detectPolice,
            onChanged: (v) => _set(() => _detectPolice = v),
          ),
        ],
      ),
    );
  }

  Widget _aiPanel() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(
              title: '알림 / AI 설정', icon: Icons.psychology_outlined),
          const SizedBox(height: 10),
          _SwitchRow(
            label: '소리 알림',
            value: _alertSound,
            onChanged: (v) => _set(() => _alertSound = v),
          ),
          _SwitchRow(
            label: '푸시 알림',
            value: _alertPush,
            onChanged: (v) => _set(() => _alertPush = v),
          ),
          _SwitchRow(
            label: '이메일 알림',
            value: _alertEmail,
            onChanged: (v) => _set(() => _alertEmail = v),
          ),
          const SizedBox(height: 12),
          const Text('AI 모드',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _ModePill(
                label: '균형',
                active: _aiMode == '균형',
                onTap: () => _set(() => _aiMode = '균형'),
              )),
              const SizedBox(width: 6),
              Expanded(child: _ModePill(
                label: '효율',
                active: _aiMode == '효율',
                onTap: () => _set(() => _aiMode = '효율'),
              )),
              const SizedBox(width: 6),
              Expanded(child: _ModePill(
                label: '안전',
                active: _aiMode == '안전',
                onTap: () => _set(() => _aiMode = '안전'),
              )),
            ],
          ),
          const SizedBox(height: 14),
          _SliderField(
            label: '경보 민감도',
            value: 0.6,
            onChanged: (_) {},
            valueLabel: '60%',
          ),
        ],
      ),
    );
  }

  Widget _signalTimePanel() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(
              title: '신호 시간 설정', icon: Icons.timer_outlined),
          const SizedBox(height: 10),
          _SliderField(
            label: '북(N) 직진',
            value: _greenN / 90,
            onChanged: (v) => _set(() => _greenN = v * 90),
            valueLabel: '${_greenN.round()}초',
            color: AppColors.north,
          ),
          const SizedBox(height: 6),
          _SliderField(
            label: '동(E) 직진',
            value: _greenE / 90,
            onChanged: (v) => _set(() => _greenE = v * 90),
            valueLabel: '${_greenE.round()}초',
            color: AppColors.east,
          ),
          const SizedBox(height: 6),
          _SliderField(
            label: '남(S) 직진',
            value: _greenS / 90,
            onChanged: (v) => _set(() => _greenS = v * 90),
            valueLabel: '${_greenS.round()}초',
            color: AppColors.south,
          ),
          const SizedBox(height: 6),
          _SliderField(
            label: '서(W) 직진',
            value: _greenW / 90,
            onChanged: (v) => _set(() => _greenW = v * 90),
            valueLabel: '${_greenW.round()}초',
            color: AppColors.west,
          ),
          const SizedBox(height: 6),
          _SliderField(
            label: '황색 신호',
            value: _yellow / 6,
            onChanged: (v) => _set(() => _yellow = v * 6),
            valueLabel: '${_yellow.round()}초',
            color: AppColors.warn,
          ),
        ],
      ),
    );
  }

  Widget _emergencyPanel() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(
              title: '긴급 우선 설정', icon: Icons.local_hospital_outlined),
          const SizedBox(height: 10),
          _SwitchRow(
            label: '우선 신호 자동 활성화',
            value: _emergencyPriority,
            onChanged: (v) => _set(() => _emergencyPriority = v),
          ),
          const SizedBox(height: 8),
          _SliderField(
            label: '활성 거리 임계값',
            value: 0.4,
            onChanged: (_) {},
            valueLabel: '400m',
          ),
          const SizedBox(height: 6),
          _SliderField(
            label: '최소 우선 시간',
            value: 0.3,
            onChanged: (_) {},
            valueLabel: '30초',
          ),
          const SizedBox(height: 6),
          _SliderField(
            label: '복구 지연',
            value: 0.5,
            onChanged: (_) {},
            valueLabel: '5초',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.4), width: 1),
            ),
            child: Row(
              children: const [
                Icon(Icons.warning_amber_rounded,
                    size: 14, color: AppColors.danger),
                SizedBox(width: 6),
                Expanded(
                  child: Text('수동 활성 시 일반 통행에 영향이 발생합니다.',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _networkPanel() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(
              title: '네트워크 / 연결', icon: Icons.lan_outlined),
          const SizedBox(height: 10),
          _TextField(
            label: 'Jetson WebSocket',
            value: _wsUrl,
            onChanged: (v) => _set(() => _wsUrl = v),
          ),
          const SizedBox(height: 12),
          const Text('연결 상태',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 6),
          Row(
            children: const [
              StatusDotPill(label: '연결 대기', color: AppColors.textMuted, dense: true),
              SizedBox(width: 8),
              Text('지연 — ms',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          const StatLine(label: 'CCTV 스트림', value: '—'),
          const StatLine(label: '백엔드 API', value: '—'),
          const StatLine(label: '저장소 동기화', value: '—'),
          const StatLine(label: 'NTP', value: '—'),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _MutedBtn(
                  label: '연결 테스트',
                  icon: Icons.bolt,
                  onTap: () => showActionSnack(
                      context, 'Jetson WS 연결 테스트 — 응답 없음 (미연결)',
                      icon: Icons.check_circle_outline),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MutedBtn(
                  label: '재연결',
                  icon: Icons.refresh,
                  onTap: () => showActionSnack(
                      context, '$_wsUrl 재연결 시도',
                      icon: Icons.refresh),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _storagePanel() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(
              title: '데이터 / 저장', icon: Icons.storage_outlined),
          const SizedBox(height: 10),
          _DropdownField(
            label: '보관 기간',
            value: _retention,
            items: const ['7일', '14일', '30일', '90일'],
            onChanged: (v) => _set(() => _retention = v),
          ),
          const SizedBox(height: 8),
          _SwitchRow(
            label: '자동 백업',
            value: _backupEnabled,
            onChanged: (v) => _set(() => _backupEnabled = v),
          ),
          const SizedBox(height: 12),
          const Text('저장소 사용량',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 6),
          MiniBar(value: 0, color: AppColors.warn, height: 8),
          const SizedBox(height: 4),
          Row(
            children: const [
              Text('—',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Spacer(),
              Text('전체 용량 —',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ExportPicker(onJson: _exportJson, onCsv: _exportCsv),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MutedBtn(
                  label: '정리',
                  icon: Icons.cleaning_services_outlined,
                  onTap: () => showActionSnack(
                      context, '오래된 로그/스냅샷 정리 시작',
                      icon: Icons.cleaning_services_outlined),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _apiPanel() {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.api_outlined,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              const Text('Open API / Webhook',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.violet.withValues(alpha: 0.4),
                      width: 1),
                ),
                child: const Text('차별점',
                    style: TextStyle(
                        color: AppColors.violet,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _downloadOpenApi,
                icon: const Icon(Icons.download,
                    size: 14, color: AppColors.accent),
                label: const Text('OpenAPI 스펙',
                    style:
                        TextStyle(color: AppColors.accent, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('API 토큰',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.panelAlt,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.stroke, width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _apiToken,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontFeatures: [
                                  FontFeature.tabularFigures()
                                ],
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '복사',
                            iconSize: 14,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.content_copy,
                                color: AppColors.accent),
                            onPressed: _copyToken,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: '재발급',
                            iconSize: 14,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.refresh,
                                color: AppColors.warn),
                            onPressed: _regenerateToken,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Webhook URL',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _webhookUrl,
                            onChanged: (v) =>
                                _set(() => _webhookUrl = v),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontFeatures: [
                                FontFeature.tabularFigures()
                              ],
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.panelAlt,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: AppColors.stroke),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: AppColors.accent),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _testWebhook,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.accent
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppColors.accent
                                      .withValues(alpha: 0.4),
                                  width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.send_outlined,
                                    size: 13, color: AppColors.accent),
                                SizedBox(width: 4),
                                Text('테스트 전송',
                                    style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('이벤트 구독',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 4),
                    _EventCheck(
                      label: '혼잡도 임계값 초과',
                      value: _evtCongestion,
                      onChanged: (v) => _set(() => _evtCongestion = v),
                    ),
                    _EventCheck(
                      label: '긴급차량 감지/통과',
                      value: _evtEmergency,
                      onChanged: (v) => _set(() => _evtEmergency = v),
                    ),
                    _EventCheck(
                      label: '신호 단계 변경',
                      value: _evtSignal,
                      onChanged: (v) => _set(() => _evtSignal = v),
                    ),
                    _EventCheck(
                      label: '시스템 알림 (장애/복구)',
                      value: _evtSystem,
                      onChanged: (v) => _set(() => _evtSystem = v),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.violet.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 11, color: AppColors.violet),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Webhook은 HTTP POST로 발송됩니다. 서명: HMAC-SHA256.',
                              style: TextStyle(
                                  color: AppColors.violet,
                                  fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _saveBar() {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Icon(
            _dirty ? Icons.edit_note : Icons.check_circle_outline,
            size: 14,
            color: _dirty ? AppColors.warn : AppColors.ok,
          ),
          const SizedBox(width: 6),
          Text(
            _dirty ? '저장하지 않은 변경사항이 있습니다.' : '모든 변경사항이 저장되었습니다.',
            style: TextStyle(
                color: _dirty ? AppColors.warn : AppColors.textMuted,
                fontSize: 11),
          ),
          const Spacer(),
          _MutedBtn(
            label: '취소',
            icon: Icons.close,
            onTap: _dirty ? _cancel : () {},
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _dirty ? _save : () => showActionSnack(context, '변경사항이 없습니다.',
                icon: Icons.info_outline),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _dirty
                    ? AppColors.accent
                    : AppColors.accent.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save_outlined, size: 14, color: Colors.black),
                  SizedBox(width: 6),
                  Text('저장',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Form controls
// ============================================================
class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final String? suffix;
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.panelAlt,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.stroke, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              dropdownColor: AppColors.panelAlt,
              icon: const Icon(Icons.arrow_drop_down,
                  color: AppColors.textSecondary, size: 18),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              items: [
                for (final v in items)
                  DropdownMenuItem(
                    value: v,
                    child: Text(suffix != null ? '$v $suffix' : v),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SliderField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final String valueLabel;
  final Color? color;
  const _SliderField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.valueLabel,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
            const Spacer(),
            Text(valueLabel,
                style: TextStyle(
                    color: c,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: c,
            inactiveTrackColor: AppColors.strokeDim,
            thumbColor: c,
            overlayColor: c.withValues(alpha: 0.18),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12)),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.accent,
              activeTrackColor: AppColors.accent.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const _TextField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: AppColors.panelAlt,
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
    );
  }
}

class _EventCheck extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _EventCheck({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_box_outlined : Icons.check_box_outline_blank,
              size: 16,
              color: value ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: value
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportPicker extends StatelessWidget {
  final VoidCallback onJson;
  final VoidCallback onCsv;
  const _ExportPicker({required this.onJson, required this.onCsv});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '내보내기',
      color: AppColors.panel,
      onSelected: (v) {
        if (v == 'json') onJson();
        if (v == 'csv') onCsv();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'json',
          child: Row(
            children: [
              Icon(Icons.data_object, size: 14, color: AppColors.accent),
              SizedBox(width: 8),
              Text('JSON',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'csv',
          child: Row(
            children: [
              Icon(Icons.table_chart, size: 14, color: AppColors.accent),
              SizedBox(width: 8),
              Text('CSV',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 12)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.panelAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.stroke, width: 1),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.file_download_outlined,
                size: 13, color: AppColors.textSecondary),
            SizedBox(width: 5),
            Text('내보내기',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            SizedBox(width: 3),
            Icon(Icons.arrow_drop_down,
                size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _MutedBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _MutedBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.panelAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.stroke, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.panelAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.stroke,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
