import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class JitsiMeetWidget extends StatefulWidget {
  final String roomName;
  final String userName;
  final String? userEmail;
  final bool isAudioMuted;
  final bool isVideoMuted;
  final String? subject;

  const JitsiMeetWidget({
    super.key,
    required this.roomName,
    required this.userName,
    this.userEmail,
    this.isAudioMuted = false,
    this.isVideoMuted = false,
    this.subject,
  });

  @override
  State<JitsiMeetWidget> createState() => _JitsiMeetWidgetState();
}

class _JitsiMeetWidgetState extends State<JitsiMeetWidget> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _configureJitsiSettings();
          },
        ),
      )
      ..loadRequest(Uri.parse(_buildJitsiUrl()));
  }

  String _buildJitsiUrl() {
    final baseUrl = 'https://meet.jit.si/${widget.roomName}';
    final params = <String, String>{
      if (widget.userName.isNotEmpty) 'userDisplayName': widget.userName,
      if (widget.userEmail != null && widget.userEmail!.isNotEmpty)
        'userEmail': widget.userEmail!,
      if (widget.subject != null && widget.subject!.isNotEmpty)
        'subject': widget.subject!,
    };

    if (params.isEmpty) return baseUrl;

    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '$baseUrl#config.startWithAudioMuted=${widget.isAudioMuted}&config.startWithVideoMuted=${widget.isVideoMuted}&$queryString';
  }

  void _configureJitsiSettings() {
    // Configure Jitsi settings via JavaScript
    final jsCode =
        '''
      if (typeof JitsiMeetJS !== 'undefined') {
        // Configure audio/video settings
        if (${widget.isAudioMuted}) {
          APP.conference.muteAudio(true);
        }
        if (${widget.isVideoMuted}) {
          APP.conference.muteVideo(true);
        }
      }
    ''';

    _controller.runJavaScript(jsCode).catchError((error) {
      debugPrint('Failed to configure Jitsi settings: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      );
    } else {
      // For mobile, open in external browser or use native handling
      return _buildMobileView();
    }
  }

  Widget _buildMobileView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_call, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            'Join Video Call',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Room: ${widget.roomName}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _launchJitsiInBrowser,
            child: const Text('Open in Browser'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchJitsiInBrowser() async {
    final url = Uri.parse(_buildJitsiUrl());
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch video call')),
        );
      }
    }
  }
}

// Helper class for easy usage
class JitsiMeetHelper {
  static Widget buildJitsiWidget({
    required String roomName,
    required String userName,
    String? userEmail,
    bool isAudioMuted = false,
    bool isVideoMuted = false,
    String? subject,
  }) {
    return JitsiMeetWidget(
      roomName: roomName,
      userName: userName,
      userEmail: userEmail,
      isAudioMuted: isAudioMuted,
      isVideoMuted: isVideoMuted,
      subject: subject,
    );
  }

  static Future<void> launchJitsiMeeting({
    required String roomName,
    required String userName,
    String? userEmail,
    String? subject,
  }) async {
    final baseUrl = 'https://meet.jit.si/$roomName';
    final params = <String, String>{};

    if (userName.isNotEmpty) params['userDisplayName'] = userName;
    if (userEmail != null && userEmail.isNotEmpty) {
      params['userEmail'] = userEmail;
    }
    if (subject != null && subject.isNotEmpty) params['subject'] = subject;

    String finalUrl = baseUrl;
    if (params.isNotEmpty) {
      final queryString = params.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
      finalUrl = '$baseUrl#$queryString';
    }

    final url = Uri.parse(finalUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
