// lib/models/post.dart
class Post {
  final int id;
  final String userLogin;
  final int? postId; // id do post pai se for reply
  final String message;
  final String? createdAt;
  final String? updatedAt;

  int likeCount;
  int? myLikeId;

  // Respostas
  List<Post> replies;
  bool repliesLoaded;

  Post({
    required this.id,
    required this.userLogin,
    required this.postId,
    required this.message,
    this.createdAt,
    this.updatedAt,
    this.likeCount = 0,
    this.myLikeId,
    List<Post>? replies,
    this.repliesLoaded = false,
  }) : replies = replies ?? List<Post>.empty(growable: true);

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: (json['id'] as num).toInt(),
      userLogin: (json['user_login'] ?? '') as String,
      postId: (json['post_id'] as num?)?.toInt(),
      message: (json['message'] ?? '') as String,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      likeCount: 0,
      myLikeId: null,
      replies: List<Post>.empty(growable: true),
      repliesLoaded: false,
    );
  }

  Post copyWith({
    int? id,
    String? userLogin,
    int? postId,
    String? message,
    String? createdAt,
    String? updatedAt,
    int? likeCount,
    int? myLikeId,
    List<Post>? replies,
    bool? repliesLoaded,
  }) {
    return Post(
      id: id ?? this.id,
      userLogin: userLogin ?? this.userLogin,
      postId: postId ?? this.postId,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likeCount: likeCount ?? this.likeCount,
      myLikeId: myLikeId ?? this.myLikeId,
      replies: replies ?? this.replies,
      repliesLoaded: repliesLoaded ?? this.repliesLoaded,
    );
  }
}
