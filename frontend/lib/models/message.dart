class MessageModel {
  final String messageId;
  final String groupId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final String type;
  final String fileUrl;
  final String fileName;
  
  // Custom field to manage local Optimistic UI state
  final bool isSent;

  MessageModel({
    required this.messageId,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.type = 'text',
    this.fileUrl = '',
    this.fileName = '',
    this.isSent = true,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      messageId: json['messageId'] ?? '',
      groupId: json['groupId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      type: json['type'] ?? 'text',
      fileUrl: json['fileUrl'] ?? '',
      fileName: json['fileName'] ?? '',
      isSent: json['isSent'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'groupId': groupId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': type,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  MessageModel copyWith({
    String? messageId,
    String? groupId,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? timestamp,
    String? type,
    String? fileUrl,
    String? fileName,
    bool? isSent,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      isSent: isSent ?? this.isSent,
    );
  }
}
