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
  })  : _baseUrl = baseUrl ?? AppConfig.defaultApiBaseUrl,
        _dio = dio ??
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
  }) async {
    return _sendRequest(
      {
        'requestId': requestId,
        'mode': 'describe',
        'language': language,
        'image': {
          'mimeType': 'image/jpeg',
          'base64': base64Jpeg,
        },
      },
      cancelToken: cancelToken,
    );
  }

  @override
  Future<SceneResult> askQuestion({
    required String requestId,
    required String base64Jpeg,
    required String question,
    required String language,
    CancelToken? cancelToken,
  }) async {
    return _sendRequest(
      {
        'requestId': requestId,
        'mode': 'ask',
        'language': language,
        'question': question,
        'image': {
          'mimeType': 'image/jpeg',
          'base64': base64Jpeg,
        },
      },
      cancelToken: cancelToken,
    );
  }

  Future<SceneResult> _sendRequest(
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await _dio.post(
        '$_baseUrl/v1/vision',
        data: body,
        options: Options(headers: headers),
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
          e.type == DioExceptionType.receiveTimeout) {
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
      if (e.response?.statusCode == 429) {
        throw const AppException(
          code: ErrorCode.upstreamRateLimited,
          userMessage: 'Service rate limit reached. Please wait a moment and try again.',
        );
      }
      if (e.response?.statusCode == 503) {
        throw const AppException(
          code: ErrorCode.cloudDisabled,
          userMessage: 'Cloud processing is temporarily disabled on the server.',
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
