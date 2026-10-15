import 'dart:typed_data';

class MultimediaDraftFile {
  final String fileName;
  final Uint8List bytes;
  final bool fromOriginalZip;

  MultimediaDraftFile({
    required this.fileName,
    required this.bytes,
    this.fromOriginalZip = false,
  });
}

class MultimediaLessonDraft {
  final String lessonId;
  final String folderName;

  final Map<String, MultimediaDraftFile> files = {};

  MultimediaLessonDraft({
    required this.lessonId,
    required this.folderName,
  });

  bool hasFile(String fileName) {
    return files.containsKey(fileName);
  }

  MultimediaDraftFile? getFile(String fileName) {
    return files[fileName];
  }

  void addOrReplaceFile(
    String fileName,
    Uint8List bytes, {
    bool fromOriginalZip = false,
  }) {
    files[fileName] = MultimediaDraftFile(
      fileName: fileName,
      bytes: bytes,
      fromOriginalZip: fromOriginalZip,
    );
  }

  void removeFile(String fileName) {
    files.remove(fileName);
  }
}

class MultimediaImportDraftService {

  List<String> getFileNames(String lessonId) {
    return _drafts[lessonId]?.files.keys.toList() ?? [];
  }
  
  static final MultimediaImportDraftService instance =
      MultimediaImportDraftService._internal();

  MultimediaImportDraftService._internal();

  final Map<String, MultimediaLessonDraft> _drafts = {};

  void clear() {
    _drafts.clear();
  }

  void createLessonDraft({
    required String lessonId,
    required String folderName,
  }) {
    _drafts.putIfAbsent(
      lessonId,
      () => MultimediaLessonDraft(
        lessonId: lessonId,
        folderName: folderName,
      ),
    );
  }

  MultimediaLessonDraft? getLessonDraft(String lessonId) {
    return _drafts[lessonId];
  }

  List<MultimediaLessonDraft> get allDrafts {
    return _drafts.values.toList();
  }

  void addOrReplaceFile({
    required String lessonId,
    required String fileName,
    required Uint8List bytes,
    bool fromOriginalZip = false,
  }) {
    final draft = _drafts[lessonId];

    if (draft == null) {
      throw Exception(
        'No existe un borrador para la lección $lessonId',
      );
    }

    draft.addOrReplaceFile(
      fileName,
      bytes,
      fromOriginalZip: fromOriginalZip,
    );
  }

  void removeFile({
    required String lessonId,
    required String fileName,
  }) {
    _drafts[lessonId]?.removeFile(fileName);
  }

  bool hasFile({
    required String lessonId,
    required String fileName,
  }) {
    return _drafts[lessonId]?.hasFile(fileName) ?? false;
  }

  Uint8List? getFile({
    required String lessonId,
    required String fileName,
  }) {
    return _drafts[lessonId]?.getFile(fileName)?.bytes;
  }
}