import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/chat_message.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_store.dart';

/// Manages the live chat WebSocket connection plus cached conversation /
/// message state. REST endpoints (via [ApiClient]) back the same data for
/// initial loads and as a fallback when the socket isn't connected;
/// incoming/outgoing messages over the socket update this store's cache
/// directly so open chat screens update live without polling.
///
/// If the connection drops (phone sleeps, backend restarts) it reconnects
/// by itself with a growing delay, for as long as someone is signed in.
class ChatStore extends ChangeNotifier {
  ChatStore._();
  static final ChatStore instance = ChatStore._();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _wanted = false; // true while someone is signed in and the app wants a socket

  final Map<int, List<ChatMessage>> _messagesByUser = {};
  List<Conversation> conversations = [];
  bool loadingConversations = false;

  bool get isConnected => _channel != null;

  /// Messages I haven't read yet, across all conversations (tab badge).
  int get unreadTotal => conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

  void connect() {
    _wanted = true;
    if (_channel != null) return;
    _retryTimer?.cancel();
    try {
      final channel = WebSocketChannel.connect(ApiClient.instance.chatWebSocketUri);
      _channel = channel;
      _subscription = channel.stream.listen(
        _onData,
        onDone: _onClosed,
        onError: (_) => _onClosed(),
        cancelOnError: true,
      );
      _attempt = 0;
    } catch (_) {
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _onClosed() {
    _channel = null;
    _subscription = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_wanted) return;
    _retryTimer?.cancel();
    // 2s, 4s, 8s ... capped at 30s.
    final seconds = math.min(30, 2 << math.min(_attempt, 4));
    _attempt++;
    _retryTimer = Timer(Duration(seconds: seconds), () {
      if (_wanted && AuthStore.instance.isLoggedIn) connect();
    });
  }

  void disconnect() {
    _wanted = false;
    _retryTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscription = null;
    _messagesByUser.clear();
    conversations = [];
    notifyListeners();
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['type'] != 'message') return;

      final message = ChatMessage.fromJson(data);
      final myId = AuthStore.instance.currentUser?.id;
      if (myId == null) return;

      final otherId = message.senderId == myId ? message.receiverId : message.senderId;
      _appendMessage(otherId, message);
      loadConversations();
    } catch (_) {
      // Ignore malformed frames rather than crash the listener.
    }
  }

  void _appendMessage(int otherId, ChatMessage message) {
    final list = _messagesByUser.putIfAbsent(otherId, () => []);
    if (!list.any((m) => m.id == message.id)) {
      list.add(message);
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    notifyListeners();
  }

  List<ChatMessage> messagesFor(int otherUserId) =>
      List.unmodifiable(_messagesByUser[otherUserId] ?? const <ChatMessage>[]);

  /// Loads the history with one person. The server marks their messages as
  /// read, so the conversation list is refreshed afterwards to clear badges.
  Future<void> loadHistory(int otherUserId) async {
    try {
      final data = await ApiClient.instance.getConversationWith(otherUserId);
      _messagesByUser[otherUserId] =
          data.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
      loadConversations();
    } on ApiException {
      // Leave whatever was cached; the chat screen can retry via pull-to-refresh.
    }
  }

  Future<void> loadConversations() async {
    loadingConversations = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.listConversations();
      conversations = data.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      // Keep the previous list rather than clearing it on a transient failure.
    } finally {
      loadingConversations = false;
      notifyListeners();
    }
  }

  /// Sends over the live socket when connected (fastest, and the server's
  /// echo is what actually lands in the cache: see [_onData]); falls back
  /// to a plain REST call otherwise. Returns an error message or null.
  Future<String?> sendMessage({required int receiverId, required String content, int? propertyId}) async {
    final channel = _channel;
    if (channel != null) {
      channel.sink.add(jsonEncode({
        'receiver_id': receiverId,
        'content': content,
        if (propertyId != null) 'property_id': propertyId,
      }));
      return null;
    }

    try {
      final data = await ApiClient.instance.sendMessage(
        receiverId: receiverId,
        content: content,
        propertyId: propertyId,
      );
      _appendMessage(receiverId, ChatMessage.fromJson(data));
      loadConversations();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}
