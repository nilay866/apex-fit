import '../services/social_service.dart';
import 'auth_repository.dart';

class SocialFeedPage {
  final List<Map<String, dynamic>> items;
  final int nextOffset;
  final bool hasMore;

  const SocialFeedPage({
    required this.items,
    required this.nextOffset,
    required this.hasMore,
  });
}

class SocialRepository {
  const SocialRepository();

  Future<SocialFeedPage> fetchFeedPage({
    int offset = 0,
    int pageSize = 10,
  }) async {
    final items = await SocialService.getSocialFeedPage(
      userId: authRepository.requireUserId(),
      offset: offset,
      limit: pageSize,
    );

    return SocialFeedPage(
      items: items,
      nextOffset: offset + items.length,
      hasMore: items.length == pageSize,
    );
  }

  Future<List<Map<String, dynamic>>> searchProfiles(String query) {
    return SocialService.searchProfiles(query);
  }

  Future<void> connectWithUser(String otherUserId) {
    return SocialService.connectWithUser(otherUserId);
  }

  Future<Map<String, dynamic>> getVersusStats(String otherId) {
    return SocialService.getVersusStats(otherId);
  }
}

const socialRepository = SocialRepository();
