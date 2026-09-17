import 'package:share_plus/share_plus.dart' show Share, ShareResult, XFile;

export 'package:share_plus/share_plus.dart' show XFile;

/// The instance-style share_plus API used by the report screen.
///
/// share_plus 10 exposes the same native operation through [Share.shareXFiles],
/// so this small adapter keeps the call site compatible with the newer API
/// shape without adding any platform-specific behavior.
class SharePlus {
  const SharePlus._();

  static const SharePlus instance = SharePlus._();

  Future<ShareResult> share(ShareParams params) => Share.shareXFiles(
    params.files,
    subject: params.subject,
    text: params.text,
  );
}

class ShareParams {
  const ShareParams({required this.files, this.subject, this.text});

  final List<XFile> files;
  final String? subject;
  final String? text;
}
