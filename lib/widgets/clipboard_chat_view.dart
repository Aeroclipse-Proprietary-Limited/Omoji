import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:omoji/build_config.dart';
import 'package:omoji/models/chat_message.dart';
import 'package:omoji/models/quantum-network/quantum_network_service.dart';
import 'package:omoji/services/app_settings.dart';
import 'package:omoji/widgets/full_version_prompt.dart';

class ClipboardChatView extends StatefulWidget {
  final String initialPrompt;
  final List<ChatMessage> messages;
  final VoidCallback onBack;
  final VoidCallback onExport;
  final ValueChanged<bool> onAttachmentPickerChanged;
  final VoidCallback onPurchaseLicense;

  const ClipboardChatView({
    super.key,
    required this.initialPrompt,
    required this.messages,
    required this.onBack,
    required this.onExport,
    required this.onAttachmentPickerChanged,
    required this.onPurchaseLicense,
  });

  @override
  State<ClipboardChatView> createState() => _ClipboardChatViewState();
}

class _ClipboardChatViewState extends State<ClipboardChatView> {
  static const _quantumNetwork = QuantumNetworkService();
  late final TextEditingController _promptController;
  final List<QuantumAttachment> _attachments = [];
  bool _isAttachmentMenuHovered = false;

  bool _superAgentsEnabled = false;
  String _superAgentModelType = 'local';
  String _superAgentCloudProvider = 'OpenAI';
  String _superAgentApiKey = '';
  String _superAgentRequestyModel = 'gemma-4-31b-it';
  int? _googleGemmaCooldownUntilMs;
  bool _isSending = false;
  int _sessionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.initialPrompt);
    _loadSuperAgentSettings();
  }

  Future<void> _loadSuperAgentSettings() async {
    final settings = await AppSettings.loadSettings();
    if (!mounted) return;
    setState(() {
      _superAgentsEnabled = settings['superAgentsEnabled'] as bool? ?? false;
      _superAgentModelType =
          settings['superAgentModelType'] as String? ?? 'local';
      _superAgentCloudProvider =
          settings['superAgentCloudProvider'] as String? ?? 'OpenAI';
      _superAgentApiKey = settings['superAgentApiKey'] as String? ?? '';
      _superAgentRequestyModel =
          settings['superAgentRequestyModel'] as String? ?? 'gemma-4-31b-it';
      _googleGemmaCooldownUntilMs =
          settings['superAgentModelCooldownUntilMs'] as int?;
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (!isDeveloperBuild) {
      final wantsLicense = await showFullVersionPrompt(
        context,
        feature: 'File attachments',
      );
      if (wantsLicense && mounted) widget.onPurchaseLicense();
      return;
    }
    widget.onAttachmentPickerChanged(true);
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
    } finally {
      widget.onAttachmentPickerChanged(false);
    }
  }

  void _showUnavailableAttachment(String kind) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$kind attachments are not integrated yet.')),
    );
  }

  Future<void> _sendMessage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    if (_superAgentsEnabled &&
        _superAgentModelType == 'cloud' &&
        _superAgentApiKey.isEmpty) {
      _appendOmojiReply(
        prompt,
        'I can’t reach my cloud chat yet because there’s no API key saved. Add your ${_providerDisplayName} key in Settings, then try again.',
      );
      return;
    }

    final useCloud = _superAgentsEnabled && _superAgentModelType == 'cloud';
    if (useCloud &&
        _superAgentCloudProvider == 'Gemini' &&
        _googleGemmaCooldownUntilMs != null &&
        _googleGemmaCooldownUntilMs! > DateTime.now().millisecondsSinceEpoch) {
      _appendOmojiReply(
        prompt,
        'Something doesnt seem right with Google. Your time is too precious so I stopped waiting for a responce, I recommend coming back after an hour',
      );
      return;
    }
    if (useCloud && _attachments.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cloud text chat does not support attachments yet.'),
        ),
      );
      return;
    }
    if (useCloud &&
        _superAgentCloudProvider != 'DeepSeek' &&
        _superAgentCloudProvider != 'Gemini' &&
        _superAgentCloudProvider != 'Requesty') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google AI Studio, DeepSeek, and Requesty chat are available so far.'),
        ),
      );
      return;
    }
    if (!useCloud && !_quantumNetwork.isAvailable) return;

    final attachments = List<QuantumAttachment>.unmodifiable(_attachments);
    final requestSession = _sessionGeneration;
    setState(() {
      widget.messages.add(ChatMessage(role: ChatRole.user, text: prompt));
      _promptController.clear();
      _attachments.clear();
      _isSending = true;
    });

    try {
      final String reply;
      if (useCloud) {
        reply = await _requestCloudReply();
      } else {
        reply = await _quantumNetwork.generateReply(
          prompt: prompt,
          attachments: attachments,
        );
      }
      if (!mounted || requestSession != _sessionGeneration) return;
      setState(() {
        widget.messages.add(ChatMessage(role: ChatRole.assistant, text: reply));
        _isSending = false;
      });
    } catch (error) {
      if (!mounted || requestSession != _sessionGeneration) return;
      if (_shouldCooldownGoogleModel(error)) {
        final cooldownUntil = DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch;
        await AppSettings.saveSettings(
          superAgentModelOnCooldown: 'Gemma 4 31B IT (Google AI Studio)',
          superAgentModelCooldownUntilMs: cooldownUntil,
        );
        if (!mounted) return;
        _googleGemmaCooldownUntilMs = cooldownUntil;
      }
      setState(() {
        widget.messages.add(
          ChatMessage(
            role: ChatRole.assistant,
            text: _friendlyError(error, useCloud: useCloud),
          ),
        );
        _isSending = false;
      });
    }
  }

  void _appendOmojiReply(String prompt, String text) {
    setState(() {
      widget.messages.add(ChatMessage(role: ChatRole.user, text: prompt));
      widget.messages.add(ChatMessage(role: ChatRole.assistant, text: text));
      _promptController.clear();
    });
  }

  String _friendlyError(Object error, {required bool useCloud}) {
    final provider = useCloud ? _providerDisplayName : 'local chat';
    final detail = error.toString().toLowerCase();
    if (error is SocketException ||
        error is HandshakeException ||
        detail.contains('socketexception') ||
        detail.contains('failed host lookup')) {
      return 'I can’t reach $provider right now. Please check your internet connection and try again.';
    }
    if (_shouldCooldownGoogleModel(error)) {
      return 'Something doesnt seem right with Google. Your time is too precious so I stopped waiting for a responce, I recommend coming back after an hour';
    }
    if (error is TimeoutException || detail.contains('timed out')) {
      return 'I’m taking too long to get a reply from $provider. I stopped waiting after 18 seconds; please try again.';
    }
    if (detail.contains('high demand') ||
        detail.contains('overloaded') ||
        detail.contains('503')) {
      return '$provider is busy right now because demand is high. Your key appears to be reaching the service; please try again in a little while.';
    }
    if (detail.contains('credit') ||
        detail.contains('balance') ||
        detail.contains('quota') ||
        detail.contains('insufficient')) {
      return 'I couldn’t answer because the $provider account appears to be out of credits or quota. Please check its balance, then try again.';
    }
    if (detail.contains('401') ||
        detail.contains('403') ||
        detail.contains('invalid api key') ||
        detail.contains('authentication')) {
      return 'I couldn’t sign in to $provider with the saved API key. Please check the key in Settings and try again.';
    }
    return 'I’m having trouble getting a reply from $provider right now. Please try again. (Details: ${error.toString().replaceFirst('Exception: ', '')})';
  }

  bool _shouldCooldownGoogleModel(Object error) {
    if (_superAgentCloudProvider != 'Gemini') return false;
    final detail = error.toString().toLowerCase();
    return error is TimeoutException ||
        detail.contains('high demand') ||
        detail.contains('overloaded') ||
        detail.contains('503');
  }

  String get _providerDisplayName => switch (_superAgentCloudProvider) {
    'Gemini' => 'Gemma 4 31B IT (Google AI Studio)',
    'Requesty' => 'Requesty ($_superAgentRequestyModel)',
    _ => 'DeepSeek',
  };

  void _startNewSession() {
    _sessionGeneration++;
    setState(() {
      widget.messages.clear();
      _attachments.clear();
      _promptController.clear();
      _isSending = false;
    });
  }

  Future<String> _requestCloudReply() async {
    final isGoogleAiStudio = _superAgentCloudProvider == 'Gemini';
    final isRequesty = _superAgentCloudProvider == 'Requesty';
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      return await _performCloudRequest(
        client,
        isGoogleAiStudio,
        isRequesty,
      ).timeout(
        const Duration(seconds: 18),
        onTimeout: () {
          client.close(force: true);
          throw TimeoutException(
            'The chat request took longer than 18 seconds.',
          );
        },
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _performCloudRequest(
    HttpClient client,
    bool isGoogleAiStudio,
    bool isRequesty,
  ) async {
    final request = await client.postUrl(
      isGoogleAiStudio
          ? Uri.https(
              'generativelanguage.googleapis.com',
              '/v1beta/models/gemma-4-31b-it:generateContent',
            )
          : Uri.https(
              isRequesty ? 'router.requesty.ai' : 'api.deepseek.com',
              isRequesty ? '/v1/chat/completions' : '/chat/completions',
            ),
    );
    request.headers.contentType = ContentType.json;
    if (isGoogleAiStudio) {
      request.headers.set('x-goog-api-key', _superAgentApiKey);
      request.write(jsonEncode({
        'contents': [
          for (final message in widget.messages)
            {
              'role': message.role == ChatRole.user ? 'user' : 'model',
              'parts': [
                {'text': message.text},
              ],
            },
        ],
        'generationConfig': {'maxOutputTokens': 512},
      }));
    } else {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $_superAgentApiKey',
      );
      request.write(jsonEncode({
        'model': isRequesty ? _superAgentRequestyModel : 'deepseek-chat',
        'messages': [
          for (final message in widget.messages)
            {
              'role': message.role == ChatRole.user ? 'user' : 'assistant',
              'content': message.text,
            },
        ],
        'stream': false,
        'max_tokens': 512,
      }));
    }
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['error'] is Map
          ? (decoded['error']['message'] as String? ?? 'Request failed')
          : 'HTTP ${response.statusCode}';
      throw HttpException('$_superAgentCloudProvider: $message');
    }
    final dynamic content;
    if (isGoogleAiStudio) {
      final candidates = decoded is Map ? decoded['candidates'] : null;
      if (candidates is! List || candidates.isEmpty) {
        throw const FormatException(
          'Google AI Studio returned an empty response.',
        );
      }
      final parts = candidates[0]['content']['parts'];
      content = parts is List
          ? parts
                .whereType<Map>()
                .map((part) => part['text'])
                .whereType<String>()
                .join()
          : null;
    } else {
      if (decoded is! Map ||
          decoded['choices'] is! List ||
          (decoded['choices'] as List).isEmpty) {
        throw FormatException(
          '$_providerDisplayName returned an empty response.',
        );
      }
      content = decoded['choices'][0]['message']['content'];
    }
    if (content is! String || content.trim().isEmpty) {
      throw FormatException(
        '$_superAgentCloudProvider returned an empty response.',
      );
    }
    return content.trim();
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
              onPressed: _startNewSession,
              icon: const Icon(Icons.add_comment_outlined),
            ),
            IconButton(
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
                  itemCount: widget.messages.length + (_isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isSending && index == widget.messages.length) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: textColor.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Omoji is thinking…',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
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
                  _superAgentsEnabled
                      ? (_superAgentModelType == 'cloud'
                            ? 'Cloud chat uses $_providerDisplayName. Messages are sent to that provider.'
                            : 'Local Omoji chat is selected.')
                      : (_quantumNetwork.isAvailable
                            ? 'Chat is processed locally and is not saved automatically.'
                            : 'Quantum Network model integration is pending. Prompts and attachments are not sent or stored.'),
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
                              tooltip: isDeveloperBuild
                                  ? 'Attach file'
                                  : 'Purchase a license to attach files',
                              icon: const Icon(Icons.attach_file_rounded),
                              onPressed: _pickFile,
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
              onPressed: !_isSending &&
                      _promptController.text.trim().isNotEmpty &&
                      ((_superAgentsEnabled && _superAgentModelType == 'cloud') ||
                          _quantumNetwork.isAvailable)
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
