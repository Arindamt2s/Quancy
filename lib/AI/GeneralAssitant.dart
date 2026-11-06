/// General questions outside the app ("what's the latest news", "who won
/// the match", "weather tomorrow") and places ("where is Central Park",
/// "directions to the nearest gas station").
///
///  * Places open Google Maps (app if installed, otherwise the browser).
///  * Everything else is answered by Claude with live web search, as a short
///    spoken reply.
///
/// pubspec.yaml:
///   http: ^1.2.0
///   url_launcher: ^6.3.0
///
/// Configure ONE of these at build time:
///   flutter run --dart-define=AI_PROXY_URL=https://your-server/ai/ask
///   flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...   (testing only)
///
/// Use the proxy for real builds: an API key inside an app can be pulled out
/// of the APK. The proxy just adds the key and forwards the JSON body to
/// https://api.anthropic.com/v1/messages, returning the response unchanged.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class MapIntent {
  /// Place to search for. Empty → just open Maps.
  final String place;

  /// true → turn-by-turn directions, false → show the place.
  final bool directions;

  const MapIntent(this.place, {this.directions = false});

  @override
  String toString() => '${directions ? 'directions' : 'search'}: $place';
}

class GeneralReply {
  /// Text to speak.
  final String text;

  /// Set when the answer is about a place the user wants to see.
  final MapIntent? map;

  const GeneralReply(this.text, {this.map});
}

class GeneralAssistant {
  GeneralAssistant({
    this.proxyUrl = const String.fromEnvironment('AI_PROXY_URL'),
    this.proxyToken = const String.fromEnvironment('AI_PROXY_TOKEN'),
    this.apiKey = const String.fromEnvironment('ANTHROPIC_API_KEY'),
    this.model = 'claude-sonnet-5-5',
    this.country, // two letters, e.g. 'US' – improves local search results
    this.region,
    this.city,
    this.timezone, // IANA, e.g. 'America/Chicago'
  });

  final String proxyUrl;
  final String proxyToken;
  final String apiKey;
  final String model;
  final String? country;
  final String? region;
  final String? city;
  final String? timezone;

  /// Short memory so follow-ups work ("and what about tomorrow?").
  final List<Map<String, dynamic>> _history = [];
  DateTime _lastAsk = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isConfigured => proxyUrl.isNotEmpty || apiKey.isNotEmpty;

  void clearHistory() => _history.clear();

  // ---------------- Places → Google Maps ----------------

  static final RegExp _filler = RegExp(
    r"\b(?:please|kindly|hey quincy|quincy|can you|could you|would you|"
    r"will you|i want to|i wanna|i need to|i'd like to|for me)\b",
    caseSensitive: false,
  );

  static final List<RegExp> _directionPatterns = [
    RegExp(
        r'^(?:navigate|directions?|route|drive|take me|get me|guide me|'
        r'how (?:do|can|should) i (?:get|go)|how to (?:get|go|reach)|'
        r'show (?:me )?(?:the )?(?:way|route|directions?)|'
        r'give me directions?|get directions?)\s+(?:me\s+)?'
        r'(?:to|for|towards|till)\s+(.+)$'),
    RegExp(r'^(?:go|drive|walk)\s+to\s+(.+)$'),
    RegExp(r'^how far is\s+(.+)$'),
  ];

  static final List<RegExp> _searchPatterns = [
    RegExp(r'^(?:open|show|launch)\s+(?:the\s+)?(?:google\s+)?maps?\s+'
        r'(?:of|for|to|at|with)\s+(.+)$'),
    RegExp(r'^(?:show|find|search|locate|look up|search for|show me)\s+(.+?)'
        r'\s+(?:on|in)\s+(?:the\s+)?(?:google\s+)?maps?$'),
    RegExp(r"^(?:where is|where's|wheres|where are|where can i find|"
        r'show me where|location of|address of|what is the address of|'
        r"what's the address of|locate)\s+(.+)$"),
    RegExp(r'^(?:find|show|search for|look for)\s+(?:me\s+)?(?:a\s+|an\s+|some\s+)?'
        r'(.+?\s+(?:near|around|close to)\s+(?:me|here|by|us)(?:\s.*)?)$'),
    RegExp(r'^(.+?\s+near\s+(?:me|here|by|us))$'),
  ];

  static final RegExp _nearest = RegExp(
      r"^(?:where is |where are |where's |find |show |show me |what is |"
      r"what's |whats |take me to |navigate to |directions to )?(?:the\s+)?"
      r'(?:nearest|closest|nearby)\s+(.+)$');

  static final RegExp _openMapsOnly =
      RegExp(r'^(?:open|show|launch)\s+(?:the\s+)?(?:google\s+)?maps?$');

  /// "where is Central Park" → search, "directions to the airport" →
  /// directions, "nearest gas station" → "gas station near me".
  static MapIntent? detectMapIntent(String text) {
    var t = text.toLowerCase().replaceAll(_filler, ' ');
    t = t.replaceAll(RegExp(r'[?!.,]+'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return null;

    if (_openMapsOnly.hasMatch(t)) return const MapIntent('');

    final nearest = _nearest.firstMatch(t);
    if (nearest != null) {
      final what = _cleanPlace(nearest[1]!);
      if (what.isNotEmpty) {
        final directions = RegExp(r'^(?:take me|navigate|directions?)')
            .hasMatch(t);
        return MapIntent('$what near me', directions: directions);
      }
    }

    for (final p in _directionPatterns) {
      final m = p.firstMatch(t);
      if (m != null) {
        final place = _cleanPlace(m[1]!);
        if (place.isNotEmpty) return MapIntent(place, directions: true);
      }
    }
    for (final p in _searchPatterns) {
      final m = p.firstMatch(t);
      if (m != null) {
        final place = _cleanPlace(m[1]!);
        if (place.isNotEmpty) return MapIntent(place);
      }
    }
    return null;
  }

  static String _cleanPlace(String s) {
    var t = s.trim();
    t = t.replaceFirst(RegExp(r'^(?:the|a|an)\s+'), '');
    t = t.replaceFirst(
        RegExp(r'\s+(?:on|in)\s+(?:the\s+)?(?:google\s+)?maps?$'), '');
    t = t.replaceFirst(RegExp(r'\s+(?:located|situated)$'), '');
    return t.trim();
  }

  /// Opens Google Maps. Returns false if nothing could open the link.
  static Future<bool> openMap(MapIntent m) async {
    final Uri uri;
    if (m.place.isEmpty) {
      uri = Uri.https('www.google.com', '/maps');
    } else if (m.directions) {
      uri = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': m.place,
      });
    } else {
      uri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': m.place,
      });
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('⚠️ Could not open maps: $e');
      return false;
    }
  }

  // ---------------- General questions ----------------

  static final RegExp _questionStart = RegExp(
    r"^(?:what|what's|whats|who|who's|whos|when|why|how|which|is|are|was|"
    r'were|do|does|did|can|could|should|will|would|tell me|explain|define|'
    r'give me|search|look up|google|find out|latest|today|news|weather|'
    r"translate|calculate|convert|i want to know|any news|what's new)\b",
    caseSensitive: false,
  );

  static final RegExp _generalTopic = RegExp(
    r'\b(?:news|headlines?|weather|temperature|forecast|rain|score|match|'
    r'game|stock|price|rate|exchange|election|president|prime minister|'
    r'capital|population|meaning|definition|recipe|history|holiday|time in|'
    r'traffic|flight|movie|song|who won|latest|today|tomorrow|yesterday)\b',
    caseSensitive: false,
  );

  /// A question or a request for information (not an app command).
  static bool looksLikeGeneralQuestion(String text) {
    final t = text.toLowerCase().replaceAll(_filler, ' ').trim();
    if (t.endsWith('?')) return true;
    return _questionStart.hasMatch(t) || _generalTopic.hasMatch(t);
  }

  String _systemPrompt() {
    final now = DateTime.now();
    final date = '${now.year}-${_two(now.month)}-${_two(now.day)}';
    return 'You are Quincy, the voice assistant inside an inspection app. '
        'The user is speaking to you, and your reply is read aloud by '
        'text-to-speech. Today is $date.\n'
        'Answer any question: news, weather, sports, places, general '
        'knowledge, maths, definitions and so on. Use web search for '
        'anything current or that may have changed, and give the most '
        'recent facts you find.\n'
        'Reply in two to four short sentences of plain spoken English. No '
        'markdown, lists, headings, links, URLs, emojis or citation marks. '
        'Say numbers and dates the way a person would say them.\n'
        'If you are not sure, say so briefly instead of guessing.\n'
        'If the user wants to see, find or go to a place, add one last line '
        'exactly like "MAP: place name, city" (or "DIRECTIONS: place name, '
        'city" for directions). Do not mention this line in your answer.';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  Future<GeneralReply> ask(String question) async {
    if (!isConfigured) {
      return const GeneralReply(
        "I can't answer general questions yet, because the AI service is "
        'not set up in this app.',
      );
    }

    // Forget the old conversation after a long pause
    if (DateTime.now().difference(_lastAsk) > const Duration(minutes: 10)) {
      _history.clear();
    }
    _lastAsk = DateTime.now();

    _history.add({'role': 'user', 'content': question});
    while (_history.length > 10) {
      _history.removeRange(0, 2); // drop the oldest question + answer
    }

    try {
      final raw = await _callClaude();
      if (raw.trim().isEmpty) {
        _history.removeLast();
        return const GeneralReply(
            "Sorry, I couldn't find an answer to that. Try asking another way.");
      }
      _history.add({'role': 'assistant', 'content': raw});
      return _toReply(raw);
    } on TimeoutException {
      _history.removeLast();
      return const GeneralReply(
          'That took too long. Please check your internet and ask again.');
    } on SocketException {
      _history.removeLast();
      return const GeneralReply(
          "I'm offline right now, so I can't look that up.");
    } catch (e) {
      debugPrint('⚠️ General assistant error: $e');
      _history.removeLast();
      return const GeneralReply(
          "Sorry, I couldn't get an answer right now. Please try again.");
    }
  }

  Future<String> _callClaude() async {
    final messages = List<Map<String, dynamic>>.from(_history);
    final texts = <String>[];

    // A long web search may pause; send the turn back to let it finish.
    for (var round = 0; round < 3; round++) {
      final body = {
        'model': model,
        'max_tokens': 700,
        'system': _systemPrompt(),
        'messages': messages,
        'tools': [
          {
            'type': 'web_search_20250305',
            'name': 'web_search',
            'max_uses': 3,
            if (country != null || city != null || timezone != null)
              'user_location': {
                'type': 'approximate',
                if (city != null) 'city': city,
                if (region != null) 'region': region,
                if (country != null) 'country': country,
                if (timezone != null) 'timezone': timezone,
              },
          },
        ],
      };

      final useProxy = proxyUrl.isNotEmpty;
      final res = await http
          .post(
            Uri.parse(useProxy
                ? proxyUrl
                : 'https://api.anthropic.com/v1/messages'),
            headers: {
              'content-type': 'application/json',
              if (useProxy && proxyToken.isNotEmpty)
                'authorization': 'Bearer $proxyToken',
              if (!useProxy) 'x-api-key': apiKey,
              if (!useProxy) 'anthropic-version': '2023-06-01',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 40));

      if (res.statusCode != 200) {
        throw HttpException('AI service ${res.statusCode}: ${res.body}');
      }

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final content = (data['content'] as List?) ?? const [];
      for (final block in content) {
        if (block is Map && block['type'] == 'text') {
          texts.add('${block['text'] ?? ''}');
        }
      }

      if (data['stop_reason'] != 'pause_turn') break;
      messages.add({'role': 'assistant', 'content': content});
    }
    return texts.join();
  }

  static final RegExp _mapLine = RegExp(
    r'^\s*(MAP|DIRECTIONS)\s*:\s*(.+?)\s*$',
    multiLine: true,
    caseSensitive: false,
  );

  GeneralReply _toReply(String raw) {
    MapIntent? map;
    final m = _mapLine.firstMatch(raw);
    if (m != null) {
      map = MapIntent(m[2]!.trim(),
          directions: m[1]!.toUpperCase() == 'DIRECTIONS');
    }
    final spoken = _forSpeech(raw.replaceAll(_mapLine, ' '));
    return GeneralReply(
      spoken.isEmpty && map != null ? 'Opening ${map.place} in Maps.' : spoken,
      map: map,
    );
  }

  /// Removes anything that sounds bad when read aloud.
  static String _forSpeech(String s) {
    var t = s;
    t = t.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!);
    t = t.replaceAll(RegExp(r'https?://\S+'), '');
    t = t.replaceAll(RegExp(r'^\s*#+\s*', multiLine: true), '');
    t = t.replaceAll(RegExp(r'^\s*(?:[-*•]|\d+[.)])\s+', multiLine: true), '');
    t = t.replaceAll(RegExp(r'[*_`#>]'), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Keep it short for speech: cut at a sentence end near 600 characters
    if (t.length > 600) {
      final cut = t.lastIndexOf(RegExp(r'[.!?]\s'), 600);
      t = cut > 200 ? t.substring(0, cut + 1) : '${t.substring(0, 600)}…';
    }
    return t;
  }
}