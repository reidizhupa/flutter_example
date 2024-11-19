import 'dart:io';
import 'dart:typed_data';

// https://github.com/dart-lang/mime/blob/master/lib/src/magic_number.dart
//https://www.garykessler.net/library/file_sigs.html
//https://en.wikipedia.org/wiki/List_of_file_signatures

/*
A magic number is a numeric or string constant that indicates the file type

WEBP magic number: [0x52, 0x49, 0x46, 0x46, ??, ??, ??, ??, 0x57, 0x45, 0x42, 0x50]
dove [??, ??, ??, ??] rappresenta la dimensione del file, ovvero questi byte sono dinamici e non statici
per questo motivo si utilizza la "mask", dove il valore 0xFF indica byte statico, mentre il valore 0x00 indica byte dinamico
*/
class MagicNumber {
  final Uint8List numbers;
  final Uint8List? mask;

  const MagicNumber(this.numbers, [this.mask]);
}

class FileSignature {
  final MagicNumber magicNumbers;
  final int offset; //In alcuni file la "signature" non si trova all'inizio del file

  const FileSignature(this.magicNumbers, [this.offset = 0]);
}

class FileType {
  final String mimeType;
  final List<String> extension;
  final FileSignature signature;
  final String? description;

  const FileType(this.mimeType, this.extension, this.signature, [this.description]);
}

class FileTypeManager {
  static String? getFileExtension(String filePath) {
    filePath = filePath.trim();
    if (!filePath.contains(".") || filePath.length < 2 || filePath.endsWith(".")) {
      return null;
    }
    return filePath.substring(filePath.lastIndexOf('.')).substring(1).toLowerCase();
  }

  static String getFileMimeType(String filePath) {
    filePath = filePath.trim();
    if (filePath.length < 2 || filePath.endsWith(".")) return "";
    Uint8List header = File(filePath).readAsBytesSync();
    header =
        Uint8List.fromList(header.take(64).toList()); //siccome devo controllare solo i primi byte, prendo una piccola porzione del file

    for (FileType fileType in _fileTypes) {
      bool trovato = true;
      int offset = fileType.signature.offset;
      int magicNumbersLength = fileType.signature.magicNumbers.numbers.length;
      Uint8List? mask = fileType.signature.magicNumbers.mask;
      Uint8List numbers = fileType.signature.magicNumbers.numbers;

      for (int i = offset; i < magicNumbersLength; i++) {
        if ((mask != null && (mask[i] & numbers[i]) != (mask[i] & header[i])) || (mask == null && numbers[i] != header[i])) {
          trovato = false;
          break;
        }
      }

      if (trovato) {
        return fileType.mimeType;
      }
    }

    return "";
  }
}

/*
image/jpg is not the same as image/jpeg. You should use image/jpeg. Only image/jpeg is recognised as the actual mime type for JPEG files.
*/
List<FileType> _fileTypes = [
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
