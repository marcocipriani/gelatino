import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

final class EmulatorPhotoFixture {
  const EmulatorPhotoFixture._();

  static const fileName = 'gelatino-e2e-fixture.jpg';
  static final Uint8List bytes = base64Decode(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoH'
    'BwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRQBAwQEBQQF'
    'CQUFCRQNCw0UFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQU'
    'FBQUFBQUFBQUFP/AABEIAAIAAgMBEQACEQEDEQH/xAGiAAABBQEBAQEBAQAAAAAAAA'
    'AAAQIDBAUGBwgJCgsQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQ'
    'ygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RV'
    'VldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys'
    '7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+gEAAw'
    'EBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoLEQACAQIEBAMEBwUEBAABAncAAQIDEQQF'
    'ITEGEkFRB2FxEyIygQgUQpGhscEJIzNS8BVictEKFiQ04SXxFxgZGiYnKCkqNTY3O'
    'Dk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqCg4SFhoeIiYqSk5SVl'
    'peYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2dri4+Tl5ufo6'
    'ery8/T19vf4+fr/2gAMAwEAAhEDEQA/AOi0bxdrq6PYga1qIAgjwBdSf3R715+YZR'
    'lyxlb/AGaHxS+xHu/I/NMzzvNFjq6WKqfHL7cu78z/AP/Z',
  );
}

final class EmulatorPhotoFixtureButton extends StatelessWidget {
  const EmulatorPhotoFixtureButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: OutlinedButton.icon(
      key: const ValueKey('e2e-photo-fixture'),
      onPressed: onPressed,
      icon: const Icon(Icons.science_outlined),
      label: const Text('Usa foto E2E'),
    ),
  );
}
