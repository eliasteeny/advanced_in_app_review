import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _IntermediateDialogState { rate, later, ignore }

class InAppReviewManager {
  static final InAppReviewManager _singleton = InAppReviewManager._internal();

  InAppReviewManager._internal();

  static const String _prefKeyInstallDate = "advanced_in_app_review_install_date";
  static const String _prefKeyLaunchTimes = "advanced_in_app_review_launch_times";
  static const String _prefKeyRemindInterval = "advanced_in_app_remind_interval";
  static const String _prefKeyIsIgnored = "advanced_in_app_remind_is_ignored";

  static int _minLaunchTimes = 2;
  static int _minDaysAfterInstall = 2;
  static int _minDaysBeforeRemind = 1;
  static int _minSecondsBeforeShowDialog = 1;

  static void Function(Object error, StackTrace stackTrace)? _onFailed;

  factory InAppReviewManager() {
    return _singleton;
  }

  bool _isIntermediateDialogInProgress = false;

  void monitor() async {
    try {
      if (await _isFirstLaunch() == true) {
        _setInstallDate();
      }
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
    }
  }

  void applicationWasLaunched() async {
    try {
      _setLaunchTimes(await _getLaunchTimes() + 1);
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
    }
  }

  Future<bool> showRateDialogIfMeetsConditions(
    BuildContext? context, {
    required String rateNowButtonText,
    required String ignoreButtonText,
    required Widget? intermediateDialogTitle,
    required Widget? intermediateDialogContent,
  }) async {
    try {
      bool isMeetsConditions = await _shouldShowRateDialog();

      if (isMeetsConditions) {
        await Future.delayed(Duration(seconds: _minSecondsBeforeShowDialog));

        _showDialog(
          context,
          rateNowButtonText: rateNowButtonText,
          ignoreButtonText: ignoreButtonText,
          intermediateDialogTitle: intermediateDialogTitle,
          intermediateDialogContent: intermediateDialogContent,
        );
      }
      return isMeetsConditions;
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);

      return false;
    }
  }

  // Setters

  void setMinLaunchTimes(int times) {
    _minLaunchTimes = times;
  }

  void setMinDaysAfterInstall(int days) {
    _minDaysAfterInstall = days;
  }

  void setMinDaysBeforeRemind(int days) {
    _minDaysBeforeRemind = days;
  }

  void setMinSecondsBeforeShowDialog(int seconds) {
    _minSecondsBeforeShowDialog = seconds;
  }

  void setOnFailed(void Function(Object error, StackTrace stackTrace) onFailed) {
    _onFailed = onFailed;
  }

  // Dialog
  void _showDialog(
    BuildContext? context, {
    required String rateNowButtonText,
    required String ignoreButtonText,
    required Widget? intermediateDialogTitle,
    required Widget? intermediateDialogContent,
  }) async {
    try {
      final InAppReview inAppReview = InAppReview.instance;

      if (context != null && context.mounted) {
        _isIntermediateDialogInProgress = true;
        final popValue = await showDialog<_IntermediateDialogState>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: intermediateDialogTitle,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (intermediateDialogContent != null) intermediateDialogContent,
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.blue,
                            width: 3,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(_IntermediateDialogState.ignore);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            ignoreButtonText,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.green,
                            width: 3,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(_IntermediateDialogState.rate);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            rateNowButtonText,
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        _isIntermediateDialogInProgress = false;

        // if popValue is _IntermediateDialogState.rate, resume function normally
        if (popValue == null || popValue == _IntermediateDialogState.later) {
          _setRemindTimestamp();
          return;
        } else if (popValue == _IntermediateDialogState.ignore) {
          await _setIsIgnored(true);
          return;
        }
      }
      // _showDialog can only be called if inAppReview.isAvailable() returned true

      inAppReview.requestReview();

      _setRemindTimestamp();
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
    }
  }

  // Checkers

  Future<bool> _shouldShowRateDialog() async {
    try {
      final InAppReview inAppReview = InAppReview.instance;
      return await _isOverLaunchTimes() &&
          await _isOverInstallDate() &&
          await _isOverRemindDate() &&
          await _isNotIgnored() &&
          await inAppReview.isAvailable() &&
          !_isIntermediateDialogInProgress;
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
      return false;
    }
  }

  Future<bool> _isOverLaunchTimes() async {
    try {
      bool overLaunchTimes = await _getLaunchTimes() >= _minLaunchTimes;
      return overLaunchTimes;
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
      return false;
    }
  }

  Future<bool> _isOverInstallDate() async {
    try {
      bool overInstallDate = await _isOverDate(await _getInstallTimestamp(), _minDaysAfterInstall);
      return overInstallDate;
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
      return false;
    }
  }

  Future<bool> _isOverRemindDate() async {
    try {
      bool overRemindDate = await _isOverDate(await _getRemindTimestamp(), _minDaysBeforeRemind);
      return overRemindDate;
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
      return false;
    }
  }

  Future<bool> _isNotIgnored() async {
    try {
      bool isIgnored = await _getIsIgnored();
      return !isIgnored;
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
      return false;
    }
  }

  // Helpers

  Future<bool> _isOverDate(int targetDate, int threshold) async {
    try {
      return DateTime.now().millisecondsSinceEpoch - targetDate >= threshold * 24 * 60 * 60 * 1000;
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
      return false;
    }
  }

  // Shared Preference Values

  Future<bool> _isFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? installDate = prefs.getInt(_prefKeyInstallDate);
      return installDate == null;
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
      return false;
    }
  }

  Future<int> _getInstallTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? installTimestamp = prefs.getInt(_prefKeyInstallDate);
      if (installTimestamp != null) {
        return installTimestamp;
      }
      return 0;
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
      return 0;
    }
  }

  void _setInstallDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      prefs.setInt(_prefKeyInstallDate, timestamp);
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
    }
  }

  Future<int> _getLaunchTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? launchTimes = prefs.getInt(_prefKeyLaunchTimes);
      if (launchTimes != null) {
        return launchTimes;
      }
      return 0;
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
      return 0;
    }
  }

  static void _setLaunchTimes(int launchTimes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt(_prefKeyLaunchTimes, launchTimes);
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
    }
  }

  Future<int> _getRemindTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? remindIntervalTime = prefs.getInt(_prefKeyRemindInterval);
      if (remindIntervalTime != null) {
        return remindIntervalTime;
      }
      return 0;
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
      return 0;
    }
  }

  void _setRemindTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.remove(_prefKeyRemindInterval);
      prefs.setInt(_prefKeyRemindInterval, DateTime.now().millisecondsSinceEpoch);
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
    }
  }

  Future<bool> _getIsIgnored() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool? isIgnored = prefs.getBool(_prefKeyIsIgnored);
      return isIgnored ?? false;
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
      return false;
    }
  }

  Future<void> _setIsIgnored(bool isIgnored) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.remove(_prefKeyIsIgnored);
      prefs.setBool(_prefKeyIsIgnored, isIgnored);
    } catch (error, stackTrace) {
      _onFailed?.call(error, stackTrace);
    }
  }
}
