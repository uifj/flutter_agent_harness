/// 升级发布说明截图墙（legacy: cloudspace MultiImages 的通用化重写）。
///
/// 行为保真：纵向滚动 + 常显滚动条、首图就绪前显示整体 loading、
/// 每张图帧到达前占位（避免高度跳动）；URL 解析失败/空列表 → 占位文案。
/// 去宿主化改造：NetworkImageSSL(proxy) 收敛为 [imageProviderBuilder] 注入
/// （代理/证书策略属宿主网络栈），默认 [NetworkImage]。
library;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class UpgradeReleaseImages extends StatefulWidget {
  const UpgradeReleaseImages({
    super.key,
    required this.urls,
    this.imageProviderBuilder,
    this.emptyText = '数据获取失败，请稍后再试',
  });

  /// 截图 URL 列表（legacy: versionUrl 单串或 JSON 数组，解析由调用方完成）。
  final List<String> urls;

  /// 自定义图片源（宿主注入代理/自签证书加载器）；默认 [NetworkImage]。
  final ImageProvider<Object> Function(String url)? imageProviderBuilder;

  /// 空列表占位文案。
  final String emptyText;

  @override
  State<UpgradeReleaseImages> createState() => _UpgradeReleaseImagesState();
}

class _UpgradeReleaseImagesState extends State<UpgradeReleaseImages> {
  final ScrollController _scrollController = ScrollController();
  bool _firstFrameReady = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  ImageProvider<Object> _provider(String url) =>
      widget.imageProviderBuilder?.call(url) ?? NetworkImage(url);

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.maybeOf(context)?.colorScheme;
    final muted = cs?.mutedForeground ?? Theme.of(context).colorScheme.outline;

    if (widget.urls.isEmpty) {
      return Center(
        child: Text(widget.emptyText, style: TextStyle(color: muted)),
      );
    }

    return Stack(
      children: [
        Scrollbar(
          thumbVisibility: true,
          controller: _scrollController,
          radius: const Radius.circular(8),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                for (var i = 0; i < widget.urls.length; i++)
                  Image(
                    image: _provider(widget.urls[i]),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    frameBuilder: (context, child, frame, wasSync) {
                      if (frame == null) return const SizedBox.shrink();
                      // 首图帧到达 → 撤掉整体 loading（legacy 语义）。
                      if (i == 0 && !_firstFrameReady) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => _firstFrameReady = true);
                          }
                        });
                      }
                      return child;
                    },
                    errorBuilder: (context, error, stack) => const SizedBox(
                      height: 120,
                      child: Center(
                        child: Icon(LucideIcons.imageOff, size: 24),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!_firstFrameReady) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
