import 'dart:convert';
import 'dart:io';

/// Play Store app categories (games excluded; Flutter games are rare and
/// the game charts would crowd out apps).
const playCategories = [
  'ART_AND_DESIGN',
  'AUTO_AND_VEHICLES',
  'BEAUTY',
  'BOOKS_AND_REFERENCE',
  'BUSINESS',
  'COMICS',
  'COMMUNICATION',
  'DATING',
  'EDUCATION',
  'ENTERTAINMENT',
  'EVENTS',
  'FINANCE',
  'FOOD_AND_DRINK',
  'HEALTH_AND_FITNESS',
  'HOUSE_AND_HOME',
  'LIFESTYLE',
  'MAPS_AND_NAVIGATION',
  'MEDICAL',
  'MUSIC_AND_AUDIO',
  'NEWS_AND_MAGAZINES',
  'PARENTING',
  'PERSONALIZATION',
  'PHOTOGRAPHY',
  'PRODUCTIVITY',
  'SHOPPING',
  'SOCIAL',
  'SPORTS',
  'TOOLS',
  'TRAVEL_AND_LOCAL',
  'VIDEO_PLAYERS',
  'WEATHER',
];

class PlayApp {
  PlayApp(this.appId, this.title, this.installs);

  factory PlayApp.fromJson(Map<String, Object?> j) => PlayApp(
    j['appId']! as String,
    j['title'] as String?,
    j['installs'] as int?,
  );

  final String appId;
  final String? title;

  /// Exact install count from the details page (not the "10M+" bucket).
  final int? installs;

  Map<String, Object?> toJson() => {
    'appId': appId,
    'title': title,
    'installs': installs,
  };
}

final _detailsId = RegExp(r'details\?id=([A-Za-z0-9._]+)');

/// `["10,000,000+",10000000,21987452,"10M+"]` on a details page.
final installsPattern = RegExp(r'\["[0-9,]+\+",\d+,(\d+),"[^"]+"\]');
final _title = RegExp(r'<title[^>]*>([^<]+?) - Apps on Google Play');

String? _unescape(String? s) => s
    ?.replaceAll('&amp;', '&')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');

class PlaySearchThrottled implements Exception {
  PlaySearchThrottled(this.message);
  final String message;
  @override
  String toString() =>
      '$message after ${PlayWeb.searchBackoff.length} retries; '
      'Play is throttling. Wait a while and rerun search (it only adds).';
}

class PlayWeb {
  PlayWeb({this.country = 'US', this.language = 'en'});

  final String country;
  final String language;
  final _client = HttpClient()..userAgent = 'Mozilla/5.0';

  Future<String> _get(String path) async {
    final base = Uri.parse('https://play.google.com$path');
    final uri = base.replace(
      queryParameters: {...base.queryParameters, 'hl': language, 'gl': country},
    );
    final req = await _client.getUrl(uri);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${res.statusCode}', uri: uri);
    }
    return body;
  }

  Iterable<String> _ids(String html) =>
      _detailsId.allMatches(html).map((m) => m.group(1)!);

  /// App ids from the top charts page and every app category page.
  Future<Set<String>> harvestIds({void Function(String)? log}) async {
    final ids = <String>{};
    for (final path in [
      '/store/apps/top',
      for (final c in playCategories) '/store/apps/category/$c',
    ]) {
      final before = ids.length;
      ids.addAll(_ids(await _get(path)));
      log?.call('$path: +${ids.length - before}');
    }
    return ids;
  }

  /// App ids from Play search, up to 30 per term.
  Future<Set<String>> searchIds(
    Iterable<String> terms, {
    void Function(String)? log,
  }) async {
    final ids = <String>{};
    for (final term in terms) {
      final before = ids.length;
      ids.addAll(await _searchOne(term));
      log?.call('"$term": +${ids.length - before}');
      await Future<void>.delayed(searchPause);
    }
    return ids;
  }

  /// Pause between searches; Play throttles fast sequential searches.
  static const searchPause = Duration(milliseconds: 1500);

  /// One search page. An error or an empty page is treated as throttling
  /// (real terms return results): wait and retry, then stop the run rather
  /// than record a silently empty search.
  Future<Iterable<String>> _searchOne(String term) async {
    final q = Uri.encodeQueryComponent(term);
    Object? last;
    for (final wait in [Duration.zero, ...searchBackoff]) {
      await Future<void>.delayed(wait);
      try {
        final found = _ids(await _get('/store/search?q=$q&c=apps')).toList();
        if (found.isNotEmpty) return found;
        last = 'no results';
      } on Object catch (e) {
        last = e;
      }
    }
    throw PlaySearchThrottled('Play search for "$term" ($country): $last');
  }

  static const searchBackoff = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
  ];

  Future<PlayApp> details(String appId) async {
    final html = await _get('/store/apps/details?id=$appId');
    final installs = installsPattern.firstMatch(html)?.group(1);
    return PlayApp(
      appId,
      _unescape(_title.firstMatch(html)?.group(1)),
      installs == null ? null : int.parse(installs),
    );
  }

  /// Fetches details for [ids] with bounded concurrency.
  Future<List<PlayApp>> detailsAll(
    Iterable<String> ids, {
    int concurrency = 8,
    void Function(PlayApp)? onEach,
  }) async {
    final queue = ids.toList();
    final results = <PlayApp>[];
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final id = queue.removeLast();
        try {
          final app = await details(id);
          results.add(app);
          onEach?.call(app);
        } on Object catch (e) {
          stderr.writeln('details $id failed: $e');
        }
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));
    return results;
  }

  void close() => _client.close();
}
