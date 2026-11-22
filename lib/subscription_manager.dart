import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';

class SubscriptionManager extends ChangeNotifier {
  // RevenueCat panelinde oluşturacağımız yetki (entitlement) kimliği
  static const String entitlementId = 'pro'; 
  
  static const String revenueCatApiKey = 'goog_aeiJToJtllCdVHpGrKiAEmcJKoA';

  bool _isPro = false;
  bool _isLoading = true;
  bool _isInitialized = false;
  
  // EKRANDA GÖSTERECEĞİMİZ DİNAMİK FİYAT DEĞİŞKENİ
  String _proPrice = '₺49.90'; 

  bool get isPro => _isPro;
  bool get isLoading => _isLoading;
  String get proPrice => _proPrice; 

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    }

    try {
      if (Platform.isAndroid) {
        final configuration = PurchasesConfiguration(revenueCatApiKey);
        await Purchases.configure(configuration);

        await refreshSubscriptionStatus();
        await _fetchPackagePrice(); 

        Purchases.addCustomerInfoUpdateListener((customerInfo) {
          _isPro = _hasActiveEntitlement(customerInfo);
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint("RevenueCat başlatma hatası: $e");
      _isPro = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _isPro = _hasActiveEntitlement(customerInfo);
    } catch (e) {
      debugPrint("Durum yenileme hatası: $e");
      _isPro = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchPackagePrice() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        _proPrice = offerings.current!.availablePackages.first.storeProduct.priceString;
        notifyListeners(); 
      }
    } catch (e) {
      debugPrint("Fiyat çekme hatası: $e");
    }
  }

  // --- GÜNCELLENEN GÜVENLİ KONTROL FONKSİYONU ---
  bool _hasActiveEntitlement(CustomerInfo info) {
    return info.entitlements.active.containsKey(entitlementId);
  }

  // --- GÜNCELLENEN GÜVENLİ SATIN ALMA FONKSİYONU ---
 Future<bool> purchaseProVersion() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        
        // 1. Satın alma işlemini tetikle (Paketine uygun olan yöntem)
        await Purchases.purchasePackage(
          offerings.current!.availablePackages.first
        );
        
        // 2. İşlem bitince GÜNCEL bilgiyi sunucudan çek
        CustomerInfo customerInfo = await Purchases.getCustomerInfo();
        
        // 3. YENİ VE GÜVENLİ fonksiyonumuzla (active) kontrol et
        if (_hasActiveEntitlement(customerInfo)) {
          _isPro = true;
          _isLoading = false;
          notifyListeners();
          return true; 
        }
      }
      return false; 
    } catch (e) {
      debugPrint("Satın alma hatası veya iptal: $e");
      return false; 
    }
  }

  void toggleProForTest() {
    _isPro = !_isPro;
    notifyListeners();
  }
}