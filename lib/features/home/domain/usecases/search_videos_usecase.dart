import '../entities/video_entity.dart';
import '../repositories/youtube_repository.dart';

class SearchVideosUseCase {
  SearchVideosUseCase(this._repository);
  final YoutubeRepository _repository;

  Future<List<VideoEntity>> call(String query) => _repository.searchVideos(query);
}
