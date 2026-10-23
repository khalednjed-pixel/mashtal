import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import 'common.dart';

/// A freely licensed photo of a species from Wikipedia / Wikimedia Commons.
class WikiPhoto {
  const WikiPhoto(this.imageUrl, this.pageUrl);
  final String imageUrl;
  final String pageUrl;
}

/// Looks up plant photos through the Wikipedia REST API, once per species.
class WikiPhotos {
  WikiPhotos._();

  /// Turned off in tests, which have no network.
  static bool enabled = true;
  static final Map<String, Future<WikiPhoto?>> _cache = {};

  static String titleFor(Plant p) => p.wikiTitle ?? p.scientificName;

  static Future<WikiPhoto?> of(Plant p) {
    if (!enabled || p.isCustom || p.scientificName.isEmpty) return Future.value(null);
    final title = titleFor(p);
    return _cache.putIfAbsent(title, () => _fetch(title));
  }

  static Future<WikiPhoto?> _fetch(String title) async {
    try {
      final uri = Uri(
        scheme: 'https',
        host: 'en.wikipedia.org',
        pathSegments: ['api', 'rest_v1', 'page', 'summary', title.replaceAll(' ', '_')],
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final image = (j['thumbnail'] as Map?)?['source'] as String?;
      final page = ((j['content_urls'] as Map?)?['desktop'] as Map?)?['page'] as String?;
      if (image == null) return null;
      return WikiPhoto(image, page ?? 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title)}');
    } catch (_) {
      return null;
    }
  }
}

final Map<int, Uint8List> _decoded = {};

/// Decodes a base64 photo once and keeps the bytes.
Uint8List decodePhoto(String base64Photo) =>
    _decoded.putIfAbsent(Object.hash(base64Photo.length, base64Photo.hashCode), () => base64Decode(base64Photo));

/// Square plant picture: the nursery's own photo if given, else the plant's
/// uploaded photo, else its Wikipedia photo, else a coloured icon.
class PlantPhoto extends StatelessWidget {
  const PlantPhoto({super.key, required this.plant, this.size = 56, this.listingPhoto, this.radius});

  final Plant plant;
  final double size;
  final String? listingPhoto;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final own = listingPhoto ?? plant.photo;
    final fallback = PlantAvatar(plant: plant, size: size);
    Widget child;
    if (own != null) {
      child = Image.memory(decodePhoto(own), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true);
    } else {
      child = FutureBuilder<WikiPhoto?>(
        future: WikiPhotos.of(plant),
        builder: (context, snap) {
          final photo = snap.data;
          if (photo == null) return fallback;
          return Image.network(
            photo.imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            errorBuilder: (_, _, _) => fallback,
            loadingBuilder: (_, img, progress) => progress == null ? img : fallback,
          );
        },
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius ?? size / 4), child: SizedBox(width: size, height: size, child: child));
  }
}

/// "Photo: Wikipedia" link under a species photo (licence attribution).
class PhotoCredit extends StatelessWidget {
  const PhotoCredit({super.key, required this.plant});
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    if (plant.photo != null) return const SizedBox.shrink();
    return FutureBuilder<WikiPhoto?>(
      future: WikiPhotos.of(plant),
      builder: (context, snap) {
        final photo = snap.data;
        if (photo == null) return const SizedBox.shrink();
        return TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
          icon: const Icon(Icons.photo_camera_outlined, size: 16),
          label: Text(context.tr('photoCredit'), style: Theme.of(context).textTheme.bodySmall),
          onPressed: () => launchUrl(Uri.parse(photo.pageUrl), webOnlyWindowName: kIsWeb ? '_blank' : null),
        );
      },
    );
  }
}
