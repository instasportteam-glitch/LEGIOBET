import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

/// URL, который открывается в WebView — замени на свой.
const String kStartUrl = 'https://gameproc.legioexercitus.space/';

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
      title: 'B.E.T',
      home: WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefresh;
  bool _isLoading = true;

  /// Схемы, которые открывает сам WebView. Всё остальное (tel:, mailto:,
  /// tg:, whatsapp:, intent: и т.д.) уходит во внешние приложения.
  static const _webSchemes = {
    'http', 'https', 'file', 'about', 'data', 'javascript', 'blob',
  };

  final InAppWebViewSettings _settings = InAppWebViewSettings(
    // --- JavaScript / хранилище ---
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    supportMultipleWindows: true, // нужно для onCreateWindow (target=_blank)
    domStorageEnabled: true,
    databaseEnabled: true,
    cacheEnabled: true,
    cacheMode: CacheMode.LOAD_DEFAULT,
    thirdPartyCookiesEnabled: true,
    sharedCookiesEnabled: true, // iOS: общие cookies с HTTPCookieStorage

    // --- Медиа ---
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    allowsPictureInPictureMediaPlayback: true,
    iframeAllowFullscreen: true,

    // --- Навигация ---
    useShouldOverrideUrlLoading: true,
    useOnDownloadStart: true,
    allowsBackForwardNavigationGestures: true, // iOS: свайп назад/вперёд
    allowsLinkPreview: false,

    // --- Зум / скролл / внешний вид ---
    supportZoom: false,

    displayZoomControls: false,
    disallowOverScroll: false,
    verticalScrollBarEnabled: false,
    horizontalScrollBarEnabled: false,
    transparentBackground: true,
    preferredContentMode: UserPreferredContentMode.MOBILE,

    // --- Безопасность / контент ---
    mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
    allowFileAccessFromFileURLs: false,
    allowUniversalAccessFromFileURLs: false,

    // Отладка через Safari/Chrome DevTools только в debug-сборке.
    isInspectable: kDebugMode,
  );

  @override
  void initState() {
    super.initState();
    _pullToRefresh = PullToRefreshController(
      settings: PullToRefreshSettings(color: Colors.white),
      onRefresh: () async {
        final c = _controller;
        if (c == null) return;
        if (defaultTargetPlatform == TargetPlatform.android) {
          await c.reload();
        } else {
          final url = await c.getUrl();
          if (url != null) {
            await c.loadUrl(urlRequest: URLRequest(url: url));
          }
        }
      },
    );
  }

  void _setLoading(bool value) {
    if (mounted && _isLoading != value) setState(() => _isLoading = value);
  }

  void _finishLoading() {
    _pullToRefresh?.endRefreshing();
    _setLoading(false);
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Не удалось открыть $uri: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final c = _controller;
        if (c != null && await c.canGoBack()) {
          await c.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(kStartUrl)),
                initialSettings: _settings,
                pullToRefreshController: _pullToRefresh,
                onWebViewCreated: (c) => _controller = c,
                onLoadStart: (_, __) => _setLoading(true),
                onLoadStop: (_, __) => _finishLoading(),
                onProgressChanged: (_, progress) {
                  if (progress >= 100) _finishLoading();
                },
                onReceivedError: (_, request, error) {
                  debugPrint('WebView error: ${error.type} ${error.description}');
                  if (request.isForMainFrame ?? true) _finishLoading();
                },

                // Внешние схемы (tel:, mailto:, tg:, …) — в системные приложения.
                shouldOverrideUrlLoading: (controller, action) async {
                  final uri = action.request.url;
                  if (uri == null) return NavigationActionPolicy.ALLOW;
                  if (_webSchemes.contains(uri.scheme.toLowerCase())) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  await _openExternal(uri);
                  return NavigationActionPolicy.CANCEL;
                },

                // target="_blank" / window.open — открываем в этом же WebView.
                onCreateWindow: (controller, action) async {
                  final url = action.request.url;
                  if (url != null) {
                    await controller.loadUrl(urlRequest: URLRequest(url: url));
                  }
                  return false;
                },

                // Загрузки файлов — отдаём системе.
                onDownloadStartRequest: (_, request) async {
                  await _openExternal(request.url);
                },

                // Камера / микрофон и т.п. для сайта.
                onPermissionRequest: (_, request) async {
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },

                // iOS: если процесс WebKit упал — перезагружаем страницу.
                onWebContentProcessDidTerminate: (controller) async {
                  await controller.reload();
                },
                // Android: то же самое для рендер-процесса.
                onRenderProcessGone: (controller, _) async {
                  await controller.reload();
                },
              ),
              IgnorePointer(
                ignoring: !_isLoading,
                child: AnimatedOpacity(
                  opacity: _isLoading ? 1 : 0,
                  duration: const Duration(milliseconds: 350),
                  child: const ColoredBox(
                    color: Colors.black,
                    child: Center(child: BetLoader()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Лоадер: "B . E . T" — буквы по очереди увеличиваются и уменьшаются.
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
