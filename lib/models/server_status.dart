enum ServerStatus { stopped, starting, running, stopping, error }

class ServerState {
  final ServerStatus status;
  final String? token;
  final String? sessionId;
  final String? host;
  final int? port;
  final DateTime? startedAt;
  final String? errorMessage;
  final List<String> logs;

  ServerState({
    this.status = ServerStatus.stopped,
    this.token,
    this.sessionId,
    this.host,
    this.port,
    this.startedAt,
    this.errorMessage,
    this.logs = const [],
  });

  bool get isRunning => status == ServerStatus.running;
  bool get isStopped => status == ServerStatus.stopped;
  bool get isStarting => status == ServerStatus.starting;
  bool get isStopping => status == ServerStatus.stopping;
  bool get isError => status == ServerStatus.error;

  String? get url => host != null && port != null ? 'http://$host:$port' : null;

  Duration? get uptime {
    if (startedAt == null) return null;
    return DateTime.now().difference(startedAt!);
  }

  ServerState copyWith({
    ServerStatus? status,
    String? token,
    bool clearToken = false,
    String? sessionId,
    bool clearSessionId = false,
    String? host,
    int? port,
    DateTime? startedAt,
    bool clearStartedAt = false,
    String? errorMessage,
    bool clearError = false,
    List<String>? logs,
  }) {
    return ServerState(
      status: status ?? this.status,
      token: clearToken ? null : (token ?? this.token),
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      host: host ?? this.host,
      port: port ?? this.port,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      logs: logs ?? this.logs,
    );
  }
}
