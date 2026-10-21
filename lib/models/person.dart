// Database data models.
// A student/employee in `persons`.
class Person {
  final String? id;
  final String formId;
  final String name;
  final String? memberCode;
  final String? groupName;

  Person({
    this.id,
    required this.formId,
    required this.name,
    this.memberCode,
    this.groupName,
  });

  Person copyWith({String? name, String? memberCode, String? groupName}) =>
      Person(
        id: id,
        formId: formId,
        name: name ?? this.name,
        memberCode: memberCode ?? this.memberCode,
        groupName: groupName ?? this.groupName,
      );

  Map<String, dynamic> toSupabase() => {
        if (id != null) 'id': id,
        'form_id': formId,
        'name': name.trim(),
        'member_code': _clean(memberCode),
        'group_name': _clean(groupName),
      };

  factory Person.fromSupabase(Map<String, dynamic> json) => Person(
        id: json['id']?.toString(),
        formId: json['form_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        memberCode: json['member_code']?.toString(),
        groupName: json['group_name']?.toString(),
      );

  static String? _clean(String? input) {
    final trimmed = input?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
