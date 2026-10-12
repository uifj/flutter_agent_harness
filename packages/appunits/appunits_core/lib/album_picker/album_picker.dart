import 'dart:ui';

import 'album_picker_platform.dart';

enum AlbumPickerMediaFilter {
  imageOnly,
  videoOnly,
  imageAndVideo,
}

enum AlbumMediaType {
  image,
  video,
}

enum AlbumPickerStyle {
  likeWeChat,
  likeWhatsApp,
}

enum AlbumPickerLanguage {
  system,
  en,
  zhHans,
  zhHant,
  ar,
}

enum AlbumPickerCompressQuality {
  standard,
  high,
}

class AlbumPickerTheme {
  final Color? primaryColor;
  final Color? backgroundColor;
  final Color? backgroundColorSecondary;
  final Color? textColor;
  final Color? textColorSecondary;
  final String? confirmButtonIconAsset;
  final double? bigFontSize;
  final double? normalFontSize;
  final double? smallFontSize;
  final double? bigRadius;
  final double? normalRadius;
  final double? smallRadius;

  const AlbumPickerTheme({
    this.primaryColor,
    this.backgroundColor,
    this.backgroundColorSecondary,
    this.textColor,
    this.textColorSecondary,
    this.confirmButtonIconAsset,
    this.bigFontSize,
    this.normalFontSize,
    this.smallFontSize,
    this.bigRadius,
    this.normalRadius,
    this.smallRadius,
  });
}

class AlbumMedia {
  final int id;
  final String uri;
  final AlbumMediaType mediaType;
  final String mediaPath;
  final String fileExtension;
  final int fileSize;
  final String? videoThumbnailPath;
  final int duration;

  AlbumMedia({
    required this.id,
    this.uri = '',
    required this.mediaType,
    this.mediaPath = '',
    this.fileExtension = '',
    this.fileSize = 0,
    this.videoThumbnailPath,
    this.duration = 0,
  });

  @override
  String toString() {
    return 'AlbumMedia(id: $id, uri: $uri, mediaType: $mediaType, mediaPath: $mediaPath, '
        'fileExtension: $fileExtension, fileSize: $fileSize, '
        'videoThumbnailPath: $videoThumbnailPath, duration: $duration)';
  }
}

class AlbumPickerConfig {
  final AlbumPickerMediaFilter? mediaFilter;
  final int? maxSelectionCount;
  final int? itemsPerRow;
  final bool? showsCameraItem;
  final AlbumPickerStyle? style;
  final AlbumPickerLanguage? language;
  final AlbumPickerCompressQuality? compressQuality;
  final int? maxVideoDurationInSeconds;
  final int? maxOutputFileSizeInMB;

  const AlbumPickerConfig({
    this.mediaFilter,
    this.maxSelectionCount,
    this.itemsPerRow,
    this.showsCameraItem,
    this.style,
    this.language,
    this.compressQuality,
    this.maxVideoDurationInSeconds,
    this.maxOutputFileSizeInMB,
  });
}

class AlbumPicker {
  static final AlbumPicker instance = AlbumPicker._internal();

  AlbumPicker._internal();

  /// Callbacks mirror native AlbumPickerDelegate / AlbumPickerListener:
  /// - [onPickConfirm]: User confirmed selection. Provides all selected media.
  /// - [onMediaProcessing]: A media item is being processed (export/compress).
  /// - [onMediaProcessed]: All media items have finished processing.
  /// - [onCancel]: User cancelled the picker.
  static Future<void> pickMedia({
    AlbumPickerConfig? config,
    AlbumPickerTheme? theme,
    Function(List<AlbumMedia> pickedAlbumMedias, String? textMessage)?
        onPickConfirm,
    Function(AlbumMedia albumMedia, double progress, bool error)?
        onMediaProcessing,
    Function()? onMediaProcessed,
    Function()? onCancel,
  }) async {
    return AlbumPickerPlatform.pickMediaNative(
      config: config,
      theme: theme,
      onPickConfirm: onPickConfirm,
      onMediaProcessing: onMediaProcessing,
      onMediaProcessed: onMediaProcessed,
      onCancel: onCancel,
    );
  }
}
