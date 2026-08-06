class GelatoType {
  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  const GelatoType({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.isActive = true,
  });

  factory GelatoType.fromMap(Map<String, dynamic> data, String id) {
    return GelatoType(
      id: id,
      name: (data['name'] ?? '').toString(),
      sortOrder: data['sort_order'] is int ? data['sort_order'] as int : 0,
      isActive: data['is_active'] != false,
    );
  }

  factory GelatoType.fromSnapshotMap(Map<String, dynamic> data) {
    return GelatoType(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      sortOrder: 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'sort_order': sortOrder, 'is_active': isActive};
  }

  Map<String, dynamic> toSnapshotMap() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) {
    return other is GelatoType &&
        other.id == id &&
        other.name == name &&
        other.sortOrder == sortOrder &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder, isActive);
}

const defaultGelatoTypes = <GelatoType>[
  GelatoType(id: 'cono', name: 'Cono', sortOrder: 0),
  GelatoType(id: 'coppetta', name: 'Coppetta', sortOrder: 1),
  GelatoType(id: 'brioche', name: 'Brioche', sortOrder: 2),
  GelatoType(id: 'vaschetta', name: 'Vaschetta', sortOrder: 3),
  GelatoType(id: 'frappe', name: 'Frappè', sortOrder: 4),
  GelatoType(id: 'affogato', name: 'Affogato', sortOrder: 5),
  GelatoType(id: 'granita', name: 'Granita', sortOrder: 6),
  GelatoType(id: 'stecco', name: 'Stecco', sortOrder: 7),
  GelatoType(id: 'biscotto-gelato', name: 'Biscotto gelato', sortOrder: 8),
  GelatoType(id: 'coppa-dessert', name: 'Coppa dessert', sortOrder: 9),
  GelatoType(id: 'semifreddo', name: 'Semifreddo', sortOrder: 10),
  GelatoType(id: 'torta-gelato', name: 'Torta gelato', sortOrder: 11),
  GelatoType(id: 'altro', name: 'Altro', sortOrder: 12),
];
