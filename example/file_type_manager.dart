import 'dart:io';
import 'dart:typed_data';

/// This implementation identifies file types based on their "magic numbers"—unique byte patterns that appear at the start of files.
/// The `MagicNumber` class defines these patterns along with optional masks for dynamic bytes.
/// `FileTypeManager` provides utility methods to extract file extensions and MIME types.
///
/// **Key Features:**
/// 1. Recognizes common file types (e.g., JPEG, PNG, WebP).
/// 2. Supports identifying file signatures even with dynamic byte regions using masks.
/// 3. Efficiently checks file headers to determine MIME types without reading the full file.
///
/// Example:
/// ```dart
/// String mimeType = FileTypeManager.getFileMimeType("example.png");
/// print(mimeType); // Outputs: "image/png"
/// ```

class MagicNumber {
  final Uint8List numbers; // Defines the static byte pattern.
  final Uint8List? mask; // Specifies dynamic byte regions (0x00 for dynamic, 0xFF for static).

  const MagicNumber(this.numbers, [this.mask]);
}

class FileSignature {
  final MagicNumber magicNumbers; // Magic numbers associated with the file type.
  final int offset; // Byte offset where the signature starts.

  const FileSignature(this.magicNumbers, [this.offset = 0]);
}

class FileType {
  final String mimeType; // MIME type (e.g., "image/jpeg").
  final List<String> extension; // Supported file extensions.
  final FileSignature signature; // File signature for validation.
  final String? description; // Optional description of the file type.

  const FileType(this.mimeType, this.extension, this.signature, [this.description]);
}

class FileTypeManager {
  /// Extracts the file extension from a given file path.
  static String? getFileExtension(String filePath) {
    filePath = filePath.trim();
    if (!filePath.contains(".") || filePath.length < 2 || filePath.endsWith(".")) return null;
    return filePath.substring(filePath.lastIndexOf('.')).substring(1).toLowerCase();
  }

  /// Determines the MIME type of a file by reading its header and comparing it with known signatures.
  static String getFileMimeType(String filePath) {
    filePath = filePath.trim();
    if (filePath.length < 2 || filePath.endsWith(".")) return "";

    Uint8List header = File(filePath).readAsBytesSync();
    header = Uint8List.fromList(header.take(64).toList()); // Read only the first 64 bytes.

    for (FileType fileType in _fileTypes) {
      bool match = true;
      int offset = fileType.signature.offset;
      int length = fileType.signature.magicNumbers.numbers.length;
      Uint8List? mask = fileType.signature.magicNumbers.mask;
      Uint8List numbers = fileType.signature.magicNumbers.numbers;

      for (int i = 0; i < length; i++) {
        int index = offset + i;
        if (index >= header.length) {
          match = false;
          break;
        }
        if (mask != null && (mask[i] & numbers[i]) != (mask[i] & header[index]) || mask == null && numbers[i] != header[index]) {
          match = false;
          break;
        }
      }

      if (match) return fileType.mimeType;
    }
    return "";
  }
}

/// Predefined file types with their respective magic numbers and optional masks.
final List<FileType> _fileTypes = [
  FileType("image/jpeg", ["jpeg", "jpg"], FileSignature(MagicNumber(Uint8List.fromList([0xFF, 0xD8])))),
  FileType("image/png", ["png"], FileSignature(MagicNumber(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])))),
  FileType(
    "image/webp",
    ["webp"],
    FileSignature(
      MagicNumber(
        Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50]),
        Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF]),
      ),
    ),
  ),
];
