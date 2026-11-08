import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../data/seed/plant_media.g.dart';
import '../../data/seed/plant_photos.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../models/plant_media.dart';
import '../theme.dart';
import 'common.dart';

/// A freely licensed photo of a species from Wikipedia / Wikimedia Commons.
class WikiPhoto {
  const WikiPhoto(this.imageUrl, this.pageUrl, {this.media, this.asset, this.edited = false, this.aiGenerated = false, this.studio = false});
  final String imageUrl;
  final String pageUrl;

  /// Bundled shop photo (assets/plants/), shown instead of [imageUrl].
  final String? asset;

  /// The bundled photo's background was changed (CC licences ask to say so).
  final bool edited;

  /// The bundled image is an AI illustration of the species, not a photo.
  final bool aiGenerated;

  /// Plain white studio background.
  final bool studio;

  /// Author and licence, when the photo comes from the imported dataset.
  final PlantMedia? media;
}

/// Imported Wikidata / Commons record of a knowledge-base plant, if any.
PlantMedia? mediaFor(Plant p) => p.isCustom ? null : plantMedia[p.id];

/// Plant photos: the imported Commons photo with its credit
/// (docs/plant-data.md), else a lookup through the Wikipedia REST API, once
/// per species.
class WikiPhotos {
  WikiPhotos._();

  /// Turned off in tests, which have no network.
  static bool enabled = true;
  static final Map<String, Future<WikiPhoto?>> _cache = {};

  static String titleFor(Plant p) => p.wikiTitle ?? p.scientificName;

  static Future<WikiPhoto?> of(Plant p) {
    if (!enabled || p.isCustom || p.scientificName.isEmpty) return Future.value(null);
    final shop = shopPhotos[p.id];
    if (shop != null) {
      final media = PlantMedia(
        wikidataId: mediaFor(p)?.wikidataId ?? '',
        photoFile: shop.file,
        photoAuthor: shop.author,
        photoLicence: shop.licence,
        photoLicenceUrl: shop.licenceUrl,
      );
      return Future.value(
        WikiPhoto(shop.asset, media.photoPageUrl!, media: media, asset: shop.asset, edited: shop.edited, aiGenerated: shop.aiGenerated, studio: shop.studio),
      );
    }
    final media = mediaFor(p);
    if (media != null && media.hasPhoto) {
      return Future.value(WikiPhoto(media.photoUrl!, media.photoPageUrl!, media: media));
    }
    final title = titleFor(p);
    return _cache.putIfAbsent(title, () => _fetch(title));
  }

  static Future<WikiPhoto?> _fetch(String title) async {
    try {
      final uri = Uri(scheme: 'https', host: 'en.wikipedia.org', pathSegments: ['api', 'rest_v1', 'page', 'summary', title.replaceAll(' ', '_')]);
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
Uint8List decodePhoto(String base64Photo) => _decoded.putIfAbsent(Object.hash(base64Photo.length, base64Photo.hashCode), () => base64Decode(base64Photo));

/// Square plant picture: the nursery's own photo if given, else the plant's
/// uploaded photo, else its Wikipedia photo, else a placeholder icon.
/// Photos are cropped to cover on a ground-tinted placeholder, so uneven
/// photos still look like a set.
class PlantPhoto extends StatelessWidget {
  const PlantPhoto({super.key, required this.plant, double this.size = 56, this.listingPhoto, this.radius});

  /// Fills its parent (give it a fixed aspect, e.g. with [AspectRatio]).
  /// Used for the photo-first shop cards.
  const PlantPhoto.fill({super.key, required this.plant, this.listingPhoto, this.radius}) : size = null;

  final Plant plant;

  final double? size;
  final String? listingPhoto;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final own = listingPhoto ?? plant.photo;
    final size = this.size;
    final Widget fallback = size == null ? PlantAvatar.fill(plant: plant) : PlantAvatar(plant: plant, size: size);
    Widget child;
    if (own != null) {
      child = Image.memory(decodePhoto(own), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true);
    } else {
      child = FutureBuilder<WikiPhoto?>(
        future: WikiPhotos.of(plant),
        builder: (context, snap) {
          final photo = snap.data;
          if (photo == null) return fallback;
          if (photo.asset != null) {
            return Image.asset(photo.asset!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
          }
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
    final r = radius ?? (size == null ? 0 : MashtalSpace.radius);
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: ColoredBox(
        color: MashtalColors.ground,
        child: size == null ? SizedBox.expand(child: child) : SizedBox(width: size, height: size, child: child),
      ),
    );
  }
}

/// Credit under a species photo. Imported Commons photos show author and
/// licence (CC BY / BY-SA need both); others show "Photo: Wikipedia".
class PhotoCredit extends StatelessWidget {
  const PhotoCredit({super.key, required this.plant});
  final Plant plant;

  static void _open(String url) => launchUrl(Uri.parse(url), webOnlyWindowName: kIsWeb ? '_blank' : null);

  @override
  Widget build(BuildContext context) {
    if (plant.photo != null) return const SizedBox.shrink();
    return FutureBuilder<WikiPhoto?>(
      future: WikiPhotos.of(plant),
      builder: (context, snap) {
        final photo = snap.data;
        if (photo == null) return const SizedBox.shrink();
        final small = Theme.of(context).textTheme.bodySmall;
        final media = photo.media;
        if (photo.aiGenerated) {
          return Row(
            key: const Key('photoCredit'),
            children: [
              Icon(Icons.image_outlined, size: 16, color: MashtalColors.muted),
              const SizedBox(width: 4),
              Text(context.tr('photoAi'), style: small),
            ],
          );
        }
        final style = TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, minimumSize: const Size(0, 32));
        if (media == null) {
          return TextButton.icon(
            style: style,
            icon: const Icon(Icons.photo_camera_outlined, size: 16),
            label: Text(context.tr('photoCredit'), style: small),
            onPressed: () => _open(photo.pageUrl),
          );
        }
        return Wrap(
          key: const Key('photoCredit'),
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            TextButton.icon(
              style: style,
              icon: const Icon(Icons.photo_camera_outlined, size: 16),
              label: Text('${context.tr('photoBy')}: ${media.photoAuthor ?? 'Wikimedia Commons'}', style: small),
              onPressed: () => _open(photo.pageUrl),
            ),
            if (media.photoLicence != null)
              TextButton(
                style: style,
                onPressed: media.photoLicenceUrl == null ? null : () => _open(media.photoLicenceUrl!),
                child: Text(media.photoLicence!, style: small),
              ),
            if (photo.edited) Text(context.tr('photoEdited'), style: small),
          ],
        );
      },
    );
  }
}
