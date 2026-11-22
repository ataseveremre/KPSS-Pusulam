import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class AdManager {
  // Google'ın Resmi Test Kimlikleri (Android)
  static const String _bannerTestId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _interstitialTestId = 'ca-app-pub-3940256099942544/1033173712';

  // Senin Gerçek Reklam Kimliklerin
  static const String _bannerAdId = 'ca-app-pub-3828685926389916/5646105813';
  static const String _interstitialAdId = 'ca-app-pub-3828685926389916/8753683139';

  static InterstitialAd? _interstitialAd;

  /// Geçiş reklamını önceden yükler (Test başlamadan çağrılmalı)
  static void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          debugPrint('Geçiş reklamı hazır (Yüklendi).');
        },
        onAdFailedToLoad: (err) {
          _interstitialAd = null;
          debugPrint('Geçiş reklamı yüklenemedi: $err');
        },
      ),
    );
  }

  /// Reklam yüklüyse anında gösterir, değilse yüklemeyi dener
  static void showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null; // Gösterildiği için temizle
      loadInterstitialAd(); // Bir sonraki test için şimdiden yüklemeye başla
    } else {
      debugPrint('Reklam henüz hazır değil, tekrar yükleniyor...');
      loadInterstitialAd();
    }
  }

  /// Banner reklam kimliğini döndürür (Debug modunda test kimliğini verir)
  static String get bannerAdUnitId {
    if (kDebugMode) {
      return _bannerTestId;
    }
    if (Platform.isAndroid) {
      return _bannerAdId;
    }
    throw UnsupportedError("Desteklenmeyen platform");
  }

  /// Geçiş reklamı kimliğini döndürür (Debug modunda test kimliğini verir)
  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return _interstitialTestId;
    }
    if (Platform.isAndroid) {
      return _interstitialAdId;
    }
    throw UnsupportedError("Desteklenmeyen platform");
  }

  /// AdMob SDK'sını başlatır
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }
}

// --- HER EKRANDA KULLANACAĞIMIZ YENİ BANNER WIDGET'I ---
class CustomBannerAd extends StatefulWidget {
  const CustomBannerAd({super.key});

  @override
  State<CustomBannerAd> createState() => _CustomBannerAdState();
}

class _CustomBannerAdState extends State<CustomBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdManager.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Banner reklam yüklenemedi: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null) {
      return SafeArea(
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}