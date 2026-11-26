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
    'Đường phía trước thoáng, đi thẳng 5 mét.',
    'Dừng lại chờ chút, còn xe đang đi ngang.',
    'Bước chếch sang phải, bên trái có xe đậu.',
    'Đúng trạm xe buýt cần tìm rồi.',
    'Đèn đi bộ đang đỏ, hãy chờ đèn xanh.',
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
        behavior: SnackBarBehavior.floating,
        backgroundColor: kInk,
        content: Text(
          'Đã đọc lời chỉ dẫn trực tiếp vào tai nghe kính.',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final items = vm.assistRequests;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        const SectionHeader(
          title: 'Hỏi người thân qua ảnh tĩnh',
          subtitle: 'Khi kính gặp biển báo mờ hoặc ngã tư đông xe, ảnh chụp sẽ hiển thị tại đây để bạn phản hồi bằng giọng nói.',
        ),
        if (items.isEmpty)
          SurfaceCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: kSurfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    size: 26,
                    color: kInkMuted,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chưa có yêu cầu xem ảnh',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Khi ${vm.wearerName} nói "Aurelia, hỏi người thân", ảnh chụp từ kính sẽ xuất hiện ngay tại đây.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: kInkSecondary),
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
      child: SurfaceCard(
        borderColor: pending ? kPrimary.withValues(alpha: 0.45) : kBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                StatusBadge(
                  label: pending ? 'Cần hỗ trợ' : 'Đã phản hồi',
                  textColor: pending ? kWarning : kSuccess,
                  bgColor: pending ? kWarningSoft : kSuccessSoft,
                  icon: pending
                      ? Icons.mark_chat_unread_outlined
                      : Icons.check_circle_outline_rounded,
                ),
                const Spacer(),
                Text(
                  formatRelativeTime(req.createdAt),
                  style: const TextStyle(fontSize: 12, color: kInkMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CameraScenePreview(
              capturedAt: req.createdAt,
              imageBase64: req.imageBase64,
              sceneKind: req.sceneKind,
              detections: req.detections,
              tofMinM: req.tofMinM,
              height: 215,
            ),
            const SizedBox(height: 14),
            // Bong bóng câu hỏi tự nhiên
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kSurfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    req.question,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: kInk,
                      height: 1.4,
                    ),
                  ),
                  if (req.contextNote.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      req.contextNote,
                      style: const TextStyle(fontSize: 12, color: kInkMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (!pending && req.replyText != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kPrimarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.volume_up_rounded,
                          size: 16,
                          color: kPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Đã phát qua tai nghe (${req.repliedBy ?? vm.caregiverName})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"${req.replyText}"',
                      style: const TextStyle(fontSize: 14, color: kInk),
                    ),
                  ],
                ),
              )
            else ...<Widget>[
              const Text(
                'Trả lời nhanh 1 chạm',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: kInkSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickReplies
                    .map(
                      (preset) => ActionChip(
                        label: Text(preset),
                        onPressed: () => _sendReply(req, preset),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      onSubmitted: (v) => _sendReply(req, v),
                      decoration: InputDecoration(
                        hintText: vm.isListeningVoice
                            ? 'Đang nghe giọng nói...'
                            : 'Nhập hoặc bấm mic nói lời chỉ dẫn...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: vm.isListeningVoice
                          ? kDangerSoft
                          : kSurfaceMuted,
                      foregroundColor: vm.isListeningVoice ? kDanger : kPrimary,
                      minimumSize: const Size(48, 48),
                    ),
                    tooltip: 'Nói để trả lời',
                    onPressed: () => vm.toggleVoiceDictation((recognized) {
                      ctrl.text = recognized;
                    }),
                    icon: Icon(
                      vm.isListeningVoice
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => _sendReply(req, ctrl.text),
                    child: const Icon(Icons.send_rounded, size: 19),
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
