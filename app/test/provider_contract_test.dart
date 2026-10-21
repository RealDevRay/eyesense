import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eyesense/models/direct_ai_provider.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/providers/groq_direct_provider.dart';
import 'package:eyesense/services/providers/hosted_provider.dart';
import 'package:eyesense/services/providers/openai_compatible_provider.dart';
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
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          ErrorCode.upstreamAuthFailed,
        ),
      ),
    );
  });

  test(
    'hosted describe posts the bearer token, mode and remaining timeout',
    () async {
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
      expect(
        adapter.last?.uri.toString(),
        'https://eyesense.example/v1/vision',
      );
      expect(adapter.last?.headers['Authorization'], 'Bearer internal-token');
      expect(adapter.last?.data['mode'], 'describe');
      expect(adapter.last?.sendTimeout, const Duration(seconds: 4));
      expect(adapter.last?.receiveTimeout, const Duration(seconds: 4));
    },
  );

  test('hosted endpoint normalizes whitespace and trailing slashes', () async {
    final adapter = ScriptedAdapter(
      (_) async => jsonBody({'result': resultJson}),
    );
    final provider = HostedVisionProvider(
      dio: Dio()..httpClientAdapter = adapter,
      credentialService: MemoryCredentials(hosted: 'internal-token'),
      baseUrl: ' https://eyesense.example/// ',
    );
    await provider.describeScene(
      requestId: 'slash',
      base64Jpeg: 'abc',
      language: 'en',
    );
    expect(adapter.last?.uri.toString(), 'https://eyesense.example/v1/vision');
  });

  test('hosted gateway timeout is not reported as offline', () async {
    final adapter = ScriptedAdapter(
      (options) async => ResponseBody.fromString('', 504),
    );
    final provider = HostedVisionProvider(
      dio: Dio()..httpClientAdapter = adapter,
      credentialService: MemoryCredentials(hosted: 'internal-token'),
      baseUrl: 'https://eyesense.example',
    );
    await expectLater(
      provider.describeScene(
        requestId: 'timeout',
        base64Jpeg: 'abc',
        language: 'en',
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          ErrorCode.requestTimeout,
        ),
      ),
    );
  });

  test('hosted ask includes the question and maps a rejected token', () async {
    String? seenQuestion;
    final adapter = ScriptedAdapter((options) async {
      final raw = options.data;
      final body = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
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
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          ErrorCode.upstreamAuthFailed,
        ),
      ),
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
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          ErrorCode.upstreamAuthFailed,
        ),
      ),
    );
  });

  test('direct Mistral contract uses its own key and documented JSON vision fields', () async {
    final adapter = ScriptedAdapter(
      (_) async => jsonBody({
        'choices': [
          {
            'finish_reason': 'stop',
            'message': {'content': jsonEncode(resultJson)},
          },
        ],
      }),
    );
    final provider = OpenAiCompatibleVisionProvider(
      provider: DirectAiProvider.mistral,
      dio: Dio()..httpClientAdapter = adapter,
      credentialService: MemoryCredentials(
        groq: 'groq-must-not-be-used',
        hosted: 'hosted-must-not-be-used',
        mistral: 'mistral-test',
      ),
    );
    final result = await provider.askQuestion(
      requestId: 'mistral-ask',
      base64Jpeg: 'synthetic-jpeg',
      question: 'Where is the cup?',
      language: 'sw',
      timeout: const Duration(seconds: 4),
    );
    expect(result.summary, resultJson['summary']);
    final request = adapter.last!;
    expect(
      request.uri.toString(),
      'https://api.mistral.ai/v1/chat/completions',
    );
    expect(request.headers['Authorization'], 'Bearer mistral-test');
    expect(request.followRedirects, isFalse);
    expect(request.sendTimeout, greaterThan(Duration.zero));
    expect(request.sendTimeout, lessThanOrEqualTo(const Duration(seconds: 4)));
    final body = request.data as Map;
    expect(body['model'], 'mistral-small-latest');
    expect(body['response_format'], {'type': 'json_object'});
    expect(body['max_tokens'], 512);
    expect(body['temperature'], 0.1);
    expect(body.containsKey('reasoning_effort'), isFalse);
    expect(body.containsKey('max_completion_tokens'), isFalse);
    expect(body['messages'].last['content'].last['image_url'], {
      'url': 'data:image/jpeg;base64,synthetic-jpeg',
    });
  });

  test(
    'Mistral never borrows Groq or hosted credentials when its key is absent',
    () async {
      final adapter = ScriptedAdapter(
        (_) => throw StateError('Unexpected upload'),
      );
      final provider = OpenAiCompatibleVisionProvider(
        provider: DirectAiProvider.mistral,
        dio: Dio()..httpClientAdapter = adapter,
        credentialService: MemoryCredentials(
          groq: 'groq-test',
          hosted: 'hosted-test',
        ),
      );
      await expectLater(
        provider.describeScene(
          requestId: 'missing-mistral',
          base64Jpeg: 'synthetic',
          language: 'en',
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            ErrorCode.upstreamAuthFailed,
          ),
        ),
      );
      expect(adapter.last, isNull);
    },
  );

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
    expect(
      adapter.last?.uri.toString(),
      DirectAiProvider.groq.chatCompletionsUrl,
    );
    expect(adapter.last?.headers['Authorization'], 'Bearer gsk-test');
    expect(adapter.last?.data['model'], DirectAiProvider.groq.defaultModel);
    expect(adapter.last?.data['max_completion_tokens'], 512);
    expect(adapter.last?.data['reasoning_effort'], 'none');
    expect(adapter.last?.data['temperature'], 0.1);
    expect(adapter.last?.data.containsKey('max_tokens'), isFalse);
    expect(adapter.last?.followRedirects, isFalse);
    expect(
      adapter.last?.sendTimeout,
      lessThanOrEqualTo(const Duration(seconds: 6)),
    );
    expect(adapter.last?.sendTimeout, greaterThan(Duration.zero));
    final messages = adapter.last?.data['messages'] as List<dynamic>;
    final user = messages.last as Map<String, dynamic>;
    final content = user['content'] as List<dynamic>;
    expect(content.last['image_url']['url'], 'data:image/jpeg;base64,abc');
  });
}

class MemoryCredentials extends CredentialService {
  MemoryCredentials({this.hosted, this.groq, this.mistral});

  final String? hosted;
  final String? groq;
  final String? mistral;

  @override
  Future<String?> getProviderApiKey(DirectAiProvider provider) =>
      provider == DirectAiProvider.mistral
      ? Future.value(mistral)
      : super.getProviderApiKey(provider);

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
