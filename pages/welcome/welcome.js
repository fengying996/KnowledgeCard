import wx from 'wx';

export default {
  onLoad() {
    var self = this;

    this.isNavigating = false;

    this.welcomeTimer = setTimeout(function() {
      self.goToIndex();
    }, 5000);
  },
  onUnload() {
    if (this.welcomeTimer) {
      clearTimeout(this.welcomeTimer);
      this.welcomeTimer = null;
    }
    if (this.navigationUnlockTimer) {
      clearTimeout(this.navigationUnlockTimer);
      this.navigationUnlockTimer = null;
    }
  },
  goToIndex() {
    var self = this;
    var targetUrl = '/pages/index/index?entry=menu';

    if (this.isNavigating) {
      return;
    }

    this.isNavigating = true;

    if (this.welcomeTimer) {
      clearTimeout(this.welcomeTimer);
      this.welcomeTimer = null;
    }

    if (this.navigationUnlockTimer) {
      clearTimeout(this.navigationUnlockTimer);
      this.navigationUnlockTimer = null;
    }

    wx.redirectTo({
      url: targetUrl,
      fail: function(error) {
        console.error('redirectTo index failed', error);
        self.isNavigating = false;
      },
      complete: function() {
        self.navigationUnlockTimer = setTimeout(function() {
          self.navigationUnlockTimer = null;
          if (self && self.isNavigating) {
            self.isNavigating = false;
          }
        }, 1200);
      }
    });
  },
  handleWelcomeTap() {
    this.goToIndex();
  },
  onKeyDown(event) {
    var code = event && event.code;
    var text = '';

    if (code) {
      text = String(code).toUpperCase();
    } else if (event && event.key) {
      text = String(event.key).toUpperCase();
    } else if (event && event.action) {
      text = String(event.action).toUpperCase();
    }

    if (
      code === 23 ||
      code === 66 ||
      text.indexOf('ENTER') !== -1 ||
      text.indexOf('OK') !== -1 ||
      text.indexOf('RIGHT') !== -1 ||
      text.indexOf('NEXT') !== -1
    ) {
      this.goToIndex();
    }
  }
};
