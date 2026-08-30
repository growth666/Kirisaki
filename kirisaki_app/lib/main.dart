import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  // 为后续轮次 shared_preferences / permission_handler 等插件初始化预留。
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KirisakiApp());
}
