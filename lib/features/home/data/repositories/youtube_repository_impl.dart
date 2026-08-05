import '../../../../services/youtube_service.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/repositories/youtube_repository.dart';

class YoutubeRepositoryImpl implements YoutubeRepository {
  YoutubeRepositoryImpl(this._service);
  final YoutubeService _service;

  @override
  Future<List<VideoEntity>> searchVideos(String query) {
    return _service.searchVideos(query: query);
  }

  @override
  Future<VideoEntity?> getVideoDetails(String videoId) {
    return _service.getVideoDetails(videoId);
  }

  @override
  Future<List<VideoEntity>> getRelatedVideos(String videoId) {
    return _service.getRelatedVideos(videoId);
  }
}
