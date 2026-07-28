// Web-only browser helpers: fullscreen toggle and file download.
// This file imports `dart:html` directly. The app is web-targeted; if we
// later add native targets, conditional imports will be needed.
//
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

bool isFullscreen() => html.document.fullscreenElement != null;

Future<void> toggleFullscreen() async {
  if (isFullscreen()) {
    html.document.exitFullscreen();
  } else {
    await html.document.documentElement?.requestFullscreen();
  }
}

void downloadFile(
  String filename,
  String content, {
  String mime = 'text/plain;charset=utf-8',
}) {
  final blob = html.Blob([content], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
