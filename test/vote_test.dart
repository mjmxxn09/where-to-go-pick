import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/core/votes/vote_repository.dart';
import 'package:where_to_go_pick/features/trip_card/card_stickers.dart';
import 'package:where_to_go_pick/features/votes/pickle_ask_bubble.dart';
import 'package:where_to_go_pick/features/votes/poll_question_sheet.dart';

void main() {
  test('픽클이 질문의 "랑/이랑"', () {
    expect(withRang('경포해변'), '경포해변이랑');
    expect(withRang('안목 커피거리'), '안목 커피거리랑');
    expect(withRang('오죽헌'), '오죽헌이랑');
  });

  test('체크인 질문에 답하면 다녀온 사람 표가 들어가고 포인트를 받는다', () async {
    final votes = FixtureVoteRepository();
    final points = await votes.answerPair(cityId: '32030', winnerPlaceId: 'anmok', otherPlaceId: 'gyeongpo');
    expect(points, 10);
    expect(votes.answers.single.winner, 'anmok');
  });

  test('후보 투표: 내 표를 바꿀 수 있고, 마감하면 더는 바뀌지 않는다', () async {
    final votes = FixtureVoteRepository();
    var poll = await votes.askFriends(question: '이번 주말 어디 갈까?', cities: [
      (key: 'a', label: '강릉시'),
      (key: 'b', label: '속초시'),
      (key: 'c', label: '양양군'),
    ]);
    expect(poll.total, 5); // 예시 친구 표 3 + 2 + 0
    expect(poll.leader.key, 'a');

    poll = await votes.vote(poll.id, 'b');
    expect(poll.myChoice, 'b');
    expect(poll.votesOf('b'), 3);
    expect(poll.total, 6);
    expect(poll.ranked.map((o) => o.key), ['a', 'b', 'c']); // 3:3 동점이면 먼저 올린 후보

    poll = await votes.vote(poll.id, 'c');
    expect(poll.votesOf('b'), 2);
    expect(poll.votesOf('c'), 1);

    poll = await votes.close(poll.id);
    expect(poll.closed, isTrue);
    expect(poll.leader.label, '강릉시');
    poll = await votes.vote(poll.id, 'b');
    expect(poll.myChoice, 'c');
    expect([for (final o in poll.options) poll.percentOf(o.key)].reduce((a, b) => a + b), inInclusiveRange(99, 101));
  });

  test('후보는 2~4곳', () async {
    final votes = FixtureVoteRepository();
    await expectLater(votes.askFriends(question: 'q', cities: [(key: 'a', label: 'A')]), throwsArgumentError);
  });

  test('한 표 핀 옆의 장소가 투표 후보가 된다(가까운 곳, 붙인 순서, 중복 없음)', () {
    const stops = [
      (id: 'gyeongpo', x: 120.0, y: 170.0),
      (id: 'anmok', x: 180.0, y: 170.0),
      (id: 'ojuk', x: 240.0, y: 310.0),
    ];
    final stickers = [
      const PlacedSticker(id: '1', name: 'vote_pick', x: 236, y: 280, size: 50, rotation: 0),
      const PlacedSticker(id: '2', name: 'place_cafe_coffee', x: 120, y: 175, size: 72, rotation: 0),
      const PlacedSticker(id: '3', name: 'vote_pick', x: 125, y: 140, size: 50, rotation: 0),
      const PlacedSticker(id: '4', name: 'vote_pick', x: 118, y: 150, size: 50, rotation: 0),
      const PlacedSticker(id: '5', name: 'vote_pick', x: 340, y: 600, size: 50, rotation: 0),
    ];
    expect(voteCandidates(stickers, stops), ['ojuk', 'gyeongpo']);
    expect(voteCandidates(const [], stops), isEmpty);
  });

  test('후보 투표 기본 질문은 후보 이름으로, 길면 짧은 질문', () {
    expect(defaultRegionQuestion(['강릉', '속초']), '강릉 vs 속초, 어디 갈까?');
    expect(defaultRegionQuestion(['강릉', '속초', '양양']), '강릉·속초·양양 중 어디 갈까?');
    expect(defaultRegionQuestion(['강릉']), '어디로 여행 갈까?');
    final long = defaultRegionQuestion(['서귀포', '남해', '고성', '아주아주긴지역이름입니다만요정말로길어요']);
    expect(long.length, lessThanOrEqualTo(pollQuestionMaxLength));
    expect(cardQuestionIdeas('강릉').first, '강릉 가면 어디부터 가야 해?');
  });
}
