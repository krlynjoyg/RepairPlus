import 'dart:convert';
import 'package:http/http.dart' as http;

/// Normalized tutorial model used inside the app
class NormalizedTutorial {
  final String id;
  final String title;
  final String subtitle;
  final String image;
  final String url;
  final String source;

  NormalizedTutorial({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.url,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'image': image,
    'url': url,
    'source': source,
  };
}

/// Fetch iFixit guides by query
Future<List<NormalizedTutorial>> fetchIfixitGuides(String query,
    {int limit = 20}) async {
  final url =
      'https://www.ifixit.com/api/2.0/search/${Uri.encodeComponent(query)}?doctypes=guide&limit=$limit';
  final resp = await http.get(Uri.parse(url));
  final List<NormalizedTutorial> guides = [];

  if (resp.statusCode == 200) {
    final Map<String, dynamic> data = json.decode(resp.body);
    final results = data['results'];
    if (results is List) {
      for (var item in results) {
        try {
          final gid = item['guideid']?.toString() ??
              item['id']?.toString() ??
              item['title'].toString();
          String imageUrl =
              "https://www.ifixit.com/static/images/meta/ifixit-meta-image.jpg";
          if (item['image'] is Map && item['image']['standard'] != null) {
            imageUrl = item['image']['standard'];
          } else if (item['image'] is String) {
            imageUrl = item['image'];
          }

          final title = item['title'] ?? 'Untitled Guide';
          final subtitle = item['summary'] ?? '';
          final url =
              'https://www.ifixit.com/Guide/${Uri.encodeComponent(title)}/$gid';

          guides.add(NormalizedTutorial(
            id: 'ifixit_$gid',
            title: title,
            subtitle: subtitle,
            image: imageUrl,
            url: url,
            source: 'iFixit',
          ));
        } catch (_) {}
      }
    }
  }

  return guides;
}


Future<List<NormalizedTutorial>> fetchYoutubeVideos(
    String query,
    String apiKey, {
      int maxResults = 5,
    }) async {
  if (apiKey.isEmpty) return [];

  final youtubeUrl =
      'https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&maxResults=$maxResults&q=${Uri.encodeComponent(query)}&key=$apiKey';
  final resp = await http.get(Uri.parse(youtubeUrl));
  final List<NormalizedTutorial> videos = [];

  if (resp.statusCode == 200) {
    final Map<String, dynamic> data = json.decode(resp.body);
    final items = data['items'];

    if (items is List) {
      for (var item in items) {
        try {
          final id = item['id']?['videoId'] ?? item['id']?.toString();
          final snippet = item['snippet'] ?? {};
          final title = snippet['title'] ?? 'Untitled Video';
          final description = snippet['description'] ?? '';
          final thumb = snippet['thumbnails']?['high']?['url'] ??
              snippet['thumbnails']?['default']?['url'] ??
              '';
          final url = 'https://www.youtube.com/watch?v=$id';

          videos.add(NormalizedTutorial(
            id: 'youtube_$id',
            title: title,
            subtitle: description,
            image: thumb,
            url: url,
            source: 'YouTube',
          ));
        } catch (_) {}
      }
    }
  }

  return videos;
}
