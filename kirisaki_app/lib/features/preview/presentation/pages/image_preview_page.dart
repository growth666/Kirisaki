import 'package:flutter/material.dart';

/// 图片预览页（占位）。
///
/// 通过路由 `url` 查询参数接收图片地址。后续轮次在此渲染大图、
/// 手势缩放与保存到相册等操作。
class ImagePreviewPage extends StatelessWidget {
  const ImagePreviewPage({super.key, this.imageUrl});

  /// 图片地址（本轮仅展示以验证路由参数传递，不做网络加载）。
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('图片预览')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('图片预览功能开发中', style: theme.textTheme.titleMedium),
            if (imageUrl != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  imageUrl!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
