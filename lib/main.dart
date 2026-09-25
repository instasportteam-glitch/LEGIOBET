import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';


class WebScreen extends StatefulWidget {
  const WebScreen({super.key, required this.url});

  final String url;

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  InAppWebViewController? _controller;
  bool _loading = true;

  /// Лоадер убирается максимум через 5 секунд после запуска.
  Timer? _loaderTimer;

  @override
  void initState() {
    super.initState();
    _loaderTimer = Timer(const Duration(seconds: 5), () => _setLoading(false));
  }

  @override
  void dispose() {
    _loaderTimer?.cancel();
    super.dispose();
  }

  /// User-Agent мобильного Safari (iPhone, iOS 26).


  final _settings = InAppWebViewSettings(

    javaScriptEnabled: true,
    domStorageEnabled: true,
    databaseEnabled: true,
    thirdPartyCookiesEnabled: true,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    supportZoom: false,
    useHybridComposition: true,
    transparentBackground: true,
  );

  void _setLoading(bool value) {
    if (mounted && _loading != value) setState(() => _loading = value);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final c = _controller;
        if (c != null && await c.canGoBack()) {
          c.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                initialSettings: _settings,
                onWebViewCreated: (c) => _controller = c,
                onLoadStart: (_, url) => debugPrint('[WV] start: $url'),
                onLoadStop: (_, url) {
                  debugPrint('[WV] stop: $url');
                  _setLoading(false);
                },
                onReceivedHttpError: (_, request, response) => debugPrint(
                    '[WV] HTTP ${response.statusCode} ${request.url}'),
                onConsoleMessage: (_, msg) =>
                    debugPrint('[WV console] ${msg.messageLevel}: ${msg.message}'),
                onProgressChanged: (_, progress) {
                  debugPrint('[WV] progress: $progress');
                  if (progress >= 100) _setLoading(false);
                },
                onReceivedError: (_, request, error) {
                  debugPrint('[WV] error: ${error.type} ${error.description} ${request.url}');
                  if (request.isForMainFrame ?? true) _setLoading(false);
                },
              ),
              if (_loading)
                const ColoredBox(
                  color: Colors.black,
                  child: Center(child: BetLoader()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebScreen(url: 'https://gameproc.legioexercitus.space/'),
    );
  }
}

 class BetLoader extends StatefulWidget {
  const BetLoader({
    super.key,
    this.color = Colors.white,
    this.fontSize = 44,
    this.maxScale = 1.6,
    this.duration = const Duration(milliseconds: 1200),
  });

  final Color color;
  final double fontSize;
  final double maxScale;
  final Duration duration;

  @override
  State<BetLoader> createState() => _BetLoaderState();
}

class _BetLoaderState extends State<BetLoader>
    with SingleTickerProviderStateMixin {
  static const _letters = ['B', 'E', 'T'];
  late final AnimationController _ctrl =
  AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Каждая буква анимируется в своём окне цикла (с небольшим перекрытием):
  /// 0 → 1 → 0 по синусу, поэтому волна идёт B → E → T.
  double _scaleFor(int index) {
    const window = 0.45; // доля цикла на одну букву
    const step = (1 - window) / 2; // сдвиг между буквами
    final start = index * step;
    final t = (_ctrl.value - start) / window;
    if (t < 0 || t > 1) return 1;
    final wave = math.sin(t * math.pi); // 0 → 1 → 0
    return 1 + (widget.maxScale - 1) * wave;
  }

  @override
  Widget build(BuildContext context) {
    final letterStyle = TextStyle(
      color: widget.color,
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    );
    final dotStyle = letterStyle.copyWith(
      color: widget.color.withValues(alpha: 0.7),
    );

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final children = <Widget>[];
        for (var i = 0; i < _letters.length; i++) {
          if (i > 0) {
            children.add(Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.fontSize * 0.3),
              child: Text('.', style: dotStyle),
            ));
          }
          children.add(Transform.scale(
            scale: _scaleFor(i),
            child: Text(_letters[i], style: letterStyle),
          ));
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        );
      },
    );
  }
}