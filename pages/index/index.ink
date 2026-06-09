<script def>
{
  "navigationBarTitleText": "知识小卡片"
}
</script>

<script setup>
export default {
  data: {
    viewMode: 'study',
    phase: 'learn',
    currentIndex: 0,
    countdown: 5,
    firstRoundComplete: false,
    imuStatus: '正在初始化点头识别...',
        imuHint: '学习模式点头切卡，挑战模式点头或摇头回答',
    imuMode: '未连接',
    imuValue: '--',
    pitchValue: '--',
    yawValue: '--',
    calibrationText: '等待姿态校准',
    lastAction: '等待第一次点头',
    resultFace: '',
    resultText: '',
    resultType: '',
    voiceEnabled: false,
    voiceListening: false,
    voiceStatus: '点击开始语音后，可以直接说卡片名字。',
    voiceHint: '例如说“光年”“丝绸之路”就会直接打开对应训练页。',
    lastTranscript: '等待语音指令',
    nodEnabled: false,
    shatterActive: false,
    selectedCategory: '知识卡片',
    categoryOptions: [
      '自然科学',
      '历史',
      '生物',
      '地理',
      '物理',
      '化学',
      '计算机'
    ],
    shards: [
      { id: 1, className: 'shard-1' },
      { id: 2, className: 'shard-2' },
      { id: 3, className: 'shard-3' },
      { id: 4, className: 'shard-4' },
      { id: 5, className: 'shard-5' },
      { id: 6, className: 'shard-6' }
    ],
    cards: [
      {
        id: 1,
        category: '历史',
        topics: ['历史'],
        title: '丝绸之路',
        image: '../../assets/illustrations/silk-road.svg',
        scene: '驼队穿过沙海，连通多地贸易路线',
        symbols: ['驼队', '沙海', '地图'],
        memoryKey: '商路',
        memoryHint: '记住骆驼商队和地图，就能快速联想到跨区域贸易网络。',
        content: '丝绸之路不是单一路线，而是连接东亚、中亚、西亚与欧洲的贸易网络。'
      },
      {
        id: 2,
        category: '物理',
        topics: ['自然科学', '物理'],
        title: '光年',
        image: '../../assets/illustrations/light-year.svg',
        scene: '一束光在星空中高速前进，用来衡量超远距离',
        symbols: ['光束', '星空', '距离'],
        memoryKey: '尺子',
        memoryHint: '把光年想成“宇宙里的尺子”，就不容易和时间单位混淆。',
        content: '光年是距离单位，不是时间单位，表示光在真空中一年传播的距离。'
      },
      {
        id: 3,
        category: '地理',
        topics: ['自然科学', '地理'],
        title: '板块运动',
        image: '../../assets/illustrations/plate-motion.svg',
        scene: '两块地壳相互推挤，慢慢抬升出山脉',
        symbols: ['板块', '山脉', '地震'],
        memoryKey: '碰撞',
        memoryHint: '看到两块地壳相撞形成山脉，就能想到地震和板块边界。',
        content: '地球表面的大陆并非静止不动，板块运动会形成山脉、海沟和地震带。'
      },
      {
        id: 4,
        category: '生物',
        topics: ['自然科学', '生物'],
        title: '树木通信',
        image: '../../assets/illustrations/tree-network.svg',
        scene: '树根与菌丝在地下连接，互相传递信号和养分',
        symbols: ['树根', '菌丝', '协作'],
        memoryKey: '网络',
        memoryHint: '把地下菌丝网络看作森林的信息线缆，更容易记住树木之间会互相协作。',
        content: '森林中的树木可以通过地下真菌网络交换养分和化学信号。'
      }
    ]
  },
  onLoad() {
    this.allCards = this.data.cards.map((item) => ({ ...item }));
    this.setData({
      cards: this.allCards,
      currentIndex: 0,
      countdown: this.allCards.length ? 5 : 0,
      lastAction: '已进入知识卡片播放页',
      imuStatus: this.allCards.length ? '知识卡片已准备好' : '当前没有可播放的卡片',
      imuHint: this.allCards.length ? '学习模式点头切卡，挑战模式点头或摇头回答' : '请先补充卡片内容'
    });
    this.initImu();
    if (this.allCards.length) {
      this.startRotation();
    }
  },
  onUnload() {
    this.stopRotation();
    this.clearRecallTimer();
    this.stopVoiceRecognition();
    this.stopImu();
  },
  initVoiceRecognition() {
    if (typeof SpeechRecognition !== 'function') {
      this.setData({
        voiceEnabled: false,
        voiceStatus: '当前环境暂不支持语音进入',
        voiceHint: '可以先点分类，再点击下方按钮进入训练页',
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
          voiceStatus: '正在听你说话...',
          voiceHint: '试着说“光年”“树木通信”或“进入历史”',
          lastTranscript: '语音识别已开始'
        });
      };

      this.voiceRecognition.onresult = (event) => {
        const transcript = this.extractTranscript(event);
        this.setData({
          voiceListening: false,
          lastTranscript: transcript || '没有识别到有效语音'
        });
        this.handleVoiceCommand(transcript);
      };

      this.voiceRecognition.onnomatch = () => {
        this.setData({
          voiceListening: false,
          voiceStatus: '没有听清楚这次指令',
          voiceHint: '可以再说一次“开始学习”或“进入某个分类”',
          lastTranscript: '未匹配到语音内容'
        });
      };

      this.voiceRecognition.onerror = (event) => {
        const message = event && (event.message || event.error) ? String(event.message || event.error) : '语音识别失败';
        this.setData({
          voiceEnabled: true,
          voiceListening: false,
          voiceStatus: '语音识别出错',
          voiceHint: '请再试一次，或改用按钮进入训练页',
          lastTranscript: message
        });
      };

      this.voiceRecognition.onend = () => {
        this.setData({
          voiceEnabled: true,
          voiceListening: false
        });
      };

      this.setData({
        voiceEnabled: true,
        voiceStatus: '语音入口已准备好',
        voiceHint: '点击开始语音，然后说卡片名字，例如“光年”',
        lastTranscript: '等待语音指令'
      });
    } catch (error) {
      this.setData({
        voiceEnabled: false,
        voiceListening: false,
        voiceStatus: '语音入口初始化失败',
        voiceHint: '可以先点分类，再点击下方按钮进入训练页',
        lastTranscript: error && error.message ? error.message : '未知错误'
      });
    }
  },
  extractTranscript(event) {
    if (!event || !event.results || !event.results.length) {
      return '';
    }

    const resultIndex = typeof event.resultIndex === 'number' ? event.resultIndex : 0;
    const firstResult = event.results[resultIndex] || event.results[0];
    if (!firstResult || !firstResult.length || !firstResult[0]) {
      return '';
    }

    return firstResult[0].transcript ? String(firstResult[0].transcript).trim() : '';
  },
  normalizeVoiceText(text) {
    return text ? String(text).replace(/\s+/g, '').replace(/[，。、“”"'`~!@#$%^&*()_+\-=\[\]{};:<>?/\\|]/g, '') : '';
  },
  startVoiceRecognition() {
    if (!this.voiceRecognition || this.data.voiceListening) {
      return;
    }

    try {
      this.voiceRecognition.start();
    } catch (error) {
      this.setData({
        voiceStatus: '语音启动失败',
        voiceHint: '请稍后再试，或改用按钮进入训练页',
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
      // ignore abort errors from an inactive session
    }
  },
  handleVoiceCommand(transcript) {
    const text = this.normalizeVoiceText(transcript);

    if (!text) {
      this.setData({
        voiceStatus: '没有识别到清晰指令',
        voiceHint: '请再说一次卡片名字，例如“光年”'
      });
      return;
    }

    const matchedCard = this.allCards.find((item) => {
      const normalizedTitle = this.normalizeVoiceText(item.title);
      return normalizedTitle && (text.indexOf(normalizedTitle) !== -1 || normalizedTitle.indexOf(text) !== -1);
    });

    if (matchedCard) {
      this.openCardByVoice(matchedCard, `语音打开${matchedCard.title}`);
      return;
    }

    const matchedCategory = this.data.categoryOptions.find((item) => text.indexOf(item) !== -1);

    if (matchedCategory) {
      this.applyCategory(matchedCategory, false);
      if (this.allCards.some((item) => item.topics && item.topics.indexOf(matchedCategory) !== -1)) {
        this.enterStudyMode(`语音进入${matchedCategory}`);
      }
      return;
    }

    if (
      text.indexOf('开始学习') !== -1 ||
      text.indexOf('进入学习') !== -1 ||
      text.indexOf('开始训练') !== -1 ||
      text.indexOf('进入知识卡片') !== -1 ||
      text.indexOf('进入二级页面') !== -1
    ) {
      this.enterStudyMode('语音进入训练页');
      return;
    }

    this.setData({
      voiceStatus: '没有匹配到可执行指令',
      voiceHint: '可以直接说卡片名字，例如“光年”“板块运动”',
      lastTranscript: text
    });
  },
  openCardByVoice(card, trigger) {
    const targetCategory = card.category || (card.topics && card.topics[0]) || this.data.selectedCategory;
    const filteredCards = this.allCards.filter((item) => item.topics && item.topics.indexOf(targetCategory) !== -1);
    const targetIndex = filteredCards.findIndex((item) => item.id === card.id);
    const triggerText = trigger || `语音打开${card.title}`;

    if (!filteredCards.length || targetIndex < 0) {
      this.setData({
        voiceStatus: '没有找到对应的卡片入口',
        voiceHint: '请再说一次完整卡片名字',
        lastTranscript: triggerText
      });
      return;
    }

    this.clearRecallTimer();
    this.stopVoiceRecognition();
    this.setData({
      viewMode: 'study',
      selectedCategory: targetCategory,
      cards: filteredCards,
      phase: 'learn',
      currentIndex: targetIndex,
      countdown: 5,
      firstRoundComplete: false,
      shatterActive: false,
      resultFace: '',
      resultText: '',
      resultType: '',
      lastAction: triggerText,
      voiceStatus: `已打开${card.title}`,
      voiceHint: '你可以回到首页重新选择分类，或继续语音打开其他卡片',
      lastTranscript: triggerText
    });
    this.startRotation();
  },
  enterStudyMode(trigger) {
    const triggerText = typeof trigger === 'string' ? trigger : '已进入训练页';

    if (!this.data.cards.length) {
      this.setData({
        voiceStatus: '当前分类暂时没有内容',
        voiceHint: '请先换一个有内容的分类再进入训练页',
        lastTranscript: triggerText
      });
      return;
    }

    this.clearRecallTimer();
    this.stopVoiceRecognition();
    this.setData({
      viewMode: 'study',
      phase: 'learn',
      currentIndex: 0,
      countdown: 5,
      firstRoundComplete: false,
      shatterActive: false,
      resultFace: '',
      resultText: '',
      resultType: '',
      lastAction: triggerText,
      voiceStatus: '已进入训练页',
      voiceHint: '你可以回到首页重新选择分类',
      lastTranscript: triggerText
    });
    this.startRotation();
  },
  goHome() {
    this.stopRotation();
    this.clearRecallTimer();
    this.stopVoiceRecognition();
    this.setData({
      viewMode: 'home',
      phase: 'learn',
      countdown: 0,
      currentIndex: 0,
      firstRoundComplete: false,
      shatterActive: false,
      resultFace: '',
      resultText: '',
      resultType: '',
      lastAction: '已返回首页',
      voiceStatus: '已回到首页',
      voiceHint: '可以重新选分类，再通过语音或按钮进入训练页',
      lastTranscript: '等待新的语音指令'
    });
  },
  initImu() {
    const hasGyroscope = typeof Gyroscope === 'function';
    const hasOrientation = typeof AbsoluteOrientationSensor === 'function';

    if (!hasGyroscope && !hasOrientation) {
      this.setData({
        imuStatus: '当前环境不支持 IMU 传感器',
        imuHint: '请使用按钮或等待自动轮播',
        imuMode: '已降级',
        lastAction: '已切换到手动/自动模式',
        nodEnabled: false
      });
      return;
    }

    this.nodState = 'idle';
    this.nodStartAt = 0;
    this.nodCooldownUntil = 0;
    this.nodDirection = 0;
    this.latestPitch = null;
    this.latestYaw = null;
    this.latestPitchSpeed = 0;
    this.latestYawSpeed = 0;
    this.calibrationPitchSamples = [];
    this.calibrationYawSamples = [];
    this.baselinePitch = null;
    this.baselineYaw = null;
    this.gesturePitchRef = null;
    this.gestureYawRef = null;
    this.shakeState = 'idle';
    this.shakeStartAt = 0;
    this.shakeDirection = 0;
    this.lastUiUpdateAt = 0;

    try {
      this.setData({
        imuStatus: hasOrientation ? '正在校准头部自然姿态...' : '正在启动陀螺仪监听...',
        imuHint: hasOrientation ? '请自然平视前方 1 秒，准备进入学习与挑战模式' : '暂时使用陀螺仪增强识别',
        imuMode: hasOrientation && hasGyroscope ? '双传感器模式' : hasOrientation ? '姿态模式' : '陀螺仪模式',
        calibrationText: hasOrientation ? '校准中 0/12' : '未启用姿态校准'
      });

      if (hasGyroscope) {
        this.gyroscope = new Gyroscope({ frequency: 60 });
        this.onGyroActivate = () => {
          this.setData({
            lastAction: '陀螺仪已开始监听'
          });
        };

        this.onGyroReading = () => {
          const x = this.gyroscope.x ?? 0;
          const y = this.gyroscope.y ?? 0;
          const z = this.gyroscope.z ?? 0;
          const now = Date.now();
          const pitchSpeed = Math.abs(y) >= Math.abs(x) ? y : x;
          const yawSpeed = Math.abs(z) >= Math.abs(x) ? z : x;

          this.latestPitchSpeed = pitchSpeed;
          this.latestYawSpeed = yawSpeed;
          this.updateImuSnapshot({
            imuValue: `${x.toFixed(2)} / ${y.toFixed(2)} / ${z.toFixed(2)}`
          }, now);

          if (!this.orientationSensor && this.baselinePitch === null) {
            this.evaluateGyroOnly(now, pitchSpeed);
          }
        };

        this.onGyroError = (event) => {
          const errorMessage = event && event.error ? String(event.error) : '陀螺仪启动失败';
          this.setData({
            imuStatus: '点头识别部分不可用',
            imuHint: '继续尝试使用其他可用传感器',
            lastAction: errorMessage
          });
        };

        this.gyroscope.addEventListener('activate', this.onGyroActivate);
        this.gyroscope.addEventListener('reading', this.onGyroReading);
        this.gyroscope.addEventListener('error', this.onGyroError);
        this.gyroscope.start();
      }

      if (hasOrientation) {
        this.orientationSensor = new AbsoluteOrientationSensor({ frequency: 30 });

        this.onOrientationActivate = () => {
          this.setData({
            lastAction: '方向传感器已开始监听'
          });
        };

        this.onOrientationReading = () => {
          const quaternion = this.orientationSensor.quaternion;
          const now = Date.now();

          if (!quaternion) {
            return;
          }

          const pitch = this.getPitchFromQuaternion(quaternion);
          const yaw = this.getYawFromQuaternion(quaternion);
          this.latestPitch = pitch;
          this.latestYaw = yaw;
          this.updateImuSnapshot({
            pitchValue: `${pitch.toFixed(1)}°`,
            yawValue: `${yaw.toFixed(1)}°`
          }, now);

          if (this.baselinePitch === null || this.baselineYaw === null) {
            this.collectCalibrationSample(pitch, yaw);
            return;
          }

          this.evaluateNod(now, pitch, this.latestPitchSpeed);
          this.evaluateShake(now, yaw, this.latestYawSpeed);
        };

        this.onOrientationError = (event) => {
          const errorMessage = event && event.error ? String(event.error) : '方向传感器启动失败';
          if (this.orientationSensor) {
            this.orientationSensor.stop();
            this.orientationSensor = null;
          }
          this.setData({
            imuStatus: '姿态校准不可用',
            imuHint: hasGyroscope ? '已切换为陀螺仪识别模式' : '请使用按钮或等待自动轮播',
            imuMode: hasGyroscope ? '陀螺仪模式' : '已降级',
            calibrationText: '姿态校准失败',
            lastAction: errorMessage,
            nodEnabled: hasGyroscope
          });
        };

        this.orientationSensor.addEventListener('activate', this.onOrientationActivate);
        this.orientationSensor.addEventListener('reading', this.onOrientationReading);
        this.orientationSensor.addEventListener('error', this.onOrientationError);
        this.orientationSensor.start();
      }

      if (!hasOrientation && hasGyroscope) {
        this.setData({
          imuStatus: '已启用陀螺仪监听',
          imuHint: '请自然点头一次测试灵敏度',
          imuMode: '陀螺仪模式',
          calibrationText: '未启用姿态校准',
          nodEnabled: true
        });
      }
    } catch (error) {
      this.setData({
        imuStatus: '点头识别初始化失败',
        imuHint: '请使用按钮或等待自动轮播',
        imuMode: '已降级',
        lastAction: error && error.message ? error.message : '未知错误',
        nodEnabled: false
      });
    }
  },
  getPitchFromQuaternion(quaternion) {
    const [x, y, z, w] = quaternion;
    const sinp = 2 * (w * y - z * x);
    const safeSinp = Math.max(-1, Math.min(1, sinp));
    return Math.asin(safeSinp) * (180 / Math.PI);
  },
  getYawFromQuaternion(quaternion) {
    const [x, y, z, w] = quaternion;
    const sinyCosp = 2 * (w * z + x * y);
    const cosyCosp = 1 - 2 * (y * y + z * z);
    return Math.atan2(sinyCosp, cosyCosp) * (180 / Math.PI);
  },
  collectCalibrationSample(pitch, yaw) {
    this.calibrationPitchSamples.push(pitch);
    this.calibrationYawSamples.push(yaw);

    if (this.calibrationPitchSamples.length < 12) {
      this.setData({
        imuStatus: '正在校准头部自然姿态...',
        imuHint: '请保持头部平稳，校准马上完成',
        calibrationText: `校准中 ${this.calibrationPitchSamples.length}/12`
      });
      return;
    }

    const pitchTotal = this.calibrationPitchSamples.reduce((sum, value) => sum + value, 0);
    const yawTotal = this.calibrationYawSamples.reduce((sum, value) => sum + value, 0);
    this.baselinePitch = pitchTotal / this.calibrationPitchSamples.length;
    this.baselineYaw = yawTotal / this.calibrationYawSamples.length;
    this.setData({
      imuStatus: '点头识别已校准',
      imuHint: '学习模式下可点头切卡，回忆模式下点头或摇头回答',
      calibrationText: `基线俯仰角 ${this.baselinePitch.toFixed(1)}°`,
      lastAction: '姿态基线校准完成',
      nodEnabled: true
    });
  },
  updateImuSnapshot(partialState, now) {
    if (!now) {
      this.setData(partialState);
      return;
    }

    if (now - this.lastUiUpdateAt < 120) {
      return;
    }

    this.lastUiUpdateAt = now;
    this.setData(partialState);
  },
  evaluateGyroOnly(now, pitchSpeed) {
    if (now < this.nodCooldownUntil) {
      return;
    }

    if (this.data.viewMode !== 'study') {
      return;
    }

    if (this.data.phase !== 'learn' && this.data.phase !== 'recall') {
      return;
    }

    if (this.nodState === 'idle') {
      if (Math.abs(pitchSpeed) > 0.95) {
        this.nodState = 'down_detected';
        this.nodStartAt = now;
        this.nodDirection = Math.sign(pitchSpeed) || 1;
        this.setData({
          imuStatus: '检测到头部运动',
          imuHint: '继续完成回抬动作以确认点头'
        });
      }
      return;
    }

    if (now - this.nodStartAt > 900) {
      this.resetNodState('动作超时，继续监听下一次点头');
      return;
    }

    if (pitchSpeed * this.nodDirection < -0.85) {
      this.nodCooldownUntil = now + 1200;
      this.nodState = 'idle';
      if (this.data.phase === 'recall') {
        this.handleRecallYes('陀螺仪识别到点头，回答“是”');
      } else {
        this.handleNodTrigger('陀螺仪识别成功');
      }
    }
  },
  evaluateNod(now, pitch, pitchSpeed) {
    if (now < this.nodCooldownUntil || this.baselinePitch === null) {
      return;
    }

    if (this.data.viewMode !== 'study') {
      return;
    }

    if (this.data.phase !== 'learn' && this.data.phase !== 'recall') {
      return;
    }

    const referencePitch = this.data.phase === 'recall' && this.gesturePitchRef !== null
      ? this.gesturePitchRef
      : this.baselinePitch;
    const delta = pitch - referencePitch;
    const absDelta = Math.abs(delta);
    const absSpeed = Math.abs(pitchSpeed);

    if (this.nodState === 'idle') {
      if (absDelta > 8 && absSpeed > 0.45) {
        this.nodState = 'down_detected';
        this.nodStartAt = now;
        this.nodDirection = Math.sign(pitchSpeed) || Math.sign(delta) || 1;
        this.setData({
          imuStatus: '检测到低头趋势',
          imuHint: '请抬头回到自然姿态完成点头'
        });
      }
      return;
    }

    if (now - this.nodStartAt > 1200) {
      this.resetNodState('本次点头动作超时，已重新待命');
      return;
    }

    const returnedNearBaseline = absDelta < 4.5;
    const reversedDirection = pitchSpeed * this.nodDirection < -0.28;

    if (returnedNearBaseline && reversedDirection) {
      this.nodCooldownUntil = now + 1400;
      this.nodState = 'idle';
      if (this.data.phase === 'recall') {
        this.handleRecallYes(`点头回答“是”，姿态变化 ${Math.abs(delta).toFixed(1)}°`);
      } else {
        this.handleNodTrigger(`点头成功，姿态变化 ${Math.abs(delta).toFixed(1)}°`);
      }
    }
  },
  evaluateShake(now, yaw, yawSpeed) {
    if (this.data.viewMode !== 'study') {
      return;
    }

    if (this.data.phase !== 'recall' || this.gestureYawRef === null) {
      return;
    }

    if (now < this.nodCooldownUntil) {
      return;
    }

    const delta = yaw - this.gestureYawRef;
    const absDelta = Math.abs(delta);
    const absSpeed = Math.abs(yawSpeed);

    if (this.shakeState === 'idle') {
      if (absDelta > 7 && absSpeed > 0.35) {
        this.shakeState = 'turn_detected';
        this.shakeStartAt = now;
        this.shakeDirection = Math.sign(yawSpeed) || Math.sign(delta) || 1;
        this.setData({
          imuStatus: '检测到摇头趋势',
          imuHint: '返回中间位置即可判定为“否”'
        });
      }
      return;
    }

    if (now - this.shakeStartAt > 1200) {
      this.resetShakeState('本次摇头动作超时，继续等待回答');
      return;
    }

    const returnedNearCenter = absDelta < 4.5;
    const reversedDirection = yawSpeed * this.shakeDirection < -0.22;

    if (returnedNearCenter && reversedDirection) {
      this.nodCooldownUntil = now + 1400;
      this.shakeState = 'idle';
      this.handleRecallNo(`摇头回答“否”，偏航变化 ${Math.abs(delta).toFixed(1)}°`);
    }
  },
  resetNodState(message) {
    this.nodState = 'idle';
    this.nodDirection = 0;
    this.setData({
      imuStatus: '点头识别待命中',
      imuHint: '学习模式点头切卡，挑战模式点头或摇头回答',
      lastAction: message
    });
  },
  resetShakeState(message) {
    this.shakeState = 'idle';
    this.shakeDirection = 0;
    this.setData({
      imuStatus: '回忆回答待命中',
      imuHint: '挑战模式只看图片回忆，点头选“是”，摇头选“否”',
      lastAction: message
    });
  },
  clearRecallTimer() {
    if (this.recallTimer) {
      clearTimeout(this.recallTimer);
      this.recallTimer = null;
    }
  },
  applyCategory(category, silent) {
    const filteredCards = this.allCards.filter((item) => item.topics && item.topics.indexOf(category) !== -1);
    const hasCards = filteredCards.length > 0;

    this.clearRecallTimer();
    if (this.data.viewMode === 'study') {
      this.stopRotation();
    }
    this.setData({
      selectedCategory: category,
      cards: filteredCards,
      phase: 'learn',
      currentIndex: 0,
      countdown: hasCards ? 5 : 0,
      firstRoundComplete: false,
      shatterActive: false,
      resultFace: '',
      resultText: '',
      resultType: '',
      lastAction: silent ? '已初始化首页分类' : `已切换到${category}`,
      imuStatus: hasCards ? '已切换知识分类' : '当前分类内容准备中',
      imuHint: hasCards ? '学习模式点头切卡，挑战模式点头或摇头回答' : '该分类暂时没有卡片，可以先切换到其他分类',
    });

    if (!hasCards || this.data.viewMode !== 'study') {
      return;
    }

    this.startRotation();
  },
  handleCategoryTap(event) {
    const category = event && event.currentTarget && event.currentTarget.dataset
      ? event.currentTarget.dataset.category
      : '';

    if (!category || category === this.data.selectedCategory) {
      return;
    }

    this.applyCategory(category, false);
  },
  enterRecallPhase(index) {
    if (!this.data.cards.length) {
      return;
    }
    this.stopRotation();
    this.clearRecallTimer();
    this.nodState = 'idle';
    this.shakeState = 'idle';
    this.gesturePitchRef = this.latestPitch !== null ? this.latestPitch : this.baselinePitch;
    this.gestureYawRef = this.latestYaw !== null ? this.latestYaw : this.baselineYaw;
    this.setData({
      phase: 'recall',
      currentIndex: index,
      shatterActive: false,
      countdown: 0,
      resultFace: '',
      resultText: '',
      resultType: '',
      imuStatus: '挑战模式已开启',
      imuHint: '只根据图片回忆知识，点头选“是”，摇头选“否”',
      lastAction: '请根据图片做出回答'
    });
  },
  showReviewCard(reason) {
    this.clearRecallTimer();
    this.nodState = 'idle';
    this.shakeState = 'idle';
    this.setData({
      phase: 'review',
      countdown: 5,
      shatterActive: false,
      resultFace: '▔\\▁((.′◔_′◔.))▁/▔',
      resultText: '再接再励',
      resultType: 'wrong',
      imuStatus: '已返回学习模式',
      imuHint: '重新学习这张知识卡，5 秒后再次进入挑战',
      lastAction: reason || '用户选择了“否”'
    });
    this.startRotation();
  },
  advanceRecallCard() {
    if (!this.data.cards.length) {
      return;
    }
    const nextIndex = this.data.currentIndex + 1;

    if (nextIndex >= this.data.cards.length) {
      this.restartLearningCycle();
      return;
    }

    this.enterRecallPhase(nextIndex);
  },
  restartLearningCycle() {
    this.clearRecallTimer();
    this.setData({
      phase: 'learn',
      currentIndex: 0,
      countdown: this.data.cards.length ? 5 : 0,
      firstRoundComplete: false,
      shatterActive: false,
      resultFace: '',
      resultText: '',
      resultType: '',
      imuStatus: '已完成一轮挑战',
      imuHint: '开始新一轮学习模式浏览',
      lastAction: '所有卡片已完成图片回忆'
    });
    this.startRotation();
  },
  stopImu() {
    if (this.gyroscope) {
      if (this.onGyroActivate) {
        this.gyroscope.removeEventListener('activate', this.onGyroActivate);
      }
      if (this.onGyroReading) {
        this.gyroscope.removeEventListener('reading', this.onGyroReading);
      }
      if (this.onGyroError) {
        this.gyroscope.removeEventListener('error', this.onGyroError);
      }
      this.gyroscope.stop();
      this.gyroscope = null;
    }

    if (this.orientationSensor) {
      if (this.onOrientationActivate) {
        this.orientationSensor.removeEventListener('activate', this.onOrientationActivate);
      }
      if (this.onOrientationReading) {
        this.orientationSensor.removeEventListener('reading', this.onOrientationReading);
      }
      if (this.onOrientationError) {
        this.orientationSensor.removeEventListener('error', this.onOrientationError);
      }
      this.orientationSensor.stop();
      this.orientationSensor = null;
    }
  },
  startRotation() {
    if (!this.data.cards.length) {
      return;
    }
    this.stopRotation();
    this.timer = setInterval(() => {
      if (this.data.phase !== 'learn' && this.data.phase !== 'review') {
        return;
      }

      const nextCountdown = this.data.countdown - 1;

      if (nextCountdown <= 0) {
        if (this.data.phase === 'review') {
          this.enterRecallPhase(this.data.currentIndex);
        } else {
          this.showNextCard();
        }
        return;
      }

      this.setData({
        countdown: nextCountdown
      });
    }, 1000);
  },
  stopRotation() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  },
  showNextCard() {
    if (!this.data.cards.length) {
      return;
    }
    const nextIndex = (this.data.currentIndex + 1) % this.data.cards.length;

    if (this.data.phase === 'learn' && nextIndex === 0 && !this.data.firstRoundComplete) {
      this.setData({
        firstRoundComplete: true,
        lastAction: '第一轮浏览完成，进入图片回忆模式'
      });
      this.enterRecallPhase(0);
      return;
    }

    this.setData({
      currentIndex: nextIndex,
      countdown: 5
    });
  },
  showPrevCard() {
    if (!this.data.cards.length) {
      return;
    }
    const prevIndex = (this.data.currentIndex - 1 + this.data.cards.length) % this.data.cards.length;

    this.setData({
      currentIndex: prevIndex,
      countdown: 5
    });
  },
  handleNextTap() {
    this.setData({
      lastAction: '手动切换到下一张'
    });
    this.showNextCard();
  },
  handlePrevTap() {
    this.setData({
      lastAction: '手动切换到上一张'
    });
    this.showPrevCard();
  },
  handleNodTrigger(detailMessage) {
    this.setData({
      imuStatus: '识别到点头动作',
      imuHint: '已切换到下一张学习卡',
      lastAction: detailMessage || '点头成功，已切换卡片'
    });
    this.showNextCard();
  },
  handleRecallYes(detailMessage) {
    if (this.data.phase !== 'recall') {
      return;
    }

    this.clearRecallTimer();
    this.setData({
      phase: 'shatter',
      shatterActive: true,
      resultFace: '⋆(ㆆᴗㆆ)*✲ﾟ*｡⋆',
      resultText: '太棒了，已经记住了',
      resultType: 'correct',
      imuStatus: '很好，这张知识已经记住了',
      imuHint: '挑战成功，图片击碎后进入下一张',
      lastAction: detailMessage || '回答“是”'
    });

    this.recallTimer = setTimeout(() => {
      this.advanceRecallCard();
    }, 900);
  },
  handleRecallNo(detailMessage) {
    if (this.data.phase !== 'recall') {
      return;
    }

    this.showReviewCard(detailMessage || '回答“否”');
  }
}
</script>

<page>
  <view class="page">
    <view class="background-glow glow-left"></view>
    <view class="background-glow glow-right"></view>

    <view class="hero">
      <text class="hero-eyebrow">AI Memory Cards</text>
      <text class="hero-subtitle" ink:if="{{ phase === 'learn' }}">学习模式：文字加图片一起看，先建立知识和记忆联想</text>
      <text class="hero-subtitle" ink:elif="{{ phase === 'review' }}">学习模式：这张还没记住，重新看一遍文字和配图</text>
      <text class="hero-subtitle" ink:elif="{{ phase === 'recall' }}">挑战模式：只看图片回顾知识，点头表示记住，摇头表示没记住</text>
      <text class="hero-subtitle" ink:else>挑战模式：这张已经记住，图片正在击碎进入下一题</text>

      <view class="hero-meta">
        <text class="meta-pill" ink:if="{{ cards.length }}">{{ cards[currentIndex].category }}</text>
        <text class="meta-pill" ink:else>知识卡片</text>
        <text class="meta-pill" ink:if="{{ phase === 'learn' }}">学习模式</text>
        <text class="meta-pill" ink:elif="{{ phase === 'review' }}">学习模式</text>
        <text class="meta-pill" ink:elif="{{ phase === 'recall' }}">挑战模式</text>
        <text class="meta-pill" ink:else>挑战模式</text>
        <text class="meta-pill">第 {{ currentIndex + 1 }} / {{ cards.length }} 张</text>
        <text class="meta-pill" ink:if="{{ phase === 'learn' || phase === 'review' }}">{{ countdown }}s 后切换</text>
        <text class="meta-pill" ink:elif="{{ phase === 'recall' }}">¯\_( ◉ 666 ◉ )_/¯</text>
        <text class="meta-pill" ink:else>正在进入下一题</text>
      </view>

    </view>

    <text class="review-banner" ink:if="{{ phase === 'review' }}">没记住就回到学习模式，再看一次文字和图片</text>

    <view class="result-banner {{ resultType }}" ink:if="{{ resultFace }}">
      <text class="result-face">{{ resultFace }}</text>
      <text class="result-text">{{ resultText }}</text>
    </view>

    <view class="empty-state" ink:if="{{ !cards.length }}">
      <text class="empty-title">知识卡片</text>
      <text class="empty-copy">当前还没有可播放的知识卡片内容。</text>
    </view>

    <view class="card" ink:if="{{ cards.length && (phase === 'learn' || phase === 'review') }}">
      <view class="cover">
        <view class="cover-copy">
          <text class="cover-scene">{{ cards[currentIndex].scene }}</text>
          <view class="cover-symbols">
            <text class="cover-symbol" ink:for="{{ cards[currentIndex].symbols }}" ink:key="index">{{ item }}</text>
          </view>
        </view>
        <view class="cover-visual">
          <image class="card-image" src="{{ cards[currentIndex].image }}" mode="aspectFill"></image>
        </view>
      </view>

      <text class="badge">{{ cards[currentIndex].category }}</text>
      <text class="title">{{ cards[currentIndex].title }}</text>
      <text class="content">{{ cards[currentIndex].content }}</text>

      <view class="memory-card">
        <view class="memory-image">
          <image class="memory-photo" src="{{ cards[currentIndex].image }}" mode="aspectFill"></image>
        </view>
        <view class="memory-copy">
          <text class="memory-label">记忆配图</text>
          <text class="memory-hint">{{ cards[currentIndex].memoryHint }}</text>
        </view>
      </view>

      <view class="footer">
        <text class="progress" ink:if="{{ phase === 'review' }}">重新学习</text>
        <text class="progress" ink:else>学习模式</text>
        <text class="countdown">{{ countdown }}s 后自动切换到下一张</text>
      </view>
    </view>

    <view class="recall-card" ink:if="{{ cards.length && (phase === 'recall' || phase === 'shatter') }}">
      <view class="recall-image-box">
        <view class="recall-photo {{ shatterActive ? 'is-shattering' : '' }}">
          <view class="recall-memory-badge">{{ cards[currentIndex].memoryKey }}</view>
          <text class="recall-memory-title">{{ cards[currentIndex].title }}</text>
          <text class="recall-memory-scene">{{ cards[currentIndex].scene }}</text>
          <view class="recall-symbols">
            <text class="recall-symbol" ink:for="{{ cards[currentIndex].symbols }}" ink:key="index">{{ item }}</text>
          </view>
          <view class="recall-memory-mark recall-mark-left"></view>
          <view class="recall-memory-mark recall-mark-right"></view>
        </view>

        <view class="shatter-layer" ink:if="{{ shatterActive }}">
          <view class="shard {{ item.className }}" ink:for="{{ shards }}" ink:key="id"></view>
        </view>
      </view>

      <view class="recall-copy">
        <text class="recall-question">只看这张图片，你能回忆出对应知识吗？</text>
        <text class="recall-subtitle">学习模式会展示文字和图片，挑战模式只保留图片线索</text>
        <text class="recall-tip">点头表示记住了，摇头表示还没记住</text>
      </view>
    </view>

    <view class="imu-panel">
      <view class="imu-head">
        <text class="imu-title">动作识别状态</text>
        <text class="imu-badge" ink:if="{{ nodEnabled }}">已启用</text>
        <text class="imu-badge muted" ink:else>降级中</text>
      </view>
      <text class="imu-status">{{ imuStatus }}</text>
      <text class="imu-hint">{{ imuHint }}</text>
      <view class="imu-grid">
        <text class="imu-chip">模式 {{ imuMode }}</text>
        <text class="imu-chip">俯仰 {{ pitchValue }}</text>
        <text class="imu-chip">偏航 {{ yawValue }}</text>
        <text class="imu-chip">陀螺仪 {{ imuValue }}</text>
      </view>
      <text class="imu-action">校准状态: {{ calibrationText }}</text>
      <text class="imu-action">最近动作: {{ lastAction }}</text>
      <text class="imu-note" ink:if="{{ nodEnabled }}">建议在真机上自然点头测试一次</text>
      <text class="imu-note" ink:else>当前已自动降级为按钮和定时切换模式</text>
    </view>

    <view class="actions" ink:if="{{ cards.length && (phase === 'learn' || phase === 'review') }}">
      <button class="ghost-button" bindtap="handlePrevTap">上一张</button>
      <button class="primary-button" bindtap="handleNextTap">下一张</button>
    </view>

    <view class="actions" ink:if="{{ cards.length && phase === 'recall' }}">
      <button class="ghost-button" bindtap="handleRecallNo">否</button>
      <button class="primary-button" bindtap="handleRecallYes">是</button>
    </view>
  </view>
</page>

<style>
.page {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  gap: 18px;
  min-height: 100vh;
  padding: 28px 20px 32px;
  box-sizing: border-box;
  background-color: var(--color-background);
  overflow: hidden;
}

.background-glow {
  position: absolute;
  width: 240px;
  height: 240px;
  border-radius: 999px;
  background-color: var(--color-primary-40);
  filter: blur(48px);
  opacity: 0.18;
  pointer-events: none;
}

.glow-left {
  left: -80px;
  top: 30px;
}

.glow-right {
  right: -96px;
  top: 220px;
}

.hero {
  width: 100%;
  max-width: 440px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.hero-topline {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.hero-eyebrow {
  color: var(--color-primary);
  font-size: 13px;
  line-height: 18px;
  letter-spacing: 1px;
}

.hero-title {
  color: var(--color-text-primary);
  font-size: 34px;
  line-height: 40px;
  font-weight: bold;
}

.hero-subtitle {
  color: var(--color-text-secondary);
  font-size: 15px;
  line-height: 22px;
}

.hero-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.meta-pill {
  color: var(--color-text-primary);
  background-color: rgba(64, 255, 94, 0.1);
  border: var(--border-width-thin) solid var(--border-color-accent);
  border-radius: 999px;
  padding: 6px 10px;
  box-sizing: border-box;
  font-size: 13px;
  line-height: 18px;
}

.progress-dots {
  display: flex;
  gap: 8px;
  align-items: center;
}

.progress-dot {
  width: 16px;
  height: 6px;
  border-radius: 999px;
  background-color: rgba(64, 255, 94, 0.16);
  border: var(--border-width-thin) solid rgba(64, 255, 94, 0.26);
}

.progress-dot.is-active {
  width: 36px;
  background-color: var(--color-primary);
  border-color: var(--border-color-accent);
}

.card {
  width: 100%;
  max-width: 440px;
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 18px;
  box-sizing: border-box;
  border: var(--card-border-width) solid var(--card-border-color);
  border-radius: var(--radius-md);
  background-color: var(--color-surface);
  box-shadow: 0 16px 40px rgba(0, 0, 0, 0.28), 0 0 24px rgba(64, 255, 94, 0.1);
}

.review-banner {
  width: 100%;
  max-width: 440px;
  color: var(--color-text-primary);
  font-size: 14px;
  line-height: 20px;
  text-align: center;
  background-color: rgba(64, 255, 94, 0.08);
  border: var(--border-width-thin) solid var(--border-color-muted);
  border-radius: 999px;
  padding: 8px 12px;
  box-sizing: border-box;
}

.category-panel {
  width: 100%;
  max-width: 440px;
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 16px;
  box-sizing: border-box;
  border: var(--border-width-thin) solid var(--border-color-muted);
  border-radius: var(--radius-md);
  background-color: rgba(255, 255, 255, 0.02);
}

.section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.section-title {
  color: var(--color-text-primary);
  font-size: 18px;
  line-height: 24px;
}

.section-meta {
  color: var(--color-text-secondary);
  font-size: 13px;
  line-height: 18px;
}

.category-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 10px;
}

.category-item {
  min-height: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 8px 10px;
  box-sizing: border-box;
  text-align: center;
  position: relative;
  border-radius: var(--radius-md);
  border: var(--border-width-thin) solid var(--border-color-muted);
  background-color: rgba(255, 255, 255, 0.03);
  transition: box-shadow 0.22s ease, border-color 0.22s ease, background-color 0.22s ease, opacity 0.22s ease;
}

.category-item.is-selected {
  border-color: var(--border-color-accent);
  background-color: rgba(64, 255, 94, 0.12);
  box-shadow: 0 0 16px rgba(64, 255, 94, 0.12);
  animation: category-selected-glow 1.8s ease-in-out infinite;
}

.category-name {
  color: var(--color-text-primary);
  font-size: 14px;
  line-height: 20px;
}

.voice-panel {
  width: 100%;
  max-width: 440px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 16px;
  box-sizing: border-box;
  border: var(--border-width-thin) solid var(--border-color-muted);
  border-radius: var(--radius-md);
  background: linear-gradient(135deg, rgba(64, 255, 94, 0.08), rgba(255, 255, 255, 0.02));
}

.voice-status {
  color: var(--color-text-primary);
  font-size: 17px;
  line-height: 24px;
}

.voice-hint,
.voice-transcript {
  color: var(--color-text-secondary);
  font-size: 14px;
  line-height: 20px;
}

.entry-button {
  transition: transform 0.22s ease, box-shadow 0.22s ease, opacity 0.22s ease;
}

.entry-button.is-ready {
  box-shadow: 0 0 18px rgba(64, 255, 94, 0.24);
  animation: entry-ready-pulse 1.6s ease-in-out infinite;
}

.entry-button.is-disabled {
  opacity: 0.68;
}

.result-banner {
  width: 100%;
  max-width: 440px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 14px 16px;
  box-sizing: border-box;
  border-radius: var(--radius-md);
  border: var(--border-width-thin) solid var(--border-color-muted);
  background-color: rgba(255, 255, 255, 0.03);
}

.result-banner.correct {
  border-color: var(--border-color-success);
  background-color: rgba(64, 255, 94, 0.08);
}

.result-banner.wrong {
  border-color: var(--border-color-warning);
  background-color: rgba(255, 214, 102, 0.08);
}

.result-face {
  color: var(--color-text-primary);
  font-size: 20px;
  line-height: 26px;
  text-align: center;
}

.result-text {
  color: var(--color-text-primary);
  font-size: 15px;
  line-height: 20px;
  text-align: center;
}

.empty-state {
  width: 100%;
  max-width: 440px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 22px 20px;
  box-sizing: border-box;
  border-radius: var(--radius-md);
  border: var(--border-width-thin) dashed var(--border-color-muted);
  background-color: rgba(255, 255, 255, 0.02);
}

.empty-title {
  color: var(--color-text-primary);
  font-size: 24px;
  line-height: 30px;
}

.empty-copy {
  color: var(--color-text-secondary);
  font-size: 15px;
  line-height: 22px;
  text-align: center;
}

.cover {
  width: 100%;
  min-height: 180px;
  border-radius: var(--radius-md);
  background: linear-gradient(135deg, rgba(64, 255, 94, 0.08), rgba(64, 255, 94, 0.02));
  border: var(--border-width-thin) solid var(--border-color-muted);
  padding: 18px;
  box-sizing: border-box;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
}

.cover-copy {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.cover-title {
  color: var(--color-primary);
  font-size: 14px;
  line-height: 18px;
}

.cover-scene {
  color: var(--color-text-primary);
  font-size: 17px;
  line-height: 24px;
}

.cover-symbols {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.cover-symbol {
  color: var(--color-text-primary);
  background-color: var(--color-surface-highlight);
  border: var(--border-width-thin) solid var(--border-color-accent);
  border-radius: var(--radius-sm);
  padding: 4px 8px;
  box-sizing: border-box;
  font-size: 13px;
  line-height: 18px;
}

.cover-visual {
  width: 132px;
  height: 132px;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  overflow: hidden;
  border-radius: 20px;
  border: var(--border-width-default) solid var(--border-color-accent);
  background-color: rgba(255, 255, 255, 0.03);
  box-shadow: 0 0 18px rgba(64, 255, 94, 0.16);
}

.card-image {
  width: 100%;
  height: 100%;
}

.badge {
  align-self: flex-start;
  color: var(--color-primary);
  border: var(--border-width-default) solid var(--border-color-accent);
  border-radius: var(--radius-sm);
  padding: 4px 10px;
  box-sizing: border-box;
  font-size: 14px;
  line-height: 20px;
  background-color: var(--color-primary-40);
}

.title {
  color: var(--color-text-primary);
  font-size: 30px;
  line-height: 36px;
  font-weight: bold;
}

.content {
  color: var(--color-text-secondary);
  font-size: 17px;
  line-height: 28px;
}

.memory-card {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px;
  border: var(--border-width-thin) solid var(--border-color-muted);
  border-radius: var(--radius-md);
  background: linear-gradient(135deg, rgba(64, 255, 94, 0.12), rgba(64, 255, 94, 0.04));
}

.memory-image {
  width: 92px;
  height: 72px;
  border-radius: var(--radius-sm);
  flex-shrink: 0;
  overflow: hidden;
  border: var(--border-width-thin) solid var(--border-color-accent);
  background-color: rgba(255, 255, 255, 0.03);
}

.memory-photo {
  width: 100%;
  height: 100%;
}

.memory-copy {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.memory-label {
  color: var(--color-primary);
  font-size: 14px;
  line-height: 18px;
}

.memory-hint {
  color: var(--color-text-secondary);
  font-size: 15px;
  line-height: 22px;
}

.footer {
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding-top: 10px;
  border-top: var(--border-width-thin) solid var(--border-color-muted);
}

.progress,
.countdown {
  color: var(--color-text-primary);
  font-size: 13px;
  line-height: 18px;
  background-color: rgba(64, 255, 94, 0.08);
  border: var(--border-width-thin) solid var(--border-color-muted);
  border-radius: 999px;
  padding: 6px 10px;
  box-sizing: border-box;
}

.actions {
  width: 100%;
  max-width: 440px;
  display: flex;
  gap: 12px;
}

.recall-card {
  width: 100%;
  max-width: 440px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 18px;
  box-sizing: border-box;
  border: var(--card-border-width) solid var(--card-border-color);
  border-radius: var(--radius-md);
  background-color: var(--color-surface);
  box-shadow: 0 16px 40px rgba(0, 0, 0, 0.28), 0 0 24px rgba(64, 255, 94, 0.1);
}

.recall-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.recall-kicker {
  color: var(--color-primary);
  font-size: 14px;
  line-height: 18px;
}

.recall-state {
  color: var(--color-text-primary);
  font-size: 13px;
  line-height: 18px;
  border-radius: 999px;
  padding: 6px 10px;
  box-sizing: border-box;
  background-color: rgba(64, 255, 94, 0.08);
  border: var(--border-width-thin) solid var(--border-color-muted);
}

.recall-image-box {
  width: 100%;
  height: 220px;
  position: relative;
  overflow: hidden;
  border-radius: var(--radius-md);
  border: var(--border-width-thin) solid var(--border-color-muted);
  background: radial-gradient(circle at 50% 50%, rgba(64, 255, 94, 0.1), rgba(64, 255, 94, 0.02));
}

.recall-photo {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: flex-end;
  gap: 10px;
  padding: 18px;
  box-sizing: border-box;
  position: relative;
  z-index: 1;
  background:
    radial-gradient(circle at 18% 24%, rgba(217, 255, 122, 0.9), rgba(217, 255, 122, 0.15) 18%, rgba(7, 18, 10, 0) 19%),
    linear-gradient(180deg, rgba(9, 30, 14, 0.55), rgba(10, 42, 18, 0.9)),
    linear-gradient(135deg, rgba(64, 255, 94, 0.14), rgba(64, 255, 94, 0.03));
}

.recall-photo.is-shattering {
  opacity: 0.24;
  transition: opacity 0.18s ease;
}

.recall-memory-badge {
  color: #08120A;
  font-size: 13px;
  line-height: 18px;
  font-weight: bold;
  padding: 6px 12px;
  border-radius: 999px;
  background-color: #D9FF7A;
  box-sizing: border-box;
}

.recall-memory-title {
  color: var(--color-text-primary);
  font-size: 28px;
  line-height: 34px;
  font-weight: bold;
}

.recall-memory-scene {
  max-width: 250px;
  color: rgba(255, 255, 255, 0.9);
  font-size: 14px;
  line-height: 20px;
}

.recall-symbols {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.recall-symbol {
  color: var(--color-text-primary);
  font-size: 13px;
  line-height: 18px;
  padding: 5px 10px;
  border-radius: 999px;
  border: var(--border-width-thin) solid rgba(64, 255, 94, 0.4);
  background-color: rgba(0, 0, 0, 0.28);
  box-sizing: border-box;
}

.recall-memory-mark {
  position: absolute;
  border-radius: 999px;
  border: var(--border-width-thin) solid rgba(64, 255, 94, 0.48);
  background-color: rgba(64, 255, 94, 0.12);
}

.recall-mark-left {
  width: 86px;
  height: 86px;
  right: 34px;
  bottom: 28px;
}

.recall-mark-right {
  width: 44px;
  height: 44px;
  right: 92px;
  top: 30px;
}

.recall-question {
  color: var(--color-text-primary);
  font-size: 24px;
  line-height: 32px;
  text-align: center;
}

.recall-copy {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.recall-subtitle {
  color: var(--color-text-secondary);
  font-size: 15px;
  line-height: 22px;
  text-align: center;
}

.recall-tip {
  color: var(--color-primary);
  font-size: 14px;
  line-height: 20px;
  text-align: center;
}

.shatter-layer {
  position: absolute;
  inset: 0;
  z-index: 2;
}

.shard {
  width: 72px;
  height: 72px;
  position: absolute;
  border-radius: var(--radius-sm);
  background-color: var(--color-primary-40);
  border: var(--border-width-thin) solid var(--border-color-accent);
  animation: shard-burst 0.8s ease-out forwards;
}

.shard-1 {
  left: 52px;
  top: 56px;
  animation-delay: 0s;
}

.shard-2 {
  left: 138px;
  top: 42px;
  animation-delay: 0.04s;
}

.shard-3 {
  right: 66px;
  top: 60px;
  animation-delay: 0.08s;
}

.shard-4 {
  left: 74px;
  bottom: 54px;
  animation-delay: 0.12s;
}

.shard-5 {
  left: 178px;
  bottom: 42px;
  animation-delay: 0.16s;
}

.shard-6 {
  right: 48px;
  bottom: 58px;
  animation-delay: 0.2s;
}

@keyframes shard-burst {
  0% {
    opacity: 1;
    transform: scale(1) rotate(0deg);
  }

  100% {
    opacity: 0;
    transform: translateY(-26px) scale(0.5) rotate(22deg);
  }
}

.imu-panel {
  width: 100%;
  max-width: 440px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 14px 16px;
  box-sizing: border-box;
  border: var(--border-width-thin) solid var(--border-color-muted);
  border-radius: var(--radius-md);
  background-color: rgba(255, 255, 255, 0.02);
}

.imu-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.imu-title {
  color: var(--color-primary);
  font-size: 15px;
  line-height: 20px;
}

.imu-badge {
  color: var(--color-text-primary);
  font-size: 12px;
  line-height: 16px;
  border-radius: 999px;
  padding: 4px 8px;
  box-sizing: border-box;
  background-color: rgba(64, 255, 94, 0.1);
  border: var(--border-width-thin) solid var(--border-color-accent);
}

.imu-badge.muted {
  color: var(--color-text-secondary);
  border-color: var(--border-color-muted);
  background-color: rgba(255, 255, 255, 0.04);
}

.imu-status {
  color: var(--color-text-primary);
  font-size: 16px;
  line-height: 22px;
}

.imu-hint,
.imu-action,
.imu-note {
  color: var(--color-text-secondary);
  font-size: 14px;
  line-height: 20px;
}

.imu-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.imu-chip {
  color: var(--color-text-secondary);
  font-size: 13px;
  line-height: 18px;
  border-radius: 999px;
  padding: 6px 10px;
  box-sizing: border-box;
  background-color: rgba(255, 255, 255, 0.03);
  border: var(--border-width-thin) solid var(--border-color-muted);
}

.ghost-button,
.primary-button {
  flex: 1;
  border-radius: var(--radius-md);
  box-sizing: border-box;
  text-align: center;
  line-height: 24px;
  min-height: 54px;
  font-size: 16px;
}

.back-button {
  min-width: 110px;
  min-height: 40px;
  padding: 0 14px;
  box-sizing: border-box;
  border-radius: 999px;
  border: var(--border-width-thin) solid var(--border-color-muted);
  background-color: rgba(255, 255, 255, 0.03);
  color: var(--color-text-primary);
  font-size: 14px;
  line-height: 20px;
}

@keyframes category-selected-glow {
  0% {
    box-shadow: 0 0 8px rgba(64, 255, 94, 0.08);
    border-color: rgba(64, 255, 94, 0.45);
  }

  50% {
    box-shadow: 0 0 20px rgba(64, 255, 94, 0.22);
    border-color: rgba(64, 255, 94, 0.9);
  }

  100% {
    box-shadow: 0 0 8px rgba(64, 255, 94, 0.08);
    border-color: rgba(64, 255, 94, 0.45);
  }
}

@keyframes entry-ready-pulse {
  0% {
    transform: scale(1);
    box-shadow: 0 0 12px rgba(64, 255, 94, 0.14);
  }

  50% {
    transform: scale(1.02);
    box-shadow: 0 0 24px rgba(64, 255, 94, 0.26);
  }

  100% {
    transform: scale(1);
    box-shadow: 0 0 12px rgba(64, 255, 94, 0.14);
  }
}

.ghost-button {
  color: var(--color-text-primary);
  border: var(--border-width-default) solid var(--border-color-default);
  background-color: rgba(255, 255, 255, 0.02);
}

.primary-button {
  color: var(--color-background);
  border: var(--border-width-default) solid var(--border-color-accent);
  background: linear-gradient(135deg, var(--color-primary), #7dff91);
}
</style>
