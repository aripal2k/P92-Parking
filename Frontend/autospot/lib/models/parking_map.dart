class ParkingMap {
  final String building;
  final int level;
  final int rows;
  final int cols;
  final List<dynamic> entrances;
  final List<dynamic> exits;
  final List<dynamic> slots;
  final List<dynamic> corridors;
  final List<dynamic> walls;
  final List<dynamic> ramps;

  ParkingMap({
    required this.building,
    required this.level,
    required this.rows,
    required this.cols,
    required this.entrances,
    required this.exits,
    required this.slots,
    required this.corridors,
    required this.walls,
    required this.ramps,
  });

  factory ParkingMap.fromJson(Map<String, dynamic> json) {
    return ParkingMap(
      building: json['building'] ?? 'Unknown',
      level: json['level'] ?? 1,
      rows: json['size']?['rows'] ?? 6,
      cols: json['size']?['cols'] ?? 6,
      entrances: json['entrances'] ?? [],
      exits: json['exits'] ?? [],
      slots: json['slots'] ?? [],
      corridors: json['corridors'] ?? [],
      walls: json['walls'] ?? [],
      ramps: json['ramps'] ?? [],
    );
  }
}
