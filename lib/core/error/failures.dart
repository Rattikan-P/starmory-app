import 'package:equatable/equatable.dart';

/// Base class for all failures
abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure(this.message, {this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

// Server-related failures
class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.statusCode});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message) : super();
}

// Cache-related failures
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

// Auth-related failures
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.statusCode});
}

// Quota-related failures
class QuotaExceededFailure extends Failure {
  const QuotaExceededFailure(super.message) : super();
}

// AI-related failures
class AIServiceFailure extends Failure {
  const AIServiceFailure(super.message) : super();
}

// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

// Unknown failures
class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}
