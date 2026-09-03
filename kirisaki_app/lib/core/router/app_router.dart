import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/preview/presentation/pages/image_preview_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/source/presentation/pages/source_manage_page.dart';
import '../constants/app_constants.dart';
import '../source/image_item.dart';
import 'route_names.dart';

/// 全局路由实例。
final GoRouter appRouter = GoRouter(
  initialLocation: RouteNames.search,
  routes: <RouteBase>[
    GoRoute(
      path: RouteNames.search,
      name: 'search',
      builder: (BuildContext context, GoRouterState state) =>
          const SearchPage(),
    ),
    GoRoute(
      path: RouteNames.sources,
      name: 'sources',
      builder: (BuildContext context, GoRouterState state) =>
          const SourceManagePage(),
    ),
    GoRoute(
      path: RouteNames.preview,
      name: 'preview',
      builder: (BuildContext context, GoRouterState state) {
        // 优先取 extra 携带的完整 ImageItem（含标签）；
        // url 查询参数兼容保留（深链与旧调用方式）。
        final ImageItem? extraItem =
            state.extra is ImageItem ? state.extra! as ImageItem : null;
        return ImagePreviewPage(
          item: extraItem,
          imageUrl: state.uri.queryParameters[AppConstants.previewUrlParam],
        );
      },
    ),
  ],
);
