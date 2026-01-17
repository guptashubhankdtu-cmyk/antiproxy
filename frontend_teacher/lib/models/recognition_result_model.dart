import 'package:flutter/material.dart';

class RecognitionResultModel {
  final Rect boundingBox;
  final String name;
  final double similarityScore;

  RecognitionResultModel({
    required this.boundingBox,
    required this.name,
    required this.similarityScore,
  });

  // Factory constructor to create an instance from a JSON map
  factory RecognitionResultModel.fromJson(Map<String, dynamic> json) {
    // Assuming the bounding box in JSON is a map like {'left': 10.0, 'top': 20.0, ...}
    final box = json['boundingBox'];
    return RecognitionResultModel(
      boundingBox: Rect.fromLTWH(
        box['left'].toDouble(),
        box['top'].toDouble(),
        box['width'].toDouble(),
        box['height'].toDouble(),
      ),
      name: json['name'],
      similarityScore: json['similarityScore'].toDouble(),
    );
  }

  // Method to convert an instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'boundingBox': {
        'left': boundingBox.left,
        'top': boundingBox.top,
        'width': boundingBox.width,
        'height': boundingBox.height,
      },
      'name': name,
      'similarityScore': similarityScore,
    };
  }
}