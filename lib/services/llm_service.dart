import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/run_model.dart';
import 'api_config.dart';

class LLMService {
  late final GenerativeModel _model;

  // Prioritize the local config file, but keep environment variable support
  static const String _apiKey = ApiConfig.geminiApiKey != 'YOUR_API_KEY_HERE'
      ? ApiConfig.geminiApiKey
      : String.fromEnvironment('GEMINI_API_KEY');

  LLMService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(
        'You are "Coach Sarge," a elite-level sprinting coach with a drill sergeant personality. '
        'Your tone is gruff, direct, and no-nonsense, but your goal is to help your athletes improve. '
        'You expect excellence and have zero tolerance for lazines. '
        'You have access to their sprinting data (splits, velocities, accelerations). '
        'Analyze the data with technical precision but deliver the feedback like you are on a track at 5 AM. '
        'Use phrases like "Listen up athlete!", "The clock doesn\'t lie!", or "We\'re not here for a picnic!" '
        'Keep responses concise, actionable, and data-driven.',
      ),
    );
  }

  Future<List<String>> getAvailableModels() async {
    if (!isConfigured) return ["API Key not configured."];
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$_apiKey',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> models = data['models'] ?? [];
        return models.map((m) => m['name'] as String).toList();
      } else {
        return ["Failed to load models: ${response.statusCode}", response.body];
      }
    } catch (e) {
      return ["Error listing models: $e"];
    }
  }

  bool get isConfigured => _apiKey.isNotEmpty;

  String serializeRun(Run run) {
    final Map<String, dynamic> data = {
      'name': run.name,
      'date': run.timestamp.toIso8601String(),
      'total_time': run.totalTimeSeconds,
      'distance_class': run.distanceClass,
      'splits': run.splitTimesSeconds,
      'velocities': run.segmentVelocities,
      'accelerations': run.segmentAccelerations,
      'notes': run.notes,
    };
    return jsonEncode(data);
  }

  Future<String> getCoachResponse(String message, {List<Run>? runs}) async {
    if (!isConfigured) {
      return "LISTEN UP! I can't talk to you without my secure connection! Get that GEMINI_API_KEY configured and stop wasting my time!";
    }

    try {
      String fullPrompt = message;
      if (runs != null && runs.isNotEmpty) {
        final runsData = runs.map((r) => serializeRun(r)).join('\n');
        fullPrompt =
            "Athlete Performance Data:\n$runsData\n\nAthlete Question: $message";
      }

      final content = [Content.text(fullPrompt)];
      final response = await _model.generateContent(content);
      return response.text ??
          "I've got nothing to say to that performance! Try again!";
    } catch (e) {
      return "ERROR IN THE FIELD! Something went wrong with the connection. Fix it! ($e)";
    }
  }

  Stream<String> getCoachResponseStream(
    String message, {
    List<Run>? runs,
  }) async* {
    if (!isConfigured) {
      yield "LISTEN UP! I can't talk to you without my secure connection! Get that GEMINI_API_KEY configured and stop wasting my time!";
      return;
    }

    try {
      String fullPrompt = message;
      if (runs != null && runs.isNotEmpty) {
        final runsData = runs.map((r) => serializeRun(r)).join('\n');
        fullPrompt =
            "Athlete Performance Data:\n$runsData\n\nAthlete Question: $message";
      }

      final content = [Content.text(fullPrompt)];
      final responses = _model.generateContentStream(content);

      await for (final response in responses) {
        if (response.text != null) {
          yield response.text!;
        }
      }
    } catch (e) {
      yield "ERROR IN THE FIELD! Fix it! ($e)";
    }
  }
}
