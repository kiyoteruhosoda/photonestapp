import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/entities/tag.dart';
import 'package:photonest/domain/value_objects/tag_id.dart';

void main() {
  group('TagAttribute', () {
    test('parses every attribute the server spells', () {
      for (final attribute in TagAttribute.values) {
        expect(TagAttribute.tryParse(attribute.wireValue), attribute);
      }
    });

    test('leaves an unknown or absent attribute unset', () {
      // Not "others": a tag stored before this vocabulary existed has no
      // known attribute, and labelling it would state something the server
      // never said.
      expect(TagAttribute.tryParse('colour'), isNull);
      expect(TagAttribute.tryParse(null), isNull);
      expect(TagAttribute.tryParse(''), isNull);
    });
  });

  group('Tag', () {
    test('is equal by id, not by name — a renamed tag is the same tag', () {
      final renamed = Tag(id: TagId(3), name: 'Kyōto');
      expect(Tag(id: TagId(3), name: 'Kyoto'), renamed);
      expect({Tag(id: TagId(3), name: 'Kyoto'), renamed}, hasLength(1));
      expect(Tag(id: TagId(4), name: 'Kyoto'), isNot(renamed));
    });

    test('keeps the attribute the server reported', () {
      expect(
        Tag(
          id: TagId(3),
          name: 'Kyoto',
          attribute: TagAttribute.place,
        ).attribute,
        TagAttribute.place,
      );
      expect(Tag(id: TagId(3), name: 'Kyoto').attribute, isNull);
    });

    test('describes itself with its id and name', () {
      expect(Tag(id: TagId(3), name: 'Kyoto').toString(), 'Tag(3, Kyoto)');
    });
  });
}
