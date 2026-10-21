import 'package:dio/dio.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/models/scene_result.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/vision_api_service.dart';

class HostedVisionProvider implements VisionApiService {
  final Dio _dio;
  final CredentialService credentialService;
  final String _baseUrl;

  HostedVisionProvider({
    Dio? dio,
    required this.credentialService,
    String? baseUrl,
  }) : _baseUrl = (baseUrl ?? AppConfig.defaultApiBaseUrl).trim().replaceFirst(
         RegExp(r'/+$'),
         '',
       ),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: AppConfig.clientTimeout,
               receiveTimeout: AppConfig.clientTimeout,
             ),
           );

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await credentialService.getDemoAccessToken();
    if (token == null || token.isEmpty) {
      throw const AppException(
        code: ErrorCode.upstreamAuthFailed,
        userMessage: 'Hosted access token is not configured. Please check AI connection settings.',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  @override
  Future<SceneResult> describeScene({
    required String requestId,
    required String base64Jpeg,
    required String language,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    return _sendRequest(
      {
        'requestId': requestId,
        'mode': 'describe',
        'language': language,
        'image': {'mimeType': 'image/jpeg', 'base64': base64Jpeg},
      },
      cancelToken: cancelToken,
      timeout: timeout,
    );
  }

  @override
  Future<SceneResult> askQuestion({
    required String requestId,
    required String base64Jpeg,
    required String question,
    required String language,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    return _sendRequest(
      {
        'requestId': requestId,
        'mode': 'ask',
        'language': language,
        'question': question,
        'image': {'mimeType': 'image/jpeg', 'base64': base64Jpeg},
      },
      cancelToken: cancelToken,
      timeout: timeout,
    );
  }

  Future<SceneResult> _sendRequest(
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await _dio.post(
        '$_baseUrl/v1/vision',
        data: body,
        options: Options(
          followRedirects: false,
          headers: headers,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final rawResult = data['result'] as Map<String, dynamic>?;
        if (rawResult == null) {
          throw const AppException(
            code: ErrorCode.validationFailed,
            userMessage: 'Invalid server response structure.',
          );
        }
        return SceneResult.fromJson(rawResult);
      }

      throw const AppException(
        code: ErrorCode.validationFailed,
        userMessage: 'Unexpected server response.',
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw const AppException(
          code: ErrorCode.operationCancelled,
          userMessage: 'Operation was cancelled.',
        );
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.response?.statusCode == 504) {
        throw const AppException(
          code: ErrorCode.requestTimeout,
          userMessage: 'Visual analysis timed out. Please try again.',
        );
      }
      if (e.response?.statusCode == 401) {
        throw const AppException(
          code: ErrorCode.upstreamAuthFailed,
          userMessage: 'Invalid demo access token. Please update Settings.',
        );
      }
      // Treat all server text as untrusted. Map only known codes to local copy.
      final data = e.response?.data;
      final error = data is Map ? data['error'] : null;
      final code = error is Map ? error['code'] : null;
      if (e.response?.statusCode == 429) {
        final raw = e.response?.headers.value('retry-after') ?? '';
        final seconds = RegExp(r'^\d{1,6}$').hasMatch(raw)
            ? int.tryParse(raw)
            : null;
        final wait = seconds != null && seconds > 0
            ? 'Wait $seconds seconds before trying again.'
            : 'Wait before trying again.';
        throw AppException(
          code: ErrorCode.upstreamRateLimited,
          userMessage:
              'Shared service usage limit reached. $wait Read Text OCR is still available. No request was retried automatically.',
        );
      }
      if (e.response?.statusCode == 502 &&
          (code == 'UPSTREAM_AUTH_ERROR' || code == 'UPSTREAM_ACCESS_DENIED')) {
        throw AppException(
          code: ErrorCode.upstreamAuthFailed,
          userMessage: code == 'UPSTREAM_ACCESS_DENIED'
              ? 'Groq denied access to the EyeSense service. Ask the pilot operator to check Groq account and model permissions. Read Text OCR is still available.'
              : 'Groq rejected the service API key. Ask the pilot operator to update it. Do not share keys in feedback.',
        );
      }
      if (e.response?.statusCode == 503) {
        throw AppException(
          code: ErrorCode.cloudDisabled,
          userMessage: switch (code) {
            'DAILY_BUDGET_EXHAUSTED' => 'The pilot shared daily allowance is used up. Use Read Text OCR or try again tomorrow.',
            'BUDGET_UNAVAILABLE' => 'Hosted usage accounting is unavailable. Please try later or use Read Text OCR.',
            _ => 'Cloud processing is temporarily disabled on the server.',
          },
        );
      }
      throw AppException(
        code: ErrorCode.networkOffline,
        userMessage: 'Network error communicating with EyeSense service.',
        technicalDetail: e.message,
      );
    }
  }
}
