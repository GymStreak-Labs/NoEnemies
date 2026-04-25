import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat-backed subscription manager.
///
/// NoEnemies is premium-only. The live RevenueCat catalog mirrors GymLevels:
/// - entitlement: `premium`
/// - `default` offering: `$rc_annual` + `$rc_weekly`
/// - `special_offer` offering: `special_annual`
///
/// The public SDK keys are intentionally embedded in the client. RevenueCat
/// public keys are app-specific, non-secret keys and are required for SDK
/// configuration; the `sk_...` secret key stays in Mission Control only.
class SubscriptionService extends ChangeNotifier {
  static const entitlementId = 'premium';

  static const defaultOfferingId = 'default';
  static const specialOfferOfferingId = 'special_offer';
  static const annualPackageId = r'$rc_annual';
  static const weeklyPackageId = r'$rc_weekly';
  static const specialAnnualPackageId = 'special_annual';

  static const _iosApiKey = 'appl_AnJpHnbAwyfYjwedGzqGutycJkB';
  static const _androidApiKey = 'goog_WXPGPAhqRjJbUstWnNnyecNxDrp';

  /// Build-time escape hatch for internal/screenshot builds only.
  ///
  /// Usage: `flutter run --dart-define=FORCE_PREMIUM=true`.
  /// Never commit this as true; the default build remains hard-paywalled.
  static const forcePremium = bool.fromEnvironment('FORCE_PREMIUM');

  bool _isConfigured = false;
  bool _isLoadingOfferings = false;
  bool _isPurchasing = false;
  String? _lastError;
  String? _loggedInUserId;
  CustomerInfo? _customerInfo;
  Offerings? _offerings;

  bool get isConfigured => _isConfigured;
  bool get isLoadingOfferings => _isLoadingOfferings;
  bool get isPurchasing => _isPurchasing;
  String? get lastError => _lastError;
  CustomerInfo? get customerInfo => _customerInfo;
  Offerings? get offerings => _offerings;

  bool get hasPremium {
    if (forcePremium) return true;
    return _customerInfo?.entitlements.active.containsKey(entitlementId) ??
        false;
  }

  Offering? get defaultOffering =>
      _offerings?.getOffering(defaultOfferingId) ?? _offerings?.current;

  Offering? get specialOffer => _offerings?.getOffering(specialOfferOfferingId);

  Package? get regularAnnualPackage =>
      defaultOffering?.getPackage(annualPackageId) ?? defaultOffering?.annual;

  Package? get weeklyPackage =>
      defaultOffering?.getPackage(weeklyPackageId) ?? defaultOffering?.weekly;

  Package? get specialAnnualPackage =>
      specialOffer?.getPackage(specialAnnualPackageId) ??
      specialOffer?.annual ??
      specialOffer?.availablePackages.firstOrNull;

  /// The annual package shown first on the NoEnemies paywall. Prefer the
  /// GymLevels-style special annual offer when RevenueCat returns it.
  Package? get preferredAnnualPackage =>
      specialAnnualPackage ?? regularAnnualPackage;

  String get annualPrice =>
      preferredAnnualPackage?.storeProduct.priceString ?? r'$29.99';

  String get regularAnnualPrice =>
      regularAnnualPackage?.storeProduct.priceString ?? r'$59.99';

  String get weeklyPrice => weeklyPackage?.storeProduct.priceString ?? r'$4.99';

  String get annualWeeklyBreakdown {
    final perWeek = preferredAnnualPackage?.storeProduct.pricePerWeekString;
    if (perWeek != null && perWeek.isNotEmpty) return '$perWeek/week';
    return r'$0.58/week';
  }

  String get specialOfferTitle {
    final value = specialOffer?.metadata['title'];
    if (value is String && value.trim().isNotEmpty) return value;
    return 'Limited Offer';
  }

  String get specialOfferBadge {
    final value = specialOffer?.metadata['badge_text'];
    if (value is String && value.trim().isNotEmpty) return value;
    return 'BEST VALUE';
  }

  int get specialOfferCountdownSeconds {
    final value = specialOffer?.metadata['countdown_seconds'];
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool get hasSpecialAnnualOffer => specialAnnualPackage != null;

  Package? packageForPlan({required bool annual}) {
    return annual ? preferredAnnualPackage : weeklyPackage;
  }

  Future<void> init({String? appUserId}) async {
    if (_isConfigured) return;

    if (!Platform.isIOS && !Platform.isAndroid) {
      _lastError = 'RevenueCat is only configured for iOS and Android.';
      if (kDebugMode) {
        debugPrint('[SubscriptionService] $_lastError');
      }
      notifyListeners();
      return;
    }

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      final configuration =
          PurchasesConfiguration(Platform.isIOS ? _iosApiKey : _androidApiKey)
            ..appUserID = appUserId
            ..storeKitVersion = StoreKitVersion.defaultVersion
            ..diagnosticsEnabled = kDebugMode;

      await Purchases.configure(configuration);
      _isConfigured = true;
      _loggedInUserId = appUserId;

      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);

      await refreshCustomerInfo();
      await loadOfferings();
    } catch (e, st) {
      _lastError = _friendlyError(e);
      if (kDebugMode) {
        debugPrint('[SubscriptionService] init failed: $e\n$st');
      }
      notifyListeners();
    }
  }

  Future<void> refreshCustomerInfo() async {
    if (!_isConfigured) return;
    try {
      _handleCustomerInfoUpdate(await Purchases.getCustomerInfo());
      _lastError = null;
    } catch (e, st) {
      _lastError = _friendlyError(e);
      if (kDebugMode) {
        debugPrint('[SubscriptionService] refreshCustomerInfo failed: $e\n$st');
      }
      notifyListeners();
    }
  }

  Future<void> loadOfferings() async {
    if (!_isConfigured) return;

    _isLoadingOfferings = true;
    _lastError = null;
    notifyListeners();

    try {
      _offerings = await Purchases.getOfferings();
      if (kDebugMode) {
        debugPrint(
          '[SubscriptionService] offerings loaded: '
          'current=${_offerings?.current?.identifier}, '
          'all=${_offerings?.all.keys.toList()}',
        );
      }
    } catch (e, st) {
      _lastError = _friendlyError(e);
      if (kDebugMode) {
        debugPrint('[SubscriptionService] loadOfferings failed: $e\n$st');
      }
    } finally {
      _isLoadingOfferings = false;
      notifyListeners();
    }
  }

  /// Link a Firebase uid to the RevenueCat subscriber.
  ///
  /// RevenueCat aliases the anonymous purchase made on the paywall with the
  /// Firebase uid after auth, which is the exact flow we want: pay first,
  /// then sign in, then land in the app.
  Future<void> logIn(String userId) async {
    if (forcePremium) return;
    if (!_isConfigured || _loggedInUserId == userId) return;

    try {
      final result = await Purchases.logIn(userId);
      _loggedInUserId = userId;
      _handleCustomerInfoUpdate(result.customerInfo);
      await Purchases.setAttributes({'firebase_uid': userId});
      _lastError = null;
    } catch (e, st) {
      _lastError = _friendlyError(e);
      if (kDebugMode) {
        debugPrint('[SubscriptionService] logIn($userId) failed: $e\n$st');
      }
      notifyListeners();
    }
  }

  Future<void> logOut() async {
    if (forcePremium || !_isConfigured) return;

    try {
      if (_loggedInUserId != null) {
        _handleCustomerInfoUpdate(await Purchases.logOut());
      }
      _loggedInUserId = null;
      _lastError = null;
    } catch (e, st) {
      // RevenueCat throws if logOut is called for an anonymous subscriber.
      // Treat that as a harmless no-op during Firebase sign-out.
      if (kDebugMode) {
        debugPrint('[SubscriptionService] logOut ignored: $e\n$st');
      }
      _loggedInUserId = null;
      _customerInfo = null;
      notifyListeners();
    }
  }

  Future<SubscriptionPurchaseResult> purchase(Package package) async {
    if (!_isConfigured) {
      return const SubscriptionPurchaseResult(
        success: false,
        errorMessage: 'Purchases are still loading. Please try again.',
      );
    }

    _isPurchasing = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _handleCustomerInfoUpdate(result.customerInfo);
      final active = result.customerInfo.entitlements.active.containsKey(
        entitlementId,
      );
      return SubscriptionPurchaseResult(
        success: active,
        customerInfo: result.customerInfo,
        errorMessage: active
            ? null
            : 'Purchase finished, but access is not active yet.',
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const SubscriptionPurchaseResult(
          success: false,
          cancelled: true,
        );
      }
      final message = _friendlyPurchaseError(code);
      _lastError = message;
      return SubscriptionPurchaseResult(success: false, errorMessage: message);
    } catch (e, st) {
      final message = _friendlyError(e);
      _lastError = message;
      if (kDebugMode) {
        debugPrint('[SubscriptionService] purchase failed: $e\n$st');
      }
      return SubscriptionPurchaseResult(success: false, errorMessage: message);
    } finally {
      _isPurchasing = false;
      notifyListeners();
    }
  }

  Future<SubscriptionRestoreResult> restorePurchases() async {
    if (!_isConfigured) {
      return const SubscriptionRestoreResult(
        success: false,
        isPremium: false,
        errorMessage: 'Purchases are still loading. Please try again.',
      );
    }

    _isPurchasing = true;
    _lastError = null;
    notifyListeners();

    try {
      final info = await Purchases.restorePurchases();
      _handleCustomerInfoUpdate(info);
      final active = info.entitlements.active.containsKey(entitlementId);
      return SubscriptionRestoreResult(success: true, isPremium: active);
    } catch (e, st) {
      final message = _friendlyError(e);
      _lastError = message;
      if (kDebugMode) {
        debugPrint('[SubscriptionService] restore failed: $e\n$st');
      }
      return SubscriptionRestoreResult(
        success: false,
        isPremium: false,
        errorMessage: message,
      );
    } finally {
      _isPurchasing = false;
      notifyListeners();
    }
  }

  void _handleCustomerInfoUpdate(CustomerInfo info) {
    _customerInfo = info;
    notifyListeners();
  }

  String _friendlyError(Object e) {
    if (e is PlatformException) {
      return e.message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  String _friendlyPurchaseError(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device.';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'This plan is not available yet. Please try again shortly.';
      case PurchasesErrorCode.networkError:
      case PurchasesErrorCode.offlineConnectionError:
        return 'You appear to be offline. Please check your connection.';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'This subscription is already active.';
      case PurchasesErrorCode.paymentPendingError:
        return 'Your purchase is pending approval.';
      case PurchasesErrorCode.configurationError:
      case PurchasesErrorCode.invalidCredentialsError:
        return 'Purchases are not configured correctly yet.';
      default:
        return 'Purchase failed. Please try again.';
    }
  }
}

class SubscriptionPurchaseResult {
  const SubscriptionPurchaseResult({
    required this.success,
    this.cancelled = false,
    this.customerInfo,
    this.errorMessage,
  });

  final bool success;
  final bool cancelled;
  final CustomerInfo? customerInfo;
  final String? errorMessage;
}

class SubscriptionRestoreResult {
  const SubscriptionRestoreResult({
    required this.success,
    required this.isPremium,
    this.errorMessage,
  });

  final bool success;
  final bool isPremium;
  final String? errorMessage;
}

extension _PackageListX on List<Package> {
  Package? get firstOrNull => isEmpty ? null : first;
}
