/// AI 提示词模板
class AiPrompts {
  /// 系统提示词：写作助手角色设定
  static const String systemWriter = '''
你是一位专业的网文写作助手。你的任务是帮助作者完成网络小说的创作。
你熟悉各种网文套路、爽点设计、节奏把控和人物塑造。
回答要简洁实用，直接给出可用的内容。
''';

  /// 生成章节大纲
  static String outline(String storyIdea) => '''
请根据以下故事核心，生成一份详细的章节大纲（10-20章）。

故事核心：
$storyIdea

要求：
1. 每章给出标题和核心内容
2. 标注每章的爽点/钩子
3. 合理安排节奏：起-承-转-合
4. 确保前后章节有连贯性

输出格式：
第1章 - [标题]
核心内容：[简述]
爽点/钩子：[说明]
''';

  /// 细纲扩写
  static String expandOutline(String outline, {String context = ''}) => '''
请根据以下细纲扩写成一篇完整的网文章节（约3000-4000字）。

${context.isNotEmpty ? '前文摘要：\n$context\n' : ''}
细纲：
$outline

要求：
1. 保持网文风格，语言流畅但不追求华丽
2. 注意章节开头要有钩子，结尾要有悬念
3. 对话要自然，符合人物性格
4. 合理分配笔墨，重点场景详细描写
5. 直接输出正文，不要加额外说明
''';

  /// 起名工具
  static String naming(String type, {String style = '', int count = 10}) => '''
请为网文$type生成$count个名字。

${style.isNotEmpty ? '风格要求：$style\n' : ''}
要求：
1. 每个名字要朗朗上口
2. 有网文特色，不落俗套
3. 简短易记，2-4个字为佳
4. 输出格式：每行一个名字，不要编号
''';

  /// 卡文助手
  static String writerBlock(String recentContent, String storyContext) => '''
作者在写小说时卡住了，需要你的帮助。

小说背景：
$storyContext

最近写的内容：
$recentContent

请给出 3-5 个不同的发展方向建议，每个建议包括：
1. 发展方向简述
2. 具体的剧情走向
3. 这个方向能带来的爽点/看点

要求：不要太过跳脱，要符合当前故事逻辑。
''';

  /// 拆书分析
  static String bookAnalysis(String content) => '''
请分析以下小说片段，提取关键信息。

小说内容：
$content

请输出：
一、人物列表
- 姓名 | 角色类型(主角/配角/反派) | 性格特征 | 简要背景

二、人物关系
- [人物A] → [关系] → [人物B]（简要说明）

三、剧情节奏
- 主要情节线
- 爽点/高潮节点
- 伏笔/悬念

四、写作技巧
- 开篇方式
- 对话特点
- 节奏把控手法
''';

  /// ===== 大纲系统提示词 =====

  /// 从故事概念生成书籍级大纲
  static String generateOutline(String storyConcept, {String characters = '', String worldBuilding = ''}) => '''
请根据以下故事概念，生成一份完整的书籍级大纲。

故事概念：
$storyConcept

${characters.isNotEmpty ? '主要角色：\n$characters\n' : ''}${worldBuilding.isNotEmpty ? '世界观设定：\n$worldBuilding\n' : ''}
请以 JSON 格式输出，结构如下：
[
  {"title": "第一卷 XXX", "type": "volume", "content": "卷概述", "children": [
    {"title": "第X章 XXX", "type": "chapter", "content": "章节概要", "children": [
      {"title": "节标题", "type": "section", "content": "具体内容"},
      {"title": "剧情节点", "type": "beat", "content": "具体内容"}
    ]}
  ]}
]

要求：
1. 建议 3-5 卷，每卷 8-15 章
2. 每章标注核心冲突/爽点
3. 确保起承转合完整
4. 角色弧光清晰
5. 直接输出 JSON，不要额外说明
''';

  /// 扩写大纲节点
  static String expandOutlineNode(String title, String currentContent) => '''
请扩写以下大纲节点，补充更多细节。

节点标题：$title
${currentContent.isNotEmpty ? '当前内容：\n$currentContent\n' : ''}
要求：
1. 展开情节细节，增加场景描写
2. 补充对话片段和冲突设计
3. 确保与整体故事风格一致
4. 输出格式：先简要说明扩写思路，再给出扩写后的完整内容
''';

  /// 从大纲节点生成章节细纲
  static String generateChapterOutline(String volumeTitle, String chapterTitle, String context) => '''
请根据以下卷和章的大纲，生成详细的章节细纲。

所属卷：$volumeTitle
章节：$chapterTitle
${context.isNotEmpty ? '上下文信息：\n$context\n' : ''}
要求：
1. 将章节拆分为 5-8 个场景/片段
2. 每个场景给出核心内容、字数建议、爽点
3. 确保场景之间有流畅过渡
4. 标注开篇钩子和结尾悬念

输出格式：
【开篇钩子】...
【场景1】...（约XXX字）— 爽点：...
【场景2】...
...
【结尾悬念】...
''';
}
