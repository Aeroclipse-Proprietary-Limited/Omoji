enum QuantumAttachmentType { file, image, audio }

class QuantumAttachment {
  final String path;
  final String name;
  final QuantumAttachmentType type;

  const QuantumAttachment({
    required this.path,
    required this.name,
    required this.type,
  });
}

class QuantumNetworkService {
  const QuantumNetworkService();

  bool get isAvailable => false;

  Future<String> generateReply({
    required String prompt,
    List<QuantumAttachment> attachments = const [],
  }) {
    throw StateError(
      'Quantum Network model integration has not been implemented yet.',
    );
  }
}
