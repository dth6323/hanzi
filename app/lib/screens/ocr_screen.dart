import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/dict_db.dart';
import '../data/models.dart';
import '../data/text_utils.dart';
import '../services/ocr_service.dart';
import '../services/speaker.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'char_screen.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final _textCtrl = TextEditingController();
  Uint8List? _imageBytes;
  bool _busy = false;
  String? _statusMsg;
  List<Word> _words = [];
  List<String> _chars = [];

  Future<void> _analyzeText(String raw) async {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) {
      setState(() {
        _words = [];
        _chars = [];
      });
      return;
    }
    final words = await DictDb.instance.segmentChineseText(cleaned);
    final chars = cjkChars(cleaned);
    if (mounted) {
      setState(() {
        _words = words;
        _chars = chars;
      });
    }
  }

  Future<void> _runSource(Future<OcrCaptureResult?> Function() action,
      String loadingLabel) async {
    setState(() {
      _busy = true;
      _statusMsg = loadingLabel;
    });
    try {
      final res = await action();
      if (!mounted) return;
      if (res != null) {
        _imageBytes = res.imageBytes;
        _textCtrl.text = res.text;
        await _analyzeText(res.text);
        setState(() {
          _busy = false;
          _statusMsg = res.text.trim().isEmpty
              ? 'Không phát hiện chữ Hán rõ ràng trong ảnh. Bạn có thể chụp lại hoặc gõ/dán trực tiếp vào ô bên dưới.'
              : null;
        });
      } else {
        setState(() {
          _busy = false;
          _statusMsg = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        setState(() {
          _busy = false;
          _statusMsg = errStr.contains('CANCELLED') ? null : 'Lỗi quét ảnh: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLinuxDesktop =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét ảnh & Tách từ OCR'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn nguồn ảnh có chữ Hán',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  isLinuxDesktop
                      ? 'Bấm "Chụp vùng màn hình" rồi kéo chuột khoanh vùng chữ Trung trên màn hình, hoặc chọn file ảnh.'
                      : 'Chụp trực tiếp từ Camera hoặc chọn ảnh / ảnh chụp màn hình trong máy.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _runSource(
                                OcrService.instance.scanFromCamera,
                                isLinuxDesktop
                                    ? 'Hãy dùng chuột khoanh vùng màn hình cần quét…'
                                    : 'Đang mở Camera & nhận diện chữ Hán…',
                              ),
                      icon: Icon(isLinuxDesktop
                          ? Icons.crop_free_rounded
                          : Icons.camera_alt_rounded),
                      label: Text(isLinuxDesktop
                          ? 'Chụp vùng màn hình'
                          : 'Chụp Camera'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _runSource(
                                OcrService.instance.scanFromGallery,
                                'Đang đọc ảnh & nhận diện chữ Hán…',
                              ),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Chọn ảnh / Ảnh chụp màn hình'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            if (_statusMsg != null) ...[
              const SizedBox(height: 10),
              Text(
                _statusMsg!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.gold),
              ),
            ],
          ] else if (_statusMsg != null) ...[
            const SizedBox(height: 12),
            Text(
              _statusMsg!,
              style: const TextStyle(color: AppColors.gold, fontSize: 13),
            ),
          ],
          if (_imageBytes != null) ...[
            const SectionTitle('Ảnh đã chụp'),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: Image.memory(_imageBytes!, fit: BoxFit.contain),
              ),
            ),
          ],
          const SectionTitle('Văn bản nhận diện được'),
          TextField(
            controller: _textCtrl,
            maxLines: 3,
            onChanged: _analyzeText,
            decoration: InputDecoration(
              hintText:
                  'Văn bản chữ Hán sau khi quét sẽ hiện ở đây (hoặc dán đoạn văn cần tách từ vào đây)…',
              suffixIcon: _textCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Đọc cả câu',
                      icon: const Icon(Icons.volume_up_rounded,
                          color: AppColors.gold),
                      onPressed: () => Speaker.instance.speak(_textCtrl.text),
                    ),
            ),
          ),
          if (_words.isNotEmpty) ...[
            const SectionTitle('Từ vựng tách được (Bấm để tra)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in _words)
                  ActionChip(
                    label: Text(
                      '${w.simp} (${w.pinyin})',
                      style: const TextStyle(fontSize: 15),
                    ),
                    onPressed: () => Speaker.instance.speak(w.simp),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _words.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 16),
                    WordTile.fromWord(_words[i]),
                  ],
                ],
              ),
            ),
          ],
          if (_chars.isNotEmpty) ...[
            const SectionTitle('Từng chữ Hán trong ảnh'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _chars)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CharScreen(char: c)),
                    ),
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        c,
                        style: const TextStyle(
                            fontSize: 28, color: AppColors.ink),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
