import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'http_client_factory.dart';
import 'image_response.dart';
import 'proxy_settings_service.dart';

class OriginalImage extends StatefulWidget {
  const OriginalImage({super.key, required this.url, this.client});
  final String url;
  final http.Client? client;
  @override
  State<OriginalImage> createState() => _OriginalImageState();
}

class _OriginalImageState extends State<OriginalImage> {
  late final http.Client _client = widget.client ?? buildClient();
  Uint8List? _bytes;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    ProxySettingsService.instance.addListener(_proxyChanged);
    _load();
  }

  void _proxyChanged() {
    if (_bytes == null) _load();
  }

  @override
  void didUpdateWidget(covariant OriginalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _bytes = null;
      _failed = false;
    });
    try {
      final response = await fetchImageResponse(_client, Uri.parse(widget.url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw const FormatException('Image request failed');
      }
      if (mounted && generation == _generation) {
        setState(() => _bytes = response.bodyBytes);
      }
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  Widget _error() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('图片加载失败'),
      IconButton(
        tooltip: '重试图片',
        onPressed: _load,
        icon: const Icon(Icons.refresh),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (_failed) return _error();
    if (_bytes == null) return const CircularProgressIndicator();
    return Image.memory(
      _bytes!,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _error(),
    );
  }

  @override
  void dispose() {
    _generation++;
    ProxySettingsService.instance.removeListener(_proxyChanged);
    if (widget.client == null) _client.close();
    super.dispose();
  }
}
