import 'package:equatable/equatable.dart';

class UserStatsModel extends Equatable {
  final int totalReviewsCompleted;
  final double averageTimePerCard;
  final DateTime lastReviewDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserStatsModel({
    this.totalReviewsCompleted = 0,
    this.averageTimePerCard = 7.0,
    required this.lastReviewDate,
    this.createdAt,
    this.updatedAt,
  });

  factory UserStatsModel.fromJson(Map<String, dynamic> json) => UserStatsModel(
        totalReviewsCompleted: json['totalReviewsCompleted'] as int? ?? 0,
        averageTimePerCard:
            (json['averageTimePerCard'] as num?)?.toDouble() ?? 7.0,
        lastReviewDate: DateTime.parse(json['lastReviewDate'] as String),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'totalReviewsCompleted': totalReviewsCompleted,
        'averageTimePerCard': averageTimePerCard,
        'lastReviewDate': lastReviewDate.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  UserStatsModel copyWith({
    int? totalReviewsCompleted,
    double? averageTimePerCard,
    DateTime? lastReviewDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      UserStatsModel(
        totalReviewsCompleted: totalReviewsCompleted ?? this.totalReviewsCompleted,
        averageTimePerCard: averageTimePerCard ?? this.averageTimePerCard,
        lastReviewDate: lastReviewDate ?? this.lastReviewDate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [
        totalReviewsCompleted,
        averageTimePerCard,
        lastReviewDate,
        createdAt,
        updatedAt,
      ];
}
