import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/strings.dart';
import 'plant_photo.dart';

/// Picks a photo from the gallery (or camera on a phone), shrunk so it fits in
/// device storage, and returns it as base64 JPEG.
Future<String?> pickPlantPhoto(BuildContext context) async {
  var source = ImageSource.gallery;
  if (!kIsWeb) {
    final chosen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: Text(c.tr('camera')), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: Text(c.tr('gallery')), onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ]),
      ),
    );
    if (chosen == null) return null;
    source = chosen;
  }
  final file = await ImagePicker().pickImage(source: source, maxWidth: 480, maxHeight: 480, imageQuality: 60);
  if (file == null) return null;
  return base64Encode(await file.readAsBytes());
}

/// Photo box with add / change / remove buttons.
class PhotoField extends StatelessWidget {
  const PhotoField({super.key, required this.photo, required this.onChanged});

  final String? photo;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 88,
            height: 88,
            color: scheme.surfaceContainerHighest,
            child: photo == null
                ? Icon(Icons.add_a_photo_outlined, color: scheme.onSurfaceVariant)
                : Image.memory(decodePhoto(photo!), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('pickPhoto'),
                icon: const Icon(Icons.photo_outlined),
                label: Text(context.tr(photo == null ? 'addPhoto' : 'changePhoto')),
                onPressed: () async {
                  final picked = await pickPlantPhoto(context);
                  if (picked != null) onChanged(picked);
                },
              ),
              if (photo != null)
                TextButton(onPressed: () => onChanged(null), child: Text(context.tr('removePhoto'))),
            ],
          ),
        ),
      ],
    );
  }
}
