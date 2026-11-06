// Put in test/ and run: flutter test test/item_answer_voice_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quincy/AI/ItemAnswerVoiceParser.dart';

final _form = VoiceItemContext(
  allNumbers: List.generate(20, (i) => i + 1),
  answered: const {},
  sectionNumbers: List.generate(8, (i) => i + 1),
);

VoiceItemContext _withMemory({
  List<int> recent = const [],
  List<int> awaiting = const [],
}) =>
    VoiceItemContext(
      allNumbers: _form.allNumbers,
      answered: const {},
      sectionNumbers: _form.sectionNumbers,
      recentNumbers: recent,
      awaitingCommentFor: awaiting,
    );

List<String> _answers(String text, [VoiceItemContext? ctx]) =>
    (ItemAnswerVoiceParser.parse(text, context: ctx ?? _form)?.answers ??
            const [])
        .map((a) => a.toString())
        .toList();

void main() {
  group('still works', () {
    test('basic', () {
      expect(_answers('question 1 IN'), ['Q1 set IN']);
      expect(_answers('question no 4 OUT with R'), ['Q4 set OUT+R']);
      expect(_answers('question 7 COS'), ['Q7 set OUT+COS']);
      expect(_answers('question 3 not observed'), ['Q3 set NO']);
      expect(_answers('question 5 N/A'), ['Q5 set NA']);
    });
    test('many', () {
      expect(_answers('questions 1 to 3 IN'),
          ['Q1 set IN', 'Q2 set IN', 'Q3 set IN']);
      expect(_answers('set item 1,2,5,7 IN'),
          ['Q1 set IN', 'Q2 set IN', 'Q5 set IN', 'Q7 set IN']);
      expect(_answers('question 1 IN 2 OUT with R 3 NA'),
          ['Q1 set IN', 'Q2 set OUT+R', 'Q3 set NA']);
    });
  });

  group('mis-heard words', () {
    test('question / item', () {
      expect(_answers('kwestion 4 out'), ['Q4 set OUT']);
      expect(_answers('cushion 3 not observe'), ['Q3 set NO']);
      expect(_answers('idem 2 in'), ['Q2 set IN']);
      expect(_answers('item for out with are'), ['Q4 set OUT+R']);
    });
    test('results', () {
      expect(_answers('question 4 owt with our'), ['Q4 set OUT+R']);
      expect(_answers('question 4 are'), ['Q4 set OUT+R']);
      expect(_answers('question 2 cause'), ['Q2 set OUT+COS']);
      expect(_answers('question 5 and a'), ['Q5 set NA']);
      expect(_answers('question 6 know'), ['Q6 set NO']);
      expect(_answers('question 4 out corrected on sight'),
          ['Q4 set OUT+COS']);
      expect(_answers('question 4 out see oh es'), ['Q4 set OUT+COS']);
    });
    test('"are" in a normal sentence is not R', () {
      expect(_answers('questions 1 to 3 are in'),
          ['Q1 set IN', 'Q2 set IN', 'Q3 set IN']);
    });
    test('except / ordinals / forty→fourteen', () {
      expect(_answers('questions 1 to 4 IN accept 2'),
          ['Q1 set IN', 'Q3 set IN', 'Q4 set IN']);
      expect(_answers('the fourth question IN'), ['Q4 set IN']);
      final r = ItemAnswerVoiceParser.parse('question forty IN',
          context: _form)!;
      expect(r.answers.single.number, 14);
      expect(r.assumptions, isNotEmpty);
    });
    test('assumptions are reported', () {
      final r = ItemAnswerVoiceParser.parse('question 4 owt', context: _form)!;
      expect(r.assumptions, ['I heard "owt" as OUT.']);
    });
  });

  group('smart behaviour', () {
    test('pairs answers in order', () {
      expect(_answers('items 1 2 5 7 IN OUT NO NA'),
          ['Q1 set IN', 'Q2 set OUT', 'Q5 set NO', 'Q7 set NA']);
    });
    test('self-correction', () {
      expect(_answers('question 4 IN, sorry, OUT'), ['Q4 set OUT']);
      expect(_answers('question 4 IN, no, OUT'), ['Q4 set OUT']);
      expect(_answers('question 4 sorry 5 IN'), ['Q5 set IN']);
      expect(_answers('question 4 OUT with R, no, COS'), ['Q4 set OUT+COS']);
    });
    test('remembers the last question', () {
      final ctx = _withMemory(recent: [4]);
      expect(_answers('OUT with R', ctx), ['Q4 set OUT+R']);
      expect(_answers('clear it', ctx), ['Q4 clear null']);
      // a lone "no" is a yes/no answer, not NO
      expect(ItemAnswerVoiceParser.parse('no', context: ctx), isNull);
    });
    test('number not on the form', () {
      final r = ItemAnswerVoiceParser.parse('question 25 IN', context: _form)!;
      expect(r.answers, isEmpty);
      expect(r.warnings.first, contains('not on this form'));
    });
    test('result without a number asks which question', () {
      final r = ItemAnswerVoiceParser.parse('question OUT', context: _form)!;
      expect(r.warnings.first, startsWith('Which question should be OUT'));
    });
  });

  group('comments', () {
    VoiceItemComment one(String text, [VoiceItemContext? ctx]) =>
        ItemAnswerVoiceParser.parse(text, context: ctx ?? _form)!
            .comments
            .single;

    test('mis-heard comment word', () {
      expect(one('item1 set commend test1').toString(), 'Q1 comment set "Test1"');
      expect(one('question 1 set comet hand sink blocked').text,
          'Hand sink blocked');
      expect(one('add a note for question 5: no soap').number, 5);
      expect(one('kwestion 3 comment wall dirty').number, 3);
    });
    test('comment text is kept as spoken', () {
      final r = ItemAnswerVoiceParser.parse(
          'question 4 OUT with R comment no thermometer',
          context: _form)!;
      expect(r.answers.single.toString(), 'Q4 set OUT+R');
      expect(r.comments.single.text, 'No thermometer');
    });
    test('asks for text, then takes the next sentence', () {
      final first =
          ItemAnswerVoiceParser.parse('question 4 comment', context: _form)!;
      expect(first.commentNeeded, [4]);

      final memory = VoiceItemMemory()..remember(first);
      final second = ItemAnswerVoiceParser.parse(
        'no soap at the hand sink',
        context: memory.context(allNumbers: _form.allNumbers),
      )!;
      expect(second.comments.single.toString(),
          'Q4 comment set "No soap at the hand sink"');

      final cancel = ItemAnswerVoiceParser.parse('never mind',
          context: memory.context(allNumbers: _form.allNumbers))!;
      expect(cancel.comments, isEmpty);
    });
    test('"comment …" without a number uses the last question', () {
      expect(one('comment owner informed', _withMemory(recent: [6])).number,
          6);
    });
  });

  test('not about questions → null', () {
    expect(ItemAnswerVoiceParser.parse('open incomplete', context: _form),
        isNull);
    expect(ItemAnswerVoiceParser.parse('how many items are out',
            context: _form),
        isNull);
  });
}