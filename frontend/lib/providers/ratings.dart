import 'package:dummy_apps/model/rating.dart';
import 'package:dummy_apps/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import 'package:flutter/foundation.dart';

class RatingsProvider extends Notifier<List<Rating>> {
  @override
  List<Rating> build() => [];

  Future<String> fetchSummary(String productId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/fetchSummary/$productId"),
      );

      print("response returned by nodejs: ${response.body}");

      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data["summary"] ?? "Not available";
      } else {
        final message = data['message'] ?? data['error'] ?? 'Failed to fetch summary';
        throw Exception(message.toString());
      }
    } catch (e) {
      print("fetchSummary error: $e");
      return "Not available due to error";
    }
  }

  Future<List<Rating>> fetchRating(String productId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/rating/$productId"),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> ratingsJson = data['ratings'] ?? [];
        state = ratingsJson.map<Rating>((e) => Rating.fromJson(e)).toList();
      }
      return state;
    } catch (e) {
      print("fetchRating error: $e");
      throw "Server Error";
    }
  }

  Future<List<Rating>> addRating(Rating rating) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/addRating/${rating.productId}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(rating.toJson()),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['ratings'] != null && data['ratings'] is List) {
          final list = (data['ratings'] as List)
              .map<Rating>((r) => Rating.fromJson(r))
              .toList();
          state = list;
        } else if (data['rating'] != null) {
          final newRating = Rating.fromJson(data['rating']);
          final existingIndex = state.indexWhere(
            (item) => item.id == newRating.id,
          );
          if (existingIndex >= 0) {
            state = [
              for (var i = 0; i < state.length; i++)
                if (i == existingIndex) newRating else state[i],
            ];
          } else {
            state = [...state, newRating];
          }
        }

        return state;
      } else {
        throw "Failed to add rating";
      }
    } catch (e) {
      print("addRating error: $e");
      throw "Server error";
    }
  }

  Future<void> upvote(String ratingId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/rating/$ratingId/upvote"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": userId}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> ratingsJson = data['ratings'] ?? [];
        if (ratingsJson.isNotEmpty) {
          state = ratingsJson.map<Rating>((e) => Rating.fromJson(e)).toList();
        } else if (data['rating'] != null) {
          final updatedRating = Rating.fromJson(data['rating']);
          state = state
              .map((item) => item.id == updatedRating.id ? updatedRating : item)
              .toList();
        }
      }
    } catch (e) {
      print("upvote error: $e");
    }
  }

  Future<void> downvote(String ratingId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/rating/$ratingId/downvote"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": userId}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> ratingsJson = data['ratings'] ?? [];
        if (ratingsJson.isNotEmpty) {
          state = ratingsJson.map<Rating>((e) => Rating.fromJson(e)).toList();
        } else if (data['rating'] != null) {
          final updatedRating = Rating.fromJson(data['rating']);
          state = state
              .map((item) => item.id == updatedRating.id ? updatedRating : item)
              .toList();
        }
      }
    } catch (e) {
      print("downvote error: $e");
    }
  }
}

final ratingsProvider = NotifierProvider<RatingsProvider, List<Rating>>(
  RatingsProvider.new,
);
