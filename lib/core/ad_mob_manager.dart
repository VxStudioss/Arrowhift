import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobManager {
  // Singleton pattern so the same manager instance is shared everywhere
  static final AdMobManager _instance = AdMobManager._internal();
  factory AdMobManager() => _instance;
  AdMobManager._internal();

  // Test Ad Unit IDs (Replace with your live IDs after making your console account)
  final String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  final String _interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  RewardedAd? _rewardedAd;
  bool _isRewardedLoaded = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoaded = false;

  /// Call this once in main.dart inside your main() method
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    loadRewardedAd();
    loadInterstitialAd();
  }

  // ==========================================
  // REWARDED AD LOGIC (For Revive & Continue)
  // ==========================================

  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoaded = true;
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isRewardedLoaded = false;
              loadRewardedAd(); // Preload next
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isRewardedLoaded = false;
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isRewardedLoaded = false;
          debugPrint('RewardedAd failed to load: $error');
        },
      ),
    );
  }

  void showRewardedAd({required VoidCallback onRewardEarned, required VoidCallback onAdClosed}) {
    if (_isRewardedLoaded && _rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          onRewardEarned();
        },
      );
      // Ensure local state updates when ad finishes running
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isRewardedLoaded = false;
          loadRewardedAd();
          onAdClosed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isRewardedLoaded = false;
          loadRewardedAd();
          onAdClosed();
        },
      );
    } else {
      debugPrint('Rewarded ad not ready yet.');
      onRewardEarned(); // Fallback: grant reward anyway or show dialog
      onAdClosed();
    }
  }

  // ==========================================
  // INTERSTITIAL AD LOGIC (Between Levels)
  // ==========================================

  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      // FIX HERE: Changed from 'interstitialAdLoadCallback' to 'adLoadCallback'
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoaded = true;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialLoaded = false;
              loadInterstitialAd(); // Preload next
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isInterstitialLoaded = false;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoaded = false;
          debugPrint('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  void showInterstitialAd({required VoidCallback onAdClosed}) {
    if (_isInterstitialLoaded && _interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isInterstitialLoaded = false;
          loadInterstitialAd();
          onAdClosed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isInterstitialLoaded = false;
          loadInterstitialAd();
          onAdClosed();
        },
      );
    } else {
      onAdClosed(); // If ad fails to display, seamlessly skip to next level
    }
  }
}
