import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dummy_apps/model/rating.dart';
import 'package:dummy_apps/providers/ratings.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dummy_apps/utils/auth-service.dart';

class RatingWidget extends ConsumerStatefulWidget {
  const RatingWidget({super.key, required this.product});

  final dynamic product;

  @override
  ConsumerState<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends ConsumerState<RatingWidget> {
  bool isAddingReview = false;

  final TextEditingController controller = TextEditingController();

  int ratingGiven = 1;
  String _currentUserName = 'Anonymous';
  String _currentUserId = '1';
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    ref.read(ratingsProvider.notifier).fetchRating(widget.product.id);
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      _isLoggedIn = await AuthService.isLoggedIn();
      final storedName = await AuthService.getUserName();
      if (storedName != null && storedName.isNotEmpty) {
        _currentUserName = storedName;
      } else {
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: 'token');
        if (token != null) {
          final decoded = JwtDecoder.decode(token);
          if (decoded['name'] != null) {
            _currentUserName = decoded['name'];
            await AuthService.saveUserName(_currentUserName);
          }
          if (decoded['userId'] != null) {
            _currentUserId = decoded['userId'];
          }
        }
      }
      setState(() {});
    } catch (e) {
      print("Error loading user info in RatingWidget: $e");
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> addReview() async {
    final description = controller.text.trim();
    if (description.isEmpty) return;

    final rating = Rating(
      productId: widget.product.id,
      description: description,
      likeCount: 0,
      dislikeCount: 0,
      likedBy: [],
      dislikedBy: [],
      user: _currentUserName,
      rating: ratingGiven.toDouble(),
      timestamp: DateTime.now(),
    );

    try {
      await ref.read(ratingsProvider.notifier).addRating(rating);
      await ref.read(ratingsProvider.notifier).fetchRating(widget.product.id);

      controller.clear();
      setState(() {
        isAddingReview = false;
        ratingGiven = 1;
      });
    } catch (exception) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit review. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratingsList = ref.watch(ratingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpansionTile(
          title: const Text('Summarized Review'),
          children: [
            FutureBuilder<String>(
              future: ref
                  .read(ratingsProvider.notifier)
                  .fetchSummary(widget.product.id.toString()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Failed to load summary'),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    snapshot.data ?? "Not available",
                    style: const TextStyle(fontSize: 15),
                  ),
                );
              },
            ),
          ],
        ),

        ExpansionTile(
          title: const Text('Reviews'),

          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const SizedBox(height: 10),

                  isAddingReview
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            DropdownButton<int>(
                              value: ratingGiven,

                              items: List.generate(5, (index) {
                                return DropdownMenuItem(
                                  value: index + 1,
                                  child: Text('${index + 1}'),
                                );
                              }),

                              onChanged: (value) {
                                if (value == null) return;

                                setState(() {
                                  ratingGiven = value;
                                });
                              },
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'Reviewing as: $_currentUserName',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 12),

                            TextField(
                              controller: controller,
                              maxLines: 3,

                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: _isLoggedIn ? addReview : null,
                                  child: const Text('Submit'),
                                ),

                                const SizedBox(width: 10),

                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      isAddingReview = false;
                                    });
                                  },
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ],
                        )
                      : TextButton(
                          onPressed: () {
                            if (!_isLoggedIn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please login to submit a review.',
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              isAddingReview = true;
                            });
                          },
                          child: Text(
                            _isLoggedIn ? 'Add Rating' : 'Login to add review',
                          ),
                        ),

                  const SizedBox(height: 20),

                  if (ratingsList.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No reviews yet'),
                      ),
                    ),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ratingsList.length,

                    itemBuilder: (context, index) {
                      final rating = ratingsList[index];

                      final isLiked = rating.likedBy.contains(_currentUserId);
                      final isDisliked = rating.dislikedBy.contains(
                        _currentUserId,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 15),

                        child: Padding(
                          padding: const EdgeInsets.all(16),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(),

                                  const SizedBox(width: 10),

                                  Text(
                                    rating.user.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              Text(
                                '${rating.rating}/5',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),

                              const SizedBox(height: 10),

                              Text(rating.description),

                              const SizedBox(height: 15),

                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () async {
                                      if (rating.id != null) {
                                        await ref
                                            .read(ratingsProvider.notifier)
                                            .upvote(rating.id!, _currentUserId);
                                      }
                                    },

                                    icon: Icon(
                                      isLiked
                                          ? Icons.thumb_up
                                          : Icons.thumb_up_outlined,
                                      color: isLiked
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),

                                  Text(rating.likeCount.toString()),

                                  const SizedBox(width: 25),

                                  IconButton(
                                    onPressed: () async {
                                      if (rating.id != null) {
                                        await ref
                                            .read(ratingsProvider.notifier)
                                            .downvote(
                                              rating.id!,
                                              _currentUserId,
                                            );
                                      }
                                    },

                                    icon: Icon(
                                      isDisliked
                                          ? Icons.thumb_down
                                          : Icons.thumb_down_outlined,
                                      color: isDisliked
                                          ? Theme.of(context).colorScheme.error
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),

                                  Text(rating.dislikeCount.toString()),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
