import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/favorite/presentation/pages/favorites_page.dart';
import '../../features/preview/presentation/pages/image_preview_page.dart';
import '../../features/profile/presentation/pages/browse_history_page.dart';
import '../../features/profile/presentation/pages/download_records_page.dart';
import '../../features/profile/presentation/pages/search_history_page.dart';
import '../../features/settings/presentation/pages/about_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/shell/presentation/pages/home_shell.dart';
import '../../features/source/presentation/pages/custom_sources_page.dart';
import '../../features/source/presentation/pages/source_import_page.dart';
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
          const HomeShell(),
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
    GoRoute(
      path: RouteNames.favorites,
      name: 'favorites',
      builder: (BuildContext context, GoRouterState state) =>
          const FavoritesPage(),
    ),
    GoRoute(
      path: RouteNames.sourceImport,
      name: 'sourceImport',
      builder: (BuildContext context, GoRouterState state) =>
          const SourceImportPage(),
    ),
    GoRoute(
      path: RouteNames.history,
      name: 'history',
      builder: (BuildContext context, GoRouterState state) =>
          const BrowseHistoryPage(),
    ),
    GoRoute(
      path: RouteNames.searchHistory,
      name: 'searchHistory',
      builder: (BuildContext context, GoRouterState state) =>
          const SearchHistoryPage(),
    ),
    GoRoute(
      path: RouteNames.downloads,
      name: 'downloads',
      builder: (BuildContext context, GoRouterState state) =>
          const DownloadRecordsPage(),
    ),
    GoRoute(
      path: RouteNames.mySources,
      name: 'mySources',
      builder: (BuildContext context, GoRouterState state) =>
          const CustomSourcesPage(),
    ),
    GoRoute(
      path: RouteNames.settings,
      name: 'settings',
      builder: (BuildContext context, GoRouterState state) =>
          const SettingsPage(),
    ),
    GoRoute(
      path: RouteNames.about,
      name: 'about',
      builder: (BuildContext context, GoRouterState state) =>
          const AboutPage(),
    ),
  ],
);
