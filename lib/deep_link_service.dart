import 'dart:async';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamController<Uri>? _linkStreamController;

  Stream<Uri> get linkStream {
    _linkStreamController ??= StreamController<Uri>.broadcast();
    return _linkStreamController!.stream;
  }

  Future<void> initialize() async {
    // Listen to incoming deep links when the app is already running
    _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _linkStreamController?.add(uri);
      },
      onError: (err) {
        print('Deep link error: $err');
      },
    );

    // Handle app opened via deep link when app was closed
    try {
      final Uri? initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _linkStreamController?.add(initialLink);
      }
    } catch (e) {
      print('Failed to get initial link: $e');
    }
  }

  void dispose() {
    _linkStreamController?.close();
    _linkStreamController = null;
  }
}