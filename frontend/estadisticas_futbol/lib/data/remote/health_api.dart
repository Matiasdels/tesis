import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class HealthApi {
  HealthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<HealthCheckResult> checkServer() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/health');
      final response = await _client.get(uri).timeout(
            const Duration(seconds: 3),
          );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return HealthCheckResult(
          canCommunicate: false,
          technicalError: 'HTTP ${response.statusCode}: health check failed',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status']?.toString().toLowerCase();
      final database = json['database'];

      return HealthCheckResult(
        canCommunicate: status == 'ok' && database == true,
      );
    } catch (error) {
      return HealthCheckResult(
        canCommunicate: false,
        technicalError: '${error.runtimeType}: $error',
      );
    }
  }
}

class HealthCheckResult {
  final bool canCommunicate;
  final String? technicalError;

  const HealthCheckResult({
    required this.canCommunicate,
    this.technicalError,
  });
}
