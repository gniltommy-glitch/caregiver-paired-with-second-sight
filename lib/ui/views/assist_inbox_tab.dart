import 'package:flutter/material.dart';

import '../../domain/models/caregiver_models.dart';
import '../core/caregiver_theme.dart';
import '../view_models/caregiver_view_model.dart';
import '../widgets/camera_scene_preview.dart';

class AssistInboxTab extends StatefulWidget {
  final CaregiverViewModel vm;

  const AssistInboxTab({super.key, required this.vm});

  @override
  State<AssistInboxTab> createState() => _AssistInboxTabState();
}

class _AssistInboxTabState extends State<AssistInboxTab> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  static const List<String> _quickReplies = <String>[
    'Đường phía trước thoáng, đi thẳng khoảng 5 mét.',
    'Dừng lại chờ một chút, còn xe đang chạy ngang.',
    'Bước chếch nhẹ sang bên phải, bên trái có xe đậu.',
    'Đúng biển trạm xe buýt / địa điểm cần tìm rồi.',
    'Đèn đi bộ đang đỏ, hãy đứng yên chờ đèn xanh.',
  ];

  TextEditingController _ctrlFor(String id) =>
      _controllers.putIfAbsent(id, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendReply(AssistRequest req, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await widget.vm.replyToAssistRequest(req.requestId, trimmed);
    _ctrlFor(req.requestId).clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: kCard2,
        content: Text(
          'Đã phát câu trả lời vào tai nghe kính của người dùng.',
          style: TextStyle(color: kText),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final items = vm.assistRequests;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        SpotlightCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Hỏi người thân qua ảnh tĩnh',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Khi VietOCR gặp biển mờ hoặc ngã tư phức tạp, ${vm.wearerName} gửi 1 tấm ảnh tĩnh từ kính. Câu trả lời của bạn được Piper/TTS đọc thẳng vào tai nghe.',
                      style: const TextStyle(fontSize: 12.5, color: kTextSub),
                    ),
                  ],
                ),
              ),
              if (vm.simulationMode) ...<Widget>[
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: kCard2,
                    foregroundColor: kAccent,
                  ),
                  onPressed: vm.triggerDemoAssistSnapshot,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Ảnh mẫu'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorder),
            ),
            child: const Column(
              children: <Widget>[
                Icon(Icons.photo_library_outlined, size: 40, color: kTextSub),
                SizedBox(height: 10),
                Text(
                  'Chưa có yêu cầu xem ảnh nào',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kText,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Khi người đeo kính nói "Aurelia, hỏi người thân", ảnh chụp tức thời sẽ xuất hiện tại đây.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: kTextSub),
                ),
              ],
            ),
          )
        else
          ...items.map((req) => _buildRequestCard(vm, req)),
      ],
    );
  }

  Widget _buildRequestCard(CaregiverViewModel vm, AssistRequest req) {
    final ctrl = _ctrlFor(req.requestId);
    final pending = req.isPending;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: pending ? kAccent.withValues(alpha: 0.55) : kBorder,
            width: pending ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                StatusPill(
                  label: pending ? 'CẦN PHẢN HỒI' : 'ĐÃ TRẢ LỜI VÀO KÍNH',
                  color: pending ? kWarning : kAccent,
                  icon: pending
                      ? Icons.mark_chat_unread_rounded
                      : Icons.check_circle_outline,
                ),
                Text(
                  formatRelativeTime(req.createdAt),
                  style: const TextStyle(fontSize: 12, color: kTextSub),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              req.question,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kText,
              ),
            ),
            if (req.contextNote.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                req.contextNote,
                style: const TextStyle(fontSize: 12, color: kTextSub),
              ),
            ],
            const SizedBox(height: 12),
            CameraScenePreview(
              capturedAt: req.createdAt,
              imageBase64: req.imageBase64,
              sceneKind: req.sceneKind,
              detections: req.detections,
              tofMinM: req.tofMinM,
            ),
            const SizedBox(height: 12),
            if (!pending && req.replyText != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kAccent.withValues(alpha: 0.30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Đã đọc qua tai nghe (${req.repliedBy ?? vm.caregiverName}):',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: kAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"${req.replyText}"',
                      style: const TextStyle(fontSize: 13.5, color: kText),
                    ),
                  ],
                ),
              )
            else ...<Widget>[
              const Text(
                'Chọn câu trả lời nhanh (1 chạm):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kTextSub,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickReplies
                    .map(
                      (preset) => ActionChip(
                        backgroundColor: kCard2,
                        side: BorderSide(
                          color: kAccent.withValues(alpha: 0.30),
                        ),
                        label: Text(
                          preset,
                          style: const TextStyle(fontSize: 12, color: kText),
                        ),
                        onPressed: () => _sendReply(req, preset),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      onSubmitted: (v) => _sendReply(req, v),
                      decoration: InputDecoration(
                        hintText: vm.isListeningVoice
                            ? 'Đang nghe giọng bạn...'
                            : 'Nhập hoặc bấm mic nói lời chỉ dẫn...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: vm.isListeningVoice
                          ? kDanger.withValues(alpha: 0.22)
                          : kCard2,
                      minimumSize: const Size(48, 48),
                    ),
                    tooltip: 'Nói để nhập lời chỉ dẫn',
                    onPressed: () => vm.toggleVoiceDictation((recognized) {
                      ctrl.text = recognized;
                    }),
                    icon: Icon(
                      vm.isListeningVoice
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      color: vm.isListeningVoice ? kDanger : kAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(56, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => _sendReply(req, ctrl.text),
                    child: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
