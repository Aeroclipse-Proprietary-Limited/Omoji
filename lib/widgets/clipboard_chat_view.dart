import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:omoji/models/chat_message.dart';
import 'package:omoji/models/quantum-network/quantum_network_service.dart';

class ClipboardChatView extends StatefulWidget {
  final String initialPrompt;
  final List<ChatMessage> messages;
  final VoidCallback onBack;
  final VoidCallback onExport;

  const ClipboardChatView({
    super.key,
    required this.initialPrompt,
    required this.messages,
    required this.onBack,
    required this.onExport,
  });

  @override
  State<ClipboardChatView> createState() => _ClipboardChatViewState();
}

class _ClipboardChatViewState extends State<ClipboardChatView> {
  static const _quantumNetwork = QuantumNetworkService();
  late final TextEditingController _promptController;
  final List<QuantumAttachment> _attachments = [];
  bool _isAttachmentMenuHovered = false;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.initialPrompt);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final file = await openFile();
      if (file == null || !mounted) return;
      setState(() {
        _attachments.add(
          QuantumAttachment(
            path: file.path,
            name: file.name,
            type: QuantumAttachmentType.file,
          ),
        );
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach file: $error')),
        );
      }
    }
  }

  void _showUnavailableAttachment(String kind) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$kind attachments are not integrated yet.')),
    );
  }

  Future<void> _sendMessage() async {
    final prompt = _promptController.text.trim();
    if (!_quantumNetwork.isAvailable || prompt.isEmpty) return;

    final attachments = List<QuantumAttachment>.unmodifiable(_attachments);
    setState(() {
      widget.messages.add(ChatMessage(role: ChatRole.user, text: prompt));
      _promptController.clear();
      _attachments.clear();
    });

    try {
      final reply = await _quantumNetwork.generateReply(
        prompt: prompt,
        attachments: attachments,
      );
      if (!mounted) return;
      setState(() {
        widget.messages.add(ChatMessage(role: ChatRole.assistant, text: reply));
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get a response from Omoji: $error'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back to clipboard',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                'Chat with Omoji',
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Export chat as text',
              onPressed: widget.messages.isEmpty ? null : widget.onExport,
              icon: const Icon(Icons.save_alt_rounded),
            ),
          ],
        ),
        Expanded(
          child: widget.messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 34,
                          color: accentColor.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your chat is temporary',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Chats are not saved automatically. Export a chat '
                          'as a text file if you want to keep it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.messages.length,
                  itemBuilder: (context, index) {
                    final message = widget.messages[index];
                    final isUser = message.role == ChatRole.user;
                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? accentColor.withValues(alpha: 0.18)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(color: textColor, fontSize: 13),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Colors.amber,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _quantumNetwork.isAvailable
                      ? 'Chat is processed locally and is not saved '
                            'automatically.'
                      : 'Quantum Network model integration is pending. '
                            'Prompts and attachments are not sent or stored.',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var index = 0; index < _attachments.length; index++)
                    InputChip(
                      avatar: Icon(
                        _attachments[index].type == QuantumAttachmentType.image
                            ? Icons.image_outlined
                            : Icons.attach_file_rounded,
                        size: 15,
                      ),
                      label: Text(
                        _attachments[index].name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: () {
                        setState(() => _attachments.removeAt(index));
                      },
                    ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    MouseRegion(
                      onEnter: (_) =>
                          setState(() => _isAttachmentMenuHovered = true),
                      onExit: (_) =>
                          setState(() => _isAttachmentMenuHovered = false),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Attach file',
                              onPressed: _pickFile,
                              icon: const Icon(Icons.attach_file_rounded),
                            ),
                            if (_isAttachmentMenuHovered) ...[
                              IconButton(
                                tooltip: 'Attach photo (not available yet)',
                                onPressed: () =>
                                    _showUnavailableAttachment('Camera'),
                                icon: const Icon(Icons.camera_alt_outlined),
                              ),
                              IconButton(
                                tooltip: 'Record audio (not available yet)',
                                onPressed: () =>
                                    _showUnavailableAttachment('Audio'),
                                icon: const Icon(Icons.mic_none_rounded),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: textColor, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Ask Omoji...',
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: _quantumNetwork.isAvailable
                  ? 'Send message'
                  : 'Send (unavailable)',
              onPressed:
                  _quantumNetwork.isAvailable &&
                      _promptController.text.trim().isNotEmpty
                  ? _sendMessage
                  : null,
              icon: const Icon(Icons.send_rounded, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}
