/// 生成唯一 ID（基于时间戳 + 随机数）
String generateId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = (DateTime.now().microsecondsSinceEpoch % 100000).toString().padLeft(5, '0');
  return '$timestamp$random';
}
