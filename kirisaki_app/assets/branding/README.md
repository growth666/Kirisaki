# Kirisaki

直接使用用户提供的图片制作图标，不重新绘制。原图为 3507 × 2480，按 1888 像素宽预览图中的 (480, 0) 到 (1400, 920) 比例截取方形区域，保留红色发饰、金发、面部和白裙上半身，保持原始比例和颜色。

- `source.png`：用户提供的原图，生成脚本的输入。
- `previous-silhouette.svg`：上一版剪影设计归档，不参与图标生成。
- `kirisaki.png`：1024 × 1024 不透明主图。
- `preview.png`：圆角预览。
- 背景为深灰色（#383838），人物使用原图配色。

运行 `python tool/generate_brand_icons.py` 可从 `source.png` 重新生成主图、预览及 Android、Windows、iOS、macOS、Web 图标，需要 Python 和 Pillow。Android 自适应图标使用位图前景并留出系统裁切空间。

Android 26+ 使用分层自适应图标，前景留有裁切安全区；旧版使用各密度 PNG。iOS 使用不透明方形图，由系统裁切。Windows ICO 包含 16、24、32、48、64、128、256 像素。Web 提供普通与 maskable 图标。Linux 本次更新窗口名称，未新增桌面安装器或图标注册流程。

应用显示名称统一为 `Kirisaki`；保留 Android applicationId 等既有应用标识，以便覆盖安装时沿用原数据。

原生名称与启动器图标需要重新构建、安装，热重载不会更新。桌面或启动器缓存旧图标时，先关闭应用并重新启动；不需要清除用户数据。
