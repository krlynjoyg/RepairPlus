class Tutorial {
  final int guideId;
  final String title;
  final String imageUrl;
  final String url;

  Tutorial({
    required this.guideId,
    required this.title,
    required this.imageUrl,
    required this.url,
  });

  factory Tutorial.fromJson(Map<String, dynamic> json) {
    return Tutorial(
      guideId: json['guideid'] ?? 0,
      title: json['title'] ?? 'Untitled Guide',
      imageUrl: json['image']?['medium'] ?? '',
      url: json['url'] ?? '',
    );
  }
}