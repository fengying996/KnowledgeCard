<script def>
{
  "navigationBarTitleText": "妙卡"
}
</script>

<script setup>
import { Sound } from 'audio';
import { LanguageModel } from 'language-model';
import wx from 'wx';
import studyData from '../../assets/data/data.js';

function createEmptySubject() {
  return {
    id: 0,
    title: '',
    pendingCount: 0,
    scene: '',
    content: '',
    memoryKey: '',
    memoryHint: '',
    tagTwo: '',
    tagThree: '',
    illustrationUrl: '',
    cards: []
  };
}

function createEmptyCard() {
  return {
    id: '',
    order: 0,
    title: '',
    scene: '',
    content: '',
    memoryKey: '',
    memoryHint: '',
    tagTwo: '',
    tagThree: '',
    illustrationUrl: '',
    aiInsight: ''
  };
}

function createDefaultStudyData() {
  return {
    studyVoiceHint: '点击开启系统语音',
    studyInsights: {},
    subjects: []
  };
}

function createModeSelectionClassState(mode) {
  var activeMode = mode === 'challenge' ? 'challenge' : 'read';

  return {
    readModeButtonClass: activeMode === 'read'
      ? 'difficulty-btn difficulty-btn-square difficulty-btn-active'
      : 'difficulty-btn difficulty-btn-square',
    readModeTextClass: activeMode === 'read'
      ? 'difficulty-btn-text difficulty-btn-text-active'
      : 'difficulty-btn-text',
    challengeModeButtonClass: activeMode === 'challenge'
      ? 'difficulty-btn difficulty-btn-square difficulty-btn-active'
      : 'difficulty-btn difficulty-btn-square',
    challengeModeTextClass: activeMode === 'challenge'
      ? 'difficulty-btn-text difficulty-btn-text-active'
      : 'difficulty-btn-text'
  };
}

function createSequentialOrder(total) {
  var order = [];
  var i;

  for (i = 0; i < total; i += 1) {
    order.push(i);
  }

  return order;
}

function createShuffledOrder(total) {
  var order = createSequentialOrder(total);
  var i;
  var swapIndex;
  var temp;

  for (i = order.length - 1; i > 0; i -= 1) {
    swapIndex = Math.floor(Math.random() * (i + 1));
    temp = order[i];
    order[i] = order[swapIndex];
    order[swapIndex] = temp;
  }

  return order;
}

function createEmptyChallengeProgress() {
  return {
    keywordProgressMap: {},
    blankProgressMap: {},
    completedKeywordCount: 0,
    totalKeywordCount: 0,
    completedBlankCount: 0,
    totalBlankCount: 0
  };
}

function getCardKeywords(card) {
  var source = card && typeof card === 'object' ? card : {};
  var values = [source.memoryKey, source.tagTwo, source.tagThree];
  var unique = [];

  values.forEach(function(item) {
    var value = item ? String(item).trim() : '';
    if (value && unique.indexOf(value) === -1) {
      unique.push(value);
    }
  });

  return unique;
}

function getChallengeDisplayTextByField(card, fieldKey) {
  var source = card && typeof card === 'object' ? card : {};
  var value = source[fieldKey] ? String(source[fieldKey]) : '';
  var limitMap = {
    title: 20,
    scene: 24,
    content: 30,
    memoryHint: 24
  };
  var maxLength = limitMap[fieldKey] || 0;

  if (!maxLength || !value || value.length <= maxLength) {
    return value;
  }

  return value.slice(0, maxLength - 1) + '…';
}

function getCardBlankEntries(card) {
  var source = card && typeof card === 'object' ? card : {};
  var keywords = getCardKeywords(source);
  var fieldKeys = ['title', 'scene', 'content', 'memoryHint'];
  var blankEntries = [];
  var blankNumber = 0;

  fieldKeys.forEach(function(fieldKey) {
    var text = getChallengeDisplayTextByField(source, fieldKey);
    var matches = [];

    if (!text) {
      return;
    }

    keywords.forEach(function(keyword, keywordIndex) {
      var searchStart = 0;
      var matchIndex = -1;

      if (!keyword) {
        return;
      }

      while ((matchIndex = text.indexOf(keyword, searchStart)) !== -1) {
        matches.push({
          field: fieldKey,
          start: matchIndex,
          end: matchIndex + keyword.length,
          answer: keyword,
          keywordIndex: keywordIndex
        });
        searchStart = matchIndex + keyword.length;
      }
    });

    matches.sort(function(a, b) {
      if (a.start !== b.start) {
        return a.start - b.start;
      }
      return (b.end - b.start) - (a.end - a.start);
    });

    matches.forEach(function(match, matchOrder) {
      var previous = matches[matchOrder - 1];

      if (previous && match.start < previous.end) {
        return;
      }

      blankNumber += 1;
      blankEntries.push({
        id: 'blank-' + blankNumber,
        progressIndex: blankEntries.length,
        blankNumber: blankNumber,
        field: match.field,
        start: match.start,
        end: match.end,
        answer: match.answer,
        keywordIndex: match.keywordIndex
      });
    });
  });

  return blankEntries;
}

function normalizeRecognitionText(text) {
  return (text ? String(text) : '')
    .replace(/\s+/g, '')
    .replace(/[，。！？、；：,.!?;:"'“”‘’（）()【】\[\]\-]/g, '')
    .toLowerCase();
}

function createMaskToken(keyword, draftText) {
  var length = keyword ? String(keyword).length : 0;
  var safeLength = length > 1 ? length + 1 : 3;
  var safeDraft = draftText ? String(draftText) : '';
  var visibleDraft = safeDraft.slice(0, safeLength);
  var lineCount = Math.max(safeLength - visibleDraft.length, 0);

  return visibleDraft + new Array(lineCount + 1).join('_');
}

function createRecognitionDraftText(text) {
  return (text ? String(text) : '')
    .replace(/\s+/g, '')
    .replace(/[，。！？、；：,.!?;:"'“”‘’（）()【】\[\]\-]/g, '');
}

function pickRandomText(list, fallback) {
  var items = Array.isArray(list) ? list.filter(function(item) {
    return Boolean(item);
  }) : [];

  if (!items.length) {
    return fallback || '';
  }

  return items[Math.floor(Math.random() * items.length)];
}

function buildChallengePraise(type, answers, count, score) {
  var answerText = Array.isArray(answers) && answers.length ? answers.join('、') : '';
  var praise = '';

  if (type === 'final') {
    praise = pickRandomText([
      '太稳了，这一轮发挥很棒。',
      '节奏很好，继续保持这个状态。',
      '这轮背诵表现在线，值得表扬。'
    ], '表现不错，继续保持。');
    return (score >= 60
      ? ('恭喜你，得到了' + formatChallengeScore(score) + '分。')
      : ('再接再厉，当前得分' + formatChallengeScore(score) + '分。')) + praise;
  }

  if (type === 'card') {
    praise = pickRandomText([
      '这张卡你已经拿下了。',
      '这一题背得很完整。',
      '这一张的节奏非常稳。'
    ], '本卡已完成。');
    return '正确答案：' + answerText + '。' + praise;
  }

  praise = count > 1
    ? pickRandomText([
      '一下答对多个关键词，状态很棒。',
      '连续命中好几个空，继续冲。',
      '这波回答很准，保持节奏。'
    ], '背得很好，继续保持。')
    : pickRandomText([
      '答得很准，继续保持。',
      '很好，这个空背对了。',
      '不错，继续往下背。'
    ], '背得很好，继续保持。');

  return '正确答案：' + answerText + '。' + praise;
}

function getCardMemoryHintText(card) {
  return card && card.memoryHint ? String(card.memoryHint).trim() : '';
}

function roundChallengeScore(value) {
  return Math.round((typeof value === 'number' ? value : 0) * 10) / 10;
}

function formatChallengeScore(value) {
  var rounded = roundChallengeScore(value);

  return rounded % 1 === 0 ? String(Math.round(rounded)) : rounded.toFixed(1);
}

function getChallengeCardScoreValue(subject) {
  var source = subject && typeof subject === 'object' ? subject : {};
  var cards = Array.isArray(source.cards) ? source.cards : [];

  return cards.length ? 100 / cards.length : 0;
}

function getChallengeKeywordScoreValue(card, subject) {
  var keywordCount = getCardKeywords(card).length;
  var cardScoreValue = getChallengeCardScoreValue(subject);

  return keywordCount ? cardScoreValue / keywordCount : 0;
}

function getChallengeBlankScoreValue(card, subject) {
  var blankCount = getCardBlankEntries(card).length;
  var cardScoreValue = getChallengeCardScoreValue(subject);

  return blankCount ? cardScoreValue / blankCount : 0;
}

function calculateChallengeScoreValue(subject, progressState, getCardBlankFlags) {
  var source = subject && typeof subject === 'object' ? subject : {};
  var cards = Array.isArray(source.cards) ? source.cards : [];
  var totalScore = 0;

  cards.forEach(function(card) {
    var blankScoreValue = getChallengeBlankScoreValue(card, source);
    var flags = getCardBlankFlags(card, progressState);

    flags.forEach(function(flag) {
      if (flag) {
        totalScore += blankScoreValue;
      }
    });
  });

  return roundChallengeScore(Math.min(totalScore, 100));
}

function buildChallengeHintWithMemory(baseHint, card) {
  var hint = baseHint ? String(baseHint).trim() : '';
  var memoryHint = getCardMemoryHintText(card);

  if (!memoryHint) {
    return hint;
  }

  if (!hint) {
    return memoryHint;
  }

  return hint.indexOf(memoryHint) === -1 ? (hint + '。' + memoryHint) : hint;
}

function applyBlankMask(text, fieldKey, blankEntries, blankFlags, draftMap) {
  var value = text ? String(text) : '';
  var safeDraftMap = draftMap && typeof draftMap === 'object' ? draftMap : {};
  var safeEntries = Array.isArray(blankEntries) ? blankEntries.filter(function(entry) {
    return entry.field === fieldKey;
  }) : [];
  var parts = [];
  var cursor = 0;

  if (!value || !safeEntries.length) {
    return value;
  }

  safeEntries.forEach(function(entry, index) {
    var completed = Array.isArray(blankFlags) ? Boolean(blankFlags[entry.progressIndex]) : false;

    parts.push(value.slice(cursor, entry.start));
    parts.push(completed ? entry.answer : createMaskToken(entry.answer, safeDraftMap[entry.id] || ''));
    cursor = entry.end;
  });

  parts.push(value.slice(cursor));
  return parts.join('');
}

function createResultAdviceDots(total, currentIndex) {
  var dots = [];
  var safeTotal = total > 0 ? total : 0;
  var i;

  for (i = 0; i < safeTotal; i += 1) {
    dots.push({
      id: 'result-dot-' + i,
      active: i === currentIndex
    });
  }

  return dots;
}

function createEmptyChallengeBlankAnswerMap() {
  return {};
}

export default {
  data: {
    stage: 'menu',
    currentIndex: 0,
    currentCardIndex: 0,
    challengeShuffleStep: 0,
    challengeCompletedBlankCount: 0,
    challengeTotalBlankCount: 0,
    challengeCompletedKeywordCount: 0,
    challengeTotalKeywordCount: 0,
    challengeKeywordItems: [],
    challengeRecognitionText: '',
    challengeListening: false,
    challengeIntroHintShown: false,
    challengeBlankAnswerMap: createEmptyChallengeBlankAnswerMap(),
    challengeBlankProgressMap: {},
    challengeProgressMap: {},
    modeSelectionTab: 'read',
    selectedStudyMode: 'read',
    dataLoading: true,
    challengeScore: 0,
    loadedStudyInsights: {},
    defaultStudyVoiceHint: '点击开启系统语音',
    studyVoiceHint: '点击开启系统语音',
    studyVoiceHintMarqueeActive: false,
    studyVoiceHintMarqueeTrackStyle: '',
    studyPageCounterLabel: '1 / 1',
    studyCardTitle: '',
    studyScene: '',
    studyContent: '',
    studyMemoryHint: '',
    studyAiInsight: '',
    studyImageLoading: false,
    studyImageLoadFailed: false,
    studyImageLoadingHintVisible: false,
    studyIndicatorDots: [],
    studyCardScrollTarget: '',
    resultTotalCount: 0,
    resultCorrectPercent: 0,
    resultMissPercent: 0,
    resultSummary: '',
    resultHeadline: '',
    resultScoreMessage: '',
    resultCategoryStats: [],
    resultAdvicePages: [],
    resultAdvicePageIndex: 0,
    resultAdviceDots: [],
    resultAiLoading: false,
    shuffledCardOrder: [],
    currentCard: createEmptyCard(),
    currentSubject: createEmptySubject(),
    readModeButtonClass: 'difficulty-btn difficulty-btn-square difficulty-btn-active',
    readModeTextClass: 'difficulty-btn-text difficulty-btn-text-active',
    challengeModeButtonClass: 'difficulty-btn difficulty-btn-square',
    challengeModeTextClass: 'difficulty-btn-text',
    subjects: []
  },
  onLoad() {
    var self = this;

    this.loadedStudyImageUrlMap = {};

    this.setData({
      dataLoading: true
    });

    this.dataLoadTimer = setTimeout(function() {
      self.applyStudyData(studyData);
      self.dataLoadTimer = null;
    }, 120);
  },
  onUnload() {
    if (this.dataLoadTimer) {
      clearTimeout(this.dataLoadTimer);
      this.dataLoadTimer = null;
    }
    if (this.challengeAutoNextTimer) {
      clearTimeout(this.challengeAutoNextTimer);
      this.challengeAutoNextTimer = null;
    }
    if (this.challengeNextSound) {
      try {
        this.challengeNextSound.destroy();
      } catch (error) {
        console.error('destroy next sound failed', error);
      }
      this.challengeNextSound = null;
    }
    this.stopResultAiAnalysis();
    this.stopChallengeRecognition();
    this.clearStudyVoiceHintMarqueeTimer();
    this.clearStudyImageLoadingHintTimer();
    this.loadedStudyImageUrlMap = null;
  },
  onKeyUp(event) {
    var action = this.getSubjectSwitchAction(event);

    if (event.code === 'Backspace' || event.code === 'Escape' || event.keyCode === 27 || event.keyCode === 8) {
      event.preventDefault();
      if (this.data.stage === 'mode') {
        this.stopResultAiAnalysis();
        this.setData({ stage: 'menu' });
        return;
      }
      if (this.data.stage === 'study' || this.data.stage === 'result' || this.data.stage === 'challenge_intro') {
        this.stopChallengeRecognition();
        this.stopResultAiAnalysis();
        this.setData({ stage: 'mode' });
      }
      return;
    }

    if (this.isConfirmAction(event)) {
      if (event && typeof event.preventDefault === 'function') {
        event.preventDefault();
      }
      if (this.data.stage === 'menu') {
        this.enterModeSelection();
        return;
      }
      if (this.data.stage === 'mode') {
        if (this.data.modeSelectionTab === 'challenge') {
          this.startChallengeMode();
          return;
        }
        this.startReadMode();
        return;
      }
      if (this.data.stage === 'challenge_intro') {
        this.startChallengeStudy();
      }
      return;
    }

    if (!action) {
      return;
    }

    if (event && typeof event.preventDefault === 'function') {
      event.preventDefault();
    }

    if (this.data.stage === 'mode') {
      this.toggleModeSelection(action);
      return;
    }

    if (this.data.stage === 'challenge_intro') {
      this.handleChallengeShuffleAction();
      return;
    }

    if (this.data.stage === 'result') {
      if (action === 'prev') {
        this.handleResultAdvicePrev();
        return;
      }
      this.handleResultAdviceNext();
      return;
    }

    if (this.data.stage === 'study') {
      if (action === 'prev') {
        this.handleStudyCardPrev();
        return;
      }
      this.handleStudyCardNext();
      return;
    }

    if (action === 'prev') {
      this.handlePrevTap();
      return;
    }

    this.handleNextTap();
  },
  getSubjectSwitchAction(event) {
    var code = event && event.code ? String(event.code).toUpperCase() : '';
    var key = event && event.key ? String(event.key).toUpperCase() : '';
    var action = event && event.action ? String(event.action).toUpperCase() : '';
    var detailAction = event && event.detail && event.detail.action ? String(event.detail.action).toUpperCase() : '';
    var detailKey = event && event.detail && event.detail.key ? String(event.detail.key).toUpperCase() : '';
    var keyCode = event && typeof event.keyCode === 'number' ? event.keyCode : null;
    var text = [code, key, action, detailAction, detailKey].join(' ');

    if (
      keyCode === 19 ||
      text.indexOf('UP') !== -1 ||
      text.indexOf('PREV') !== -1 ||
      text.indexOf('LEFT') !== -1
    ) {
      return 'prev';
    }

    if (
      keyCode === 20 ||
      text.indexOf('DOWN') !== -1 ||
      text.indexOf('NEXT') !== -1 ||
      text.indexOf('RIGHT') !== -1
    ) {
      return 'next';
    }

    return '';
  },
  isConfirmAction(event) {
    var code = event && event.code ? String(event.code).toUpperCase() : '';
    var key = event && event.key ? String(event.key).toUpperCase() : '';
    var action = event && event.action ? String(event.action).toUpperCase() : '';
    var detailAction = event && event.detail && event.detail.action ? String(event.detail.action).toUpperCase() : '';
    var detailKey = event && event.detail && event.detail.key ? String(event.detail.key).toUpperCase() : '';
    var keyCode = event && typeof event.keyCode === 'number' ? event.keyCode : null;
    var text = [code, key, action, detailAction, detailKey].join(' ');

    return (
      keyCode === 13 ||
      keyCode === 23 ||
      keyCode === 66 ||
      text.indexOf('ENTER') !== -1 ||
      text.indexOf('OK') !== -1 ||
      text.indexOf('CONFIRM') !== -1 ||
      text.indexOf('SELECT') !== -1
    );
  },
  getCurrentSubject() {
    return this.data.subjects[this.data.currentIndex] || this.data.subjects[0] || null;
  },
  getPlaybackOrder(subject) {
    var source = subject || this.data.currentSubject;
    var cards = source && Array.isArray(source.cards) ? source.cards : [];
    var total = cards.length;
    var order = Array.isArray(this.data.shuffledCardOrder) ? this.data.shuffledCardOrder : [];
    var isChallengeMode = this.data.selectedStudyMode === 'challenge';

    if (!isChallengeMode) {
      return createSequentialOrder(total);
    }

    if (order.length !== total) {
      return createSequentialOrder(total);
    }

    return order;
  },
  getCurrentCard(subject) {
    var source = subject || this.data.currentSubject;
    var cards = source && Array.isArray(source.cards) ? source.cards : [];
    var playbackOrder = this.getPlaybackOrder(source);
    var resolvedIndex = typeof playbackOrder[this.data.currentCardIndex] === 'number'
      ? playbackOrder[this.data.currentCardIndex]
      : 0;

    return cards[resolvedIndex] || cards[0] || null;
  },
  getCardInsight(card, subject) {
    if (card && card.aiInsight) {
      return String(card.aiInsight);
    }

    if (subject && this.data.loadedStudyInsights && this.data.loadedStudyInsights[subject.title]) {
      return String(this.data.loadedStudyInsights[subject.title]);
    }

    return '';
  },
  trimStudyText(text, maxLength) {
    var value = text ? String(text) : '';

    if (!value) {
      return '';
    }

    if (value.length <= maxLength) {
      return value;
    }

    return value.slice(0, maxLength - 1) + '…';
  },
  buildChallengeProgressState(subject) {
    var source = subject || this.getCurrentSubject() || {};
    var cards = Array.isArray(source.cards) ? source.cards : [];
    var existingMap = this.data.challengeProgressMap && typeof this.data.challengeProgressMap === 'object'
      ? this.data.challengeProgressMap
      : {};
    var existingBlankMap = this.data.challengeBlankProgressMap && typeof this.data.challengeBlankProgressMap === 'object'
      ? this.data.challengeBlankProgressMap
      : {};
    var progressMap = {};
    var blankProgressMap = {};
    var completedKeywordCount = 0;
    var totalKeywordCount = 0;
    var completedBlankCount = 0;
    var totalBlankCount = 0;

    cards.forEach(function(card) {
      var keywords = getCardKeywords(card);
      var blankEntries = getCardBlankEntries(card);
      var cardId = card && card.id ? String(card.id) : '';
      var existingFlags = cardId && Array.isArray(existingMap[cardId]) ? existingMap[cardId] : [];
      var existingBlankFlags = cardId && Array.isArray(existingBlankMap[cardId]) ? existingBlankMap[cardId] : [];
      var nextBlankFlags = blankEntries.map(function(item, index) {
        return Boolean(existingBlankFlags[index]);
      });
      var nextFlags = keywords.map(function(keyword, keywordIndex) {
        var relatedEntries = blankEntries.filter(function(entry) {
          return entry.keywordIndex === keywordIndex;
        });

        if (!relatedEntries.length) {
          return Boolean(existingFlags[keywordIndex]);
        }

        return relatedEntries.every(function(entry, entryIndex) {
          return Boolean(nextBlankFlags[entry.progressIndex]);
        });
      });

      if (cardId) {
        progressMap[cardId] = nextFlags;
        blankProgressMap[cardId] = nextBlankFlags;
      }

      totalKeywordCount += keywords.length;
      totalBlankCount += blankEntries.length;
      completedKeywordCount += nextFlags.filter(function(item) {
        return Boolean(item);
      }).length;
      completedBlankCount += nextBlankFlags.filter(function(item) {
        return Boolean(item);
      }).length;
    });

    return {
      keywordProgressMap: progressMap,
      blankProgressMap: blankProgressMap,
      completedKeywordCount: completedKeywordCount,
      totalKeywordCount: totalKeywordCount,
      completedBlankCount: completedBlankCount,
      totalBlankCount: totalBlankCount
    };
  },
  getCardBlankFlags(card, progressState) {
    var blankEntries = getCardBlankEntries(card);
    var source = progressState && progressState.blankProgressMap ? progressState.blankProgressMap : this.data.challengeBlankProgressMap;
    var cardId = card && card.id ? String(card.id) : '';
    var flags = cardId && source && Array.isArray(source[cardId]) ? source[cardId] : [];

    return blankEntries.map(function(item, index) {
      return Boolean(flags[index]);
    });
  },
  getCardKeywordFlags(card, progressState) {
    var keywords = getCardKeywords(card);
    var source = progressState && progressState.keywordProgressMap ? progressState.keywordProgressMap : this.data.challengeProgressMap;
    var cardId = card && card.id ? String(card.id) : '';
    var flags = cardId && source && Array.isArray(source[cardId]) ? source[cardId] : [];

    return keywords.map(function(keyword, index) {
      return Boolean(flags[index]);
    });
  },
  buildChallengeKeywordItems(card, progressState) {
    var subject = this.getCurrentSubject() || {};
    var keywords = getCardKeywords(card);
    var flags = this.getCardKeywordFlags(card, progressState);
    var blankEntries = getCardBlankEntries(card);
    var blankFlags = this.getCardBlankFlags(card, progressState);
    var firstPendingIndex = flags.indexOf(false);
    var keywordScoreValue = getChallengeKeywordScoreValue(card, subject);

    return keywords.map(function(keyword, index) {
      var relatedEntries = blankEntries.filter(function(entry) {
        return entry.keywordIndex === index;
      });
      var relatedFlags = relatedEntries.map(function(entry) {
        return Boolean(blankFlags[entry.progressIndex]);
      });
      var completedCount = relatedFlags.filter(function(item) {
        return item;
      }).length;
      var fillPercent = relatedFlags.length ? Math.round((completedCount / relatedFlags.length) * 100) : (flags[index] ? 100 : 0);
      return {
        id: (card && card.id ? String(card.id) : 'card') + '-keyword-' + index,
        label: keyword,
        completed: Boolean(flags[index]),
        current: firstPendingIndex === index,
        scoreValue: formatChallengeScore(keywordScoreValue),
        showFill: fillPercent > 0,
        fillPercent: fillPercent,
        fillStyle: 'height: ' + Math.max(5, Math.round(14 * fillPercent / 100)) + 'px;'
      };
    });
  },
  buildChallengeDraftMap(card, progressState) {
    var blankEntries = getCardBlankEntries(card);
    var flags = this.getCardBlankFlags(card, progressState);
    var transcript = createRecognitionDraftText(this.data.challengeRecognitionText);
    var draftMap = {};
    var pendingEntry = null;

    blankEntries.some(function(entry, index) {
      if (!flags[index]) {
        pendingEntry = entry;
        return true;
      }
      return false;
    });

    if (!transcript || !pendingEntry) {
      return draftMap;
    }

    draftMap[pendingEntry.id] = transcript;
    return draftMap;
  },
  buildChallengeBlankAnswerMap(card, progressState) {
    var flags = this.getCardBlankFlags(card, progressState);
    var blankEntries = getCardBlankEntries(card);
    var blankAnswerMap = {};

    blankEntries.forEach(function(entry, index) {
      if (flags[index]) {
        return;
      }
      blankAnswerMap[entry.blankNumber] = entry.answer;
    });

    return blankAnswerMap;
  },
  hasPendingBlanksForCard(card, progressState) {
    var blankAnswerMap = this.buildChallengeBlankAnswerMap(card, progressState);

    return Object.keys(blankAnswerMap).length > 0;
  },
  getPendingBlankCountForCard(card, progressState) {
    var blankAnswerMap = this.buildChallengeBlankAnswerMap(card, progressState);

    return Object.keys(blankAnswerMap).length;
  },
  buildChallengeMaskedCopy(card, progressState) {
    var blankEntries = getCardBlankEntries(card);
    var blankFlags = this.getCardBlankFlags(card, progressState);
    var draftMap = this.buildChallengeDraftMap(card, progressState);

    return {
      title: applyBlankMask(getChallengeDisplayTextByField(card, 'title'), 'title', blankEntries, blankFlags, draftMap),
      scene: applyBlankMask(getChallengeDisplayTextByField(card, 'scene'), 'scene', blankEntries, blankFlags, draftMap),
      content: applyBlankMask(getChallengeDisplayTextByField(card, 'content'), 'content', blankEntries, blankFlags, draftMap),
      memoryHint: applyBlankMask(getChallengeDisplayTextByField(card, 'memoryHint'), 'memoryHint', blankEntries, blankFlags, draftMap)
    };
  },
  getCurrentResolvedCardIndex(subject) {
    var source = subject || this.getCurrentSubject();
    var playbackOrder = this.getPlaybackOrder(source);

    return typeof playbackOrder[this.data.currentCardIndex] === 'number'
      ? playbackOrder[this.data.currentCardIndex]
      : 0;
  },
  buildStudyPageCounterLabel(subject) {
    var source = subject || this.getCurrentSubject();
    var cards = source && Array.isArray(source.cards) ? source.cards : [];
    var total = cards.length;
    var displayIndex = this.data.selectedStudyMode === 'challenge'
      ? this.getCurrentResolvedCardIndex(source) + 1
      : this.data.currentCardIndex + 1;

    if (!total) {
      return '0 / 0';
    }

    return displayIndex + ' / ' + total;
  },
  buildChallengeVoiceHint(card, progressState) {
    var keywordItems = this.buildChallengeKeywordItems(card, progressState);
    var allCurrentDone = keywordItems.length > 0 && keywordItems.every(function(item) {
      return item.completed;
    });
    var total = progressState.totalBlankCount || 0;
    var completed = progressState.completedBlankCount || 0;
    var score = calculateChallengeScoreValue(this.getCurrentSubject(), progressState, this.getCardBlankFlags.bind(this));
    var currentHint = this.data.studyVoiceHint || '';
    var baseHint = '';

    if (total > 0 && completed >= total) {
      baseHint = score >= 60
        ? ('恭喜你，得到了' + formatChallengeScore(score) + '分')
        : ('再接再厉，当前得分' + formatChallengeScore(score) + '分');
      return buildChallengeHintWithMemory(baseHint, card);
    }

    if (allCurrentDone) {
      baseHint = '本卡关键词已完成，继续下一张';
      return buildChallengeHintWithMemory(baseHint, card);
    }

    if (this.data.challengeIntroHintShown) {
      baseHint = currentHint && currentHint !== '请开始背诵挖空内容'
        ? currentHint
        : '等待背诵输入...';
      return buildChallengeHintWithMemory(baseHint, card);
    }

    baseHint = '请开始背诵挖空内容';
    return buildChallengeHintWithMemory(baseHint, card);
  },
  buildChallengeResultState() {
    var subject = this.getCurrentSubject() || {};
    var cards = Array.isArray(subject.cards) ? subject.cards : [];
    var progressState = this.buildChallengeProgressState(subject);
    var categoryKeys = ['memoryKey', 'tagTwo', 'tagThree'];
    var categoryLabels = [
      subject.memoryKey || '核心考点',
      subject.tagTwo || '分类二',
      subject.tagThree || '分类三'
    ];
    var categoryStats = [];
    var missedKeywords = [];
    var useKeywordScore = this.data.selectedStudyMode === 'challenge' && cards.length > 0;
    var total = useKeywordScore ? 100 : (cards.length || subject.pendingCount || 1);
    var safeTotal = total > 0 ? total : 1;
    var score = useKeywordScore
      ? calculateChallengeScoreValue(subject, progressState, this.getCardBlankFlags.bind(this))
      : this.data.challengeScore;
    var safeScore = Math.max(0, Math.min(typeof score === 'number' ? score : 0, safeTotal));
    var correctPercent = useKeywordScore ? Math.round(safeScore) : Math.round((safeScore / safeTotal) * 100);
    var missPercent = 100 - correctPercent;
    var summary = '';

    if (correctPercent >= 80) {
      summary = '本轮闯关表现稳定，核心知识点掌握度较高，可以继续提升答题速度与细节准确率。';
    } else if (correctPercent >= 50) {
      summary = '本轮闯关已建立基础掌握，建议回看错位知识点，重点强化易混概念与判断路径。';
    } else {
      summary = '本轮闯关仍有较大提升空间，建议先回到诵读模式复习当前科目的重点卡片，再重新闯关。';
    }

    categoryKeys.forEach(function(fieldKey, categoryIndex) {
      var totalCount = 0;
      var completedCount = 0;

      cards.forEach(function(card) {
        var fieldValue = card && card[fieldKey] ? String(card[fieldKey]).trim() : '';
        var keywords = getCardKeywords(card);
        var flags = this.getCardKeywordFlags(card, progressState);
        var keywordIndex = fieldValue ? keywords.indexOf(fieldValue) : -1;

        if (!fieldValue || keywordIndex === -1) {
          return;
        }

        totalCount += 1;
        if (flags[keywordIndex]) {
          completedCount += 1;
        } else if (missedKeywords.indexOf(fieldValue) === -1) {
          missedKeywords.push(fieldValue);
        }
      }, this);

      categoryStats.push({
        id: 'result-category-' + fieldKey,
        label: categoryLabels[categoryIndex],
        percent: totalCount ? Math.round((completedCount / totalCount) * 100) : 0,
        completed: completedCount,
        total: totalCount,
        fillStyle: 'width: ' + (totalCount ? Math.round((completedCount / totalCount) * 100) : 0) + '%;'
      });
    }, this);

    return {
      total: safeTotal,
      score: roundChallengeScore(safeScore),
      correctPercent: correctPercent,
      missPercent: missPercent,
      summary: summary,
      headline: subject.title ? (subject.title + '闯关完成') : '闯关完成',
      scoreMessage: safeScore >= 60
        ? ('恭喜你，获得了' + formatChallengeScore(safeScore) + '分')
        : ('再接再厉，当前得分' + formatChallengeScore(safeScore) + '分'),
      categoryStats: categoryStats,
      missedKeywords: missedKeywords.slice(0, 6)
    };
  },
  buildLocalResultAdvicePages(resultState) {
    var stats = Array.isArray(resultState && resultState.categoryStats) ? resultState.categoryStats : [];
    var sortedStats = stats.slice().sort(function(a, b) {
      return a.percent - b.percent;
    });
    var weakest = sortedStats[0] || { label: '核心考点', percent: 0 };
    var strongest = sortedStats[sortedStats.length - 1] || { label: '核心考点', percent: 0 };
    var missedKeywords = Array.isArray(resultState && resultState.missedKeywords) ? resultState.missedKeywords : [];
    var weakKeywordsText = missedKeywords.length ? missedKeywords.join('、') : '本轮关键词完成较完整';

    return [
      resultState.summary || '本轮背诵已完成，可以继续按错题与易混点复盘。',
      '当前最弱分类是' + weakest.label + '，完成度' + weakest.percent + '%，建议先回看对应卡片的判断路径。',
      '当前最强分类是' + strongest.label + '，完成度' + strongest.percent + '%，可以继续保持并提速背诵节奏。',
      '本轮优先复盘：' + weakKeywordsText + '。建议下一轮先从这些关键词开始强化。'
    ];
  },
  normalizeResultAdvicePages(text, fallbackPages) {
    var value = text ? String(text).trim() : '';
    var pages = value ? value.split('||').map(function(item) {
      return String(item).trim();
    }).filter(function(item) {
      return Boolean(item);
    }) : [];

    if (!pages.length) {
      return fallbackPages;
    }

    return pages.slice(0, 4);
  },
  stopResultAiAnalysis(keepRequestId) {
    if (!keepRequestId) {
      this.resultAnalysisRequestId = (this.resultAnalysisRequestId || 0) + 1;
    }

    if (this.resultAnalysisSession) {
      try {
        this.resultAnalysisSession.destroy();
      } catch (error) {
        console.error('destroy result analysis session failed', error);
      }
      this.resultAnalysisSession = null;
    }
  },
  async generateResultAiAnalysis(resultState) {
    var fallbackPages = this.buildLocalResultAdvicePages(resultState);
    var categoryText = (resultState.categoryStats || []).map(function(item) {
      return item.label + item.percent + '%';
    }).join('，');
    var missedText = resultState.missedKeywords && resultState.missedKeywords.length
      ? resultState.missedKeywords.join('、')
      : '无明显遗漏关键词';
    var requestId = (this.resultAnalysisRequestId || 0) + 1;
    var availability = 'unavailable';
    var session;
    var response;
    var pages;

    this.resultAnalysisRequestId = requestId;
    this.setData({
      resultAiLoading: true,
      resultAdvicePages: fallbackPages,
      resultAdvicePageIndex: 0,
      resultAdviceDots: createResultAdviceDots(fallbackPages.length, 0),
      resultSummary: fallbackPages[0] || ''
    });

    try {
      availability = await LanguageModel.availability();
      if (availability !== 'available') {
        throw new Error('LanguageModel unavailable');
      }

      this.stopResultAiAnalysis(true);

      session = await LanguageModel.create({
        initialPrompts: [
          {
            role: 'system',
            content: '你是妙卡的中文学习教练。请根据学习结果输出4段简短背诵建议。每段18到32字，不要编号，不要markdown，只返回4段文本，用||分隔。'
          }
        ]
      });
      this.resultAnalysisSession = session;
      response = await session.prompt(
        '科目：' + (this.data.currentSubject.title || '当前科目') +
        '；总分：' + resultState.score +
        '；总完成率：' + resultState.correctPercent + '%' +
        '；分类完成度：' + categoryText +
        '；待强化关键词：' + missedText +
        '；请给出4段具体背诵建议。'
      );
      pages = this.normalizeResultAdvicePages(response, fallbackPages);
    } catch (error) {
      console.error('generate result ai analysis failed', error);
      pages = fallbackPages;
    }

    if (this.resultAnalysisRequestId !== requestId || !this.data || this.data.stage !== 'result') {
      return;
    }

    this.setData({
      resultAiLoading: false,
      resultAdvicePages: pages,
      resultAdvicePageIndex: 0,
      resultAdviceDots: createResultAdviceDots(pages.length, 0),
      resultSummary: pages[0] || ''
    });
  },
  updateResultAdvicePage(nextIndex) {
    var pages = Array.isArray(this.data.resultAdvicePages) ? this.data.resultAdvicePages : [];
    var total = pages.length;
    var safeIndex;

    if (!total) {
      return;
    }

    safeIndex = (nextIndex + total) % total;
    this.setData({
      resultAdvicePageIndex: safeIndex,
      resultAdviceDots: createResultAdviceDots(total, safeIndex),
      resultSummary: pages[safeIndex] || ''
    });
  },
  handleResultAdvicePrev() {
    this.updateResultAdvicePage(this.data.resultAdvicePageIndex - 1);
  },
  handleResultAdviceNext() {
    this.updateResultAdvicePage(this.data.resultAdvicePageIndex + 1);
  },
  buildStudyIndicatorDots(total, currentIndex) {
    var safeTotal = total > 0 ? total : 0;
    var startIndex;
    var endIndex;
    var dots = [];
    var i;

    if (!safeTotal) {
      return [];
    }

    startIndex = Math.floor(currentIndex / 5) * 5;
    endIndex = Math.min(startIndex + 5, safeTotal);

    for (i = startIndex; i < endIndex; i += 1) {
      dots.push({
        id: 'indicator-' + i,
        cardIndex: i,
        active: i === currentIndex
      });
    }

    return dots;
  },
  normalizeStudyData(payload) {
    var source = payload;
    var fallback = createDefaultStudyData();

    if (typeof source === 'string') {
      try {
        source = JSON.parse(source);
      } catch (error) {
        source = fallback;
      }
    }

    return {
      studyVoiceHint: source && source.studyVoiceHint ? String(source.studyVoiceHint) : fallback.studyVoiceHint,
      studyInsights: source && source.studyInsights && typeof source.studyInsights === 'object' ? source.studyInsights : fallback.studyInsights,
      subjects: source && Array.isArray(source.subjects) ? source.subjects.map(function(subject) {
        var safeSubject = subject && typeof subject === 'object' ? subject : {};
        var cards = Array.isArray(safeSubject.cards) ? safeSubject.cards : [];

        return {
          id: safeSubject.id || 0,
          title: safeSubject.title || '',
          pendingCount: typeof safeSubject.pendingCount === 'number' ? safeSubject.pendingCount : cards.length,
          scene: safeSubject.scene || '',
          content: safeSubject.content || '',
          memoryKey: safeSubject.memoryKey || '',
          memoryHint: safeSubject.memoryHint || '',
          tagTwo: safeSubject.tagTwo || '',
          tagThree: safeSubject.tagThree || '',
          illustrationUrl: safeSubject.illustrationUrl || '',
          cards: cards.map(function(card, index) {
            var safeCard = card && typeof card === 'object' ? card : {};

            return {
              id: safeCard.id || ('card-' + index),
              order: typeof safeCard.order === 'number' ? safeCard.order : index + 1,
              title: safeCard.title || '',
              scene: safeCard.scene || '',
              content: safeCard.content || '',
              memoryKey: safeCard.memoryKey || '',
              memoryHint: safeCard.memoryHint || '',
              tagTwo: safeCard.tagTwo || '',
              tagThree: safeCard.tagThree || '',
              illustrationUrl: safeCard.illustrationUrl || '',
              aiInsight: safeCard.aiInsight || ''
            };
          })
        };
      }) : fallback.subjects
    };
  },
  applyStudyData(payload) {
    var normalized = this.normalizeStudyData(payload);

    this.setData({
      dataLoading: false,
      subjects: normalized.subjects,
      loadedStudyInsights: normalized.studyInsights,
      defaultStudyVoiceHint: normalized.studyVoiceHint
    });
    this.setStudyVoiceHint(normalized.studyVoiceHint);
    this.syncCurrentSubject();
  },
  syncCurrentSubject(options) {
    var subject = this.getCurrentSubject();
    var config = options && typeof options === 'object' ? options : {};
    var cards = subject && Array.isArray(subject.cards) ? subject.cards : [];
    var playbackOrder = this.getPlaybackOrder(subject);
    var nextCardIndex = cards.length ? Math.min(this.data.currentCardIndex, cards.length - 1) : 0;
    var resolvedCardIndex = typeof playbackOrder[nextCardIndex] === 'number' ? playbackOrder[nextCardIndex] : 0;
    var card = cards[resolvedCardIndex] || createEmptyCard();
    var insight = this.getCardInsight(card, subject);
    var isChallengeMode = this.data.selectedStudyMode === 'challenge';
    var challengeProgressState = isChallengeMode ? this.buildChallengeProgressState(subject) : createEmptyChallengeProgress();
    var maskedCopy = isChallengeMode ? this.buildChallengeMaskedCopy(card, challengeProgressState) : null;
    var keywordItems = isChallengeMode ? this.buildChallengeKeywordItems(card, challengeProgressState) : [];
    var challengeBlankAnswerMap = isChallengeMode
      ? this.buildChallengeBlankAnswerMap(card, challengeProgressState)
      : createEmptyChallengeBlankAnswerMap();
    var challengeScore = isChallengeMode
      ? calculateChallengeScoreValue(subject, challengeProgressState, this.getCardBlankFlags.bind(this))
      : this.data.challengeScore;
    var blankCount = isChallengeMode ? getCardBlankEntries(card).length : 0;
    var pendingBlankCount = isChallengeMode ? this.getPendingBlankCountForCard(card, challengeProgressState) : 0;
    var illustrationUrl = card && card.illustrationUrl ? String(card.illustrationUrl) : '';
    var hasIllustration = Boolean(illustrationUrl);
    var shouldShowImageLoading = hasIllustration && this.isRemoteStudyImageUrl(illustrationUrl) && !this.hasLoadedStudyImageUrl(illustrationUrl);
    var studyCardTitle = isChallengeMode ? this.trimStudyText(maskedCopy.title, 20) : (card && card.title ? String(card.title) : '');
    var studyScene = isChallengeMode ? this.trimStudyText(maskedCopy.scene, 24) : (card && card.scene ? String(card.scene) : '');
    var studyContent = isChallengeMode ? this.trimStudyText(maskedCopy.content, 30) : (card && card.content ? String(card.content) : '');
    var studyMemoryHint = isChallengeMode ? this.trimStudyText(maskedCopy.memoryHint, 24) : (card && card.memoryHint ? String(card.memoryHint) : '');
    var studyAiInsight = isChallengeMode ? '' : insight;
    var nextVoiceHint = isChallengeMode
      ? this.buildChallengeVoiceHint(card, challengeProgressState)
      : (this.data.defaultStudyVoiceHint || '点击开启系统语音');

    this.setData({
      currentCardIndex: nextCardIndex,
      currentSubject: subject || createEmptySubject(),
      challengeCompletedBlankCount: challengeProgressState.completedBlankCount,
      challengeTotalBlankCount: challengeProgressState.totalBlankCount,
      challengeCompletedKeywordCount: challengeProgressState.completedKeywordCount,
      challengeTotalKeywordCount: challengeProgressState.totalKeywordCount,
      challengeKeywordItems: keywordItems,
      challengeBlankAnswerMap: challengeBlankAnswerMap,
      challengeBlankProgressMap: challengeProgressState.blankProgressMap,
      challengeProgressMap: challengeProgressState.keywordProgressMap,
      currentCard: card,
      studyCardScrollTarget: cards.length ? 'study-card-item-' + resolvedCardIndex : '',
      studyPageCounterLabel: this.buildStudyPageCounterLabel(subject),
      studyCardTitle: studyCardTitle,
      studyScene: studyScene,
      studyContent: studyContent,
      studyMemoryHint: studyMemoryHint,
      studyAiInsight: studyAiInsight,
      studyImageLoading: shouldShowImageLoading,
      studyImageLoadFailed: false,
      studyImageLoadingHintVisible: false,
      studyIndicatorDots: this.buildStudyIndicatorDots(cards.length, nextCardIndex),
      challengeScore: challengeScore
    });
    if (shouldShowImageLoading) {
      this.scheduleStudyImageLoadingHint(illustrationUrl);
    } else {
      this.clearStudyImageLoadingHintTimer();
    }
    this.setStudyVoiceHint(config.resetVoiceHint ? '' : nextVoiceHint);

    console.log('[challenge-debug] current card synced', {
      subjectTitle: subject && subject.title ? subject.title : '',
      cardId: card && card.id ? card.id : '',
      cardTitle: card && card.title ? card.title : '',
      illustrationUrl: card && card.illustrationUrl ? card.illustrationUrl : '',
      blankCount: blankCount,
      pendingBlankCount: pendingBlankCount,
      completedBlankCountForCard: blankCount - pendingBlankCount,
      pageLabel: this.buildStudyPageCounterLabel(subject)
    });
  },
  handleStudyCardPrev() {
    var subject = this.data.currentSubject || {};
    var cards = Array.isArray(subject.cards) ? subject.cards : [];
    var nextCardIndex;

    if (!cards.length) {
      return;
    }

    this.stopSpeechPlayback();
    nextCardIndex = (this.data.currentCardIndex - 1 + cards.length) % cards.length;
    this.setData({
      currentCardIndex: nextCardIndex,
      challengeRecognitionText: ''
    });
    this.syncCurrentSubject({
      resetVoiceHint: true
    });
    this.resumeReadModeVoiceAfterStudySwitch();
    if (
      this.data.selectedStudyMode === 'challenge' &&
      !this.data.challengeListening &&
      this.hasPendingBlanksForCard(this.data.currentCard, this.buildChallengeProgressState(this.data.currentSubject))
    ) {
      this.startChallengeRecognition();
    }
  },
  handleStudyCardNext() {
    var subject = this.data.currentSubject || {};
    var cards = Array.isArray(subject.cards) ? subject.cards : [];
    var nextCardIndex;

    if (!cards.length) {
      return;
    }

    this.stopSpeechPlayback();
    if (
      this.data.selectedStudyMode === 'challenge' &&
      this.data.currentCardIndex >= cards.length - 1 &&
      this.data.challengeTotalBlankCount > 0 &&
      this.data.challengeCompletedBlankCount >= this.data.challengeTotalBlankCount
    ) {
      this.enterChallengeResult();
      return;
    }

    nextCardIndex = (this.data.currentCardIndex + 1) % cards.length;
    this.setData({
      currentCardIndex: nextCardIndex,
      challengeRecognitionText: ''
    });
    this.syncCurrentSubject({
      resetVoiceHint: true
    });
    this.resumeReadModeVoiceAfterStudySwitch();
    if (
      this.data.selectedStudyMode === 'challenge' &&
      !this.data.challengeListening &&
      this.hasPendingBlanksForCard(this.data.currentCard, this.buildChallengeProgressState(this.data.currentSubject))
    ) {
      this.startChallengeRecognition();
    }
  },
  handleStudyCardSelect(event) {
    var cardIndex = event && event.currentTarget && event.currentTarget.dataset
      ? Number(event.currentTarget.dataset.cardIndex)
      : NaN;
    var subject = this.data.currentSubject || {};
    var cards = Array.isArray(subject.cards) ? subject.cards : [];

    if (!cards.length || Number.isNaN(cardIndex) || cardIndex < 0 || cardIndex >= cards.length) {
      return;
    }

    this.stopSpeechPlayback();
    this.setData({
      currentCardIndex: cardIndex,
      challengeRecognitionText: ''
    });
    this.syncCurrentSubject({
      resetVoiceHint: true
    });
    this.resumeReadModeVoiceAfterStudySwitch();
    if (
      this.data.selectedStudyMode === 'challenge' &&
      !this.data.challengeListening &&
      this.hasPendingBlanksForCard(this.data.currentCard, this.buildChallengeProgressState(this.data.currentSubject))
    ) {
      this.startChallengeRecognition();
    }
  },
  handlePrevTap() {
    var nextIndex;

    if (!this.data.subjects.length) {
      return;
    }

    this.stopSpeechPlayback();
    nextIndex = (this.data.currentIndex - 1 + this.data.subjects.length) % this.data.subjects.length;
    this.setData({
      currentIndex: nextIndex
    });
    this.syncCurrentSubject();
    this.resumeReadModeVoiceAfterStudySwitch();
  },
  handleNextTap() {
    var nextIndex;

    if (!this.data.subjects.length) {
      return;
    }

    this.stopSpeechPlayback();
    nextIndex = (this.data.currentIndex + 1) % this.data.subjects.length;
    this.setData({
      currentIndex: nextIndex
    });
    this.syncCurrentSubject();
    this.resumeReadModeVoiceAfterStudySwitch();
  },
  setModeSelection(mode) {
    var activeMode = mode === 'challenge' ? 'challenge' : 'read';
    var classState = createModeSelectionClassState(activeMode);

    this.setData({
      stage: 'mode',
      modeSelectionTab: activeMode,
      readModeButtonClass: classState.readModeButtonClass,
      readModeTextClass: classState.readModeTextClass,
      challengeModeButtonClass: classState.challengeModeButtonClass,
      challengeModeTextClass: classState.challengeModeTextClass
    });
  },
  toggleModeSelection(direction) {
    var nextMode = this.data.modeSelectionTab === 'challenge' ? 'read' : 'challenge';

    if (direction === 'next') {
      nextMode = this.data.modeSelectionTab === 'read' ? 'challenge' : 'read';
    }

    this.setModeSelection(nextMode);
  },
  enterModeSelection() {
    this.setModeSelection('read');
  },
  openModeSelection(mode) {
    this.setModeSelection(mode || 'read');
  },
  handleSubjectTap() {
    this.enterModeSelection();
  },
  handleReadModeTap() {
    if (this.data.stage === 'mode') {
      if (this.data.modeSelectionTab === 'read') {
        this.startReadMode();
        return;
      }
      this.setModeSelection('read');
      return;
    }
    this.openModeSelection('read');
  },
  handleChallengeModeTap() {
    if (this.data.stage === 'mode') {
      if (this.data.modeSelectionTab === 'challenge') {
        this.startChallengeMode();
        return;
      }
      this.setModeSelection('challenge');
      return;
    }
    this.openModeSelection('challenge');
  },
  clearStudyVoiceHintMarqueeTimer() {
    if (this.studyVoiceHintMarqueeTimer) {
      clearTimeout(this.studyVoiceHintMarqueeTimer);
      this.studyVoiceHintMarqueeTimer = null;
    }
  },
  stopStudyVoiceHintMarquee() {
    this.clearStudyVoiceHintMarqueeTimer();
    if (!this.data || !this.data.studyVoiceHintMarqueeActive) {
      return;
    }
    this.setData({
      studyVoiceHintMarqueeActive: false,
      studyVoiceHintMarqueeTrackStyle: ''
    });
  },
  stopSpeechPlayback() {
    if (
      typeof speechSynthesis !== 'undefined' &&
      speechSynthesis &&
      typeof speechSynthesis.cancel === 'function'
    ) {
      try {
        speechSynthesis.cancel();
      } catch (error) {
        console.error('speech playback cancel failed', error);
      }
    }
  },
  resumeReadModeVoiceAfterStudySwitch() {
    if (this.data.selectedStudyMode !== 'read' || this.data.stage !== 'study') {
      return;
    }

    this.playReadModeVoice();
  },
  clearStudyImageLoadingHintTimer() {
    if (this.studyImageLoadingHintTimer) {
      clearTimeout(this.studyImageLoadingHintTimer);
      this.studyImageLoadingHintTimer = null;
    }
  },
  scheduleStudyImageLoadingHint(url) {
    var safeUrl = url ? String(url) : '';
    var self = this;

    this.clearStudyImageLoadingHintTimer();
    if (!safeUrl) {
      return;
    }

    this.studyImageLoadingHintTimer = setTimeout(function() {
      var currentUrl = self.data && self.data.currentCard && self.data.currentCard.illustrationUrl
        ? String(self.data.currentCard.illustrationUrl)
        : '';

      self.studyImageLoadingHintTimer = null;
      if (!self.data || !self.data.studyImageLoading || self.data.studyImageLoadFailed || currentUrl !== safeUrl) {
        return;
      }
      self.setData({
        studyImageLoadingHintVisible: true
      });
    }, 450);
  },
  estimateStudyVoiceHintMarqueeDuration(text) {
    var safeText = text ? String(text) : '';
    var safeLength = safeText.length;

    if (!safeLength) {
      return 0;
    }

    return Math.max(4200, Math.min(18000, safeLength * 240));
  },
  buildStudyVoiceHintPages(text, maxLength) {
    var safeText = text ? String(text).trim() : '';
    var safeMaxLength = maxLength > 0 ? maxLength : 22;
    var sentenceMatches;
    var rawSegments;
    var pages = [];

    if (!safeText) {
      return [''];
    }

    sentenceMatches = safeText.match(/[^。！？!?；;，,、]+[。！？!?；;，,、]?/g);
    rawSegments = sentenceMatches && sentenceMatches.length ? sentenceMatches : [safeText];

    rawSegments.forEach(function(segment) {
      var value = segment ? String(segment).trim() : '';
      var start = 0;

      if (!value) {
        return;
      }

      while (start < value.length) {
        pages.push(value.slice(start, start + safeMaxLength));
        start += safeMaxLength;
      }
    });

    return pages.length ? pages : [safeText];
  },
  isRemoteStudyImageUrl(url) {
    var value = url ? String(url) : '';

    return /^https?:\/\//i.test(value);
  },
  hasLoadedStudyImageUrl(url) {
    var value = url ? String(url) : '';
    var cache = this.loadedStudyImageUrlMap && typeof this.loadedStudyImageUrlMap === 'object'
      ? this.loadedStudyImageUrlMap
      : {};

    return Boolean(value && cache[value]);
  },
  setStudyVoiceHint(hint, options) {
    var safeHint = hint ? String(hint) : '';
    var pages = this.buildStudyVoiceHintPages(safeHint, 22);
    var shouldPaginate = pages.length > 1;
    var self = this;
    var token = (this.studyVoiceHintToken || 0) + 1;
    var index = 0;

    this.clearStudyVoiceHintMarqueeTimer();
    this.studyVoiceHintToken = token;
    this.setData({
      studyVoiceHint: pages[0] || '',
      studyVoiceHintMarqueeActive: false,
      studyVoiceHintMarqueeTrackStyle: ''
    });

    if (!shouldPaginate) {
      return;
    }

    this.studyVoiceHintMarqueeTimer = setInterval(function() {
      if (!self.data || self.studyVoiceHintToken !== token) {
        return;
      }
      index = (index + 1) % pages.length;
      self.setData({
        studyVoiceHint: pages[index] || ''
      });
    }, 1600);
  },
  startReadMode() {
    this.stopChallengeRecognition();
    this.stopResultAiAnalysis();
    this.stopSpeechPlayback();
    this.setData({
      currentCardIndex: 0,
      challengeRecognitionText: '',
      challengeListening: false,
      challengeProgressMap: {},
      challengeBlankProgressMap: {},
      challengeKeywordItems: [],
      challengeCompletedBlankCount: 0,
      challengeTotalBlankCount: 0,
      challengeCompletedKeywordCount: 0,
      challengeTotalKeywordCount: 0,
      shuffledCardOrder: [],
      selectedStudyMode: 'read',
      modeSelectionTab: 'read',
      stage: 'study'
    });
    this.syncCurrentSubject();
    this.playReadModeVoice();
  },
  startChallengeMode() {
    var subject = this.getCurrentSubject();
    var cards = subject && Array.isArray(subject.cards) ? subject.cards : [];
    var challengeProgressMap = {};
    var challengeBlankProgressMap = {};
    var challengeTotalKeywordCount = 0;
    var challengeTotalBlankCount = 0;

    cards.forEach(function(card) {
      var keywords = getCardKeywords(card);
      var blankEntries = getCardBlankEntries(card);
      if (card && card.id) {
        challengeProgressMap[String(card.id)] = keywords.map(function() {
          return false;
        });
        challengeBlankProgressMap[String(card.id)] = blankEntries.map(function() {
          return false;
        });
      }
      challengeTotalKeywordCount += keywords.length;
      challengeTotalBlankCount += blankEntries.length;
    });

    this.stopChallengeRecognition();
    this.stopResultAiAnalysis();
    this.setData({
      challengeShuffleStep: 0,
      currentCardIndex: 0,
      challengeRecognitionText: '',
      challengeListening: false,
      challengeIntroHintShown: false,
      challengeBlankAnswerMap: createEmptyChallengeBlankAnswerMap(),
      challengeBlankProgressMap: challengeBlankProgressMap,
      challengeCompletedBlankCount: 0,
      challengeTotalBlankCount: challengeTotalBlankCount,
      challengeCompletedKeywordCount: 0,
      challengeTotalKeywordCount: challengeTotalKeywordCount,
      challengeProgressMap: challengeProgressMap,
      shuffledCardOrder: createShuffledOrder(cards.length),
      selectedStudyMode: 'challenge',
      modeSelectionTab: 'challenge',
      stage: 'challenge_intro'
    });
  },
  startChallengeStudy() {
    this.setData({
      challengeShuffleStep: 4,
      currentCardIndex: 0,
      challengeRecognitionText: '',
      challengeIntroHintShown: false,
      stage: 'study'
    });
    this.syncCurrentSubject();
    this.startChallengeRecognition();
  },
  handleChallengeShuffleAction() {
    var nextStep = Math.min((this.data.challengeShuffleStep || 0) + 1, 4);

    if (nextStep >= 4) {
      this.startChallengeStudy();
      return;
    }

    this.setData({
      challengeShuffleStep: nextStep
    });
  },
  enterChallengeResult() {
    var resultState = this.buildChallengeResultState();

    this.stopChallengeRecognition();
    this.setData({
      stage: 'result',
      challengeScore: resultState.score,
      resultTotalCount: resultState.total,
      resultCorrectPercent: resultState.correctPercent,
      resultMissPercent: resultState.missPercent,
      resultSummary: resultState.summary,
      resultHeadline: resultState.headline,
      resultScoreMessage: resultState.scoreMessage,
      resultCategoryStats: resultState.categoryStats,
      resultAdvicePages: [resultState.summary],
      resultAdvicePageIndex: 0,
      resultAdviceDots: createResultAdviceDots(1, 0),
      resultAiLoading: true
    });
    this.generateResultAiAnalysis(resultState);
  },
  handleChallengeIntroTap() {
    this.startChallengeStudy();
  },
  getStudyVoiceText() {
    var subject = this.data.currentSubject || {};
    var card = this.data.currentCard || {};
    var insight = this.getCardInsight(card, subject);
    var parts = [
      subject.title || '',
      card.title || '',
      card.scene || '',
      card.content || '',
      card.memoryHint || '',
      insight || ''
    ];

    return parts.filter(function(item) {
      return Boolean(item);
    }).join('。');
  },
  buildReadModeVoiceCandidates() {
    var currentSubject = this.data.currentSubject || {};
    var currentCard = this.data.currentCard || {};
    var displayParts = [
      currentSubject.title || '',
      this.data.studyCardTitle || '',
      this.data.studyScene || '',
      this.data.studyContent || '',
      this.data.studyMemoryHint || ''
    ];
    var conciseParts = [
      currentSubject.title || '',
      this.data.studyCardTitle || '',
      this.data.studyContent || '',
      this.data.studyMemoryHint || ''
    ];
    var fallbackParts = [
      currentSubject.title || '',
      currentCard && currentCard.title ? String(currentCard.title) : '',
      currentCard && currentCard.memoryHint ? String(currentCard.memoryHint) : ''
    ];
    var candidates = [
      displayParts.filter(function(item) {
        return Boolean(item);
      }).join('。'),
      conciseParts.filter(function(item) {
        return Boolean(item);
      }).join('。'),
      fallbackParts.filter(function(item) {
        return Boolean(item);
      }).join('。'),
      this.getStudyVoiceText()
    ];

    return candidates.filter(function(item, index, list) {
      return Boolean(item) && list.indexOf(item) === index;
    });
  },
  playReadModeVoice() {
    var candidates = this.buildReadModeVoiceCandidates();
    var i;

    if (!candidates.length) {
      this.setStudyVoiceHint('当前卡片暂无可朗读内容');
      return;
    }

    for (i = 0; i < candidates.length; i += 1) {
      if (this.playSpeechText(candidates[i], '系统正在朗读当前文案')) {
        console.log('[study-voice-debug] read mode voice started', {
          candidateIndex: i,
          textLength: candidates[i].length,
          previewText: candidates[i].slice(0, 48)
        });
        return;
      }
    }

    console.error('[study-voice-debug] read mode voice start failed', {
      candidateLengths: candidates.map(function(item) {
        return item.length;
      })
    });
    this.setStudyVoiceHint('当前预览环境未提供语音能力');
  },
  playSpeechText(text, playingHint) {
    var value = text ? String(text) : '';
    var hint = playingHint || '系统正在朗读当前文案';
    var utteranceId = '';
    var utterance;

    if (!value) {
      return false;
    }

    if (wx && wx.speech && typeof wx.speech.playTTS === 'function') {
      try {
        utteranceId = wx.speech.playTTS(value) || '';
        if (utteranceId) {
          this.setStudyVoiceHint(hint, {
            animate: true,
            speechText: value
          });
          return true;
        }
      } catch (error) {
        console.error('playTTS failed', error);
      }
    }

    if (
      typeof speechSynthesis !== 'undefined' &&
      speechSynthesis &&
      typeof speechSynthesis.speak === 'function' &&
      typeof SpeechSynthesisUtterance === 'function'
    ) {
      try {
        utterance = new SpeechSynthesisUtterance(value);
        utterance.lang = 'zh-CN';
        utterance.rate = 1;
        utterance.pitch = 1;
        utterance.volume = 1;
        speechSynthesis.speak(utterance);
        this.setStudyVoiceHint(hint, {
          animate: true,
          speechText: value
        });
        return true;
      } catch (fallbackError) {
        console.error('speechSynthesis failed', fallbackError);
      }
    }

    return false;
  },
  handleStudyImageLoad(event) {
    var card = this.data.currentCard || {};
    var illustrationUrl = card && card.illustrationUrl ? String(card.illustrationUrl) : '';

    this.clearStudyImageLoadingHintTimer();

    if (illustrationUrl) {
      if (!this.loadedStudyImageUrlMap || typeof this.loadedStudyImageUrlMap !== 'object') {
        this.loadedStudyImageUrlMap = {};
      }
      this.loadedStudyImageUrlMap[illustrationUrl] = true;
    }

    this.setData({
      studyImageLoading: false,
      studyImageLoadFailed: false,
      studyImageLoadingHintVisible: false
    });

    console.log('[challenge-debug] study image loaded', {
      cardId: card && card.id ? card.id : '',
      cardTitle: card && card.title ? card.title : '',
      illustrationUrl: card && card.illustrationUrl ? card.illustrationUrl : '',
      detail: event && event.detail ? event.detail : null
    });
  },
  handleStudyImageError(event) {
    var card = this.data.currentCard || {};
    var illustrationUrl = card && card.illustrationUrl ? String(card.illustrationUrl) : '';

    this.clearStudyImageLoadingHintTimer();

    if (illustrationUrl && this.loadedStudyImageUrlMap && typeof this.loadedStudyImageUrlMap === 'object') {
      delete this.loadedStudyImageUrlMap[illustrationUrl];
    }

    this.setData({
      studyImageLoading: false,
      studyImageLoadFailed: true,
      studyImageLoadingHintVisible: false
    });

    console.error('[challenge-debug] study image failed', {
      cardId: card && card.id ? card.id : '',
      cardTitle: card && card.title ? card.title : '',
      illustrationUrl: card && card.illustrationUrl ? card.illustrationUrl : '',
      detail: event && event.detail ? event.detail : null
    });
  },
  playChallengeNextAudio() {
    try {
      if (!this.challengeNextSound) {
        this.challengeNextSound = new Sound('../../assets/audio/next_item.mp3');
        this.challengeNextSound.volume = 1;
      }
      this.challengeNextSound.play();
    } catch (error) {
      console.error('play next item audio failed', error);
    }
  },
  queueChallengeAutoNext(delay) {
    var safeDelay = typeof delay === 'number' ? delay : 900;
    var self = this;

    if (this.challengeAutoNextTimer) {
      clearTimeout(this.challengeAutoNextTimer);
      this.challengeAutoNextTimer = null;
    }

    this.challengeAutoNextTimer = setTimeout(function() {
      self.challengeAutoNextTimer = null;
      if (!self.data || self.data.stage !== 'study' || self.data.selectedStudyMode !== 'challenge') {
        return;
      }

      if (
        self.data.challengeTotalBlankCount > 0 &&
        self.data.challengeCompletedBlankCount >= self.data.challengeTotalBlankCount
      ) {
        self.enterChallengeResult();
        return;
      }

      self.handleStudyCardNext();
    }, safeDelay);
  },
  stopChallengeRecognition() {
    this.challengeRecognitionStopping = true;
    if (this.challengeAutoNextTimer) {
      clearTimeout(this.challengeAutoNextTimer);
      this.challengeAutoNextTimer = null;
    }

    if (this.challengeRecognition) {
      try {
        if (typeof this.challengeRecognition.stop === 'function') {
          this.challengeRecognition.stop();
        } else if (typeof this.challengeRecognition.abort === 'function') {
          this.challengeRecognition.abort();
        }
      } catch (error) {
        console.error('stop recognition failed', error);
      }
    }

    this.challengeRecognition = null;
    if (this.data && this.data.challengeListening) {
      this.setData({
        challengeListening: false
      });
    }
  },
  extractRecognitionTranscript(event) {
    var rawResults = event && event.results ? event.results : [];
    var parts = [];
    var i;
    var result;
    var alternative;

    for (i = 0; i < rawResults.length; i += 1) {
      result = rawResults[i];
      if (typeof result === 'string') {
        parts.push(result);
        continue;
      }
      if (Array.isArray(result) && result[0]) {
        alternative = result[0];
        if (typeof alternative === 'string') {
          parts.push(alternative);
        } else if (alternative && alternative.transcript) {
          parts.push(String(alternative.transcript));
        }
        continue;
      }
      if (result && result[0] && result[0].transcript) {
        parts.push(String(result[0].transcript));
      }
    }

    return parts.join('');
  },
  updateChallengeKeywordProgress(transcript) {
    var subject = this.getCurrentSubject() || {};
    var card = this.data.currentCard || {};
    var progressState = this.buildChallengeProgressState(subject);
    var blankEntries = getCardBlankEntries(card);
    var cardId = card && card.id ? String(card.id) : '';
    var blankFlags = this.getCardBlankFlags(card, progressState).slice();
    var transcriptText = transcript ? String(transcript).trim() : '';
    var normalizedTranscript = normalizeRecognitionText(transcript);
    var matchedAnswers = [];
    var matchedAnswerText = '';
    var allCardCompleted;
    var refreshedState;
    var score;
    var hintText;
    var speechText = '';
    var newlyCompletedCount = 0;
    var i;
    var entry;
    var matchedEntry = null;

    if (!cardId || !blankEntries.length) {
      return;
    }

    for (i = 0; i < blankEntries.length; i += 1) {
      entry = blankEntries[i];
      if (blankFlags[i]) {
        continue;
      }
      if (normalizedTranscript.indexOf(normalizeRecognitionText(entry.answer)) !== -1) {
        blankFlags[i] = true;
        matchedAnswers.push(entry.answer);
        newlyCompletedCount += 1;
        matchedEntry = entry;
        break;
      }
    }

    if (!matchedAnswers.length) {
      this.setData({
        challengeRecognitionText: transcriptText
      });
      this.setStudyVoiceHint(buildChallengeHintWithMemory(
        transcriptText ? ('识别到：' + transcriptText + '。继续努力，再接再厉') : '继续努力，再接再厉',
        card
      ));
      return;
    }

    progressState.blankProgressMap[cardId] = blankFlags;
    refreshedState = this.buildChallengeProgressState(subject);
    score = calculateChallengeScoreValue(subject, refreshedState, this.getCardBlankFlags.bind(this));
    allCardCompleted = blankFlags.every(function(item) {
      return item;
    });
    matchedAnswerText = matchedAnswers.join('、');

    console.log('[challenge-debug] recognition matched', {
      transcript: transcriptText,
      matchedAnswer: matchedAnswerText,
      blankId: matchedEntry ? matchedEntry.id : '',
      blankNumber: matchedEntry ? matchedEntry.blankNumber : 0,
      currentIllustrationUrl: card && card.illustrationUrl ? card.illustrationUrl : ''
    });

    if (refreshedState.totalBlankCount > 0 && refreshedState.completedBlankCount >= refreshedState.totalBlankCount) {
      hintText = '识别到：' + transcriptText + '。' + buildChallengePraise('final', matchedAnswers, newlyCompletedCount, score);
      speechText = hintText;
    } else if (allCardCompleted) {
      hintText = '识别到：' + transcriptText + '。' + buildChallengePraise('card', matchedAnswers, newlyCompletedCount, score);
      speechText = hintText;
    } else {
      hintText = '识别到：' + transcriptText + '。正确答案：' + matchedAnswerText + '。' + pickRandomText([
        '答得很准，继续背下一个空。',
        '很好，这个空已经背对了。',
        '不错，继续保持这个节奏。'
      ], '背得很好，继续保持。');
      speechText = hintText;
    }

    this.setData({
      challengeBlankProgressMap: refreshedState.blankProgressMap,
      challengeCompletedBlankCount: refreshedState.completedBlankCount,
      challengeTotalBlankCount: refreshedState.totalBlankCount,
      challengeProgressMap: refreshedState.keywordProgressMap,
      challengeCompletedKeywordCount: refreshedState.completedKeywordCount,
      challengeTotalKeywordCount: refreshedState.totalKeywordCount,
      challengeRecognitionText: '',
      challengeScore: score
    });
    this.syncCurrentSubject();
    this.setStudyVoiceHint(buildChallengeHintWithMemory(hintText, card));
    this.playChallengeNextAudio();
    this.playSpeechText(speechText || hintText, hintText);

    if (refreshedState.totalBlankCount > 0 && refreshedState.completedBlankCount >= refreshedState.totalBlankCount) {
      this.stopChallengeRecognition();
      this.queueChallengeAutoNext(1600);
      return;
    }

    if (allCardCompleted) {
      this.stopChallengeRecognition();
      this.queueChallengeAutoNext(900);
    }
  },
  startChallengeRecognition() {
    var recognitionId = '';
    var recognition;
    var self = this;
    var progressState;
    var currentCard;
    var pendingBlankCount;

    if (this.data.selectedStudyMode !== 'challenge' || this.data.stage !== 'study') {
      return;
    }

    progressState = this.buildChallengeProgressState(this.data.currentSubject);
    currentCard = this.data.currentCard || this.getCurrentCard(this.data.currentSubject);
    pendingBlankCount = this.getPendingBlankCountForCard(currentCard, progressState);

    if (!this.hasPendingBlanksForCard(currentCard, progressState)) {
      this.stopChallengeRecognition();
      return;
    }

    this.stopChallengeRecognition();

    if (typeof SpeechRecognition === 'function') {
      try {
        recognition = new SpeechRecognition();
        this.challengeRecognitionStopping = false;
        recognition.lang = 'zh-CN';
        recognition.continuous = false;
        recognition.interimResults = false;
        recognition.maxAlternatives = 1;
        recognition.onstart = function() {
          console.log('[challenge-debug] recognition round started', {
            cardId: currentCard && currentCard.id ? currentCard.id : '',
            cardTitle: currentCard && currentCard.title ? currentCard.title : '',
            illustrationUrl: currentCard && currentCard.illustrationUrl ? currentCard.illustrationUrl : '',
            pendingBlankCount: pendingBlankCount
          });
          if (self.data.challengeIntroHintShown) {
            self.setData({
              challengeListening: true
            });
            return;
          }
          self.setData({
            challengeListening: true,
            challengeIntroHintShown: true
          });
          self.setStudyVoiceHint(buildChallengeHintWithMemory('请开始背诵挖空内容', self.data.currentCard));
        };
        recognition.onresult = function(event) {
          var transcript = self.extractRecognitionTranscript(event);
          if (transcript) {
            self.updateChallengeKeywordProgress(transcript);
          }
          try {
            if (recognition && typeof recognition.stop === 'function') {
              recognition.stop();
            }
          } catch (stopError) {
            console.error('recognition round stop failed', stopError);
          }
        };
        recognition.onerror = function() {
          self.setData({
            challengeListening: false
          });
          self.setStudyVoiceHint(buildChallengeHintWithMemory('继续努力，再接再厉', self.data.currentCard));
        };
        recognition.onend = function() {
          if (self.data) {
            self.setData({
              challengeListening: false
            });
          }
          if (self.challengeRecognitionStopping) {
            self.challengeRecognitionStopping = false;
            return;
          }
          if (
            self.data &&
            self.data.stage === 'study' &&
            self.data.selectedStudyMode === 'challenge' &&
            !(self.data.challengeTotalBlankCount > 0 && self.data.challengeCompletedBlankCount >= self.data.challengeTotalBlankCount) &&
            !self.challengeAutoNextTimer &&
            self.hasPendingBlanksForCard(self.data.currentCard, self.buildChallengeProgressState(self.data.currentSubject))
          ) {
            setTimeout(function() {
              if (
                self.data &&
                self.data.stage === 'study' &&
                self.data.selectedStudyMode === 'challenge' &&
                !self.data.challengeListening &&
                !self.challengeAutoNextTimer &&
                self.hasPendingBlanksForCard(self.data.currentCard, self.buildChallengeProgressState(self.data.currentSubject))
              ) {
                self.startChallengeRecognition();
              }
            }, 220);
          }
        };
        recognition.start();
        this.challengeRecognition = recognition;
        return;
      } catch (error) {
        console.error('SpeechRecognition start failed', error);
      }
    }

    if (wx && wx.speech && typeof wx.speech.startRecognition === 'function') {
      try {
        recognitionId = wx.speech.startRecognition() || '';
        console.log('[challenge-debug] wx recognition started', {
          recognitionId: recognitionId,
          cardId: currentCard && currentCard.id ? currentCard.id : '',
          cardTitle: currentCard && currentCard.title ? currentCard.title : '',
          illustrationUrl: currentCard && currentCard.illustrationUrl ? currentCard.illustrationUrl : '',
          pendingBlankCount: pendingBlankCount
        });
        if (recognitionId) {
          this.setData(this.data.challengeIntroHintShown
            ? {
              challengeListening: true
            }
            : {
              challengeListening: true,
              challengeIntroHintShown: true
            });
          if (!this.data.challengeIntroHintShown) {
            this.setStudyVoiceHint(buildChallengeHintWithMemory('请开始背诵挖空内容', this.data.currentCard));
          }
        } else {
          this.setData({
            challengeListening: false
          });
          this.setStudyVoiceHint('当前预览环境未提供语音识别');
        }
        return;
      } catch (recognitionError) {
        console.error('wx.speech.startRecognition failed', recognitionError);
      }
    }

    this.setData({
      challengeListening: false
    });
    this.setStudyVoiceHint('当前预览环境未提供语音识别');
  },
  handleStudyVoiceTap() {
    if (this.data.selectedStudyMode === 'challenge') {
      this.startChallengeRecognition();
      return;
    }
    this.playReadModeVoice();
  }
};
</script>

<page>
  <view class="page">
    <view class="loading-state" ink:if="{{ dataLoading }}">
      <view class="loading-dialog">
        <view class="loading-spinner"></view>
        <text class="loading-title">数据加载中</text>
        <text class="loading-copy">让子弹飞一会儿...</text>
      </view>
    </view>

    <view class="empty-state" ink:elif="{{ !subjects.length }}">
      <text class="empty-title">妙卡</text>
      <text class="empty-copy">当前没有可展示的备考科目。</text>
    </view>

    <view class="stage-menu" ink:elif="{{ stage === 'menu' }}">
      <view class="menu-shell">
        <view class="menu-frame">
          <view class="gallery-arrow menu-arrow-btn" bindtap="handlePrevTap">
            <image class="gallery-arrow-icon gallery-arrow-icon-left" src="../../assets/icons/icon_left.png" mode="aspectFit"></image>
          </view>
          <view class="menu-inner-frame">
            <view class="menu-gallery">
              <view class="gallery-center" bindtap="handleSubjectTap">
                <view class="subject-card">
                  <text class="subject-title">{{ currentSubject.title }}</text>
                  <text class="menu-count">待学习卡片{{ currentSubject.pendingCount }}张</text>
                </view>
              </view>
            </view>
            <view class="menu-mode-actions">
              <view class="mode-btn" bindtap="handleReadModeTap">
                <text class="mode-btn-text">诵读模式</text>
              </view>
              <view class="mode-btn" bindtap="handleChallengeModeTap">
                <text class="mode-btn-text">闯关模式</text>
              </view>
            </view>
          </view>
          <view class="gallery-arrow menu-arrow-btn" bindtap="handleNextTap">
            <image class="gallery-arrow-icon gallery-arrow-icon-right" src="../../assets/icons/icon_right.png" mode="aspectFit"></image>
          </view>
        </view>
      </view>
    </view>

    <view class="stage-mode" ink:elif="{{ stage === 'mode' }}">
      <view class="mode-shell">
        <view class="difficulty-frame">
          <view class="difficulty-options">
            <view class="difficulty-option-item" bindtap="handleReadModeTap">
              <view class="{{ readModeButtonClass }}">
                <view class="difficulty-btn-pixel-layer" ink:if="{{ modeSelectionTab === 'read' }}">
                  <view class="difficulty-pixel-row">
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                    <view class="difficulty-pixel difficulty-pixel-mid"></view>
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                    <view class="difficulty-pixel difficulty-pixel-light"></view>
                  </view>
                  <view class="difficulty-pixel-row difficulty-pixel-row-offset">
                    <view class="difficulty-pixel difficulty-pixel-mid"></view>
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                    <view class="difficulty-pixel difficulty-pixel-light"></view>
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                  </view>
                  <view class="difficulty-pixel-row">
                    <view class="difficulty-pixel difficulty-pixel-light"></view>
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                    <view class="difficulty-pixel difficulty-pixel-mid"></view>
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                  </view>
                  <view class="difficulty-pixel-row difficulty-pixel-row-offset">
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                    <view class="difficulty-pixel difficulty-pixel-light"></view>
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                    <view class="difficulty-pixel difficulty-pixel-mid"></view>
                  </view>
                </view>
                <text class="{{ readModeTextClass }}">诵读模式</text>
              </view>
            </view>
            <view class="difficulty-option-item" bindtap="handleChallengeModeTap">
              <view class="{{ challengeModeButtonClass }}">
                <view class="difficulty-btn-pixel-layer" ink:if="{{ modeSelectionTab === 'challenge' }}">
                  <view class="difficulty-pixel-row">
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                    <view class="difficulty-pixel difficulty-pixel-mid"></view>
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                    <view class="difficulty-pixel difficulty-pixel-light"></view>
                  </view>
                  <view class="difficulty-pixel-row difficulty-pixel-row-offset">
                    <view class="difficulty-pixel difficulty-pixel-mid"></view>
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                    <view class="difficulty-pixel difficulty-pixel-light"></view>
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                  </view>
                  <view class="difficulty-pixel-row">
                    <view class="difficulty-pixel difficulty-pixel-light"></view>
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                    <view class="difficulty-pixel difficulty-pixel-mid"></view>
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                  </view>
                  <view class="difficulty-pixel-row difficulty-pixel-row-offset">
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                    <view class="difficulty-pixel difficulty-pixel-light"></view>
                    <view class="difficulty-pixel difficulty-pixel-strong"></view>
                    <view class="difficulty-pixel difficulty-pixel-mid"></view>
                  </view>
                </view>
                <text class="{{ challengeModeTextClass }}">闯关模式</text>
              </view>
            </view>
          </view>
        </view>
      </view>
    </view>

    <view class="stage-challenge-intro" ink:elif="{{ stage === 'challenge_intro' }}">
      <view class="challenge-intro-card" bindtap="handleChallengeIntroTap">
        <view class="challenge-intro-frame">
          <image
            class="challenge-intro-visual"
            src="../../assets/images/challenge_shuffle_intro.svg"
            mode="aspectFit"
          />
          <view class="challenge-intro-overlay">
            <text class="challenge-intro-title-text">互动洗牌模式 ↻</text>

            <text class="challenge-intro-symbol symbol-1-corner">♡</text>
            <text class="challenge-intro-symbol symbol-2-corner">♢</text>
            <text class="challenge-intro-symbol symbol-3-corner">♣</text>
            <text class="challenge-intro-symbol symbol-4-corner">♠</text>

            <text class="challenge-intro-number number-1">1</text>
            <text class="challenge-intro-number number-2">2</text>
            <text class="challenge-intro-number number-3">3</text>
            <text class="challenge-intro-number number-4">4</text>

            <view class="challenge-intro-step step-1"><text class="challenge-intro-step-text">1</text></view>
            <view class="challenge-intro-step step-2"><text class="challenge-intro-step-text">2</text></view>
            <view class="challenge-intro-step step-3"><text class="challenge-intro-step-text">3</text></view>
            <view class="challenge-intro-step step-4"><text class="challenge-intro-step-text">4</text></view>

            <text class="challenge-intro-prompt-text">请左右晃动完成洗牌</text>
            <text class="challenge-intro-phone-arrow-text phone-arrow-left">↶</text>
            <text class="challenge-intro-phone-arrow-text phone-arrow-right">↷</text>
          </view>
        </view>
      </view>
    </view>

    <view class="stage-result" ink:elif="{{ stage === 'result' }}">
      <view class="result-card">
        <view class="result-header">
          <text class="result-title">{{ resultHeadline }}</text>
          <view class="result-badge">
            <text class="result-badge-text">{{ resultCorrectPercent }}%</text>
          </view>
        </view>
        <view class="result-main">
          <view class="result-score-panel">
            <text class="result-score-label">本轮得分</text>
            <view class="result-score-row">
              <text class="result-score">{{ challengeScore }}</text>
              <text class="result-score-total">/ {{ resultTotalCount }}</text>
            </view>
            <text class="result-score-caption">{{ resultScoreMessage }}</text>
          </view>
          <view class="result-metrics">
            <view class="result-category-item" ink:for="{{ resultCategoryStats }}" ink:key="id">
              <view class="result-category-top">
                <text class="result-category-label">{{ item.label }}</text>
                <text class="result-category-percent">{{ item.percent }}%</text>
              </view>
              <view class="result-category-track">
                <view class="result-category-fill" style="{{ item.fillStyle }}"></view>
              </view>
              <text class="result-category-caption">{{ item.completed }} / {{ item.total }}</text>
            </view>
          </view>
        </view>
        <view class="result-ai-panel">
          <view class="result-ai-header">
            <text class="result-ai-title">AI解读</text>
            <text class="result-ai-status" ink:if="{{ resultAiLoading }}">分析中...</text>
            <text class="result-ai-status" ink:else>上下键翻页</text>
          </view>
          <text class="result-ai-text">{{ resultSummary }}</text>
        </view>
        <view class="result-pagination">
          <view class="result-page-dot-slot" ink:for="{{ resultAdviceDots }}" ink:key="id">
            <view class="result-page-dot result-page-dot-active" ink:if="{{ item.active }}"></view>
            <view class="result-page-dot" ink:else></view>
          </view>
        </view>
      </view>
    </view>

    <view class="study-shell" ink:else>
      <view class="study-card">
        <view class="study-top-grid">
          <view class="study-main-column">
            <view class="study-text-panel">
              <view class="study-head-row">
                <text class="study-title">{{ currentSubject.title }}</text>
                <view class="study-page-counter">
                  <text class="study-page-counter-text">{{ studyPageCounterLabel }}</text>
                </view>
              </view>
              <scroll-view class="study-text-scroll" scroll-y="true">
                <view class="study-text-body">
                  <text class="study-copy study-copy-card-index" ink:if="{{ studyCardTitle }}">{{ studyCardTitle }}</text>
                  <text class="study-copy" ink:if="{{ studyScene }}">{{ studyScene }}</text>
                  <text class="study-copy" ink:if="{{ studyContent }}">{{ studyContent }}</text>
                  <text class="study-copy" ink:if="{{ studyMemoryHint }}">{{ studyMemoryHint }}</text>
                  <text class="study-copy" ink:if="{{ studyAiInsight }}">{{ studyAiInsight }}</text>
                </view>
              </scroll-view>
            </view>
          </view>
          <view class="study-side-column">
            <view class="study-keyword-bar">
              <text class="study-keyword-label">关键词</text>
              <view class="study-keyword-chip">
                <view class="study-keyword-chip-text">
                  <text class="study-keyword-chip-value">{{ currentCard.memoryKey }}</text>
                </view>
              </view>
              <view class="study-keyword-chip">
                <view class="study-keyword-chip-text">
                  <text class="study-keyword-chip-value">{{ currentCard.tagTwo }}</text>
                </view>
              </view>
              <view class="study-keyword-chip">
                <view class="study-keyword-chip-text">
                  <text class="study-keyword-chip-value">{{ currentCard.tagThree }}</text>
                </view>
              </view>
            </view>
            <view class="study-visual-wrap">
              <image
                class="study-visual-image"
                src="{{ currentCard.illustrationUrl }}"
                mode="aspectFill"
                bindload="handleStudyImageLoad"
                binderror="handleStudyImageError"
              ></image>
              <view class="study-visual-loading study-visual-loading-failed" ink:if="{{ studyImageLoadFailed }}">
                <text class="study-visual-loading-text">图片加载失败，正在重试网络...</text>
              </view>
            </view>
          </view>
        </view>
        <view class="study-bottom-stack">
          <view class="study-voice-wrap">
            <view class="study-voice-bar" bindtap="handleStudyVoiceTap">
              <image class="study-voice-icon" src="../../assets/images/icon_smile.png" mode="aspectFit"></image>
              <text class="study-voice-text">{{ studyVoiceHint }}</text>
            </view>
          </view>
          <view class="challenge-score-strip challenge-score-strip-voice" ink:if="{{ selectedStudyMode === 'challenge' }}">
            <view class="challenge-score-item" ink:for="{{ challengeKeywordItems }}" ink:key="id">
              <view class="challenge-score-fill-window" style="{{ item.fillStyle }}" ink:if="{{ item.showFill }}">
                <view class="challenge-score-fill-bar"></view>
              </view>
              <image class="challenge-score-outline" src="../../assets/icons/heart_outline.svg" mode="aspectFit"></image>
            </view>
          </view>
          <view class="study-pagination">
            <view class="study-page-dot-slot" ink:for="{{ studyIndicatorDots }}" ink:key="id">
              <view class="study-page-dot study-page-dot-active" ink:if="{{ item.active }}"></view>
              <view class="study-page-dot" ink:else></view>
            </view>
          </view>
        </view>
      </view>
    </view>
  </view>
</page>

<style>
.page {
  width: 480px;
  height: 352px;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 12px;
  box-sizing: border-box;
  background-color: transparent;
}

.loading-state,
.empty-state,
.stage-menu,
.stage-mode,
.stage-challenge-intro,
.stage-result,
.study-shell {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.loading-dialog {
  width: 220px;
  min-height: 144px;
  border: 2px solid rgba(38, 92, 59, 0.92);
  border-radius: 26px;
  box-sizing: border-box;
  background-color: rgba(5, 12, 8, 0.9);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 14px;
  box-shadow: inset 0 0 0 1px rgba(10, 32, 18, 0.72), 0 0 18px rgba(26, 92, 53, 0.12);
}

.loading-spinner {
  width: 28px;
  height: 28px;
  border: 3px solid rgba(58, 120, 78, 0.45);
  border-top-color: rgba(101, 224, 136, 0.98);
  border-radius: 50%;
  box-sizing: border-box;
  animation: loading-spin 0.9s linear infinite;
}

.mode-shell {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.menu-gallery {
  width: 100%;
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: center;
  gap: 20px;
}

.menu-shell {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  box-sizing: border-box;
}

.menu-frame {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: center;
  gap: 22px;
  padding: 20px 36px;
  box-sizing: border-box;
  border: 2px solid rgba(38, 92, 59, 0.92);
  border-radius: 36px;
  background-color: transparent;
  box-shadow: inset 0 0 0 1px rgba(8, 24, 14, 0.76);
}

.menu-inner-frame {
  flex: 1;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 20px 18px;
  box-sizing: border-box;
  border-radius: 30px;
  background-color: transparent;
}

.menu-count {
  color: rgba(214, 235, 220, 0.84);
  font-size: 13px;
  line-height: 18px;
  position: absolute;
  left: 0;
  right: 0;
  bottom: 16px;
  text-align: center;
}

.gallery-arrow,
.interaction-arrow {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.menu-arrow-btn {
  flex-shrink: 0;
  background-color: transparent;
}

.gallery-arrow-icon {
  width: 40px;
  height: 40px;
}

.gallery-arrow-icon-left {
  margin-left: 15px;
}

.gallery-arrow-icon-right {
  margin-right: 15px;
}

.gallery-center {
  display: flex;
  align-items: center;
  justify-content: center;
}

.menu-mode-actions {
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: center;
  gap: 14px;
  margin-top: 30px;
}

.subject-card {
  width: 300px;
  height: 140px;
  border: 2px solid rgba(38, 92, 59, 0.92);
  border-radius: 28px;
  background-color: rgba(3, 10, 6, 0.42);
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  padding: 18px 22px 40px;
  box-sizing: border-box;
  box-shadow: inset 0 0 0 1px rgba(10, 32, 18, 0.72), 0 0 18px rgba(26, 92, 53, 0.1);
}

.subject-title,
.mode-subject-title,
.study-title,
.result-title {
  color: rgba(245, 250, 246, 0.96);
  letter-spacing: 1px;
}

.subject-title {
  font-size: 24px;
  font-weight: bold;
  text-align: center;
  line-height: 30px;
}

.mode-card {
  width: 270px;
  height: 134px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 14px;
  border: 2px solid rgba(38, 92, 59, 0.92);
  border-radius: 28px;
  background-color: rgba(3, 10, 6, 0.42);
  box-shadow: inset 0 0 0 1px rgba(10, 32, 18, 0.72), 0 0 18px rgba(26, 92, 53, 0.1);
}

.mode-subject-title {
  font-size: 24px;
  font-weight: bold;
  text-align: center;
  line-height: 30px;
}

.mode-options {
  display: flex;
  flex-direction: row;
  gap: 14px;
}

.mode-btn {
  min-width: 114px;
  height: 40px;
  padding: 0 18px;
  box-sizing: border-box;
  border: 2px solid rgba(38, 92, 59, 0.9);
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: rgba(4, 12, 7, 0.32);
}

.mode-btn-text {
  color: rgba(236, 244, 238, 0.92);
  font-size: 15px;
}

.difficulty-frame {
  width: 100%;
  height: 100%;
  padding: 22px 26px;
  box-sizing: border-box;
  border: 2px solid rgba(38, 92, 59, 0.92);
  border-radius: 36px;
  background-color: transparent;
  box-shadow: inset 0 0 0 1px rgba(8, 24, 14, 0.76);
  display: flex;
  align-items: center;
  justify-content: center;
}

.difficulty-options {
  width: 100%;
  display: flex;
  flex-direction: row;
  align-items: flex-start;
  justify-content: center;
  gap: 94px;
}

.difficulty-option-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
}

.difficulty-btn {
  min-width: 124px;
  height: 124px;
  padding: 0 18px;
  border: 2px solid rgba(53, 154, 79, 0.88);
  border-radius: 24px;
  background-color: rgba(7, 20, 12, 0.2);
  display: flex;
  align-items: center;
  justify-content: center;
  box-sizing: border-box;
  position: relative;
  overflow: hidden;
}

.difficulty-btn-square {
  width: 124px;
}

.difficulty-btn-active {
  border-color: rgba(80, 210, 118, 0.98);
  background-color: rgba(4, 14, 8, 0.92);
}

.difficulty-btn-pixel-layer {
  position: absolute;
  left: 12px;
  top: 12px;
  right: 12px;
  bottom: 12px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 8px;
  opacity: 0.9;
  z-index: 0;
}

.difficulty-pixel-row {
  width: 100%;
  display: flex;
  flex-direction: row;
  justify-content: space-between;
}

.difficulty-pixel-row-offset {
  padding: 0 10px;
  box-sizing: border-box;
}

.difficulty-pixel {
  width: 18px;
  height: 18px;
  border-radius: 2px;
  background-color: rgba(56, 160, 86, 0.72);
}

.difficulty-pixel-strong {
  background-color: rgba(88, 214, 124, 0.88);
}

.difficulty-pixel-mid {
  background-color: rgba(62, 185, 96, 0.78);
}

.difficulty-pixel-light {
  background-color: rgba(35, 124, 63, 0.7);
}

.difficulty-btn-text {
  color: rgba(236, 244, 238, 0.92);
  font-size: 20px;
  line-height: 24px;
  text-align: center;
  position: relative;
  z-index: 1;
}

.difficulty-btn-text-active {
  color: rgba(88, 214, 124, 0.98);
  font-weight: bold;
}

.challenge-intro-card,

.result-card,
.study-card,
.empty-state {
  height: 100%;
  border: 2px solid rgba(38, 92, 59, 0.88);
  border-radius: 28px;
  padding: 24px;
  box-sizing: border-box;
  background-color: rgba(3, 10, 6, 0.34);
  box-shadow: inset 0 0 0 1px rgba(10, 32, 18, 0.68);
}

.challenge-intro-card {
  display: flex;
  align-items: center;
  width: 100%;
  height: 100%;
  justify-content: center;
  padding: 0;
  border: 0;
  border-radius: 0;
  background-color: transparent;
  box-shadow: none;
  overflow: hidden;
}

.challenge-intro-frame {
  width: 440px;
  height: 300px;
  max-width: 100%;
  position: relative;
  flex-shrink: 0;
}

.challenge-intro-visual {
  position: absolute;
  left: 0;
  top: 0;
  width: 100%;
  height: 100%;
  z-index: 1;
}

.challenge-intro-overlay {
  position: absolute;
  inset: 0;
  z-index: 2;
}

.challenge-intro-title-text,
.challenge-intro-number,
.challenge-intro-step,
.challenge-intro-prompt-text,
.challenge-intro-phone-arrow-text {
  position: absolute;
  color: rgba(248, 252, 249, 0.98);
  font-family: Microsoft YaHei, PingFang SC, Heiti SC, SimHei, Arial, sans-serif;
  z-index: 3;
}

.challenge-intro-title-text {
  top: 14px;
  left: 0;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  font-size: 24px;
  line-height: 30px;
  font-weight: 900;
}

.challenge-intro-symbol {
  position: absolute;
  color: rgba(248, 252, 249, 0.42);
  font-size: 24px;
  line-height: 24px;
  font-weight: 900;
  font-family: Microsoft YaHei, PingFang SC, Heiti SC, SimHei, Arial, sans-serif;
  z-index: 3;
}

.symbol-1-corner {
  left: 114px;
  top: 78px;
}

.symbol-2-corner {
  left: 186px;
  top: 78px;
}

.symbol-3-corner {
  left: 258px;
  top: 78px;
}

.symbol-4-corner {
  left: 330px;
  top: 78px;
}

.challenge-intro-number {
  width: 44px;
  height: 46px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 46px;
  line-height: 46px;
  font-weight: 900;
  text-align: center;
  color: rgba(248, 252, 249, 0.98);
}

.number-1 {
  left: 102px;
  top: 110px;
}

.number-2 {
  left: 178px;
  top: 110px;
}

.number-3 {
  left: 250px;
  top: 110px;
}

.number-4 {
  left: 322px;
  top: 110px;
}

.challenge-intro-step {
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  border-radius: 50%;
  background-color: rgba(23, 54, 40, 0.92);
}

.challenge-intro-step-text {
  color: rgba(248, 252, 249, 0.98);
  font-size: 13px;
  line-height: 13px;
  font-weight: 900;
  font-family: Microsoft YaHei, PingFang SC, Heiti SC, SimHei, Arial, sans-serif;
}

.step-1 {
  left: 102px;
  top: 205px;
}

.step-2 {
  left: 174px;
  top: 205px;
}

.step-3 {
  left: 246px;
  top: 205px;
}

.step-4 {
  left: 318px;
  top: 205px;
}

.challenge-intro-prompt-text {
  left: 98px;
  top: 251px;
  width: 220px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  font-size: 17px;
  line-height: 20px;
  font-weight: 900;
}

.challenge-intro-phone-arrow-text {
  font-size: 12px;
  line-height: 12px;
  font-weight: 900;
}

.phone-arrow-left {
  left: 294px;
  top: 247px;
}

.phone-arrow-right {
  left: 320px;
  top: 267px;
}

.result-card {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  justify-content: flex-start;
  gap: 10px;
  padding: 16px 18px 12px;
  overflow: hidden;
}

.result-title {
  font-size: 22px;
  line-height: 28px;
  font-weight: bold;
}

.result-header {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.result-badge {
  min-width: 66px;
  height: 24px;
  padding: 0 10px;
  box-sizing: border-box;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(109, 255, 170, 0.86);
  border-radius: 12px 4px 12px 4px;
  background-color: rgba(12, 40, 26, 0.82);
  box-shadow: 0 0 0 1px rgba(29, 98, 61, 0.55), 0 0 8px rgba(67, 255, 149, 0.12);
}

.result-badge-text {
  color: rgba(182, 255, 214, 0.96);
  font-size: 11px;
  line-height: 12px;
  font-weight: bold;
  letter-spacing: 0.8px;
}

.result-main {
  width: 100%;
  display: flex;
  align-items: stretch;
  justify-content: space-between;
  gap: 12px;
}

.result-score-panel {
  flex: 1 1 0;
  min-width: 0;
  border: 2px solid rgba(53, 154, 79, 0.88);
  border-radius: 24px;
  padding: 14px 14px 12px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: center;
  gap: 4px;
  background-color: rgba(5, 12, 8, 0.24);
}

.result-score-label {
  color: rgba(193, 214, 200, 0.74);
  font-size: 10px;
  line-height: 12px;
}

.result-score-row {
  width: 100%;
  display: flex;
  align-items: flex-end;
  justify-content: flex-start;
  gap: 4px;
}

.result-score {
  color: rgba(232, 246, 236, 0.98);
  font-size: 44px;
  line-height: 44px;
  font-weight: bold;
  letter-spacing: 1px;
}

.result-score-total {
  color: rgba(201, 220, 208, 0.78);
  font-size: 14px;
  line-height: 18px;
  margin-bottom: 5px;
}

.result-score-caption {
  color: rgba(223, 233, 226, 0.84);
  font-size: 11px;
  line-height: 14px;
}

.result-metrics {
  width: 176px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  justify-content: flex-start;
  gap: 8px;
}

.result-category-item {
  width: 100%;
  border: 1px solid rgba(53, 154, 79, 0.72);
  border-radius: 16px;
  padding: 8px 10px 7px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  justify-content: flex-start;
  gap: 4px;
  background-color: rgba(5, 12, 8, 0.22);
}

.result-category-top {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 6px;
}

.result-category-label {
  color: rgba(223, 233, 226, 0.88);
  font-size: 11px;
  line-height: 14px;
  font-weight: bold;
}

.result-category-percent {
  color: rgba(182, 255, 214, 0.96);
  font-size: 12px;
  line-height: 14px;
  font-weight: bold;
}

.result-category-track {
  width: 100%;
  height: 8px;
  border-radius: 999px;
  box-sizing: border-box;
  background-color: rgba(16, 37, 24, 0.82);
  overflow: hidden;
}

.result-category-fill {
  height: 100%;
  border-radius: 999px;
  background-color: rgba(109, 255, 170, 0.92);
  box-shadow: 0 0 6px rgba(109, 255, 170, 0.2);
}

.result-category-caption {
  color: rgba(197, 214, 203, 0.72);
  font-size: 10px;
  line-height: 12px;
}

.result-ai-panel {
  width: 100%;
  flex: 1 1 auto;
  min-height: 0;
  border: 2px solid rgba(53, 154, 79, 0.82);
  border-radius: 22px;
  padding: 10px 12px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  justify-content: flex-start;
  gap: 6px;
  background-color: rgba(5, 12, 8, 0.18);
  overflow: hidden;
}

.result-ai-header {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.result-ai-title {
  color: rgba(182, 255, 214, 0.96);
  font-size: 12px;
  line-height: 14px;
  font-weight: bold;
}

.result-ai-status {
  color: rgba(197, 214, 203, 0.72);
  font-size: 10px;
  line-height: 12px;
}

.result-ai-text,
.empty-copy {
  color: rgba(223, 233, 226, 0.84);
}

.result-pagination {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  height: 18px;
  flex-shrink: 0;
  overflow: visible;
}

.result-page-dot-slot {
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.result-page-dot {
  width: 10px;
  height: 10px;
  border: 2px solid rgba(216, 231, 220, 0.88);
  box-sizing: border-box;
  transform: rotate(45deg);
  background-color: transparent;
  transition: background-color 0.18s ease, border-color 0.18s ease, opacity 0.18s ease;
  border-radius: 1px;
  flex-shrink: 0;
  display: block;
  opacity: 0.92;
}

.result-page-dot-active {
  border-color: rgba(236, 245, 239, 0.98);
  background-color: rgba(236, 245, 239, 0.96);
  box-shadow: 0 0 0 1px rgba(236, 245, 239, 0.16);
  opacity: 1;
}

.study-shell {
  justify-content: center;
}

.study-card {
  width: 100%;
  height: 100%;
  padding: 14px 20px 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  gap: 4px;
  overflow: hidden;
}

.study-top-grid {
  width: 100%;
  display: flex;
  flex-direction: row;
  align-items: flex-start;
  justify-content: center;
  gap: 10px;
  flex: 1 1 auto;
  min-height: 0;
  overflow: hidden;
}

.study-main-column {
  flex: 1 1 0;
  min-width: 0;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  justify-content: flex-start;
}

.study-text-panel {
  width: 100%;
  height: 100%;
  min-height: 0;
  border: 2px solid rgba(53, 154, 79, 0.88);
  border-radius: 26px;
  padding: 11px 14px 8px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
  gap: 3px;
  background-color: rgba(5, 12, 8, 0.24);
  overflow: hidden;
}

.study-head-row {
  width: 100%;
  min-height: 22px;
  display: flex;
  flex-direction: row;
  align-items: flex-start;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 2px;
}

.study-page-counter {
  min-width: 64px;
  height: 18px;
  padding: 0 8px;
  box-sizing: border-box;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(109, 255, 170, 0.86);
  border-radius: 9px 3px 9px 3px;
  background-color: rgba(12, 40, 26, 0.82);
  box-shadow: 0 0 0 1px rgba(29, 98, 61, 0.55), 0 0 8px rgba(67, 255, 149, 0.12);
  flex-shrink: 0;
  margin-top: 1px;
}

.study-page-counter-text {
  color: rgba(182, 255, 214, 0.96);
  font-size: 9px;
  line-height: 11px;
  font-weight: bold;
  letter-spacing: 0.8px;
  text-align: center;
  text-shadow: 0 0 4px rgba(83, 255, 180, 0.22);
}

.study-text-scroll {
  width: 100%;
  flex: 1 1 auto;
  min-height: 0;
}

.study-text-body {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding-right: 4px;
}

.study-side-column {
  width: 188px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  gap: 6px;
  align-items: stretch;
  min-height: 0;
}

.study-keyword-bar {
  width: 100%;
  min-height: 40px;
  border: 2px solid rgba(53, 154, 79, 0.88);
  border-radius: 16px;
  padding: 4px 8px;
  box-sizing: border-box;
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: space-between;
  gap: 4px;
  background-color: rgba(5, 12, 8, 0.18);
  overflow: hidden;
}

.study-keyword-label {
  color: rgba(216, 231, 220, 0.86);
  font-size: 11px;
  line-height: 14px;
  min-width: 36px;
  text-align: center;
  flex-shrink: 0;
}

.study-keyword-chip {
  min-width: 34px;
  height: 28px;
  padding: 0 4px;
  border: 2px solid rgba(125, 147, 132, 0.92);
  border-radius: 10px;
  box-sizing: border-box;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  color: rgba(239, 245, 241, 0.96);
  font-size: 10px;
  line-height: 12px;
  background-color: rgba(255, 255, 255, 0.02);
  flex-shrink: 1;
  flex-grow: 1;
  min-height: 0;
  overflow: hidden;
  white-space: nowrap;
  word-break: keep-all;
}

.study-keyword-chip-text {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 0;
  overflow: hidden;
}

.study-keyword-chip-value {
  width: 100%;
  text-align: center;
  color: rgba(239, 245, 241, 0.96);
  font-size: 10px;
  line-height: 12px;
  white-space: nowrap;
  word-break: keep-all;
  overflow: hidden;
}

.study-visual-wrap {
  width: 100%;
  height: 175px;
  position: relative;
  flex-shrink: 0;
  border-radius: 24px;
  overflow: hidden;
  background-color: rgba(8, 16, 12, 0.88);
}

.study-visual-image {
  width: 100%;
  height: 100%;
  border-radius: 24px;
  background-color: transparent;
}

.study-visual-loading {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  background-color: rgba(8, 16, 12, 0.88);
}

.study-visual-loading-failed {
  gap: 0;
  padding: 0 16px;
  box-sizing: border-box;
}

.study-visual-loading-text {
  color: rgba(214, 235, 220, 0.9);
  font-size: 11px;
  line-height: 15px;
  text-align: center;
}

.challenge-score-strip {
  width: 100%;
  min-height: 30px;
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: flex-start;
  gap: 8px;
  padding: 0 2px;
  box-sizing: border-box;
}

.challenge-score-strip-voice {
  justify-content: flex-end;
  width: 100%;
  min-height: 24px;
  padding: 0 6px 0 0;
  margin-top: 10px;
}

.challenge-score-item {
  width: 24px;
  height: 24px;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.challenge-score-fill-window {
  position: absolute;
  left: 5px;
  bottom: 4px;
  width: 14px;
  overflow: hidden;
  z-index: 1;
  border-radius: 6px 6px 4px 4px;
}

.challenge-score-fill-bar {
  position: absolute;
  left: 0;
  bottom: 0;
  width: 100%;
  height: 100%;
  border-radius: 6px 6px 4px 4px;
  background: linear-gradient(180deg, rgba(122, 255, 180, 0.98) 0%, rgba(56, 197, 112, 0.96) 100%);
}

.challenge-score-outline {
  position: relative;
  z-index: 2;
  width: 24px;
  height: 24px;
}

.study-title {
  font-size: 17px;
  font-weight: bold;
  line-height: 18px;
  margin-bottom: 0;
  flex: 1 1 auto;
  min-width: 0;
}

.study-copy-card-index {
  color: rgba(202, 220, 208, 0.72);
  margin-bottom: 2px;
}

.study-copy,
.result-ai-text,
.empty-copy {
  font-size: 10px;
  line-height: 13px;
  color: rgba(223, 233, 226, 0.84);
  word-break: break-all;
  white-space: pre-wrap;
}

.study-voice-bar {
  width: 100%;
  height: 36px;
  border: 1px solid rgba(58, 158, 92, 0.72);
  border-radius: 8px;
  padding: 0 10px;
  box-sizing: border-box;
  color: rgba(232, 241, 234, 0.94);
  font-size: 13px;
  line-height: 16px;
  text-align: left;
  background-color: rgba(6, 16, 10, 0.96);
  box-shadow: inset 0 0 0 1px rgba(14, 34, 20, 0.42);
  align-self: stretch;
  margin-top: 0;
  display: flex;
  align-items: center;
  justify-content: flex-start;
  gap: 8px;
  overflow: hidden;
}

.study-voice-wrap {
  width: 100%;
  margin-top: 5px;
}

.study-voice-icon {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
}

.study-voice-text {
  flex: 1 1 auto;
  min-width: 0;
  color: rgba(232, 241, 234, 0.94);
  font-size: 13px;
  line-height: 16px;
  text-align: left;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.study-bottom-stack {
  width: 100%;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  justify-content: flex-end;
  gap: 0;
  margin-top: auto;
  flex-shrink: 0;
  box-sizing: border-box;
}

.study-pagination {
  width: 100%;
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: center;
  gap: 12px;
  margin-top: 4px;
  height: 22px;
  min-height: 22px;
  padding-top: 0;
  padding-bottom: 0;
  box-sizing: border-box;
  flex-shrink: 0;
  overflow: visible;
  position: relative;
  z-index: 2;
}

.study-page-dot-slot {
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.study-page-dot {
  width: 10px;
  height: 10px;
  border: 2px solid rgba(216, 231, 220, 0.88);
  box-sizing: border-box;
  transform: rotate(45deg);
  background-color: transparent;
  transition: background-color 0.18s ease, border-color 0.18s ease, opacity 0.18s ease;
  opacity: 0.92;
  border-radius: 1px;
  flex-shrink: 0;
  display: block;
}

.study-page-dot-active {
  border-color: rgba(236, 245, 239, 0.98);
  background-color: rgba(236, 245, 239, 0.96);
  box-shadow: 0 0 0 1px rgba(236, 245, 239, 0.16);
  opacity: 1;
}

.empty-state {
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.loading-title,
.empty-title {
  color: rgba(244, 250, 246, 0.94);
  font-size: 22px;
  line-height: 28px;
}

.loading-copy {
  color: rgba(198, 221, 205, 0.82);
  font-size: 13px;
  line-height: 18px;
  text-align: center;
}

@keyframes loading-spin {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}

@keyframes study-voice-marquee {
  0% {
    transform: translateX(0);
  }
  100% {
    transform: translateX(-100%);
  }
}
</style>
