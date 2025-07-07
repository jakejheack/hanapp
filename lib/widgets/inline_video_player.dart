import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:hanapp/models/video.dart';

class InlineVideoPlayer extends StatefulWidget {
  final Video video;
  final bool autoplay;
  final double height;
  final double width;

  const InlineVideoPlayer({
    super.key,
    required this.video,
    this.autoplay = true,
    this.height = 200,
    this.width = double.infinity,
  });

  @override
  State<InlineVideoPlayer> createState() => InlineVideoPlayerState();
}

class InlineVideoPlayerState extends State<InlineVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  YoutubePlayerController? _youtubeController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      if (widget.video.videoUrl == null || widget.video.videoUrl!.isEmpty) {
        throw Exception('Video URL is not available');
      }

      if (_isYouTubeVideo(widget.video.videoUrl!)) {
        await _initializeYouTubeVideo();
      } else {
        await _initializeLocalVideo();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load video: $e';
      });

    }
  }

  bool _isYouTubeVideo(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  String _extractYouTubeId(String url) {
    if (url.contains('youtube.com/watch?v=')) {
      return url.split('v=')[1].split('&')[0];
    } else if (url.contains('youtu.be/')) {
      return url.split('youtu.be/')[1].split('?')[0];
    }
    return '';
  }

  Future<void> _initializeYouTubeVideo() async {
    final videoId = _extractYouTubeId(widget.video.videoUrl!);
    if (videoId.isEmpty) {
      throw Exception('Invalid YouTube URL');
    }

    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoplay,
        mute: false,
        isLive: false,
        forceHD: true,
        enableCaption: true,
        useHybridComposition: true,
      ),
    );

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _initializeLocalVideo() async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl!));
    
    await _videoController!.initialize();
    
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: widget.autoplay,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.blue,
        handleColor: Colors.blue,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.lightBlue,
      ),
    );

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildVideoContent(),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeVideo,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_youtubeController != null) {
      return YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.blue,
        progressColors: const ProgressBarColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
        ),
      );
    }

    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    return const Center(
      child: Text(
        'Video not available',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  void pauseVideo() {
    _videoController?.pause();
    _youtubeController?.pause();
  }
} 