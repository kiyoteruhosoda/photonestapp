import 'package:photonest/domain/value_objects/tag_id.dart';

/// What kind of thing a tag names, in the server's own vocabulary.
///
/// The library is tagged by more than one axis at once — "Tokyo" as a place
/// and "Tokyo" as an event name are different tags — so the attribute is what
/// tells two similarly named tags apart in a suggestion list.
enum TagAttribute {
  thing,
  person,
  place,
  event,
  scene,
  activity,
  source,
  others;

  /// The attribute the server spells [raw], or null when it names none of
  /// them.
  ///
  /// Null rather than a fallback to [others]: a tag stored before the
  /// current vocabulary existed has *no known* attribute, and labelling it
  /// "others" would state something the server never said.
  static TagAttribute? tryParse(String? raw) {
    if (raw == null) return null;
    for (final attribute in TagAttribute.values) {
      if (attribute.wireValue == raw) return attribute;
    }
    return null;
  }

  /// How the server spells this attribute in `attr`.
  String get wireValue => name;
}

/// A label the library applies to media.
///
/// Two tags are the same when their [id] is the same — a renamed tag is still
/// the same tag.
final class Tag {
  const Tag({required this.id, required this.name, this.attribute});

  final TagId id;

  /// The tag as the library spells it, for display and for matching what the
  /// reader types.
  final String name;

  /// What kind of thing the tag names, when the server reported a known one.
  final TagAttribute? attribute;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Tag && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Tag(${id.value}, $name)';
}
