class CityApi {
  CityApi({required this.results});

  List<Result> results;

  factory CityApi.fromJson(Map<String, dynamic> json) => CityApi(
    results: json['results'] == null
        ? List<Result>.empty()
        : List<Result>.from(json['results'].map((x) => Result.fromJson(x))),
  );
}

class Result {
  Result({
    required this.admin1,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
  });

  String admin1;
  String name;
  double latitude;
  double longitude;
  String? country;

  factory Result.fromJson(Map<String, dynamic> json) => Result(
    admin1: json['admin2'] ?? json['admin1'] ?? '',
    name: json['name'] ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    country: json['country'],
  );
}
