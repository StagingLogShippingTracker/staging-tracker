import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_state.dart';

class PhotoPickerService {
  final _images = ImagePicker();

  Future<List<PhotoBytes>> pickFromGallery({int max = 8}) async {
    final files = await _images.pickMultiImage(imageQuality: 85);
    final out = <PhotoBytes>[];
    for (final f in files.take(max)) {
      final bytes = await f.readAsBytes();
      out.add((bytes: Uint8List.fromList(bytes), name: f.name));
    }
    return out;
  }

  Future<PhotoBytes?> captureCamera() async {
    final f = await _images.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (f == null) return null;
    final bytes = await f.readAsBytes();
    return (bytes: Uint8List.fromList(bytes), name: f.name);
  }

  /// Windows-friendly file dialog for images when camera is unavailable.
  Future<List<PhotoBytes>> pickFiles({int max = 8}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return const [];
    final out = <PhotoBytes>[];
    for (final f in result.files.take(max)) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      out.add((bytes: Uint8List.fromList(bytes), name: f.name));
    }
    return out;
  }

  Future<List<PhotoBytes>> pickPreferred() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return pickFiles();
    }
    return pickFromGallery();
  }
}
