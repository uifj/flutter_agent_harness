/// Stone Offline Sync Service
///
/// Provides models and interfaces for offline-first data
/// synchronization with conflict resolution strategies.
///
/// Usage:
/// ```dart
/// // Queue a change while offline
/// await syncService.queueChange(
///   entityType: 'task',
///   entityId: 'task-123',
///   operationType: OfflineOperationType.update,
///   data: {'title': 'Updated title'},
/// );
///
/// // Sync when online
/// await syncService.syncChanges();
/// ```
library;

import 'dart:async';
import 'dart:convert';

/// Status of a sync operation.
enum SyncStatus {
  /// Waiting to be synced.
  pending,

  /// Currently syncing.
  syncing,

  /// Successfully synced.
  synced,

  /// Failed to sync.
  failed,

  /// Sync conflict detected.
  conflict,

  /// Canceled sync.
  canceled,
}

/// Operation type for offline changes.
enum OfflineOperationType {
  /// Create operation.
  create,

  /// Update operation.
  update,

  /// Delete operation.
  delete,

  /// Custom operation.
  custom,
}

/// Represents an offline change that needs to be synced.
class OfflineChange {
  /// Unique identifier for this change.
  final String id;

  /// Entity type (e.g., "user", "post", "comment").
  final String entityType;

  /// Entity ID (can be null for create operations).
  final String? entityId;

  /// Type of operation.
  final OfflineOperationType operationType;

  /// Data to sync (can be null for delete operations).
  final Map<String, dynamic>? data;

  /// Status of the sync operation.
  final SyncStatus status;

  /// Timestamp when the change was created.
  final DateTime timestamp;

  /// Number of retry attempts.
  final int retryCount;

  /// Time of the last retry attempt.
  final DateTime? lastRetryTime;

  /// Error message if sync failed.
  final String? errorMessage;

  const OfflineChange({
    required this.id,
    required this.entityType,
    this.entityId,
    required this.operationType,
    this.data,
    required this.status,
    required this.timestamp,
    this.retryCount = 0,
    this.lastRetryTime,
    this.errorMessage,
  });

  /// Convert to a JSON object.
  Map<String, dynamic> toJson() => {
    'id': id,
    'entityType': entityType,
    'entityId': entityId,
    'operationType': operationType.name,
    'data': data,
    'status': status.name,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
    'lastRetryTime': lastRetryTime?.toIso8601String(),
    'errorMessage': errorMessage,
  };

  /// Create from a JSON object.
  factory OfflineChange.fromJson(Map<String, dynamic> json) {
    return OfflineChange(
      id: json['id'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String?,
      operationType: OfflineOperationType.values.firstWhere(
        (e) => e.name == json['operationType'],
        orElse: () => OfflineOperationType.custom,
      ),
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      status: SyncStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SyncStatus.pending,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      retryCount: (json['retryCount'] as int?) ?? 0,
      lastRetryTime: json['lastRetryTime'] != null
          ? DateTime.parse(json['lastRetryTime'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// Serializes this change to a JSON string.
  String serialize() => jsonEncode(toJson());

  /// Deserializes from a JSON string.
  factory OfflineChange.deserialize(String source) =>
      OfflineChange.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Create a copy with updated fields.
  OfflineChange copyWith({
    String? id,
    String? entityType,
    String? entityId,
    OfflineOperationType? operationType,
    Map<String, dynamic>? data,
    SyncStatus? status,
    DateTime? timestamp,
    int? retryCount,
    DateTime? lastRetryTime,
    String? errorMessage,
  }) {
    return OfflineChange(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operationType: operationType ?? this.operationType,
      data: data ?? this.data,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      lastRetryTime: lastRetryTime ?? this.lastRetryTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// Conflict Resolution Strategies
// ---------------------------------------------------------------------------

/// Interface for conflict resolution strategies.
abstract class ConflictResolutionStrategy {
  /// Resolve conflict between local and remote changes.
  Future<Map<String, dynamic>> resolveConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? localData,
    required Map<String, dynamic>? remoteData,
    required OfflineOperationType operationType,
  });
}

/// Client wins conflict resolution strategy (client data overrides server).
class ClientWinsStrategy implements ConflictResolutionStrategy {
  @override
  Future<Map<String, dynamic>> resolveConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? localData,
    required Map<String, dynamic>? remoteData,
    required OfflineOperationType operationType,
  }) async {
    return localData ?? {};
  }
}

/// Server wins conflict resolution strategy (server data overrides client).
class ServerWinsStrategy implements ConflictResolutionStrategy {
  @override
  Future<Map<String, dynamic>> resolveConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? localData,
    required Map<String, dynamic>? remoteData,
    required OfflineOperationType operationType,
  }) async {
    return remoteData ?? {};
  }
}

/// Smart merge conflict resolution strategy (merge fields by priority).
class SmartMergeStrategy implements ConflictResolutionStrategy {
  /// Map of field name → client wins (true) or server wins (false).
  final Map<String, bool> fieldPriorities;

  SmartMergeStrategy(this.fieldPriorities);

  @override
  Future<Map<String, dynamic>> resolveConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? localData,
    required Map<String, dynamic>? remoteData,
    required OfflineOperationType operationType,
  }) async {
    if (localData == null) return remoteData ?? {};
    if (remoteData == null) return localData;

    final result = Map<String, dynamic>.from(remoteData);
    localData.forEach((key, value) {
      if (fieldPriorities[key] == true) {
        result[key] = value;
      }
    });
    return result;
  }
}

// ---------------------------------------------------------------------------
// Offline Sync Service Interface
// ---------------------------------------------------------------------------

/// Interface for syncing offline changes.
///
/// Implementations should handle persistence (Hive, SQLite, etc.)
/// and network connectivity checks internally.
abstract class OfflineSyncService {
  /// Queue an offline change.
  Future<OfflineChange> queueChange({
    required String entityType,
    String? entityId,
    required OfflineOperationType operationType,
    Map<String, dynamic>? data,
  });

  /// Start syncing pending changes.
  Future<void> syncChanges();

  /// Get the sync status for an entity.
  Future<SyncStatus?> getSyncStatus(String entityType, String entityId);

  /// Get all pending changes.
  Future<List<OfflineChange>> getPendingChanges();

  /// Handle sync conflicts.
  Future<void> resolveConflict(
    String changeId,
    Map<String, dynamic> resolvedData,
  );

  /// Listen to sync status changes.
  Stream<List<OfflineChange>> get syncStatusStream;

  /// Check if the device is online.
  Future<bool> isOnline();

  /// Initialize the sync service.
  Future<void> init();
}
