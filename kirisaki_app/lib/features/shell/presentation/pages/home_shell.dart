import 'package:flutter/material.dart';

import '../../../../core/profile/search_history_service.dart';
import '../../../favorite/presentation/pages/favorites_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../search/presentation/pages/search_page.dart';

/// 主页外壳：底部导航 + PageView 承载三个 tab（主页/收藏/我的）。
///
/// 子页各自混入 AutomaticKeepAliveClientMixin 保活——
/// 切换 tab 不重建页面、不丢失滚动位置。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // 搜索历史页点击条目快速搜索 → 自动切回主页 tab。
    SearchHistoryService.instance.addListener(_onHistoryQuickSearch);
  }

  @override
  void dispose() {
    SearchHistoryService.instance.removeListener(_onHistoryQuickSearch);
    _pageController.dispose();
    super.dispose();
  }

  void _onHistoryQuickSearch() {
    if (SearchHistoryService.instance.selectedKeyword == null) {
      return;
    }
    if (_currentIndex != 0) {
      _switchTab(0);
    }
  }

  void _switchTab(int index) {
    // PageView 物理不可滑动，仅由底部导航切换页面。
    _pageController.jumpToPage(index);
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const <Widget>[
          SearchPage(),
          FavoritesPage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _switchTab,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '主页'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: '收藏',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
