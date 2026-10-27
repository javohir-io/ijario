import 'person.dart';

class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final int? propertyId;
  final String content;
  final bool isRead;
  final DateTime createdAt; // local time

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.propertyId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      senderId: json['sender_id'] as int,
      receiverId: json['receiver_id'] as int,
      propertyId: json['property_id'] as int?,
      content: json['content'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

class Conversation {
  final Person otherUser;
  final ChatMessage lastMessage;
  final int unreadCount;

  const Conversation({
    required this.otherUser,
    required this.lastMessage,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      otherUser: Person.fromJson(json['other_user'] as Map<String, dynamic>),
      lastMessage: ChatMessage.fromJson(json['last_message'] as Map<String, dynamic>),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
