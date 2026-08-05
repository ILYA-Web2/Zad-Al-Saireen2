// ─── Abstract Repository ──────────────────────────────────────────────────────
import '../../domain/entities/video_entity.dart';

abstract class YoutubeRepository {
  Future<List<VideoEntity>> searchVideos(String query);
  Future<VideoEntity?> getVideoDetails(String videoId);
  Future<List<VideoEntity>> getRelatedVideos(String videoId);
}
