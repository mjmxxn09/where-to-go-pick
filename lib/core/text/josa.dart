/// 받침에 맞춘 조사: "강릉은 / 양양군은", "강릉으로? → 강릉으로 / 속초시로".
library;

/// 마지막 글자의 받침 번호(0 = 받침 없음). 한글이 아니면 null.
int? _batchim(String word) {
  final w = word.trimRight();
  if (w.isEmpty) return null;
  final c = w.codeUnitAt(w.length - 1) - 0xAC00;
  if (c < 0 || c > 11171) return null;
  return c % 28;
}

/// 은/는: "강릉은", "속초시는". 한글이 아니면 "은(는)".
String withEun(String word) => switch (_batchim(word)) {
      null => '$word은(는)',
      0 => '$word는',
      _ => '$word은',
    };

/// 으로/로: "양양군으로", "속초시로", "서울로"(ㄹ 받침은 '로'). 한글이 아니면 "(으)로".
String withRo(String word) => switch (_batchim(word)) {
      null => '$word(으)로',
      0 || 8 => '$word로',
      _ => '$word으로',
    };

/// 이랑/랑: "경포해변이랑", "안목 커피거리랑".
String withRang(String word) => switch (_batchim(word)) {
      null || 0 => '$word랑',
      _ => '$word이랑',
    };
