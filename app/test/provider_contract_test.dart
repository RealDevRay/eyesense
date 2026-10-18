import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/providers/groq_direct_provider.dart';
import 'package:eyesense/services/providers/hosted_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resultJson = {
    'summary': 'A cup is on the desk.',
    'possibleConcern': false,
    'direction': 'centre',
    'objects': ['cup', 'desk'],
    'imageQuality': 'usable',
  };

  test('hosted mode fails closed when no token is stored', () async {
    final adapter = ScriptedAdapter((_) {
      fail('hosted mode posted without a token');
    });
    final provider = HostedVisionProvider(
      dio: Dio()..httpClientAdapter = adapter,
      credentialService: MemoryCredentials(),
      baseUrl: 'https://eyesense.example',
    );

    expect(
      () => provider.describeScene(
        requestId: 'req-1',
        base64Jpeg: 'abc',
        language: 'en',
      ),
      throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCode.upstreamAuthFailed)),
    );
  });

  test('hosted describe posts the bearer token, mode and remaining timeout', () async {
    final adapter = ScriptedAdapter((options) async {
      return jsonBody({'result': resultJson});
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = HostedVisionProvider(
      dio: dio,
      credentialService: MemoryCredentials(hosted: 'internal-token'),
      baseUrl: 'https://eyesense.example',
    );

    final result = await provider.describeScene(
      requestId: 'req-2',
      base64Jpeg: 'abc',
      language: 'en',
      timeout: const Duration(seconds: 4),
    );

    expect(result.summary, 'A cup is on the desk.');
    expect(adapter.last?.uri.toString(), 'https://eyesense.example/v1/vision');
    expect(adapter.last?.headers['Authorization'], 'Bearer internal-token');
    expect(adapter.last?.data['mode'], 'describe');
    expect(adapter.last?.sendTimeout, const Duration(seconds: 4));
    expect(adapter.last?.receiveTimeout, const Duration(seconds: 4));
  });

  test('hosted ask includes the question and maps a rejected token', () async {
    String? seenQuestion;
    final adapter = ScriptedAdapter((options) async {
      final raw = options.data;
      final body = raw is String ? jsonDecode(raw) as Map<String, dynamic> : Map<String, dynamic>.from(raw as Map);
      seenQuestion = body['question'] as String?;
      if (seenQuestion == null) {
        throw StateError('ask body was $body');
      }
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 401),
        type: DioExceptionType.badResponse,
      );
    });
    final provider = HostedVisionProvider(
      dio: Dio()..httpClientAdapter = adapter,
      credentialService: MemoryCredentials(hosted: 'internal-token'),
      baseUrl: 'https://eyesense.example',
    );

    await expectLater(
      provider.askQuestion(
        requestId: 'req-3',
        base64Jpeg: 'abc',
        question: 'Where is the cup?',
        language: 'en',
      ),
      throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCode.upstreamAuthFailed)),
    );
    expect(seenQuestion, 'Where is the cup?');
  });

  test('direct Groq mode fails closed without a personal key', () async {
    final adapter = ScriptedAdapter((_) {
      fail('Groq was called without a key');
    });
    final provider = GroqDirectVisionProvider(
      dio: Dio()..httpClientAdapter = adapter,
      credentialService: MemoryCredentials(),
    );

    expect(
      () => provider.describeScene(
        requestId: 'req-4',
        base64Jpeg: 'abc',
        language: 'en',
      ),
      throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCode.upstreamAuthFailed)),
    );
  });

  test('direct Groq describe sends the key, model and image', () async {
    final adapter = ScriptedAdapter((options) async {
      return jsonBody({
        'choices': [
          {
            'message': {'content': jsonEncode(resultJson)},
          },
        ],
      });
    });
    final provider = GroqDirectVisionProvider(
      dio: Dio()..httpClientAdapter = adapter,
      credentialService: MemoryCredentials(groq: 'gsk-test'),
    );

    final result = await provider.describeScene(
      requestId: 'req-5',
      base64Jpeg: 'abc',
      language: 'sw',
      timeout: const Duration(seconds: 6),
    );

    expect(result.summary, 'A cup is on the desk.');
    expect(adapter.last?.uri.toString(), AppConfig.groqDirectApiUrl);
    expect(adapter.last?.headers['Authorization'], 'Bearer gsk-test');
    expect(adapter.last?.data['model'], AppConfig.defaultVisionModel);
    expect(adapter.last?.data['max_tokens'], AppConfig.sceneMaxTokens);
    expect(adapter.last?.sendTimeout, const Duration(seconds: 6));
    final messages = adapter.last?.data['messages'] as List<dynamic>;
    final user = messages.last as Map<String, dynamic>;
    final content = user['content'] as List<dynamic>;
    expect(content.last['image_url']['url'], 'data:image/jpeg;base64,abc');
  });
}

class MemoryCredentials extends CredentialService {
  MemoryCredentials({this.hosted, this.groq});

  final String? hosted;
  final String? groq;

  @override
  Future<String?> getDemoAccessToken() async => hosted;

  @override
  Future<String?> getUserGroqApiKey() async => groq;
}

class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this._handle);

  final Future<ResponseBody> Function(RequestOptions options) _handle;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    last = options;
    return _handle(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
