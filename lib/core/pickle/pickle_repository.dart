import 'pickle_api_client.dart';
import 'pickle_models.dart';

/// 화면은 이 인터페이스만 본다. 서버 주소가 없으면 [FixturePickleRepository]가 쓰인다.
abstract interface class PickleRepository {
  Future<UserProfile?> me();
  Future<List<InterestCategory>> interestCategories();
  Future<List<String>> myInterestKeys();
  Future<PickleFriend?> myFriend();
}

class RemotePickleRepository implements PickleRepository {
  RemotePickleRepository(this._client);

  final PickleApiClient _client;

  @override
  Future<UserProfile?> me() async => await _client.hasSession ? _client.getMyProfile() : null;

  @override
  Future<List<InterestCategory>> interestCategories() => _client.listInterestCategories();

  @override
  Future<List<String>> myInterestKeys() async =>
      await _client.hasSession ? _client.getMyInterestKeys() : const <String>[];

  @override
  Future<PickleFriend?> myFriend() async => await _client.hasSession ? _client.getMyFirstFriend() : null;
}

/// 서버 없이 화면을 확인하기 위한 예시 데이터. 실제 픽클 카테고리 키와 다를 수 있다.
class FixturePickleRepository implements PickleRepository {
  const FixturePickleRepository();

  @override
  Future<UserProfile?> me() async => const UserProfile(subjectId: 'fixture-subject', nickname: '픽클러');

  @override
  Future<List<InterestCategory>> interestCategories() async => const [
        InterestCategory(key: 'food', displayNameKo: '맛집', sortOrder: 1),
        InterestCategory(key: 'cafe', displayNameKo: '카페', sortOrder: 2),
        InterestCategory(key: 'nature', displayNameKo: '자연', sortOrder: 3),
        InterestCategory(key: 'history', displayNameKo: '역사', sortOrder: 4),
        InterestCategory(key: 'festival', displayNameKo: '축제', sortOrder: 5),
      ];

  @override
  Future<List<String>> myInterestKeys() async => const ['food', 'nature'];

  @override
  Future<PickleFriend?> myFriend() async =>
      const PickleFriend(name: '보리', species: PickleSpecies.otter, stage: PickleStage.juvenile);
}
