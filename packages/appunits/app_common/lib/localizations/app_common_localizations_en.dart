// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_common_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppCommonLocalizationsEn extends AppCommonLocalizations {
  AppCommonLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get feedbackTitle => 'Feedback';

  @override
  String get feedbackTypeLabel => 'Type';

  @override
  String get feedbackTypeHint => 'Select a feedback type';

  @override
  String get feedbackTypeIssue => 'Problem';

  @override
  String get feedbackTypeAdvice => 'Suggestion';

  @override
  String get feedbackContentLabel => 'Description';

  @override
  String get feedbackContentHintIssue =>
      'Describe the problem, when it happened, and how to reproduce it';

  @override
  String get feedbackContentHintAdvice => 'Describe your suggestion';

  @override
  String get feedbackCompanyIdLabel => 'Company ID';

  @override
  String get feedbackCompanyIdHint => 'Enter your company ID';

  @override
  String get feedbackContactLabel => 'Contact (optional)';

  @override
  String get feedbackContactHint => 'Email or phone so we can reach you';

  @override
  String get feedbackUploadLogLabel =>
      'Include the app version and platform in the report';

  @override
  String get feedbackSubmit => 'Submit';

  @override
  String get feedbackCancel => 'Cancel';

  @override
  String get feedbackSubmitting => 'Submitting…';

  @override
  String get feedbackSuccessTitle => 'Submitted';

  @override
  String get feedbackSuccessTip =>
      'Give this feedback ID to support so we can follow up.';

  @override
  String get feedbackSuccessIdCaption => 'Feedback ID';

  @override
  String get feedbackCopy => 'Copy';

  @override
  String get feedbackCopied => 'Copied';

  @override
  String get feedbackConfirm => 'Got it';

  @override
  String get upgradeTitleUpgrade => 'New version available';

  @override
  String upgradeTitleLatest(String version) {
    return 'Current version $version';
  }

  @override
  String upgradeTipDownloading(String version) {
    return 'Version $version is downloading';
  }

  @override
  String upgradeTipDownloaded(String version) {
    return 'Version $version is ready; restart to finish upgrading';
  }

  @override
  String upgradeTipForceDownloading(String version) {
    return 'Important update $version is downloading; upgrade right after it finishes';
  }

  @override
  String upgradeTipForceDownloaded(String version) {
    return 'Important update $version is ready; upgrading now is required';
  }

  @override
  String upgradeDownloadingText(String progress) {
    return 'Downloading $progress';
  }

  @override
  String get upgradeUnzipText => 'Unzipping the update…';

  @override
  String get upgradeCheckMd5Text => 'Verifying the installer…';

  @override
  String get upgradeDownloadedText => 'Download complete';

  @override
  String get upgradeDownloadFailedText => 'Download failed, please retry';

  @override
  String get upgradeButtonInstall => 'Restart and install';

  @override
  String get upgradeButtonRetry => 'Re-download';

  @override
  String get upgradeButtonCancel => 'Cancel';
}
