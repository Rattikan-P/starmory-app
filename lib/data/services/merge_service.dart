/// Data Merge Framework
/// Handles merging guest data with cloud server data using configurable strategies
///
/// Usage:
/// ```dart
/// final mergeService = MergeService();
/// final merged = await mergeService.mergeUserData(guestData, serverData);
/// ```

library;

/// Merge strategy for different data types
enum MergeStrategy {
  /// Keep the maximum value (e.g., streak, best score)
  max,

  /// Sum both values (e.g., XP, points, time)
  sum,

  /// Merge lists without duplicates (e.g., vocabulary)
  merge,

  /// Union of sets/arrays (e.g., badges)
  union,

  /// Keep server value (e.g., settings, preferences)
  server,

  /// Keep guest value (rare - usually for testing)
  guest,

  /// Use most recent by timestamp (e.g., last activity)
  mostRecent,

  /// Server wins if exists, otherwise guest (for new users)
  serverFallbackGuest,

  /// Follow the winner of another field (e.g., shields follows current_streak winner)
  /// Use with dependsOn to specify which field to follow
  followWinner,
}

/// Merge configuration for a specific field
class MergeFieldConfig {
  final String fieldKey;
  final MergeStrategy strategy;
  final String? serverKeyName;
  final String? guestKeyName;
  final String? dependsOn; // Field key to follow (for followWinner strategy)

  const MergeFieldConfig({
    required this.fieldKey,
    required this.strategy,
    this.serverKeyName,
    this.guestKeyName,
    this.dependsOn,
  });

  /// Get the key to read from server data
  String get serverKey => serverKeyName ?? fieldKey;

  /// Get the key to read from guest data
  String get guestKey => guestKeyName ?? fieldKey;
}

/// Result of a merge operation
class MergeResult {
  final Map<String, dynamic> mergedData;
  final Map<String, String> mergeDetails; // field -> description of what was merged

  const MergeResult({
    required this.mergedData,
    required this.mergeDetails,
  });

  /// Get human-readable summary of merge result
  String get summary {
    if (mergeDetails.isEmpty) return 'No data merged';
    final merged = mergeDetails.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    return 'Merged: $merged';
  }
}

/// Service for merging user data between guest and cloud
class MergeService {
  /// Default merge configuration for user data fields
  static const Map<String, MergeFieldConfig> defaultMergeConfig = {
    // Streak-related fields
    'current_streak': MergeFieldConfig(
      fieldKey: 'currentStreak',
      strategy: MergeStrategy.max,
    ),
    'longest_streak': MergeFieldConfig(
      fieldKey: 'longestStreak',
      strategy: MergeStrategy.max,
    ),
    'last_activity_date': MergeFieldConfig(
      fieldKey: 'lastStreakActivityDate',
      strategy: MergeStrategy.mostRecent,
    ),
    'shields_available': MergeFieldConfig(
      fieldKey: 'shields',
      serverKeyName: 'shields_available',
      strategy: MergeStrategy.followWinner,
      dependsOn: 'currentStreak', // Follow whoever won current_streak
    ),

    // Lists/Arrays - merge without duplicates
    'vocabulary': MergeFieldConfig(
      fieldKey: 'vocabulary',
      strategy: MergeStrategy.merge,
    ),

    // Settings/Preferences - server wins for existing users
    'language_level': MergeFieldConfig(
      fieldKey: 'defaultCefrLevel',
      strategy: MergeStrategy.server,
    ),
    'english_variant': MergeFieldConfig(
      fieldKey: 'languageVariant',
      strategy: MergeStrategy.server,
    ),
  };

  /// Merge two user data maps using configured strategies
  ///
  /// [guestData] - Data from guest user (local)
  /// [serverData] - Data from server (cloud), can be null for new users
  /// [config] - Custom merge config (optional, uses default if not provided)
  ///
  /// Returns [MergeResult] with merged data and details
  Future<MergeResult> mergeUserData(
    Map<String, dynamic> guestData,
    Map<String, dynamic>? serverData, {
    Map<String, MergeFieldConfig>? config,
  }) async {
    final mergeConfig = config ?? defaultMergeConfig;
    final merged = <String, dynamic>{};
    final details = <String, String>{};

    final hasServerData = serverData != null && serverData.isNotEmpty;

    for (final entry in mergeConfig.entries) {
      final fieldName = entry.key;
      final fieldConfig = entry.value;

      // Get values
      final guestValue = _getNestedValue(guestData, fieldConfig.guestKey);
      final serverValue = hasServerData
          ? _getNestedValue(serverData, fieldConfig.serverKey)
          : null;

      // Apply merge strategy
      final result = _applyStrategy(
        fieldConfig.strategy,
        guestValue,
        serverValue,
        hasServerData,
      );

      merged[fieldName] = result.value;

      if (result.description != null) {
        details[fieldName] = result.description!;
      }
    }

    // Copy other fields from server if they exist
    if (hasServerData) {
      serverData!.forEach((key, value) {
        if (!mergeConfig.containsKey(key) && !merged.containsKey(key)) {
          merged[key] = value;
        }
      });
    }

    // Copy other fields from guest if they don't exist in merged
    guestData.forEach((key, value) {
      if (!merged.containsKey(key)) {
        merged[key] = value;
      }
    });

    // Post-processing: resolve followWinner fields
    for (final entry in mergeConfig.entries) {
      final fieldConfig = entry.value;
      if (fieldConfig.strategy == MergeStrategy.followWinner && fieldConfig.dependsOn != null) {
        final dependsOnField = fieldConfig.dependsOn!;

        // Find which field the dependsOn field refers to in mergeConfig
        String? dependsOnConfigKey;
        for (final configEntry in mergeConfig.entries) {
          if (configEntry.value.fieldKey == dependsOnField) {
            dependsOnConfigKey = configEntry.key;
            break;
          }
        }

        if (dependsOnConfigKey != null && merged.containsKey(dependsOnConfigKey)) {
          // Determine winner by comparing original values
          final guestValue = _getNestedValue(guestData, fieldConfig.guestKey);
          final serverValue = hasServerData
              ? _getNestedValue(serverData, fieldConfig.serverKey)
              : null;

          // Check the dependsOn field's values
          final depGuestValue = _getNestedValue(guestData, dependsOnField);
          final depServerValue = hasServerData
              ? _getNestedValue(serverData, dependsOnField)
              : null;

          // Determine which side won the dependsOn field
          final depGuest = depGuestValue is num ? depGuestValue : 0;
          final depServer = depServerValue is num ? depServerValue : 0;

          // Use the value from the winning side
          if (depServer > depGuest) {
            // Server won, use server value
            merged[entry.key] = serverValue ?? guestValue ?? _defaultValue();
            details[entry.key] = 'Followed server winner (based on $dependsOnField)';
          } else if (depGuest > depServer) {
            // Guest won, use guest value
            merged[entry.key] = guestValue ?? serverValue ?? _defaultValue();
            details[entry.key] = 'Followed guest winner (based on $dependsOnField)';
          } else {
            // Equal or no server, use any (prefer guest)
            merged[entry.key] = guestValue ?? serverValue ?? _defaultValue();
            details[entry.key] = 'Equal values, used guest';
          }
        }
      }
    }

    return MergeResult(mergedData: merged, mergeDetails: details);
  }

  /// Result of applying a merge strategy
  ({dynamic value, String? description}) _applyStrategy(
    MergeStrategy strategy,
    dynamic guestValue,
    dynamic serverValue,
    bool hasServerData,
  ) {
    switch (strategy) {
      case MergeStrategy.max:
        return _maxStrategy(guestValue, serverValue, hasServerData);

      case MergeStrategy.sum:
        return _sumStrategy(guestValue, serverValue, hasServerData);

      case MergeStrategy.merge:
        return _mergeStrategy(guestValue, serverValue, hasServerData);

      case MergeStrategy.union:
        return _unionStrategy(guestValue, serverValue, hasServerData);

      case MergeStrategy.server:
        return (
          value: serverValue ?? guestValue ?? _defaultValue(),
          description: null
        );

      case MergeStrategy.guest:
        return (
          value: guestValue ?? serverValue ?? _defaultValue(),
          description: 'Used guest value'
        );

      case MergeStrategy.mostRecent:
        return _mostRecentStrategy(guestValue, serverValue, hasServerData);

      case MergeStrategy.serverFallbackGuest:
        if (hasServerData && serverValue != null) {
          return (value: serverValue, description: null);
        }
        return (
          value: guestValue ?? _defaultValue(),
          description: 'Used guest (server null)'
        );

      case MergeStrategy.followWinner:
        // This will be handled in post-processing phase
        return (
          value: guestValue ?? serverValue ?? _defaultValue(),
          description: 'Follows winner (to be resolved)'
        );
    }
  }

  /// MAX strategy: keep the higher value
  ({num value, String? description}) _maxStrategy(
    dynamic guestValue,
    dynamic serverValue,
    bool hasServerData,
  ) {
    final guest = guestValue is num ? guestValue : 0;
    final server = serverValue is num ? serverValue : 0;

    if (!hasServerData) {
      return (value: guest, description: 'No server data, used guest');
    }

    if (server > guest) {
      return (value: server, description: 'Server higher ($server > $guest)');
    } else if (guest > server) {
      return (value: guest, description: 'Guest higher ($guest > $server)');
    } else {
      return (value: server, description: 'Equal ($server)');
    }
  }

  /// SUM strategy: add both values
  ({num value, String? description}) _sumStrategy(
    dynamic guestValue,
    dynamic serverValue,
    bool hasServerData,
  ) {
    final guest = guestValue is num ? guestValue : 0;
    final server = serverValue is num ? serverValue : 0;
    final sum = guest + server;

    final description = hasServerData
        ? 'Combined: guest ($guest) + server ($server) = $sum'
        : 'New user: $sum';

    return (value: sum, description: description);
  }

  /// MERGE strategy: merge lists without duplicates
  ({List value, String? description}) _mergeStrategy(
    dynamic guestValue,
    dynamic serverValue,
    bool hasServerData,
  ) {
    final guestList = guestValue is List ? guestValue : <dynamic>[];
    final serverList = serverValue is List ? serverValue : <dynamic>[];

    if (!hasServerData || serverList.isEmpty) {
      return (value: List.from(guestList), description: 'No server data, used guest');
    }

    if (guestList.isEmpty) {
      return (value: List.from(serverList), description: null);
    }

    // Merge without duplicates (using identity/hashCode)
    final merged = <dynamic>[...serverList];
    for (final item in guestList) {
      if (!merged.contains(item)) {
        merged.add(item);
      }
    }

    final description = 'Merged: ${serverList.length} server + ${guestList.length} guest → ${merged.length} total';
    return (value: merged, description: description);
  }

  /// UNION strategy: combine all unique items
  ({Set value, String? description}) _unionStrategy(
    dynamic guestValue,
    dynamic serverValue,
    bool hasServerData,
  ) {
    final guestList = guestValue is List ? guestValue.toSet() : <dynamic>{};
    final serverList = serverValue is List ? serverValue.toSet() : <dynamic>{};

    if (!hasServerData || serverList.isEmpty) {
      return (value: guestList, description: 'No server data, used guest');
    }

    final union = {...serverList, ...guestList};
    final description = guestList.isNotEmpty
        ? 'Union: ${serverList.length} + ${guestList.length} → ${union.length}'
        : null;

    return (value: union, description: description);
  }

  /// MOST_RECENT strategy: use the most recent timestamp
  ({DateTime? value, String? description}) _mostRecentStrategy(
    dynamic guestValue,
    dynamic serverValue,
    bool hasServerData,
  ) {
    DateTime? guestDate = _parseDateTime(guestValue);
    DateTime? serverDate = _parseDateTime(serverValue);

    if (!hasServerData || serverDate == null) {
      return (value: guestDate, description: 'No server data, used guest');
    }

    if (guestDate == null) {
      return (value: serverDate, description: null);
    }

    if (serverDate.isAfter(guestDate)) {
      return (value: serverDate, description: 'Server more recent');
    } else if (guestDate.isAfter(serverDate)) {
      return (value: guestDate, description: 'Guest more recent');
    } else {
      return (value: serverDate, description: 'Same time');
    }
  }

  /// Parse value to DateTime
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Get nested value from map using dot notation
  dynamic _getNestedValue(Map<String, dynamic> data, String key) {
    final keys = key.split('.');
    dynamic value = data;
    for (final k in keys) {
      if (value is Map && value.containsKey(k)) {
        value = value[k];
      } else {
        return null;
      }
    }
    return value;
  }

  /// Get default value
  dynamic _defaultValue() => null;
}
