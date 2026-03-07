class User {
  final String id;
  final String name;
  final DateTime createdDate;

  User({required this.id, required this.name, required this.createdDate});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdDate': createdDate.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      createdDate: DateTime.parse(map['createdDate']),
    );
  }
}
