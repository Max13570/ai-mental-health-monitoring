// video_call_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomName;
  final bool isDoctor;
  final String participantName;

  const VideoCallScreen({
    super.key,
    required this.roomName,
    required this.isDoctor,
    required this.participantName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool micOn = true;
  bool camOn = true;
  bool isJoined = false;
  bool isRemoteUserJoined = false;

  late RtcEngine agoraEngine;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  List<int> remoteUid = [];
  int? localUid;

  static const Color medicalBlue = Color(0xFF1E3A8A);
  static const Color medicalTeal = Color(0xFF0F766E);

  // Agora Config - Replace with your actual App ID
  static const String appId = "07f6ef11d18841e4b87b5654872185d4";
  static const String token = ""; // Use temp token or generate from server

  @override
  void initState() {
    super.initState();
    _setupVideoSDKEngine();
    _updateConsultationStatus("Ongoing");
  }

  @override
  void dispose() {
    _disposeAgoraEngine();
    _updateConsultationStatus("Completed");
    super.dispose();
  }

  Future<void> _setupVideoSDKEngine() async {
    try {
      agoraEngine = createAgoraRtcEngine();
      await agoraEngine.initialize(RtcEngineContext(appId: appId));

      await agoraEngine.enableVideo();

      agoraEngine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("Local user uid:${connection.localUid} joined the channel");
            setState(() {
              isJoined = true;
              localUid = connection.localUid;
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("Remote user uid:$remoteUid joined the channel");
            setState(() {
              isRemoteUserJoined = true;
              this.remoteUid.add(remoteUid);
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint("Remote user uid:$remoteUid left the channel");
            setState(() {
              isRemoteUserJoined = false;
              this.remoteUid.remove(remoteUid);
            });
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint("Error: $err, $msg");
          },
        ),
      );

      await _joinChannel();
    } catch (e) {
      debugPrint("Error setting up Agora: $e");
    }
  }

  Future<void> _joinChannel() async {
    try {
      await agoraEngine.joinChannel(
        token: token,
        channelId: widget.roomName,
        uid: 0, // Let Agora assign UID
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      debugPrint("Error joining channel: $e");
    }
  }

  Future<void> _disposeAgoraEngine() async {
    try {
      await agoraEngine.leaveChannel();
      await agoraEngine.release();
    } catch (e) {
      debugPrint("Error disposing Agora: $e");
    }
  }

  Future<void> _updateConsultationStatus(String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('consultations')
          .doc(widget.roomName)
          .update({'status': status});
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  void _toggleMic() {
    setState(() {
      micOn = !micOn;
    });
    agoraEngine.muteLocalAudioStream(!micOn);
  }

  void _toggleCamera() {
    setState(() {
      camOn = !camOn;
    });
    agoraEngine.muteLocalVideoStream(!camOn);
  }

  void _switchCamera() {
    agoraEngine.switchCamera();
  }

  void _endCall() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isDoctor ? medicalTeal : medicalBlue;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: themeColor,
        title: Text(
          'Consultation - ${widget.roomName}',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.red),
            onPressed: _endCall,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Remote video
                _renderRemoteVideo(),

                // Local preview (picture-in-picture)
                _renderLocalPreview(themeColor),

                // Connection status
                _buildConnectionStatus(),
              ],
            ),
          ),

          // Call controls
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    micOn ? Icons.mic : Icons.mic_off,
                    color: micOn ? Colors.white : Colors.red,
                  ),
                  onPressed: _toggleMic,
                  iconSize: 32,
                ),
                IconButton(
                  icon: Icon(
                    camOn ? Icons.videocam : Icons.videocam_off,
                    color: camOn ? Colors.white : Colors.red,
                  ),
                  onPressed: _toggleCamera,
                  iconSize: 32,
                ),
                IconButton(
                  icon: const Icon(Icons.cameraswitch, color: Colors.white),
                  onPressed: _switchCamera,
                  iconSize: 32,
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                  onPressed: _endCall,
                  iconSize: 36,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderRemoteVideo() {
    return Positioned.fill(
      child: isRemoteUserJoined && remoteUid.isNotEmpty
          ? AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: agoraEngine,
          canvas: VideoCanvas(uid: remoteUid[0]),
          connection: const RtcConnection(channelId: ''),
        ),
      )
          : Container(
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person,
                size: 80,
                color: Colors.white30,
              ),
              const SizedBox(height: 16),
              Text(
                widget.participantName,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isJoined ? "Waiting for participant..." : "Connecting...",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderLocalPreview(Color themeColor) {
    return Positioned(
      top: 20,
      right: 20,
      width: 120,
      height: 160,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: themeColor, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: isJoined
              ? AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: agoraEngine,
              canvas: const VideoCanvas(uid: 0),
            ),
          )
              : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person, size: 40, color: themeColor.withOpacity(0.8)),
                const SizedBox(height: 6),
                Text("You", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Positioned(
      top: 20,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              isJoined ? Icons.video_call : Icons.signal_wifi_statusbar_connected_no_internet_4,
              size: 16,
              color: isJoined ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 6),
            Text(
              isJoined ? "Connected" : "Connecting...",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}