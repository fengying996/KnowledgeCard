<script def>
{
  "navigationBarTitleText": "知识小卡片"
}
</script>

<script setup>
export default {
  data: {
    showWelcome: true,
    welcomeCountdown: 5,
    welcomeHint: '点击开始后，说 开始 进入主页',
    currentIndex: 0,
    cardPageText: '1/1',
    currentCard: {
      id: 0,
      title: '',
      image: '',
      scene: '',
      content: '',
      symbols: [],
      memoryKey: '',
      memoryHint: ''
    },
    cardFlipped: false,
    recallMode: false,
    recallAwaitingAnswer: false,
    revealedSymbols: [],
    autoNextCountdown: 0,
    particleBurstActive: false,
    particleShards: [],
    nodEnabled: false,
    memoryList: [],
    memoryReviewDelayMs: 18000,
    cardMotionClass: '',
    voiceEnabled: false,
    voiceListening: false,
    llmRouteEnabled: false,
    voiceStatus: '卡片已准备好',
    lastTranscript: '未收到语音',
    cards: [
      {
        id: 1,
        title: '丝绸之路',
        image: '../../assets/illustrations/silk-road.svg',
        scene: '驼队穿过沙海，连通多地贸易路线',
        content: '丝绸之路不是单一路线，而是连接东亚、中亚、西亚与欧洲的贸易网络。丝绸之路不是单一路线，而是连接东亚、中亚、西亚与欧洲的贸易网络。丝绸之路不是单一路线，而是连接东亚、中亚、西亚与欧洲的贸易网络。丝绸之路不是单一路线，而是连接东亚、中亚、西亚与欧洲的贸易网络。',
        symbols: ['驼队', '沙海', '地图'],
        memoryKey: '商路',
        memoryHint: '看到骆驼和地图，就联想到跨区域贸易网络。'
      },
      {
        id: 2,
        title: '光年',
        image: '../../assets/illustrations/light-year.svg',
        scene: '一束光在星空中高速前进，用来衡量超远距离',
        content: '光年是距离单位，不是时间单位，表示光在真空中一年传播的距离。',
        symbols: ['光束', '星空', '距离'],
        memoryKey: '尺子',
        memoryHint: '把光年想成宇宙里的尺子，不要和时间单位混淆。'
      },
      {
        id: 3,
        title: '板块运动',
        image: '../../assets/illustrations/plate-motion.svg',
        scene: '两块地壳相互推挤，慢慢抬升出山脉',
        content: '地球表面的大陆并非静止不动，板块运动会形成山脉、海沟和地震带。',
        symbols: ['板块', '山脉', '地震'],
        memoryKey: '碰撞',
        memoryHint: '看到地壳相撞抬升，就想到山脉和地震带。'
      },
      {
        id: 4,
        title: '树木通信',
        image: '../../assets/illustrations/tree-network.svg',
        scene: '树根与菌丝在地下连接，互相传递信号和养分',
        content: '森林中的树木可以通过地下真菌网络交换养分和化学信号。',
        symbols: ['树根', '菌丝', '协作'],
        memoryKey: '网络',
        memoryHint: '把地下菌丝网络看作森林的信息线缆。'
      }
    ]
  },
  onLoad() {
    var firstCard = this.data.cards.length ? this.data.cards[0] : null;
    this.setData({
      showWelcome: true,
      welcomeCountdown: 5,
      welcomeHint: '点击开始后，说 开始 进入主页',
      currentIndex: 0,
      cardPageText: this.getCardPageText(0),
      currentCard: firstCard || this.getEmptyCard(),
      cardFlipped: false,
      recallAwaitingAnswer: false,
      autoNextCountdown: 0,
      particleBurstActive: false,
      particleShards: [],
      cardMotionClass: '',
      voiceStatus: firstCard ? '已加载 ' + firstCard.title : '当前没有知识卡片',
      lastTranscript: '未收到语音'
    });
    this.initVoiceRecognition();
    this.initLanguageModelRouter();
    this.startWelcomeFlow();
  },
  onUnload() {
    this.clearWelcomeTimers();
    this.clearHomeVoiceTimer();
    this.clearMotionTimers();
    this.clearAutoNextTimers();
    this.clearSpeechFollowupTimer();
    this.clearAutoNextTimers();
    this.clearParticleTimer();
    this.clearRecallTimers();
    this.clearMemoryReviewTimer();
    this.stopNodSensor();
    this.stopVoiceRecognition();
    this.destroyLanguageModelRouter();
  },
  async initLanguageModelRouter() {
    var availability;

    if (typeof LanguageModel === 'undefined' || !LanguageModel) {
      this.setData({
        llmRouteEnabled: false
      });
      return;
    }

    try {
      availability = await LanguageModel.availability();
      if (availability !== 'available') {
        this.setData({
          llmRouteEnabled: false
        });
        return;
      }

      this.voiceRouterBaseSession = await LanguageModel.create({
        initialPrompts: [
          {
            role: 'system',
            content: this.getVoiceRouterSystemPrompt()
          }
        ],
        tools: this.getVoiceRouterTools()
      });

      this.setData({
        llmRouteEnabled: true
      });
    } catch (error) {
      this.voiceRouterBaseSession = null;
      this.setData({
        llmRouteEnabled: false,
        voiceStatus: this.data.showWelcome ? '欢迎页可以说 开始' : '语音路由初始化失败',
        lastTranscript: error && error.message ? error.message : 'LanguageModel 初始化失败'
      });
    }
  },
  destroyLanguageModelRouter() {
    if (this.voiceRouterBaseSession && typeof this.voiceRouterBaseSession.destroy === 'function') {
      try {
        this.voiceRouterBaseSession.destroy();
      } catch (error) {
        // ignore destroy error
      }
    }

    this.voiceRouterBaseSession = null;
  },
  getVoiceRouterTools() {
    return [
      {
        type: 'function',
        function: {
          name: 'enter_home',
          description: '在欢迎页进入卡片主页',
          parameters: {
            type: 'object',
            properties: {}
          }
        }
      },
      {
        type: 'function',
        function: {
          name: 'next_card',
          description: '切换到下一张卡片',
          parameters: {
            type: 'object',
            properties: {}
          }
        }
      },
      {
        type: 'function',
        function: {
          name: 'prev_card',
          description: '切换到上一张卡片',
          parameters: {
            type: 'object',
            properties: {}
          }
        }
      },
      {
        type: 'function',
        function: {
          name: 'flip_to_back',
          description: '进入背面图片和回忆模式，适用于记住了、我会了、翻到背面等语义',
          parameters: {
            type: 'object',
            properties: {}
          }
        }
      },
      {
        type: 'function',
        function: {
          name: 'flip_to_front',
          description: '切回正面内容',
          parameters: {
            type: 'object',
            properties: {}
          }
        }
      },
      {
        type: 'function',
        function: {
          name: 'forget_card',
          description: '表示用户没有记住，需要播报知识文字',
          parameters: {
            type: 'object',
            properties: {}
          }
        }
      },
      {
        type: 'function',
        function: {
          name: 'confirm_remembered',
          description: '在回忆提问阶段确认已经记住，切下一张并移入延迟回顾队列',
          parameters: {
            type: 'object',
            properties: {}
          }
        }
      },
      {
        type: 'function',
        function: {
          name: 'open_card',
          description: '按卡片标题打开指定卡片',
          parameters: {
            type: 'object',
            properties: {
              title: {
                type: 'string',
                description: '目标卡片标题'
              }
            },
            required: ['title']
          }
        }
      },
      {
        type: 'function',
        function: {
          name: 'unknown',
          description: '无法确定用户意图时使用',
          parameters: {
            type: 'object',
            properties: {}
          }
        }
      }
    ];
  },
  getVoiceRouterSystemPrompt() {
    return [
      '你是知识卡片应用的语音指令路由器。',
      '你的工作是把 ASR 结果映射到一个工具动作，不要解释，不要聊天。',
      'ASR 结果可能包含语气词、停顿词、逗号、句号、礼貌词、重复词、错别字和近义表达。',
      '你必须结合当前页面状态选择最合适的工具。',
      '如果在欢迎页，开始、开始吧、进入、进去学习都应该选择 enter_home。',
      '如果在回忆提问阶段，记住了、我记住了、会了、想起来了 应选择 confirm_remembered。',
      '如果用户表达没记住、没想起来、想不起来、再讲一遍、提示一下，应选择 forget_card。',
      '如果用户表达下一张、下一页、往后翻、换一个、下一个，应选择 next_card。',
      '如果用户表达上一张、上一页、往前翻，应选择 prev_card。',
      '如果用户表达看背面、翻过去、记住了、进入回忆模式，应选择 flip_to_back。',
      '如果用户表达看正面、回到正面、返回内容，应选择 flip_to_front。',
      '如果用户说出某个卡片标题，应选择 open_card 并填 title。',
      '只输出一行 JSON，不要输出 markdown，不要输出代码块。',
      'JSON 格式固定为 {"tool":"工具名","title":"可选标题","reason":"极短原因"}。'
    ].join('');
  },
  buildVoiceRouterStateText() {
    var titles = this.data.cards.map((card) => card.title).join('、');

    return JSON.stringify({
      showWelcome: this.data.showWelcome,
      cardFlipped: this.data.cardFlipped,
      recallMode: this.data.recallMode,
      recallAwaitingAnswer: this.data.recallAwaitingAnswer,
      currentCardTitle: this.data.currentCard && this.data.currentCard.title ? this.data.currentCard.title : '',
      availableCardTitles: titles
    });
  },
  stripJsonFence(text) {
    return String(text || '')
      .replace(/^```json\s*/i, '')
      .replace(/^```\s*/i, '')
      .replace(/\s*```$/i, '')
      .trim();
  },
  parseVoiceRouterResult(resultText) {
    var cleanedText = this.stripJsonFence(resultText);
    var startIndex = cleanedText.indexOf('{');
    var endIndex = cleanedText.lastIndexOf('}');
    var jsonText = cleanedText;
    var parsed;

    if (startIndex !== -1 && endIndex !== -1 && endIndex >= startIndex) {
      jsonText = cleanedText.slice(startIndex, endIndex + 1);
    }

    parsed = JSON.parse(jsonText);
    return {
      tool: parsed && parsed.tool ? String(parsed.tool) : '',
      title: parsed && parsed.title ? String(parsed.title) : '',
      reason: parsed && parsed.reason ? String(parsed.reason) : ''
    };
  },
  async routeVoiceCommandWithLLM(transcript) {
    var session;
    var prompt;
    var resultText;
    var parsed;

    if (!this.voiceRouterBaseSession || !this.data.llmRouteEnabled) {
      return null;
    }

    prompt = [
      '当前页面状态：' + this.buildVoiceRouterStateText(),
      'ASR 文本：' + transcript
    ].join('\n');

    session = this.voiceRouterBaseSession.clone();

    try {
      resultText = await session.prompt(prompt);
      parsed = this.parseVoiceRouterResult(resultText);
      return parsed;
    } catch (error) {
      this.setData({
        voiceStatus: 'LLM 路由失败，已回退本地匹配',
        lastTranscript: error && error.message ? error.message : transcript
      });
      return null;
    } finally {
      if (session && typeof session.destroy === 'function') {
        try {
          session.destroy();
        } catch (error) {
          // ignore destroy error
        }
      }
    }
  },
  executeVoiceIntent(intent, transcript) {
    var normalizedTitle;

    if (!intent || !intent.tool) {
      return false;
    }

    if (intent.tool === 'enter_home' && this.data.showWelcome) {
      this.enterHomePage();
      this.setData({
        voiceStatus: '已进入主页',
        lastTranscript: transcript
      });
      return true;
    }

    if (intent.tool === 'next_card') {
      this.showNextCard(transcript);
      return true;
    }

    if (intent.tool === 'prev_card') {
      this.showPrevCard(transcript);
      return true;
    }

    if (intent.tool === 'flip_to_back') {
      this.flipToBack(transcript);
      return true;
    }

    if (intent.tool === 'flip_to_front') {
      this.flipToFront(transcript);
      return true;
    }

    if (intent.tool === 'forget_card') {
      this.speakKnowledgeText(transcript);
      return true;
    }

    if (intent.tool === 'confirm_remembered') {
      if (this.data.recallMode && this.data.cardFlipped && this.data.recallAwaitingAnswer) {
        this.completeRememberedCard(transcript);
        return true;
      }
      return false;
    }

    if (intent.tool === 'open_card' && intent.title) {
      normalizedTitle = this.normalizeVoiceText(intent.title);
      this.openCardByTitle(normalizedTitle, transcript);
      return true;
    }

    return false;
  },
  containsAny(text, patterns) {
    var i;

    if (!text || !patterns || !patterns.length) {
      return false;
    }

    for (i = 0; i < patterns.length; i += 1) {
      if (text.indexOf(patterns[i]) !== -1) {
        return true;
      }
    }

    return false;
  },
  initVoiceRecognition() {
    if (typeof SpeechRecognition !== 'function') {
      this.setData({
        voiceEnabled: false,
        voiceListening: false,
        voiceStatus: '当前环境暂不支持语音',
        lastTranscript: '语音识别不可用'
      });
      return;
    }

    try {
      this.voiceRecognition = new SpeechRecognition();
      this.voiceRecognition.lang = 'zh-CN';
      this.voiceRecognition.continuous = false;
      this.voiceRecognition.interimResults = false;
      this.voiceRecognition.maxAlternatives = 1;

      this.voiceRecognition.onstart = () => {
        this.setData({
          voiceEnabled: true,
          voiceListening: true,
          voiceStatus: this.data.showWelcome ? '请说 开始' : '正在听你说话',
          lastTranscript: '语音识别已开始'
        });
      };

      this.voiceRecognition.onresult = (event) => {
        var transcript = this.extractTranscript(event);
        this.setData({
          voiceListening: false,
          lastTranscript: transcript || '没有识别到有效语音'
        });
        this.handleVoiceCommand(transcript);
      };

      this.voiceRecognition.onerror = (event) => {
        var message = '语音识别失败';
        if (event && (event.message || event.error)) {
          message = String(event.message || event.error);
        }
        this.setData({
          voiceEnabled: true,
          voiceListening: false,
          voiceStatus: this.data.showWelcome ? '请说 开始' : '语音识别出错',
          lastTranscript: message
        });
        if (this.data.showWelcome) {
          this.scheduleWelcomeListening(900);
        } else {
          this.scheduleHomeListening(900);
        }
      };

      this.voiceRecognition.onend = () => {
        this.setData({
          voiceEnabled: true,
          voiceListening: false
        });
        if (this.data.showWelcome) {
          this.scheduleWelcomeListening(520);
        } else {
          this.scheduleHomeListening(520);
        }
      };

      this.setData({
        voiceEnabled: true,
        voiceStatus: this.data.showWelcome ? '欢迎页可以说 开始' : '可以说 下一张 或 记住了',
        lastTranscript: '未收到语音'
      });
    } catch (error) {
      this.setData({
        voiceEnabled: false,
        voiceListening: false,
        voiceStatus: '语音入口初始化失败',
        lastTranscript: error && error.message ? error.message : '未知错误'
      });
    }
  },
  extractTranscript(event) {
    var resultIndex;
    var result;

    if (!event || !event.results || !event.results.length) {
      return '';
    }

    resultIndex = typeof event.resultIndex === 'number' ? event.resultIndex : 0;
    result = event.results[resultIndex] || event.results[0];

    if (!result || !result.length || !result[0]) {
      return '';
    }

    return result[0].transcript ? String(result[0].transcript).trim() : '';
  },
  normalizeVoiceText(text) {
    if (!text) {
      return '';
    }

    return String(text)
      .replace(/\s+/g, '')
      .replace(/[，。、“”"'`~!@#$%^&*()_+\-=\[\]{};:<>?/\\|]/g, '');
  },
  startVoiceRecognition() {
    if (!this.voiceRecognition || this.data.voiceListening) {
      return;
    }

    this.clearHomeVoiceTimer();

    try {
      this.voiceRecognition.start();
    } catch (error) {
      this.setData({
        voiceStatus: '语音启动失败',
        lastTranscript: error && error.message ? error.message : '无法启动语音识别'
      });
    }
  },
  stopVoiceRecognition() {
    if (!this.voiceRecognition) {
      return;
    }

    try {
      this.voiceRecognition.abort();
    } catch (error) {
      // ignore inactive session errors
    }
  },
  clearSpeechFollowupTimer() {
    if (this.speechFollowupTimer) {
      clearTimeout(this.speechFollowupTimer);
      this.speechFollowupTimer = null;
    }
  },
  estimateSpeechDuration(text) {
    var length = 0;
    var duration = 0;

    if (text) {
      length = String(text).length;
    }

    duration = 1400 + length * 180;

    if (duration < 2600) {
      return 2600;
    }

    if (duration > 9000) {
      return 9000;
    }

    return duration;
  },
  askRecallQuestion(cardId, promptSource) {
    var promptText = '乐乐，你记住了吗';
    var utterance;

    if (
      !this.data.recallMode ||
      !this.data.cardFlipped ||
      !this.data.currentCard ||
      this.data.currentCard.id !== cardId
    ) {
      return;
    }

    this.setData({
      recallAwaitingAnswer: true,
      voiceStatus: promptText,
      lastTranscript: promptSource || '回忆提问'
    });

    if (
      typeof SpeechSynthesisUtterance === 'function' &&
      typeof speechSynthesis !== 'undefined' &&
      speechSynthesis &&
      typeof speechSynthesis.speak === 'function'
    ) {
      try {
        utterance = new SpeechSynthesisUtterance(promptText);
        speechSynthesis.speak(utterance, 'immediate');
      } catch (error) {
        // ignore prompt speech failure and keep text prompt visible
      }
    }

    this.scheduleHomeListening(1200);
  },
  speakKnowledgeText(transcript) {
    var textParts;
    var speakText;
    var utterance;
    var promptText = '乐乐，你记住了吗';
    var currentCardId;
    var followupDelay;

    this.clearAutoNextTimers();
    this.clearSpeechFollowupTimer();
    this.setData({
      recallAwaitingAnswer: false
    });

    if (!this.data.currentCard || !this.data.currentCard.id) {
      this.setData({
        voiceStatus: '当前没有可播报的知识内容',
        lastTranscript: transcript || '记不住'
      });
      return;
    }

    if (
      typeof SpeechSynthesisUtterance !== 'function' ||
      typeof speechSynthesis === 'undefined' ||
      !speechSynthesis ||
      typeof speechSynthesis.speak !== 'function'
    ) {
      this.setData({
        voiceStatus: '当前环境暂不支持语音播报',
        lastTranscript: transcript || '记不住'
      });
      return;
    }

    currentCardId = this.data.currentCard.id;
    textParts = [
      this.data.currentCard.title,
      this.data.currentCard.scene,
      this.data.currentCard.content
    ].filter((item) => item);
    speakText = textParts.join('。');

    if (!speakText) {
      this.setData({
        voiceStatus: '当前卡片没有可播报的知识文字',
        lastTranscript: transcript || '记不住'
      });
      return;
    }

    utterance = new SpeechSynthesisUtterance(speakText);

    try {
      speechSynthesis.speak(utterance, 'immediate');
      this.setData({
        voiceStatus: '正在播报 ' + this.data.currentCard.title + ' 的知识内容',
        lastTranscript: transcript || '记不住'
      });
    } catch (error) {
      this.setData({
        voiceStatus: '语音播报失败',
        lastTranscript: error && error.message ? error.message : (transcript || '记不住')
      });
      return;
    }

    followupDelay = this.estimateSpeechDuration(speakText);
    this.speechFollowupTimer = setTimeout(() => {
      this.speechFollowupTimer = null;
      this.askRecallQuestion(currentCardId, '知识播报完毕');
    }, followupDelay);
  },
  clearMotionTimers() {
    if (this.motionTimer) {
      clearTimeout(this.motionTimer);
      this.motionTimer = null;
    }
    if (this.motionResetTimer) {
      clearTimeout(this.motionResetTimer);
      this.motionResetTimer = null;
    }
  },
  clearParticleTimer() {
    if (this.particleTimer) {
      clearTimeout(this.particleTimer);
      this.particleTimer = null;
    }
  },
  clearWelcomeTimers() {
    if (this.welcomeListenTimer) {
      clearTimeout(this.welcomeListenTimer);
      this.welcomeListenTimer = null;
    }
    if (this.welcomeTickTimer) {
      clearInterval(this.welcomeTickTimer);
      this.welcomeTickTimer = null;
    }
    if (this.welcomeEnterTimer) {
      clearTimeout(this.welcomeEnterTimer);
      this.welcomeEnterTimer = null;
    }
  },
  clearWelcomeListenTimer() {
    if (this.welcomeListenTimer) {
      clearTimeout(this.welcomeListenTimer);
      this.welcomeListenTimer = null;
    }
  },
  clearHomeVoiceTimer() {
    if (this.homeVoiceTimer) {
      clearTimeout(this.homeVoiceTimer);
      this.homeVoiceTimer = null;
    }
  },
  startWelcomeFlow() {
    this.clearWelcomeTimers();
    this.setData({
      showWelcome: true,
      welcomeCountdown: 5,
      welcomeHint: this.data.voiceEnabled
        ? '滑动查看更多'
        : '滑动查看更多'
    });
    if (this.data.voiceEnabled) {
      this.scheduleWelcomeListening(480);
    }
    this.welcomeTickTimer = setInterval(() => {
      var nextCountdown = this.data.welcomeCountdown - 1;
      if (nextCountdown <= 0) {
        this.clearWelcomeTimers();
        this.enterHomePage();
        return;
      }
      this.setData({
        welcomeCountdown: nextCountdown
      });
    }, 1000);
    this.welcomeEnterTimer = setTimeout(() => {
      this.enterHomePage();
    }, 5000);
  },
  scheduleWelcomeListening(delay) {
    if (!this.data.showWelcome || !this.data.voiceEnabled) {
      return;
    }
    this.clearWelcomeListenTimer();
    this.welcomeListenTimer = setTimeout(() => {
      if (this.data.showWelcome && !this.data.voiceListening) {
        this.startVoiceRecognition();
      }
    }, typeof delay === 'number' ? delay : 420);
  },
  scheduleHomeListening(delay) {
    this.clearHomeVoiceTimer();
    if (this.data.showWelcome || !this.data.voiceEnabled) {
      return;
    }
    this.homeVoiceTimer = setTimeout(() => {
      if (!this.data.showWelcome && !this.data.voiceListening) {
        this.startVoiceRecognition();
      }
    }, typeof delay === 'number' ? delay : 420);
  },
  enterHomePage() {
    this.clearWelcomeTimers();
    this.clearHomeVoiceTimer();
    this.setData({
      showWelcome: false,
      welcomeCountdown: 0,
      welcomeHint: ''
    });
    this.initNodSensor();
    this.setData({
      voiceStatus: '可直接说 下一张 或 记住了',
      lastTranscript: '主页已开启自动监听'
    });
    this.scheduleHomeListening(320);
  },
  clearRecallTimers() {
    if (this.recallTimer) {
      clearTimeout(this.recallTimer);
      this.recallTimer = null;
    }
  },
  clearAutoNextTimers() {
    if (this.autoNextTickTimer) {
      clearInterval(this.autoNextTickTimer);
      this.autoNextTickTimer = null;
    }
    if (this.autoNextTimer) {
      clearTimeout(this.autoNextTimer);
      this.autoNextTimer = null;
    }
  },
  startAutoNextCountdown() {
    this.clearAutoNextTimers();

    if (this.data.showWelcome || !this.data.cardFlipped) {
      return;
    }

    this.setData({
      autoNextCountdown: 4,
      recallAwaitingAnswer: false,
      voiceStatus: '回忆模式已开启，4S 后开始提问'
    });

    this.autoNextTickTimer = setInterval(() => {
      var nextCountdown = this.data.autoNextCountdown - 1;

      if (nextCountdown <= 0) {
        clearInterval(this.autoNextTickTimer);
        this.autoNextTickTimer = null;
        this.setData({
          autoNextCountdown: 0
        });
        return;
      }

      this.setData({
        autoNextCountdown: nextCountdown,
        voiceStatus: '回忆模式已开启，' + nextCountdown + 'S 后开始提问'
      });
    }, 1000);

    this.autoNextTimer = setTimeout(() => {
      var currentCardId = this.data.currentCard && this.data.currentCard.id;
      this.clearAutoNextTimers();
      this.setData({
        autoNextCountdown: 0
      });
      this.askRecallQuestion(currentCardId, '回忆倒计时结束');
    }, 4000);
  },
  buildParticleShards(effectType) {
    if (effectType === 'shatter') {
      return [
        { id: 's1', className: 'particle-shatter', style: 'left: 14%; top: 18%; animation-delay: 0ms;' },
        { id: 's2', className: 'particle-shatter', style: 'left: 24%; top: 34%; animation-delay: 20ms;' },
        { id: 's3', className: 'particle-shatter', style: 'left: 38%; top: 16%; animation-delay: 40ms;' },
        { id: 's4', className: 'particle-shatter', style: 'left: 48%; top: 40%; animation-delay: 10ms;' },
        { id: 's5', className: 'particle-shatter', style: 'left: 58%; top: 20%; animation-delay: 60ms;' },
        { id: 's6', className: 'particle-shatter', style: 'left: 66%; top: 46%; animation-delay: 30ms;' },
        { id: 's7', className: 'particle-shatter', style: 'left: 76%; top: 28%; animation-delay: 50ms;' },
        { id: 's8', className: 'particle-shatter', style: 'left: 84%; top: 42%; animation-delay: 70ms;' },
        { id: 's9', className: 'particle-shatter', style: 'left: 30%; top: 58%; animation-delay: 35ms;' },
        { id: 's10', className: 'particle-shatter', style: 'left: 56%; top: 60%; animation-delay: 55ms;' }
      ];
    }

    return [
      { id: 'p1', className: '', style: 'left: 12%; top: 18%; animation-delay: 0ms;' },
      { id: 'p2', className: '', style: 'left: 32%; top: 26%; animation-delay: 30ms;' },
      { id: 'p3', className: '', style: 'left: 52%; top: 16%; animation-delay: 50ms;' },
      { id: 'p4', className: '', style: 'left: 72%; top: 24%; animation-delay: 80ms;' },
      { id: 'p5', className: '', style: 'left: 18%; top: 48%; animation-delay: 20ms;' },
      { id: 'p6', className: '', style: 'left: 44%; top: 52%; animation-delay: 90ms;' },
      { id: 'p7', className: '', style: 'left: 66%; top: 58%; animation-delay: 40ms;' },
      { id: 'p8', className: '', style: 'left: 82%; top: 44%; animation-delay: 70ms;' }
    ];
  },
  triggerParticleBurst() {
    this.clearParticleTimer();
    this.setData({
      particleBurstActive: true,
      particleShards: this.buildParticleShards('burst')
    });

    this.particleTimer = setTimeout(() => {
      this.setData({
        particleBurstActive: false,
        particleShards: []
      });
    }, 520);
  },
  triggerShatterBurst() {
    this.clearParticleTimer();
    this.setData({
      particleBurstActive: true,
      particleShards: this.buildParticleShards('shatter')
    });

    this.particleTimer = setTimeout(() => {
      this.setData({
        particleBurstActive: false,
        particleShards: []
      });
    }, 760);
  },
  clearMemoryReviewTimer() {
    if (this.memoryReviewTimer) {
      clearTimeout(this.memoryReviewTimer);
      this.memoryReviewTimer = null;
    }
  },
  initNodSensor() {
    if (typeof AbsoluteOrientationSensor !== 'function') {
      this.setData({
        nodEnabled: false
      });
      return;
    }

    try {
      this.orientationSensor = new AbsoluteOrientationSensor({
        frequency: 30
      });
      this.nodNeutralPitch = 0;
      this.nodPeakDetected = false;
      this.nodPeakTimestamp = 0;
      this.nodCooldownUntil = 0;

      this.orientationSensor.addEventListener('reading', (event) => {
        this.handleOrientationReading(event);
      });

      this.orientationSensor.addEventListener('error', () => {
        this.setData({
          nodEnabled: false
        });
      });

      this.orientationSensor.start();
      this.setData({
        nodEnabled: true
      });
    } catch (error) {
      this.setData({
        nodEnabled: false
      });
    }
  },
  stopNodSensor() {
    if (!this.orientationSensor) {
      return;
    }

    try {
      this.orientationSensor.stop();
    } catch (error) {
      // ignore inactive sensor errors
    }
  },
  getEventKeyInfo(event) {
    var info = {
      rawCode: null,
      rawKey: '',
      numericCode: null,
      rawAction: '',
      text: ''
    };
    var rawCode;
    var rawKey;
    var rawAction;
    var numericCode;

    if (!event) {
      return info;
    }

    rawCode = event.keyCode;
    if (typeof rawCode !== 'number' && event.detail && typeof event.detail.keyCode === 'number') {
      rawCode = event.detail.keyCode;
    }
    if (typeof rawCode !== 'number' && typeof event.which === 'number') {
      rawCode = event.which;
    }

    rawKey = event.code || event.key || '';
    if (!rawKey && event.detail) {
      rawKey = event.detail.code || event.detail.key || '';
    }

    rawAction =
      event.action ||
      event.type ||
      event.name ||
      event.direction ||
      event.gesture ||
      event.intent ||
      '';
    if (!rawAction && event.detail) {
      rawAction =
        event.detail.action ||
        event.detail.type ||
        event.detail.name ||
        event.detail.direction ||
        event.detail.gesture ||
        event.detail.intent ||
        '';
    }

    numericCode = typeof rawCode === 'number' ? rawCode : null;
    info.rawCode = rawCode;
    info.rawKey = rawKey ? String(rawKey) : '';
    info.rawAction = rawAction ? String(rawAction) : '';
    info.numericCode = numericCode;
    info.text = String([rawKey || '', rawAction || '', rawCode || ''].join(' '))
      .replace(/\s+/g, '')
      .toUpperCase();

    return info;
  },
  getHardwareAction(event) {
    var keyInfo = this.getEventKeyInfo(event);
    var text = keyInfo.text;
    var code = keyInfo.numericCode;

    if (
      code === 22 ||
      code === 24 ||
      code === 93 ||
      text.indexOf('RIGHT') !== -1 ||
      text.indexOf('SLIDERIGHT') !== -1 ||
      text.indexOf('SWIPERIGHT') !== -1 ||
      text.indexOf('NEXTPAGE') !== -1 ||
      text.indexOf('DPAD_RIGHT') !== -1 ||
      text.indexOf('VOLUME_UP') !== -1 ||
      text.indexOf('PAGE_DOWN') !== -1 ||
      text.indexOf('FORWARD') !== -1 ||
      text.indexOf('NEXT') !== -1
    ) {
      return 'next';
    }

    if (
      code === 21 ||
      code === 19 ||
      code === 25 ||
      code === 92 ||
      text.indexOf('LEFT') !== -1 ||
      text.indexOf('SLIDELEFT') !== -1 ||
      text.indexOf('SWIPELEFT') !== -1 ||
      text.indexOf('PREVPAGE') !== -1 ||
      text.indexOf('DPAD_LEFT') !== -1 ||
      text.indexOf('DPAD_UP') !== -1 ||
      text.indexOf('VOLUME_DOWN') !== -1 ||
      text.indexOf('PAGE_UP') !== -1 ||
      text.indexOf('BACKWARD') !== -1 ||
      text.indexOf('PREV') !== -1
    ) {
      return 'prev';
    }

    if (
      code === 23 ||
      code === 66 ||
      text.indexOf('OK') !== -1 ||
      text.indexOf('SELECT') !== -1 ||
      text.indexOf('DPAD_CENTER') !== -1 ||
      text.indexOf('ENTER') !== -1
    ) {
      return 'confirm';
    }

    return '';
  },
  dispatchHardwareAction(action, transcript) {
    if (!action) {
      return false;
    }

    if (this.data.showWelcome) {
      if (action === 'next' || action === 'confirm') {
        this.enterHomePage();
        this.setData({
          voiceStatus: '已进入主页',
          lastTranscript: transcript || '镜脚操作进入主页'
        });
        return true;
      }
      return false;
    }

    if (action === 'next') {
      this.showNextCard(transcript || '镜脚滑动下一张');
      return true;
    }

    if (action === 'prev') {
      this.showPrevCard(transcript || '镜脚滑动上一张');
      return true;
    }

    if (action === 'confirm') {
      this.startVoiceRecognition();
      this.setData({
        voiceStatus: '已通过镜脚操作开启语音',
        lastTranscript: transcript || '镜脚确认'
      });
      return true;
    }

    return false;
  },
  markHardwareHandled(action, transcript) {
    this.lastHardwareAction = action || '';
    this.lastHardwareKeyText = transcript || '';
    this.lastHardwareHandledAction = action || '';
    this.lastHardwareHandledAt = Date.now();
  },
  shouldSkipHardwareDuplicate(action) {
    var now = Date.now();

    if (
      action &&
      this.lastHardwareHandledAction === action &&
      this.lastHardwareHandledAt &&
      now - this.lastHardwareHandledAt < 320
    ) {
      return true;
    }

    return false;
  },
  onKeyDown(event) {
    var action = this.getHardwareAction(event);
    var keyInfo = this.getEventKeyInfo(event);
    var transcript = keyInfo.text || keyInfo.rawAction || keyInfo.rawKey || String(keyInfo.rawCode || '');

    this.lastHardwareAction = action || '';
    this.lastHardwareKeyText = transcript;

    if (!action || this.shouldSkipHardwareDuplicate(action)) {
      return;
    }

    if (this.dispatchHardwareAction(action, transcript)) {
      this.markHardwareHandled(action, transcript);
    }
  },
  onKeyUp(event) {
    var action = this.getHardwareAction(event);
    var keyInfo = this.getEventKeyInfo(event);
    var transcript = keyInfo.text || keyInfo.rawAction || keyInfo.rawKey || String(keyInfo.rawCode || '');

    if (!action) {
      this.lastHardwareAction = '';
      this.lastHardwareKeyText = '';
      return;
    }

    if (this.shouldSkipHardwareDuplicate(action)) {
      this.lastHardwareAction = '';
      this.lastHardwareKeyText = '';
      return;
    }

    transcript = this.lastHardwareKeyText || transcript || action;
    this.lastHardwareAction = '';
    this.lastHardwareKeyText = '';

    if (this.dispatchHardwareAction(action, transcript)) {
      this.markHardwareHandled(action, transcript);
    }
  },
  async handleWakeupEvent(event) {
    var wakeText = '';
    var normalizedWakeText = '';
    var handled = false;

    if (event && event.keyword) {
      wakeText = String(event.keyword);
    } else if (event && event.text) {
      wakeText = String(event.text);
    } else if (event && event.detail && event.detail.keyword) {
      wakeText = String(event.detail.keyword);
    } else if (event && event.detail && event.detail.text) {
      wakeText = String(event.detail.text);
    }

    normalizedWakeText = this.normalizeVoiceText(wakeText);

    this.setData({
      voiceStatus: this.data.showWelcome ? '语音已唤醒，请说 开始' : '语音已唤醒',
      lastTranscript: wakeText || '语音唤醒'
    });

    if (normalizedWakeText) {
      handled = await this.handleVoiceCommand(wakeText);
      if (handled) {
        if (!this.data.showWelcome) {
          this.scheduleHomeListening(960);
        }
        return;
      }
    }

    this.startVoiceRecognition();
  },
  onVoiceWakeup(event) {
    this.handleWakeupEvent(event);
  },
  onViceWakeup(event) {
    this.handleWakeupEvent(event);
  },
  getPitchFromQuaternion(quaternion) {
    var x;
    var y;
    var z;
    var w;

    if (!quaternion || quaternion.length < 4) {
      return 0;
    }

    x = Number(quaternion[0]) || 0;
    y = Number(quaternion[1]) || 0;
    z = Number(quaternion[2]) || 0;
    w = Number(quaternion[3]) || 0;

    return Math.atan2(
      2 * (w * x + y * z),
      1 - 2 * (x * x + y * y)
    );
  },
  handleOrientationReading(event) {
    var quaternion;
    var pitch;
    var delta;
    var now;

    quaternion = event && event.quaternion
      ? event.quaternion
      : this.orientationSensor && this.orientationSensor.quaternion;

    if (!quaternion) {
      return;
    }

    pitch = this.getPitchFromQuaternion(quaternion);
    this.nodNeutralPitch = this.nodNeutralPitch * 0.92 + pitch * 0.08;
    delta = pitch - this.nodNeutralPitch;
    now = Date.now();

    if (!this.data.recallMode || !this.data.cardFlipped || !this.data.nodEnabled) {
      this.nodPeakDetected = false;
      return;
    }

    if (now < this.nodCooldownUntil) {
      return;
    }

    if (!this.nodPeakDetected && Math.abs(delta) > 0.24) {
      this.nodPeakDetected = true;
      this.nodPeakTimestamp = now;
      return;
    }

    if (this.nodPeakDetected) {
      if (Math.abs(delta) < 0.08 && now - this.nodPeakTimestamp < 900) {
        this.nodPeakDetected = false;
        this.nodCooldownUntil = now + 1600;
        this.handleRememberedByNod();
        return;
      }

      if (now - this.nodPeakTimestamp >= 900) {
        this.nodPeakDetected = false;
      }
    }
  },
  resetRecallState() {
    this.clearRecallTimers();
    this.clearAutoNextTimers();
    this.clearSpeechFollowupTimer();
    this.setData({
      recallMode: false,
      recallAwaitingAnswer: false,
      revealedSymbols: [],
      autoNextCountdown: 0
    });
  },
  startRecallReveal() {
    var symbols = this.data.currentCard.symbols || [];
    var title = this.data.currentCard.title || '当前卡片';
    var revealNext = () => {
      var nextIndex = this.data.revealedSymbols.length;
      var nextSymbols;

      if (!this.data.recallMode || nextIndex >= symbols.length) {
        if (this.data.recallMode) {
          this.setData({
            voiceStatus: '回忆模式进行中'
          });
        }
        this.clearRecallTimers();
        return;
      }

      nextSymbols = symbols.slice(0, nextIndex + 1);
      this.setData({
        revealedSymbols: nextSymbols,
        voiceStatus: '正在回忆 ' + title
      });

      this.recallTimer = setTimeout(revealNext, 680);
    };

    this.clearRecallTimers();
    this.setData({
      recallMode: true,
      revealedSymbols: []
    });

    this.recallTimer = setTimeout(revealNext, 420);
  },
  getPageTextByTotal(index, total) {
    if (!total) {
      return '0/0';
    }

    return String(index + 1) + '/' + String(total);
  },
  getCardPageText(index) {
    return this.getPageTextByTotal(index, this.data.cards.length);
  },
  getEmptyCard() {
    return {
      id: 0,
      title: '',
      image: '',
      scene: '',
      content: '',
      symbols: [],
      memoryKey: '',
      memoryHint: ''
    };
  },
  getCardByIndex(index) {
    return this.data.cards[index] || this.getEmptyCard();
  },
  scheduleMemoryReview(memoryList) {
    var i;
    var nextDueAt = 0;
    var delay;
    var list = memoryList || this.data.memoryList;

    this.clearMemoryReviewTimer();

    if (!list.length) {
      return;
    }

    nextDueAt = list[0].dueAt || 0;
    for (i = 1; i < list.length; i += 1) {
      if ((list[i].dueAt || 0) < nextDueAt) {
        nextDueAt = list[i].dueAt || 0;
      }
    }

    delay = Math.max(200, nextDueAt - Date.now());
    this.memoryReviewTimer = setTimeout(() => {
      this.releaseMemoryCards();
    }, delay);
  },
  releaseMemoryCards() {
    var now = Date.now();
    var pending = [];
    var dueCards = [];
    var updatedCards;
    var updateData;
    var i;
    var item;

    for (i = 0; i < this.data.memoryList.length; i += 1) {
      item = this.data.memoryList[i];
      if ((item.dueAt || 0) <= now) {
        dueCards.push({
          id: item.id,
          title: item.title,
          image: item.image,
          scene: item.scene,
          content: item.content,
          symbols: item.symbols,
          memoryKey: item.memoryKey,
          memoryHint: item.memoryHint
        });
      } else {
        pending.push(item);
      }
    }

    if (!dueCards.length) {
      this.scheduleMemoryReview();
      return;
    }

    updatedCards = this.data.cards.slice();
    for (i = 0; i < dueCards.length; i += 1) {
      if (!updatedCards.some((card) => card.id === dueCards[i].id)) {
        updatedCards.push(dueCards[i]);
      }
    }

    updateData = {
      cards: updatedCards,
      memoryList: pending,
      cardPageText: this.getPageTextByTotal(
        Math.min(this.data.currentIndex, Math.max(updatedCards.length - 1, 0)),
        updatedCards.length
      ),
      voiceStatus: dueCards.length === 1
        ? dueCards[0].title + ' 已回到待复习队列'
        : '有卡片回到待复习队列'
    };

    if (!this.data.cards.length && updatedCards.length) {
      updateData.currentIndex = 0;
      updateData.currentCard = updatedCards[0];
      updateData.cardPageText = this.getPageTextByTotal(0, updatedCards.length);
      updateData.cardFlipped = false;
      updateData.recallMode = false;
      updateData.revealedSymbols = [];
      updateData.cardMotionClass = '';
    }

    this.setData(updateData);
    this.scheduleMemoryReview(pending);
  },
  handleRememberedByNod() {
    this.completeRememberedCard('点头确认');
  },
  completeRememberedCard(transcript) {
    var rememberedCard;
    var remainingCards;
    var memoryItem;
    var updatedMemoryList;
    var nextIndex = 0;
    var nextCard;

    if (!this.data.currentCard || !this.data.currentCard.id) {
      return;
    }

    rememberedCard = this.data.currentCard;
    remainingCards = this.data.cards.filter((card) => card.id !== rememberedCard.id);
    memoryItem = {
      id: rememberedCard.id,
      title: rememberedCard.title,
      image: rememberedCard.image,
      scene: rememberedCard.scene,
      content: rememberedCard.content,
      symbols: rememberedCard.symbols,
      memoryKey: rememberedCard.memoryKey,
      memoryHint: rememberedCard.memoryHint,
      dueAt: Date.now() + this.data.memoryReviewDelayMs
    };

    if (remainingCards.length) {
      nextIndex = this.data.currentIndex % remainingCards.length;
      nextCard = remainingCards[nextIndex];
    } else {
      nextCard = this.getEmptyCard();
    }

    updatedMemoryList = this.data.memoryList
      .filter((item) => item.id !== rememberedCard.id)
      .concat([memoryItem]);

    this.clearMotionTimers();
    this.clearAutoNextTimers();
    this.clearSpeechFollowupTimer();
    this.clearParticleTimer();
    this.clearRecallTimers();
    this.setData({
      cardMotionClass: 'card-out',
      recallAwaitingAnswer: false,
      voiceStatus: rememberedCard.title + ' 已记住，正在切换下一张',
      lastTranscript: transcript || '记住了'
    });
    this.triggerShatterBurst();

    this.motionTimer = setTimeout(() => {
      this.setData({
      cards: remainingCards,
      memoryList: updatedMemoryList,
      currentIndex: nextIndex,
      currentCard: nextCard,
      cardPageText: this.getPageTextByTotal(nextIndex, remainingCards.length),
      cardFlipped: false,
      recallMode: false,
      recallAwaitingAnswer: false,
      revealedSymbols: [],
      autoNextCountdown: 0,
      particleBurstActive: false,
      particleShards: [],
      cardMotionClass: 'card-in',
      voiceStatus: rememberedCard.title + ' 已记住，稍后再次回顾',
      lastTranscript: transcript || '记住了'
      });
      this.scheduleMemoryReview(updatedMemoryList);
      this.scheduleHomeListening(920);

      this.motionResetTimer = setTimeout(() => {
        this.setData({
          cardMotionClass: ''
        });
      }, 220);
    }, 420);
  },
  async handleVoiceCommand(transcript) {
    var text = this.normalizeVoiceText(transcript);
    var intent = null;
    var executed = false;

    if (!text) {
      this.setData({
        voiceStatus: this.data.showWelcome ? '请说 开始' : '没有识别到清晰指令',
        lastTranscript: '未收到语音'
      });
      return false;
    }

    if (this.data.llmRouteEnabled) {
      intent = await this.routeVoiceCommandWithLLM(transcript);
      executed = this.executeVoiceIntent(intent, transcript);

      if (executed) {
        return true;
      }
    }

    return this.handleVoiceCommandFallback(transcript);
  },
  handleVoiceCommandFallback(transcript) {
    var text = this.normalizeVoiceText(transcript);

    if (!text) {
      this.setData({
        voiceStatus: this.data.showWelcome ? '请说 开始' : '没有识别到清晰指令',
        lastTranscript: '未收到语音'
      });
      return false;
    }

    if (this.data.showWelcome) {
      if (
        text.indexOf('开始') !== -1 ||
        text.indexOf('开始学习') !== -1 ||
        text.indexOf('进入主页') !== -1
      ) {
        this.enterHomePage();
        this.setData({
          voiceStatus: '已进入主页',
          lastTranscript: transcript
        });
        return true;
      }

      this.setData({
        voiceStatus: '欢迎页请说 开始',
        lastTranscript: transcript
      });
      return false;
    }

    if (
      this.data.recallMode &&
      this.data.cardFlipped &&
      this.data.recallAwaitingAnswer &&
      this.containsAny(text, ['记住了', '记住啦', '我记住了', '记住这张', '记住这个', '记住'])
    ) {
      this.completeRememberedCard(transcript);
      return true;
    }

    if (
      this.containsAny(text, ['记住了', '记住啦', '我记住了', '记住这张', '记住这个'])
    ) {
      this.flipToBack(transcript);
      return true;
    }

    if (
      this.containsAny(text, ['记不住', '没记住', '想不起来', '不记得', '没想起来'])
    ) {
      this.speakKnowledgeText(transcript);
      return true;
    }

    if (
      this.containsAny(text, ['看正面', '回正面', '回到正面', '看前面', '返回正面'])
    ) {
      this.flipToFront(transcript);
      return true;
    }

    if (
      this.containsAny(text, [
        '下一张',
        '下一张卡片',
        '下一个',
        '下一页',
        '下页',
        '翻页',
        '翻到下一页',
        '切到下一页',
        '切换下一页',
        '下一卡',
        '往后翻'
      ])
    ) {
      this.showNextCard(transcript);
      return true;
    }

    if (
      this.containsAny(text, [
        '上一张',
        '上一页',
        '上一个',
        '上页',
        '翻到上一页',
        '切到上一页',
        '切换上一页',
        '往前翻'
      ])
    ) {
      this.showPrevCard(transcript);
      return true;
    }

    this.openCardByTitle(text, transcript);
    return true;
  },
  openCardByTitle(normalizedText, transcript) {
    var i;
    var title;

    for (i = 0; i < this.data.cards.length; i += 1) {
      title = this.normalizeVoiceText(this.data.cards[i].title);
      if (title && normalizedText.indexOf(title) !== -1) {
        this.clearMotionTimers();
        this.clearRecallTimers();
        this.setData({
          currentIndex: i,
          cardPageText: this.getCardPageText(i),
          currentCard: this.getCardByIndex(i),
          cardFlipped: false,
          recallMode: false,
          recallAwaitingAnswer: false,
          revealedSymbols: [],
          autoNextCountdown: 0,
          cardMotionClass: '',
          voiceStatus: '已打开 ' + this.data.cards[i].title,
          lastTranscript: transcript
        });
        return;
      }
    }

    this.setData({
      voiceStatus: '未匹配到卡片名称',
      lastTranscript: transcript
    });
  },
  showNextCard(transcript) {
    var nextIndex;

    if (!this.data.cards.length) {
      return;
    }

    this.clearMotionTimers();
    this.clearAutoNextTimers();
    this.clearSpeechFollowupTimer();
    this.clearRecallTimers();
    nextIndex = (this.data.currentIndex + 1) % this.data.cards.length;
    this.setData({
      currentIndex: nextIndex,
      cardPageText: this.getCardPageText(nextIndex),
      currentCard: this.getCardByIndex(nextIndex),
      cardFlipped: false,
      recallMode: false,
      recallAwaitingAnswer: false,
      revealedSymbols: [],
      autoNextCountdown: 0,
      particleBurstActive: false,
      particleShards: [],
      cardMotionClass: '',
      voiceStatus: '已切换到 ' + this.data.cards[nextIndex].title,
      lastTranscript: transcript || '下一张'
    });
    this.scheduleHomeListening(780);
  },
  showPrevCard(transcript) {
    var prevIndex;

    if (!this.data.cards.length) {
      return;
    }

    this.clearMotionTimers();
    this.clearAutoNextTimers();
    this.clearSpeechFollowupTimer();
    this.clearRecallTimers();
    prevIndex = (this.data.currentIndex - 1 + this.data.cards.length) % this.data.cards.length;
    this.setData({
      currentIndex: prevIndex,
      cardPageText: this.getCardPageText(prevIndex),
      currentCard: this.getCardByIndex(prevIndex),
      cardFlipped: false,
      recallMode: false,
      recallAwaitingAnswer: false,
      revealedSymbols: [],
      autoNextCountdown: 0,
      cardMotionClass: '',
      voiceStatus: '已切换到 ' + this.data.cards[prevIndex].title,
      lastTranscript: transcript || '上一张'
    });
    this.scheduleHomeListening(780);
  },
  flipToBack(transcript) {
    if (!this.data.cards.length || this.data.cardFlipped) {
      this.setData({
        voiceStatus: '当前已经是背面图片',
        lastTranscript: transcript || '记住了'
      });
      return;
    }

    this.clearMotionTimers();
    this.clearAutoNextTimers();
    this.clearSpeechFollowupTimer();
    this.clearParticleTimer();
    this.clearRecallTimers();
    this.setData({
      cardMotionClass: 'card-out',
      recallMode: true,
      recallAwaitingAnswer: false,
      revealedSymbols: [],
      autoNextCountdown: 0,
      particleBurstActive: false,
      particleShards: [],
      voiceStatus: '正在进入回忆模式',
      lastTranscript: transcript || '记住了'
    });

    this.triggerParticleBurst();

    this.motionTimer = setTimeout(() => {
      this.setData({
        cardFlipped: true,
        cardMotionClass: 'card-in',
        voiceStatus: '回忆模式已开启'
      });
      this.startRecallReveal();
      this.startAutoNextCountdown();

      this.motionResetTimer = setTimeout(() => {
        this.setData({
          cardMotionClass: ''
        });
      }, 220);
    }, 160);
    this.scheduleHomeListening(980);
  },
  flipToFront(transcript) {
    if (!this.data.cards.length || !this.data.cardFlipped) {
      this.setData({
        voiceStatus: '当前已经是正面内容',
        lastTranscript: transcript || '看正面'
      });
      return;
    }

    this.clearMotionTimers();
    this.clearAutoNextTimers();
    this.clearSpeechFollowupTimer();
    this.clearParticleTimer();
    this.clearRecallTimers();
    this.setData({
      cardMotionClass: 'card-out',
      recallMode: false,
      recallAwaitingAnswer: false,
      revealedSymbols: [],
      autoNextCountdown: 0,
      particleBurstActive: false,
      particleShards: [],
      voiceStatus: '正在回到正面内容',
      lastTranscript: transcript || '看正面'
    });

    this.motionTimer = setTimeout(() => {
      this.setData({
        cardFlipped: false,
        cardMotionClass: 'card-in',
        voiceStatus: '已回到正面内容'
      });

      this.motionResetTimer = setTimeout(() => {
        this.setData({
          cardMotionClass: ''
        });
      }, 220);
    }, 160);
    this.scheduleHomeListening(780);
  },
  handleNextTap() {
    this.showNextCard('手动点击下一张');
  },
  handleWelcomeStartTap() {
    if (this.data.voiceEnabled) {
      this.setData({
        voiceStatus: '请说 开始',
        lastTranscript: '等待开始口令'
      });
      this.startVoiceRecognition();
      return;
    }

    this.enterHomePage();
  },
  handleWelcomePosterTap() {
    this.enterHomePage();
  },
  handleVoiceTap() {
    this.startVoiceRecognition();
  }
};
</script>

<page>
  <view class="page">
    <view class="welcome-screen" ink:if="{{ showWelcome }}" bindtap="handleWelcomePosterTap">
      <image class="welcome-poster" src="../../docs/image/welcome.png" mode="widthFix"></image>
    </view>

    <view class="empty-state" ink:elif="{{ !cards.length }}">
      <text class="empty-title">知识卡片</text>
      <text class="empty-copy">当前没有可展示的知识卡片。</text>
    </view>

    <view class="dialog-shell" ink:else>
      <view class="dialog-particles" ink:if="{{ particleBurstActive }}">
        <view class="dialog-particle {{ item.className }}" ink:for="{{ particleShards }}" ink:key="id" style="{{ item.style }}"></view>
      </view>

      <view class="dialog-card {{ cardMotionClass }}" ink:if="{{ !cardFlipped }}">
        <text class="dialog-page-counter">{{ cardPageText }}</text>
        <view class="dialog-copy">
          <view class="dialog-top-row">
            <text class="dialog-title">{{ currentCard.title }}</text>
          </view>
          <view class="dialog-memory">
            <view class="dialog-memory-head">
              <text class="dialog-memory-label">keyword</text>
              <text class="dialog-memory-key">{{ currentCard.memoryKey }}</text>
              <view class="dialog-memory-grid">
                <view class="dialog-memory-cell" ink:for="{{ currentCard.symbols }}" ink:key="index">
                  <text class="dialog-memory-cell-text">{{ item }}</text>
                </view>
              </view>
            </view>
            <text class="dialog-memory-hint">{{ currentCard.memoryHint }}</text>
          </view>
          <view class="dialog-body">
            <view class="dialog-reading">
              <text class="dialog-scene">{{ currentCard.scene }}</text>
              <text class="dialog-content">{{ currentCard.content }}</text>
            </view>
          </view>
        </view>
      </view>

      <view class="dialog-card {{ cardMotionClass }}" ink:else>
        <text class="dialog-page-counter">{{ cardPageText }}</text>
        <view class="dialog-back">
          <image class="dialog-back-image" src="{{ currentCard.image }}" mode="aspectFill"></image>
          <text class="dialog-back-title">{{ currentCard.title }}</text>
          <view class="dialog-recall" ink:if="{{ recallMode }}">
            <text class="dialog-recall-label">回忆模式</text>
            <text class="dialog-recall-countdown" ink:if="{{ autoNextCountdown > 0 }}">{{ autoNextCountdown }}S 后开始提问</text>
            <text class="dialog-recall-question" ink:if="{{ recallAwaitingAnswer }}">请回答：记住了 / 记不住</text>
            <view class="dialog-recall-symbols">
              <text class="dialog-recall-symbol" ink:for="{{ revealedSymbols }}" ink:key="index">{{ item }}</text>
            </view>
          </view>
        </view>
      </view>

      <view class="dialog-bubble user-bubble">
        <text class="dialog-role">你</text>
        <text class="dialog-bubble-text">{{ lastTranscript }}</text>
      </view>

      <view class="dialog-bubble assistant-bubble">
        <text class="dialog-role">卡片</text>
        <text class="dialog-bubble-text">{{ voiceStatus }}</text>
      </view>

      <view class="dialog-actions">
        <button class="ghost-button" bindtap="handleVoiceTap">
          <text ink:if="{{ voiceListening }}">正在说话</text>
          <text ink:else>开始语音</text>
        </button>
        <button class="primary-button" bindtap="handleNextTap">下一张</button>
      </view>
    </view>
  </view>
</page>

<style>
.page {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  min-height: 100vh;
  padding: 14px;
  box-sizing: border-box;
  background-color: #000000;
}

.welcome-screen {
  width: 100%;
  max-width: 480px;
  min-height: 320px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.welcome-poster {
  width: 100%;
  border-radius: 0;
}

.dialog-shell {
  position: relative;
  width: 100%;
  max-width: 440px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.dialog-particles {
  position: absolute;
  top: 0;
  right: 0;
  bottom: 118px;
  left: 0;
  overflow: hidden;
  pointer-events: none;
  z-index: 6;
}

.dialog-particle {
  position: absolute;
  width: 12px;
  height: 12px;
  border-radius: 3px;
  border: var(--border-width-thin) solid rgba(217, 255, 122, 0.88);
  background-color: rgba(217, 255, 122, 0.22);
  box-shadow: 0 0 8px rgba(217, 255, 122, 0.32);
  animation: particle-burst 0.48s ease-out forwards;
}

.particle-shatter {
  width: 16px;
  height: 16px;
  border-radius: 2px;
  border-style: dashed;
  background-color: rgba(217, 255, 122, 0.3);
  box-shadow: 0 0 14px rgba(217, 255, 122, 0.44);
  animation: particle-shatter 0.72s ease-out forwards;
}

.dialog-card {
  position: relative;
  width: 100%;
  min-height: 320px;
  padding: 14px;
  box-sizing: border-box;
  border: var(--border-width-thin) solid rgba(64, 255, 94, 0.42);
  border-radius: 12px;
  background-color: rgba(7, 18, 10, 0.52);
}

.dialog-page-counter {
  position: absolute;
  top: 12px;
  right: 12px;
  padding: 3px 8px;
  box-sizing: border-box;
  border-radius: 999px;
  border: var(--border-width-thin) solid rgba(64, 255, 94, 0.26);
  background-color: rgba(64, 255, 94, 0.05);
  color: rgba(233, 255, 237, 0.78);
  font-size: 11px;
  line-height: 15px;
}

.card-out {
  animation: card-out 0.16s ease forwards;
}

.card-in {
  animation: card-in 0.22s ease forwards;
}

.dialog-copy {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding-top: 8px;
}

.dialog-top-row {
  display: flex;
  align-items: flex-start;
  width: 100%;
  gap: 12px;
}

.dialog-body {
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-height: 132px;
}

.dialog-reading {
  flex: 3;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.dialog-title {
  width: 100%;
  color: var(--color-text-primary);
  font-size: 28px;
  line-height: 34px;
  font-weight: bold;
}

.dialog-scene {
  color: rgba(233, 255, 237, 0.84);
  font-size: 14px;
  line-height: 20px;
}

.dialog-content {
  color: rgba(190, 255, 204, 0.76);
  font-size: 14px;
  line-height: 22px;
}

.dialog-back {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.dialog-back-image {
  width: 100%;
  height: 168px;
  border-radius: 8px;
  border: var(--border-width-thin) solid rgba(64, 255, 94, 0.34);
}

.dialog-back-title {
  color: rgba(233, 255, 237, 0.96);
  font-size: 18px;
  line-height: 24px;
}

.dialog-recall {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 10px 12px;
  box-sizing: border-box;
  border: var(--border-width-thin) dashed rgba(64, 255, 94, 0.28);
  border-radius: 10px;
  background-color: rgba(64, 255, 94, 0.03);
}

.dialog-recall-label {
  color: rgba(64, 255, 94, 0.92);
  font-size: 13px;
  line-height: 17px;
  font-weight: bold;
}

.dialog-recall-countdown {
  color: rgba(217, 255, 122, 0.96);
  font-size: 12px;
  line-height: 16px;
}

.dialog-recall-question {
  color: rgba(233, 255, 237, 0.92);
  font-size: 12px;
  line-height: 17px;
}

.dialog-recall-symbols {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-start;
  align-items: flex-start;
  gap: 6px;
}

.dialog-recall-symbol {
  padding: 4px 8px;
  box-sizing: border-box;
  border-radius: 8px;
  border: var(--border-width-thin) solid rgba(64, 255, 94, 0.3);
  background-color: rgba(64, 255, 94, 0.05);
  color: rgba(233, 255, 237, 0.92);
  font-size: 12px;
  line-height: 16px;
}

.dialog-memory {
  width: 100%;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 6px;
  padding: 8px 10px 9px;
  box-sizing: border-box;
  border: var(--border-width-thin) dashed rgba(64, 255, 94, 0.26);
  border-radius: 10px;
  background-color: rgba(64, 255, 94, 0.02);
}

.dialog-memory-head {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  gap: 6px;
}

.dialog-memory-label {
  color: rgba(64, 255, 94, 0.9);
  font-size: 14px;
  line-height: 18px;
  font-weight: bold;
  text-transform: uppercase;
}

.dialog-memory-key {
  padding: 3px 7px;
  box-sizing: border-box;
  border-radius: 4px;
  background-color: #D9FF7A;
  color: #07120A;
  font-size: 11px;
  line-height: 15px;
}

.dialog-memory-grid {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-start;
  align-items: flex-start;
  align-content: flex-start;
  gap: 6px;
}

.dialog-memory-cell {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 28px;
  min-width: 58px;
  padding: 5px 8px;
  box-sizing: border-box;
  border: var(--border-width-thin) dashed rgba(64, 255, 94, 0.3);
  border-radius: 8px;
  background-color: rgba(64, 255, 94, 0.03);
}

.dialog-memory-cell-text {
  color: rgba(233, 255, 237, 0.9);
  font-size: 12px;
  line-height: 16px;
  font-weight: bold;
}

.dialog-memory-hint {
  width: 100%;
  color: rgba(190, 255, 204, 0.74);
  font-size: 12px;
  line-height: 16px;
}

.dialog-bubble {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 10px 12px;
  box-sizing: border-box;
  border-radius: 10px;
}

.user-bubble {
  align-self: flex-end;
  width: calc(100% - 44px);
  border: var(--border-width-thin) solid rgba(64, 255, 94, 0.22);
  background-color: rgba(64, 255, 94, 0.03);
}

.assistant-bubble {
  width: calc(100% - 18px);
  border: var(--border-width-thin) solid rgba(64, 255, 94, 0.34);
  background-color: rgba(10, 24, 12, 0.52);
}

.dialog-role {
  color: rgba(64, 255, 94, 0.9);
  font-size: 11px;
  line-height: 15px;
}

.dialog-bubble-text {
  color: rgba(233, 255, 237, 0.92);
  font-size: 13px;
  line-height: 19px;
}

.dialog-actions {
  display: flex;
  gap: 10px;
}

.ghost-button,
.primary-button {
  flex: 1;
  min-height: 42px;
  border-radius: 12px;
  font-size: 15px;
  line-height: 20px;
}

.ghost-button {
  border: var(--border-width-thin) solid rgba(64, 255, 94, 0.3);
  background-color: rgba(64, 255, 94, 0.04);
  color: rgba(233, 255, 237, 0.94);
}

.primary-button {
  border: var(--border-width-thin) solid rgba(217, 255, 122, 0.9);
  background-color: #D9FF7A;
  color: #07120A;
}

.empty-state {
  width: 100%;
  max-width: 440px;
  padding: 24px 16px;
  box-sizing: border-box;
  border: var(--border-width-thin) dashed rgba(64, 255, 94, 0.26);
  border-radius: 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}

.empty-title {
  color: rgba(233, 255, 237, 0.94);
  font-size: 22px;
  line-height: 28px;
}

.empty-copy {
  color: rgba(190, 255, 204, 0.72);
  font-size: 14px;
  line-height: 20px;
  text-align: center;
}

@keyframes card-out {
  0% {
    opacity: 1;
    transform: scaleX(1);
  }

  100% {
    opacity: 0;
    transform: scaleX(0.94);
  }
}

@keyframes card-in {
  0% {
    opacity: 0;
    transform: scaleX(0.94);
  }

  100% {
    opacity: 1;
    transform: scaleX(1);
  }
}

@keyframes particle-burst {
  0% {
    opacity: 0.92;
    transform: translate3d(0, 0, 0) scale(1);
  }

  100% {
    opacity: 0;
    transform: translate3d(0, -28px, 0) scale(0.24);
  }
}

@keyframes particle-shatter {
  0% {
    opacity: 0.96;
    transform: translate3d(0, 0, 0) rotate(0deg) scale(1);
  }

  100% {
    opacity: 0;
    transform: translate3d(0, -38px, 0) rotate(28deg) scale(0.2);
  }
}
</style>
