/// Result type for handling success and failure states.
///
/// Uses sealed class pattern for exhaustive pattern matching.
sealed class Result<T> {
  const Result();

  /// Create a success result.
  const factory Result.success(T data) = Success<T>;

  /// Create a failure result.
  const factory Result.failure(String message, {int? statusCode}) =
      Failure<T>;

  /// Map the result to another type.
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, int? statusCode) failure,
  }) {
    return switch (this) {
      Success<T>(data: final data) => success(data),
      Failure<T>(message: final msg, statusCode: final code) =>
        failure(msg, code),
    };
  }

  /// Check if this result is a success.
  bool get isSuccess => this is Success<T>;

  /// Check if this result is a failure.
  bool get isFailure => this is Failure<T>;

  /// Get the data if success, or null.
  T? get dataOrNull => switch (this) {
    Success<T>(data: final data) => data,
    Failure<T>() => null,
  };
}

/// A successful result.
class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

/// A failure result.
class Failure<T> extends Result<T> {
  const Failure(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}
