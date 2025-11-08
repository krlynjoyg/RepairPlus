import 'dart:convert';
import 'package:http/http.dart' as http;

class YouTubeApiService {
  final String apiKey = 'AIzaSyDHPDJWZqdS8px7AWGW7avsSZU4mHRtz_k';
  final String baseUrl = 'https://www.googleapis.com/youtube/v3/search';

  Future<List<Map<String, dynamic>>> fetchTutorials(String query) async {
    final url = Uri.parse(
      '$baseUrl?part=snippet&q=$query+repair+tutorial&type=video&maxResults=10&key=$apiKey',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List videos = data['items'];

      return videos.map((video) {
        return {
          'title': video['snippet']['title'],
          'thumbnail': video['snippet']['thumbnails']['high']['url'],
          'videoId': video['id']['videoId'],
          'channel': video['snippet']['channelTitle'],
        };
      }).toList();
    } else {
      throw Exception('Failed to load tutorials: ${response.reasonPhrase}');
    }
  }
}
