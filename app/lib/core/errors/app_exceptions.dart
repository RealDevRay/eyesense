enum ErrorCode {
  cameraPermissionDenied,
  cameraPermissionPermanentlyDenied,
  cameraUnavailable,
  microphonePermissionDenied,
  speechRecognitionUnavailable,
  noReadableTextFound,
  networkOffline,
  requestTimeout,
  upstreamRateLimited,
  upstreamAuthFailed,
  cloudDisabled,
  validationFailed,
  staleResultDiscarded,
  operationCancelled,
  cloudConsentRequired,
  prohibitedSafetyGuidance,
  unknownError,
}

class AppException implements Exception {
  final ErrorCode code;
  final String userMessage;
  final String? technicalDetail;

  const AppException({
    required this.code,
    required this.userMessage,
    this.technicalDetail,
  });

  @override
  String toString() => 'AppException(code: $code, message: $userMessage)';

  static AppException fromError(Object error) {
    if (error is AppException) return error;
    return AppException(
      code: ErrorCode.unknownError,
      userMessage: 'An unexpected issue occurred. Please try again.',
      technicalDetail: error.toString(),
    );
  }
}
