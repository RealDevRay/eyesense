import 'package:dio/dio.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialService {
  static const _keyUserGroqApiKey = 'user_groq_api_key';
  static const _keyDemoAccessToken = 'hosted_demo_access_token';

  final FlutterSecureStorage _storage;
  final Dio _dio;

  CredentialService({
    FlutterSecureStorage? storage,
    Dio? dio,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            ),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
              ),
            );

  Future<String?> getUserGroqApiKey() async {
    return await _storage.read(key: _keyUserGroqApiKey);
  }

  Future<void> setUserGroqApiKey(String apiKey) async {
    await _storage.write(key: _keyUserGroqApiKey, value: apiKey.trim());
  }

  Future<void> clearUserGroqApiKey() async {
    await _storage.delete(key: _keyUserGroqApiKey);
  }

  Future<String?> getDemoAccessToken() async {
    return await _storage.read(key: _keyDemoAccessToken);
  }

  Future<void> setDemoAccessToken(String token) async {
    await _storage.write(key: _keyDemoAccessToken, value: token.trim());
  }

  Future<void> clearDemoAccessToken() async {
    await _storage.delete(key: _keyDemoAccessToken);
  }

  /// Tests a Groq API key via a low-impact authenticated GET /models call.
  /// Does not upload any images or scene data.
  Future<bool> testGroqApiKey(String apiKey) async {
    try {
      final response = await _dio.get(
        AppConfig.groqModelsApiUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${apiKey.trim()}',
          },
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
