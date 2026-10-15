/// Модели UI — чистые данные без зависимостей от Flutter
/// (нужны и в воркер-изоляте, и в тестах на чистом Dart).
library;

enum MessageKind { date, unreadDivider, text, image, video, quote, voice, document, audio }

class TgUser {
  const TgUser({
    required this.id,
    required this.firstName,
    this.lastName = '',
    this.username = '',
    this.phoneNumber = '',
    this.avatarEmoji = '👤',
    this.avatarColor = 0xFF766AC8,
    this.avatarPath = '',
    this.bio = 'Ai',
  });

  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String phoneNumber;
  final String avatarEmoji;
  final int avatarColor;
  final String avatarPath;
  final String bio;

  String get fullName =>
      lastName.isEmpty ? firstName : '$firstName $lastName';
}

class TgMessage {
  const TgMessage({
    this.id = 0,
    required this.kind,
    this.text = '',
    this.time = '',
    this.outgoing = false,
    this.read = true,
    this.mediaPath = '',
    this.thumbnailPath = '',
    this.duration = 0,
    this.fileName = '',
    this.fileSize = '',
    this.fileId = 0,
    this.thumbFileId = 0,
    this.width = 0,
    this.height = 0,
    this.isDownloading = false,
    this.isDownloaded = false,
    this.replyToMessageId = 0,
    this.replySenderName = '',
    this.replyText = '',
    this.replyThumbnailPath = '',
    this.replyKind,
    this.senderName = '',
    this.senderUserId = 0,
  });

  final int id;
  final MessageKind kind;
  final String text;
  final String time;
  final bool outgoing;
  final bool read;
  final String mediaPath;
  final String thumbnailPath;
  final int duration;
  final String fileName;
  final String fileSize;
  final int fileId;
  final int thumbFileId;
  final int width;
  final int height;
  final bool isDownloading;
  final bool isDownloaded;
  final int replyToMessageId;
  final String replySenderName;
  final String replyText;
  final String replyThumbnailPath;
  final MessageKind? replyKind;
  final String senderName;
  final int senderUserId;
}

class TgReaction {
  const TgReaction(this.emoji, this.count);

  final String emoji;
  final int count;
}

/// История сообщений чата: готовый список для UI + есть ли ещё сверху.
class TgChatHistory {
  const TgChatHistory({this.messages = const [], this.hasMore = false});

  final List<TgMessage> messages;
  final bool hasMore;
}

class TgChat {
  const TgChat({
    required this.id,
    required this.title,
    required this.avatarEmoji,
    required this.avatarColor,
    this.avatarPath = '',
    required this.sender,
    required this.preview,
    required this.time,
    required this.headerSubtitle,
    this.userId,
    this.verified = false,
    this.muted = false,
    this.unread = 0,
    this.unreadOwn = false,
    this.outgoing = false,
    this.outgoingRead = false,
    this.reactions = const [],
    this.messages = const [],
  });

  final String id;
  final String title;

  /// ARGB-цвет заглушки аватара (int, чтобы модель была без Flutter).
  final int avatarColor;
  final String avatarEmoji;
  final String avatarPath;
  final String sender;
  final String preview;
  final String time;
  final String headerSubtitle;
  final int? userId;
  final bool verified;
  final bool muted;
  final int unread;
  final bool unreadOwn;
  final bool outgoing;
  final bool outgoingRead;
  final List<TgReaction> reactions;
  final List<TgMessage> messages;
}

enum TgCallState {
  pending,
  ringing,
  exchangingKeys,
  ready,
  hangingUp,
  discarded,
}

class TgCallInfo {
  const TgCallInfo({
    required this.callId,
    required this.userId,
    required this.userName,
    required this.isOutgoing,
    required this.state,
    this.rawState = '',
    this.discardReason = '',
    this.emojis = const [],
    this.duration = 0,
  });

  final int callId;
  final int userId;
  final String userName;
  final bool isOutgoing;
  final TgCallState state;
  final String rawState;
  final String discardReason;
  final List<String> emojis;
  final int duration;

  TgCallInfo copyWith({
    int? callId,
    int? userId,
    String? userName,
    bool? isOutgoing,
    TgCallState? state,
    String? rawState,
    String? discardReason,
    List<String>? emojis,
    int? duration,
  }) {
    return TgCallInfo(
      callId: callId ?? this.callId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      state: state ?? this.state,
      rawState: rawState ?? this.rawState,
      discardReason: discardReason ?? this.discardReason,
      emojis: emojis ?? this.emojis,
      duration: duration ?? this.duration,
    );
  }
}
