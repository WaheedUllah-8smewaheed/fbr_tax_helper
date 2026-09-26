import 'package:fbr_tax_helper/core/network/dio_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts an absolute HTTPS API URL and uses secure defaults', () {
    final client = DioClient.create(baseUrl: 'https://api.example.com');

    expect(client.options.baseUrl, 'https://api.example.com');
    expect(client.options.followRedirects, isFalse);
    expect(client.options.maxRedirects, 0);
    expect(client.options.headers['Accept'], 'application/json');
  });

  test('rejects an HTTP or relative API URL', () {
    expect(
      () => DioClient.create(baseUrl: 'http://api.example.com'),
      throwsArgumentError,
    );
    expect(() => DioClient.create(baseUrl: '/api'), throwsArgumentError);
  });
}
