import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/preview/presentation/pages/image_preview_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/source/presentation/pages/source_manage_page.dart';
import '../constants/app_constants.dart';
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
      builder: (BuildContext context, GoRouterState state) => ImagePreviewPage(
        imageUrl: state.uri.queryParameters[AppConstants.previewUrlParam],
      ),
    ),
  ],
);
