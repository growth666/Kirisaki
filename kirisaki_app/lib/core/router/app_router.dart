import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/favorite/presentation/pages/favorites_page.dart';
import '../../features/preview/presentation/pages/image_preview_page.dart';
import '../../features/profile/presentation/pages/browse_history_page.dart';
import '../../features/profile/presentation/pages/content_display_page.dart';
import '../../features/profile/presentation/pages/download_records_page.dart';
import '../../features/profile/presentation/pages/search_history_page.dart';
import '../../features/settings/presentation/pages/about_page.dart';
import '../../features/settings/presentation/pages/contributors_page.dart';
import '../../features/settings/presentation/pages/proxy_settings_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/shell/presentation/pages/home_shell.dart';
import '../../features/source/presentation/pages/custom_sources_page.dart';
import '../../features/source/presentation/pages/source_import_page.dart';
import '../../features/source/presentation/pages/source_manage_page.dart';
import '../constants/app_constants.dart';
import '../source/image_item.dart';
import 'route_names.dart';
import 'transitions.dart';

/// 全局路由实例。
///
/// 转场：普通页面渐隐 200ms（fadePage）；预览页缩放+渐隐 200ms
/// （zoomFadePage），替代默认平台滑动转场。
final _routingConfig = ValueNotifier<RoutingConfig>(_buildRoutingConfig());

/// Refresh route definitions after hot reload without replacing the navigator.
void refreshAppRoutes() => _routingConfig.value = _buildRoutingConfig();

final GoRouter appRouter = GoRouter.routingConfig(
  initialLocation: RouteNames.search,
  routingConfig: _routingConfig,
);

RoutingConfig _buildRoutingConfig() => RoutingConfig(
  routes: <RouteBase>[
    GoRoute(
      path: RouteNames.contentDisplay,
      name: 'contentDisplay',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          fadePage(const ContentDisplayPage()),
    ),
    GoRoute(
      path: '/contributors',
      name: 'contributors',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          fadePage(const ContributorsPage()),
    ),
    GoRoute(
      path: RouteNames.search,
      name: 'search',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          fadePage(const HomeShell()),
    ),
    GoRoute(
      path: RouteNames.sources,
      name: 'sources',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          fadePage(const SourceManagePage()),
    ),
    GoRoute(
      path: RouteNames.preview,
      name: 'preview',
      pageBuilder: (BuildContext context, GoRouterState state) {
        // 优先取 extra 携带的完整 ImageItem（含标签）；
        // url 查询参数兼容保留（深链与旧调用方式）。
        final ImageItem? extraItem = state.extra is ImageItem
            ? state.extra! as ImageItem
            : null;
        return zoomFadePage(
          ImagePreviewPage(
            item: extraItem,
            imageUrl: state.uri.queryParameters[AppConstants.previewUrlParam],
          ),
        );
      },
    ),
    GoRoute(
      path: RouteNames.favorites,
      name: 'favorites',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          fadePage(const FavoritesPage()),
    ),
    GoRoute(
      path: RouteNames.sourceImport,
      name: 'sourceImport',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          fadePage(const SourceImportPage()),
    ),
    GoRoute(
      path: RouteNames.history,
      name: 'history',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          fadePage(const BrowseHistoryPage()),
    ),
    GoRoute(
      path: RouteNames.searchHistory,
      name: 'searchHistory',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          fadePage(const SearchHistoryPage()),
    ),
    GoRoute(
      path: RouteNames.downloads,
      name: 'downloads',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          fadePage(const DownloadRecordsPage()),
    ),
    GoRoute(
      path: RouteNames.mySources,
      name: 'mySources',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          fadePage(const CustomSourcesPage()),
    ),
    GoRoute(
      path: RouteNames.settings,
      name: 'settings',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          fadePage(const SettingsPage()),
    ),
    GoRoute(
      path: RouteNames.about,
      name: 'about',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          fadePage(const AboutPage()),
    ),
    GoRoute(
      path: RouteNames.proxy,
      name: 'proxy',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          fadePage(const ProxySettingsPage()),
    ),
  ],
);
