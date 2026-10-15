import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_common_localizations_en.dart';
import 'app_common_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppCommonLocalizations
/// returned by `AppCommonLocalizations.of(context)`.
///
/// Applications need to include `AppCommonLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localizations/app_common_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppCommonLocalizations.localizationsDelegates,
///   supportedLocales: AppCommonLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppCommonLocalizations.supportedLocales
/// property.
abstract class AppCommonLocalizations {
  AppCommonLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppCommonLocalizations of(BuildContext context) {
    return Localizations.of<AppCommonLocalizations>(
      context,
      AppCommonLocalizations,
    )!;
  }

  static const LocalizationsDelegate<AppCommonLocalizations> delegate =
      _AppCommonLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @feedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedbackTitle;

  /// No description provided for @feedbackTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get feedbackTypeLabel;

  /// No description provided for @feedbackTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Select a feedback type'**
  String get feedbackTypeHint;

  /// No description provided for @feedbackTypeIssue.
  ///
  /// In en, this message translates to:
  /// **'Problem'**
  String get feedbackTypeIssue;

  /// No description provided for @feedbackTypeAdvice.
  ///
  /// In en, this message translates to:
  /// **'Suggestion'**
  String get feedbackTypeAdvice;

  /// No description provided for @feedbackContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get feedbackContentLabel;

  /// No description provided for @feedbackContentHintIssue.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem, when it happened, and how to reproduce it'**
  String get feedbackContentHintIssue;

  /// No description provided for @feedbackContentHintAdvice.
  ///
  /// In en, this message translates to:
  /// **'Describe your suggestion'**
  String get feedbackContentHintAdvice;

  /// No description provided for @feedbackCompanyIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Company ID'**
  String get feedbackCompanyIdLabel;

  /// No description provided for @feedbackCompanyIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your company ID'**
  String get feedbackCompanyIdHint;

  /// No description provided for @feedbackContactLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact (optional)'**
  String get feedbackContactLabel;

  /// No description provided for @feedbackContactHint.
  ///
  /// In en, this message translates to:
  /// **'Email or phone so we can reach you'**
  String get feedbackContactHint;

  /// No description provided for @feedbackUploadLogLabel.
  ///
  /// In en, this message translates to:
  /// **'Include the app version and platform in the report'**
  String get feedbackUploadLogLabel;

  /// No description provided for @feedbackSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get feedbackSubmit;

  /// No description provided for @feedbackCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get feedbackCancel;

  /// No description provided for @feedbackSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get feedbackSubmitting;

  /// No description provided for @feedbackSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get feedbackSuccessTitle;

  /// No description provided for @feedbackSuccessTip.
  ///
  /// In en, this message translates to:
  /// **'Give this feedback ID to support so we can follow up.'**
  String get feedbackSuccessTip;

  /// No description provided for @feedbackSuccessIdCaption.
  ///
  /// In en, this message translates to:
  /// **'Feedback ID'**
  String get feedbackSuccessIdCaption;

  /// No description provided for @feedbackCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get feedbackCopy;

  /// No description provided for @feedbackCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get feedbackCopied;

  /// No description provided for @feedbackConfirm.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get feedbackConfirm;

  /// No description provided for @upgradeTitleUpgrade.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get upgradeTitleUpgrade;

  /// No description provided for @upgradeTitleLatest.
  ///
  /// In en, this message translates to:
  /// **'Current version {version}'**
  String upgradeTitleLatest(String version);

  /// No description provided for @upgradeTipDownloading.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is downloading'**
  String upgradeTipDownloading(String version);

  /// No description provided for @upgradeTipDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is ready; restart to finish upgrading'**
  String upgradeTipDownloaded(String version);

  /// No description provided for @upgradeTipForceDownloading.
  ///
  /// In en, this message translates to:
  /// **'Important update {version} is downloading; upgrade right after it finishes'**
  String upgradeTipForceDownloading(String version);

  /// No description provided for @upgradeTipForceDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Important update {version} is ready; upgrading now is required'**
  String upgradeTipForceDownloaded(String version);

  /// No description provided for @upgradeDownloadingText.
  ///
  /// In en, this message translates to:
  /// **'Downloading {progress}'**
  String upgradeDownloadingText(String progress);

  /// No description provided for @upgradeUnzipText.
  ///
  /// In en, this message translates to:
  /// **'Unzipping the update…'**
  String get upgradeUnzipText;

  /// No description provided for @upgradeCheckMd5Text.
  ///
  /// In en, this message translates to:
  /// **'Verifying the installer…'**
  String get upgradeCheckMd5Text;

  /// No description provided for @upgradeDownloadedText.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get upgradeDownloadedText;

  /// No description provided for @upgradeDownloadFailedText.
  ///
  /// In en, this message translates to:
  /// **'Download failed, please retry'**
  String get upgradeDownloadFailedText;

  /// No description provided for @upgradeButtonInstall.
  ///
  /// In en, this message translates to:
  /// **'Restart and install'**
  String get upgradeButtonInstall;

  /// No description provided for @upgradeButtonRetry.
  ///
  /// In en, this message translates to:
  /// **'Re-download'**
  String get upgradeButtonRetry;

  /// No description provided for @upgradeButtonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get upgradeButtonCancel;
}

class _AppCommonLocalizationsDelegate
    extends LocalizationsDelegate<AppCommonLocalizations> {
  const _AppCommonLocalizationsDelegate();

  @override
  Future<AppCommonLocalizations> load(Locale locale) {
    return SynchronousFuture<AppCommonLocalizations>(
      lookupAppCommonLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppCommonLocalizationsDelegate old) => false;
}

AppCommonLocalizations lookupAppCommonLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppCommonLocalizationsEn();
    case 'zh':
      return AppCommonLocalizationsZh();
  }

  throw FlutterError(
    'AppCommonLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
