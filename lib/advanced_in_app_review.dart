import 'dart:async';

import 'package:advanced_in_app_review/in_app_review_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AdvancedInAppReview with WidgetsBindingObserver {
  final String rateNowButtonText;
  final String? laterButtonText;
  final String ignoreButtonText;
  final Widget? intermediateDialogTitle;
  final Widget? intermediateDialogContent;

  AdvancedInAppReview({
    required this.rateNowButtonText,
    required this.ignoreButtonText,
    required this.intermediateDialogContent,
    required this.intermediateDialogTitle,
    this.laterButtonText,
  });

  static const MethodChannel _channel = MethodChannel('advanced_in_app_review');
  final InAppReviewManager _manager = InAppReviewManager();
  BuildContext? _context;

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  /// Start monitoring conditions to decide whether a view attempt is made or not
  void monitor(BuildContext context) {
    _context = context;
    _manager.monitor();
    _startObserver();
  }

  /// Number of times of opening the app before a view attempt is made
  AdvancedInAppReview setMinLaunchTimes(int launchTimes) {
    _manager.setMinLaunchTimes(launchTimes);
    return this;
  }

  /// Minimum number of days to wait after install before a view attempt is made
  AdvancedInAppReview setMinDaysAfterInstall(int days) {
    _manager.setMinDaysAfterInstall(days);
    return this;
  }

  /// Minimum number of days after a view attempt was made to try again
  AdvancedInAppReview setMinDaysBeforeRemind(int days) {
    _manager.setMinDaysBeforeRemind(days);
    return this;
  }

  /// If the conditions for showing the rating dialog are met, wait a number
  /// of seconds before trying to show up the rating dialog.
  AdvancedInAppReview setMinSecondsBeforeShowDialog(int seconds) {
    _manager.setMinSecondsBeforeShowDialog(seconds);
    return this;
  }

  _startObserver() {
    _ambiguate(WidgetsBinding.instance)?.addObserver(this);
    _afterLaunch();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _afterLaunch();
    }
  }

  void _afterLaunch() {
    _manager.applicationWasLaunched();
    _manager.showRateDialogIfMeetsConditions(
      _context,
      rateNowButtonText: rateNowButtonText,
      ignoreButtonText: ignoreButtonText,
      intermediateDialogTitle: intermediateDialogTitle,
      intermediateDialogContent: intermediateDialogContent,
      laterButtonText: laterButtonText,
    );
  }

  /// This allows a value of type T or T?
  /// to be treated as a value of type T?.
  ///
  /// We use this so that APIs that have become
  /// non-nullable can still be used with `!` and `?`
  /// to support older versions of the API as well.
  T? _ambiguate<T>(T? value) => value;
}
