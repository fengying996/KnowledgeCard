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
    .replace(/[，。！？、；：,.!?;:"'"'''（）()【】\[\]\-]/g, '')
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
    .replace(/[，。！？、；：,.!?;:"'"'''（）()【】\[\]\-]/g, '');
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
  generateResultAiAnalysis(resultState) {
    var self = this;
    var fallbackPages = this.buildLocalResultAdvicePages(resultState);
    var categoryText = (resultState.categoryStats || []).map(function(item) {
      return item.label + item.percent + '%';
    }).join('，');
    var missedText = resultState.missedKeywords && resultState.missedKeywords.length
      ? resultState.missedKeywords.join('、')
      : '无明显遗漏关键词';
    var requestId = (this.resultAnalysisRequestId || 0) + 1;

    this.resultAnalysisRequestId = requestId;
    this.setData({
      resultAiLoading: true,
      resultAdvicePages: fallbackPages,
      resultAdvicePageIndex: 0,
      resultAdviceDots: createResultAdviceDots(fallbackPages.length, 0),
      resultSummary: fallbackPages[0] || ''
    });

    LanguageModel.availability().then(function(availability) {
      if (availability !== 'available') {
        throw new Error('LanguageModel unavailable');
      }

      self.stopResultAiAnalysis(true);

      return LanguageModel.create({
        initialPrompts: [
          {
            role: 'system',
            content: '你是妙卡的中文学习教练。请根据学习结果输出4段简短背诵建议。每段18到32字，不要编号，不要markdown，只返回4段文本，用||分隔。'
          }
        ]
      });
    }).then(function(session) {
      self.resultAnalysisSession = session;

      return session.prompt(
        '科目：' + (self.data.currentSubject.title || '当前科目') +
        '；总分：' + resultState.score +
        '；总完成率：' + resultState.correctPercent + '%' +
        '；分类完成度：' + categoryText +
        '；待强化关键词：' + missedText +
        '；请给出4段具体背诵建议。'
      );
    }).then(function(response) {
      var pages = self.normalizeResultAdvicePages(response, fallbackPages);

      if (self.resultAnalysisRequestId !== requestId || !self.data || self.data.stage !== 'result') {
        return;
      }

      self.setData({
        resultAiLoading: false,
        resultAdvicePages: pages,
        resultAdvicePageIndex: 0,
        resultAdviceDots: createResultAdviceDots(pages.length, 0),
        resultSummary: pages[0] || ''
      });
    }).catch(function(error) {
      console.error('generate result ai analysis failed', error);

      if (self.resultAnalysisRequestId !== requestId || !self.data || self.data.stage !== 'result') {
        return;
      }

      self.setData({
        resultAiLoading: false,
        resultAdvicePages: fallbackPages,
        resultAdvicePageIndex: 0,
        resultAdviceDots: createResultAdviceDots(fallbackPages.length, 0),
        resultSummary: fallbackPages[0] || ''
      });
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