/// 픽클 투표를 이 앱 흐름 안에 녹이는 경계.
///
/// 투표를 따로 "만드는" 화면은 없다. 여행하다 보면 저절로 생긴다.
/// - 체크인 직후 픽클이가 "방금 간 곳 vs 그 전에 간 곳" 하나를 묻는다 → [answerPair] (다녀온 사람 표)
/// - 추천 목록에서 다녀온 곳에 "나도 한 표" → [setPlaceVote]
/// - 여행지 후보를 ♡로 담아 친구한테 물어본다 → [askFriends]
/// - 여행 카드에 "한 표 핀"을 붙여 공유하면 투표가 된다 → [shareCardPoll]
///
/// 픽클 서버(VoteLock `POST /v1/polls` 등)와 붙이려면 먼저 정할 것이 있다(docs/architecture.md "픽클 투표").
/// 그 전까지는 [FixtureVoteRepository]를 쓴다.
library;

/// "다녀온 1,240명이 고른 해변 1위" 같은 한 줄.
class VisitorRank {
  const VisitorRank({required this.rank, required this.voters, required this.scope});

  final int rank;

  /// 그 장소에 체크인하고 표를 준 사람 수.
  final int voters;

  /// 순위를 매긴 범위(예: 해변, 카페).
  final String scope;

  String get label => '다녀온 ${formatCount(voters)}명이 고른 $scope $rank위';
}

/// 1240 → "1,240"
String formatCount(int n) {
  final s = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

enum PollKind {
  /// 여행지 후보(시·군·구)를 친구한테 묻는 투표.
  region,

  /// 여행 카드에서 다녀온 곳을 후보로 올린 투표.
  card,
}

class PollOption {
  const PollOption({required this.key, required this.label, this.voters = const []});

  /// 시·군·구 코드 또는 체크인(장소) id.
  final String key;
  final String label;

  /// 표를 준 사람 이름(내 표는 [Poll.myChoice]로 따로 센다).
  final List<String> voters;
}

class Poll {
  const Poll({
    required this.id,
    required this.kind,
    required this.question,
    required this.options,
    required this.shareUrl,
    this.myChoice,
    this.closed = false,
  });

  final String id;
  final PollKind kind;
  final String question;
  final List<PollOption> options;

  /// 친구에게 보내는 링크(픽클 투표 미리보기 웹). 앱이 없어도 투표할 수 있다.
  final String shareUrl;
  final String? myChoice;
  final bool closed;

  int votesOf(String key) =>
      options.where((o) => o.key == key).fold(0, (sum, o) => sum + o.voters.length) + (myChoice == key ? 1 : 0);

  int get total => options.fold(0, (sum, o) => sum + votesOf(o.key));

  /// 표가 가장 많은 후보. 같으면 먼저 올린 후보.
  PollOption get leader {
    var best = options.first;
    for (final o in options.skip(1)) {
      if (votesOf(o.key) > votesOf(best.key)) best = o;
    }
    return best;
  }

  /// 표 많은 순(같으면 올린 순).
  List<PollOption> get ranked {
    final order = [for (var i = 0; i < options.length; i++) i];
    order.sort((a, b) {
      final d = votesOf(options[b].key) - votesOf(options[a].key);
      return d != 0 ? d : a - b;
    });
    return [for (final i in order) options[i]];
  }

  int percentOf(String key) => total == 0 ? 0 : (votesOf(key) * 100 / total).round();

  Poll copyWith({String? myChoice, bool? closed}) => Poll(
        id: id,
        kind: kind,
        question: question,
        options: options,
        shareUrl: shareUrl,
        myChoice: myChoice ?? this.myChoice,
        closed: closed ?? this.closed,
      );
}

typedef PollCandidate = ({String key, String label});

abstract interface class VoteRepository {
  /// 서버 없이 예시로만 도는지. 예시면 친구 표·포인트·공유 링크가 진짜가 아니라서 화면이 그렇다고 알린다.
  bool get isSample;

  /// 체크인 직후 질문에 답한다. 고른 곳에 "다녀온 사람 표"가 들어간다. 받은 픽클 포인트를 돌려준다.
  Future<int> answerPair({required String cityId, required String winnerPlaceId, required String otherPlaceId});

  /// 다녀온 곳의 "나도 한 표".
  Future<void> setPlaceVote({required String cityId, required String placeId, required bool on});

  Future<Set<String>> myPlaceVotes(String cityId);

  /// ♡로 담은 여행지 후보를 친구한테 묻는다(2~4곳).
  Future<Poll> askFriends({required String question, required List<PollCandidate> cities});

  /// 여행 카드의 "한 표 핀" 후보로 투표를 올린다(2~4곳).
  Future<Poll> shareCardPoll({required String tripId, required String question, required List<PollCandidate> places});

  /// 물어본 투표를 다시 연다. 없거나 지워졌으면 null.
  Future<Poll?> poll(String pollId);

  Future<Poll> vote(String pollId, String optionKey);

  Future<Poll> close(String pollId);
}

/// 서버 없이 쓰는 예시. 친구 표는 정해진 예시 값이다.
class FixtureVoteRepository implements VoteRepository {
  FixtureVoteRepository({this.pointsPerAnswer = 10});

  /// 체크인 질문 한 번에 주는 포인트(예시 값, 픽클 정책으로 정한다).
  final int pointsPerAnswer;

  @override
  bool get isSample => true;

  final Map<String, Set<String>> _placeVotes = {};
  final Map<String, Poll> _polls = {};
  final List<({String cityId, String winner, String other})> answers = [];
  var _seq = 0;

  static const List<List<String>> _friends = [
    ['보리', '모아', '일디'],
    ['토리', '리듬이'],
    [],
    ['픽클이'],
  ];

  @override
  Future<int> answerPair({required String cityId, required String winnerPlaceId, required String otherPlaceId}) async {
    answers.add((cityId: cityId, winner: winnerPlaceId, other: otherPlaceId));
    return pointsPerAnswer;
  }

  @override
  Future<void> setPlaceVote({required String cityId, required String placeId, required bool on}) async {
    final set = _placeVotes.putIfAbsent(cityId, () => {});
    on ? set.add(placeId) : set.remove(placeId);
  }

  @override
  Future<Set<String>> myPlaceVotes(String cityId) async => {...?_placeVotes[cityId]};

  Poll _create(PollKind kind, String question, List<PollCandidate> candidates) {
    if (candidates.length < 2 || candidates.length > 4) {
      throw ArgumentError.value(candidates.length, 'candidates', '후보는 2~4곳');
    }
    final id = 'poll-${++_seq}';
    final poll = Poll(
      id: id,
      kind: kind,
      question: question,
      shareUrl: 'https://pickle.example/v/$id',
      options: [
        for (var i = 0; i < candidates.length; i++)
          PollOption(key: candidates[i].key, label: candidates[i].label, voters: _friends[i]),
      ],
    );
    return _polls[id] = poll;
  }

  @override
  Future<Poll> askFriends({required String question, required List<PollCandidate> cities}) async =>
      _create(PollKind.region, question, cities);

  @override
  Future<Poll> shareCardPoll({required String tripId, required String question, required List<PollCandidate> places}) async =>
      _create(PollKind.card, question, places);

  @override
  Future<Poll?> poll(String pollId) async => _polls[pollId];

  Poll _get(String id) => _polls[id] ?? (throw StateError('없는 투표: $id'));

  @override
  Future<Poll> vote(String pollId, String optionKey) async {
    final poll = _get(pollId);
    if (poll.closed || !poll.options.any((o) => o.key == optionKey)) return poll;
    return _polls[pollId] = poll.copyWith(myChoice: optionKey);
  }

  @override
  Future<Poll> close(String pollId) async => _polls[pollId] = _get(pollId).copyWith(closed: true);
}
