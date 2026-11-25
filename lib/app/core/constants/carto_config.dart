/// CARTO Basemaps & Location Data Services (LDS) Routing configuration.
///
/// Reference: https://docs.carto.com/carto-for-developers/reference/carto-api/maps-api
class CartoConfig {
  CartoConfig._();

  /// TODO: Set your CARTO Cloud region API base URL (no trailing slash), e.g.:
  /// - `https://gcp-us-east1.api.carto.com`
  /// - `https://gcp-europe-west1.api.carto.com`
  /// - `https://aws-us-east-1.api.carto.com`
  static const String apiBaseUrl = 'https://gcp-us-east1.api.carto.com';

  /// TODO: Paste your CARTO API Access Token (Workspace -> Developers -> Credentials).
  /// Enable LDS API permissions on the token to use `/v3/lds/routing`.
  static const String accessToken = '';

  /// Optional separate CARTO Basemap key (`?key=...`). If left empty, falls
  /// back to [accessToken] when non-empty.
  static const String basemapApiKey = 'cb1_2u39_1_bc00bc48de4b6e1f3377478f';
  ///                               API ni sir jhun      ^       BWHAHAHAHAHAHAHA 

  /// CARTO raster basemap style:
  /// - `'rastertiles/voyager'` (Recommended colorful street basemap)
  /// - `'light_all'` (Positron minimal light grey)
  /// - `'dark_all'` (Dark Matter)
  static const String basemapStyle = 'rastertiles/voyager';

  /// CARTO LDS transport mode (`'car'`, `'truck'`, `'bicycle'`, `'foot'`).
  static const String routingMode = 'car';

  /// TODO: Paste your TomTom Developer API key for live Traffic Flow tiles
  /// (50,000 free tile requests/day, no credit card required).
  static const String tomtomTrafficApiKey = 'O2mwpK3eluSXpATk8t5lpuV2LOTjc1Jr';

  static bool get hasTomTomTrafficKey => tomtomTrafficApiKey.trim().isNotEmpty;

  /// Transparent TomTom Traffic Flow tile overlay URL (`relative` congestion colors).
  static String get tomtomTrafficTileUrlTemplate {
    final key = Uri.encodeQueryComponent(tomtomTrafficApiKey.trim());
    return 'https://api.tomtom.com/traffic/map/4/tile/flow/relative/{z}/{x}/{y}.png?thickness=6&key=$key';
  }

  static String get effectiveBasemapKey {
    final explicit = basemapApiKey.trim();
    if (explicit.isNotEmpty) return explicit;
    return accessToken.trim();
  }

  /// Raster tile URL template for `flutter_map` `TileLayer` (256px standard tiles
  /// for fast 60/120fps pan & zoom without 4x retina tile thrashing).
  static String get tileUrlTemplate {
    final key = effectiveBasemapKey;
    final query = key.isNotEmpty ? '?key=${Uri.encodeQueryComponent(key)}' : '';
    return 'https://{s}.basemaps.cartocdn.com/$basemapStyle/{z}/{x}/{y}.png$query';
  }

  /// Base map without street/city labels (used underneath live traffic lines).
  static String get noLabelsTileUrlTemplate {
    final style = switch (basemapStyle) {
      'light_all' => 'light_nolabels',
      'dark_all' => 'dark_nolabels',
      _ => 'rastertiles/voyager_nolabels',
    };
    final key = effectiveBasemapKey;
    final query = key.isNotEmpty ? '?key=${Uri.encodeQueryComponent(key)}' : '';
    return 'https://{s}.basemaps.cartocdn.com/$style/{z}/{x}/{y}.png$query';
  }

  /// Transparent labels-only overlay (rendered above live traffic lines).
  static String get onlyLabelsTileUrlTemplate {
    final style = switch (basemapStyle) {
      'light_all' => 'light_only_labels',
      'dark_all' => 'dark_only_labels',
      _ => 'rastertiles/voyager_only_labels',
    };
    final key = effectiveBasemapKey;
    final query = key.isNotEmpty ? '?key=${Uri.encodeQueryComponent(key)}' : '';
    return 'https://{s}.basemaps.cartocdn.com/$style/{z}/{x}/{y}.png$query';
  }
}
