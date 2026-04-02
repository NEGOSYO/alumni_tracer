import 'package:web/web.dart' as web;

Future<bool> openLinkedInPopup(String url) async {
  final width = 560;
  final height = 720;
  final left = (web.window.screen.width.toInt() - width) ~/ 2;
  final top = (web.window.screen.height.toInt() - height) ~/ 2;

  final features = [
    'width=$width',
    'height=$height',
    'left=$left',
    'top=$top',
    'resizable=yes',
    'scrollbars=yes',
  ].join(',');

  final popup = web.window.open(
    url,
    'linkedin_oauth_popup',
    features,
  );
  return popup != null;
}
