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

  factory InAppReviewManager() {
    return _singleton;
  }

  bool _isIntermediateDialogInProgress = false;

  void monitor() async {
    if (await _isFirstLaunch() == true) {
      _setInstallDate();
    }
  }

  void applicationWasLaunched() async {
    _setLaunchTimes(await _getLaunchTimes() + 1);
  }

  Future<bool> showRateDialogIfMeetsConditions(
    BuildContext? context, {
    required String rateNowButtonText,
    required String ignoreButtonText,
    required Widget? intermediateDialogTitle,
    required Widget? intermediateDialogContent,
  }) async {
    bool isMeetsConditions = await _shouldShowRateDialog();

    if (isMeetsConditions) {
      Future.delayed(Duration(seconds: _minSecondsBeforeShowDialog), () {
        _showDialog(
          context,
          rateNowButtonText: rateNowButtonText,
          ignoreButtonText: ignoreButtonText,
          intermediateDialogTitle: intermediateDialogTitle,
          intermediateDialogContent: intermediateDialogContent,
        );
      });
    }
    return isMeetsConditions;
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

  // Dialog
  void _showDialog(
    BuildContext? context, {
    required String rateNowButtonText,
    required String ignoreButtonText,
    required Widget? intermediateDialogTitle,
    required Widget? intermediateDialogContent,
  }) async {
    final InAppReview inAppReview = InAppReview.instance;

    if (context != null) {
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
  }

  // Checkers

  Future<bool> _shouldShowRateDialog() async {
    final InAppReview inAppReview = InAppReview.instance;
    return await _isOverLaunchTimes() &&
        await _isOverInstallDate() &&
        await _isOverRemindDate() &&
        await _isNotIgnored() &&
        await inAppReview.isAvailable() &&
        !_isIntermediateDialogInProgress;
  }

  Future<bool> _isOverLaunchTimes() async {
    bool overLaunchTimes = await _getLaunchTimes() >= _minLaunchTimes;
    return overLaunchTimes;
  }

  Future<bool> _isOverInstallDate() async {
    bool overInstallDate = await _isOverDate(await _getInstallTimestamp(), _minDaysAfterInstall);
    return overInstallDate;
  }

  Future<bool> _isOverRemindDate() async {
    bool overRemindDate = await _isOverDate(await _getRemindTimestamp(), _minDaysBeforeRemind);
    return overRemindDate;
  }

  Future<bool> _isNotIgnored() async {
    bool isIgnored = await _getIsIgnored();
    return !isIgnored;
  }

  // Helpers

  Future<bool> _isOverDate(int targetDate, int threshold) async {
    return DateTime.now().millisecondsSinceEpoch - targetDate >= threshold * 24 * 60 * 60 * 1000;
  }

  // Shared Preference Values

  Future<bool> _isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final int? installDate = prefs.getInt(_prefKeyInstallDate);
    return installDate == null;
  }

  Future<int> _getInstallTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final int? installTimestamp = prefs.getInt(_prefKeyInstallDate);
    if (installTimestamp != null) {
      return installTimestamp;
    }
    return 0;
  }

  void _setInstallDate() async {
    final prefs = await SharedPreferences.getInstance();
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    prefs.setInt(_prefKeyInstallDate, timestamp);
  }

  Future<int> _getLaunchTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final int? launchTimes = prefs.getInt(_prefKeyLaunchTimes);
    if (launchTimes != null) {
      return launchTimes;
    }
    return 0;
  }

  static void _setLaunchTimes(int launchTimes) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_prefKeyLaunchTimes, launchTimes);
  }

  Future<int> _getRemindTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final int? remindIntervalTime = prefs.getInt(_prefKeyRemindInterval);
    if (remindIntervalTime != null) {
      return remindIntervalTime;
    }
    return 0;
  }

  void _setRemindTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_prefKeyRemindInterval);
    prefs.setInt(_prefKeyRemindInterval, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> _getIsIgnored() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? isIgnored = prefs.getBool(_prefKeyIsIgnored);
    return isIgnored ?? false;
  }

  Future<void> _setIsIgnored(bool isIgnored) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_prefKeyIsIgnored);
    prefs.setBool(_prefKeyIsIgnored, isIgnored);
  }
}
