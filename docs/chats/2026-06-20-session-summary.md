# 对话压缩记录

## 项目背景

- 项目是一个 Rokid / AIUI / JSUI 的知识卡片应用。
- 目标从一开始的“自动轮播知识卡片”，逐步演化成“适合 AI 眼镜的极简知识卡片交互”。
- 用户对稳定性要求很高，后期优先级已经明显变成：
  1. 页面必须稳定渲染
  2. 交互必须简单直接
  3. 视觉保持 HUD / 眼镜风格

## 核心目标演进

### 第一阶段：基础知识卡片

- 每隔 5 秒展示下一张卡片。
- 首页显示知识卡片、图案、对应小知识。
- 加配图帮助记忆和回顾。

### 第二阶段：加入交互与模式切换

- 学习模式：文字 + 图片。
- 挑战模式：只显示图片回忆知识。
- 点头表示记住，摇头表示没记住。
- 用户曾要求：
  - 记住后击碎效果
  - 没记住后恢复原卡片
  - 正确/错误表情反馈

### 第三阶段：加入语音与入口结构

- 研究 Rokid ASR / SpeechRecognition。
- 一度设计为：首页分类 Grid -> 语音说卡片名 -> 打开二级页。
- 分类包含：
  - 自然科学
  - 历史
  - 生物
  - 地理
  - 物理
  - 化学
  - 计算机
- 后来因为复杂度和稳定性问题，首页分类和二级结构被移除。

### 第四阶段：收敛为对话式卡片

- 页面改成单页对话式交互。
- 主要语音指令：
  - `下一张`
  - `上一张`
  - `记住了`
  - `看正面`
- 卡片正面显示：
  - 标题
  - 场景句
  - 详细知识内容
- 卡片背面显示：
  - 图片

### 第五阶段：稳定性优先

- 页面多次出现布局错乱、图片不显示、初始化失败、QuickJS 异常。
- 为了止损，曾经彻底删除并重建 `pages/index/index.ink`。
- 最终策略变成：
  - 少用复杂表达式
  - 少用高风险动画
  - 尽量避免运行时不稳定的写法

## 关键问题与处理结论

### 1. 图片显示问题

- 远程图片在当前运行环境里不稳定。
- 后面主要改用本地资源：
  - `assets/illustrations/silk-road.svg`
  - `assets/illustrations/light-year.svg`
  - `assets/illustrations/plate-motion.svg`
  - `assets/illustrations/tree-network.svg`
- 备注：SVG 在 AIUI 运行时依然可能有兼容风险。

### 2. 翻转和动画问题

- 3D 翻转、粒子层、复杂叠层都曾导致错乱或初始化失败。
- 后来改成更安全的条件渲染：
  - 正面 `ink:if`
  - 背面 `ink:else`
- 动效收敛为轻量 `card-out` / `card-in`。

### 3. 语音识别逻辑

- 采用 `SpeechRecognition`。
- 支持 `onstart`、`onresult`、`onerror`、`onend`。
- 做了 `extractTranscript()` 和 `normalizeVoiceText()`。
- 指令识别逻辑已实现，但实际运行效果仍依赖设备环境是否支持语音。

### 4. “下一张内容不变”问题

- 现象：点击 `下一张` 后，界面仍显示同一张卡片内容。
- 判断原因：
  - `cards[currentIndex]` 这类动态索引表达式在当前运行时刷新不稳定。
- 修复方案：
  - 新增显式数据源 `currentCard`
  - 切换卡片时同时更新：
    - `currentIndex`
    - `cardPageText`
    - `currentCard`
- 这是当前页面最新一轮的重要稳定性修复。

## 当前页面稳定版本

### 当前主文件

- `pages/index/index.ink`

### 当前正面结构

- 标题
- 正文阅读区
  - `scene`
  - `content`
- `keyword` 区
  - `memoryKey`
  - `symbols`
  - `memoryHint`
- 右上角页码

### 当前背面结构

- 图片
- 标题

### 当前卡片数据

- 丝绸之路
- 光年
- 板块运动
- 树木通信

### 当前已落地的视觉调整

- 移除了大量顶部提示和多余说明。
- `keyword` 区已并入主卡片。
- `keyword` 区曾做成错落宫格。
- 右上角已增加页码。
- 正文区与 `keyword` 区的比例多次调整。
- 最近一次要求是把 `keyword` 区压缩到总卡片高度约 `1/4`。

## 当前代码状态摘要

### 已有数据字段

- `currentIndex`
- `cardPageText`
- `currentCard`
- `cardFlipped`
- `cardMotionClass`
- `voiceEnabled`
- `voiceListening`
- `voiceStatus`
- `lastTranscript`
- `cards`

### 当前关键方法

- `initVoiceRecognition()`
- `extractTranscript()`
- `normalizeVoiceText()`
- `handleVoiceCommand()`
- `openCardByTitle()`
- `showNextCard()`
- `showPrevCard()`
- `flipToBack()`
- `flipToFront()`
- `getCardPageText()`
- `getCardByIndex()`

## 已安装的 skills

- 之前已安装 `aiui-dev`
- 本轮又安装了 `https://github.com/tanweai/pua`
- 当前 `skills-lock.json` 已包含：
  - `ding`
  - `mama`
  - `p10`
  - `p7`
  - `p9`
  - `pro`
  - `pua`
  - `pua-en`
  - `pua-ja`
  - `pua-loop`
  - `pua-trae`
  - `shot`
  - `yes`

## 重要文件清单

- `app.js`
- `app.json`
- `pages/index/index.ink`
- `docs/ai-glasses-ui-prompts.md`
- `skills-lock.json`
- `assets/illustrations/*.svg`
- `.agents/skills/aiui-dev/*`
- `.agents/skills/pua/*`

## 风险与注意事项

- 当前运行环境对复杂模板表达式不够稳定。
- SVG 图片在设备上的兼容性仍需要继续观察。
- 语音识别是否可用依赖实际设备能力。
- 不建议立刻重新加回：
  - 重度粒子动画
  - 复杂翻转层
  - 多页面分类入口
  - IMU 挑战模式整套复杂逻辑

## 建议的后续路线

### 第一优先级

- 先在真实运行环境确认：
  - `下一张` 是否真的切换到下一张卡
  - 页码是否同步变化
  - 背面图片是否稳定显示

### 第二优先级

- 如果稳定，再继续做轻量视觉增强：
  - 更统一的 HUD 字体层级
  - 更克制的宫格动画
  - `keyword` 区更精细的压缩版式

### 第三优先级

- 只有在稳定基础确认后，才考虑重新引入：
  - 挑战模式
  - 点头 / 摇头
  - 记忆反馈动画

## 一句话结论

- 这个项目已经从“功能堆叠”收敛为“稳定优先的 AI 眼镜知识卡片页”，当前最重要的是验证最新的 `currentCard` 切换方案是否真正解决了“下一张内容不变”的问题。
