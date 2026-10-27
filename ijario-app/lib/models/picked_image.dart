import 'dart:typed_data';

/// An image picked from the device/browser, held in memory as raw bytes
/// (works uniformly across web, mobile, and desktop) until it's uploaded.
class PickedImage {
  final Uint8List bytes;
  final String filename;

  PickedImage({required this.bytes, required this.filename});
}
