import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 渐隐式页面转场（200ms，替代默认平台滑动转场，降低渲染压力）。
CustomTransitionPage<void> fadePage(Widget child) {
  return CustomTransitionPage<void>(
    transitionDuration: const Duration(milliseconds: 200),
    child: child,
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          return FadeTransition(opacity: animation, child: child);
        },
  );
}

/// 缩放 + 渐隐式转场（200ms，预览页跳转用）。
CustomTransitionPage<void> zoomFadePage(Widget child) {
  return CustomTransitionPage<void>(
    transitionDuration: const Duration(milliseconds: 200),
    child: child,
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
  );
}

/// 我的页面内部入口使用的轻量滑入转场，方向与层级一致，
/// 比整页缩放更接近原生导航，也不会影响底部主导航切换。
CustomTransitionPage<void> profilePage(Widget child) {
  return CustomTransitionPage<void>(
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    child: child,
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
  );
}
