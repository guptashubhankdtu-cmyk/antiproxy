import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/recognition_result_model.dart';

class ApiService {
  // Updated to new project face API service
  final String _backendUrl =
      "https://face-api-27dvlwurxq-el.a.run.app/recognize_faces";

  Future<(String processedImagePath, List<RecognitionResultModel> results)>
      processImageForAttendance(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(bytes);
      final body = jsonEncode({'image_data': base64Image});

      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Extract the two main parts from the response
        final String processedImageBase64 =
            responseData['processed_image_base64'];
        final List<dynamic> resultsJsonList = responseData['results_json'];

        // Decode the processed image and save it locally
        final processedImageBytes = base64Decode(processedImageBase64);
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final processedImagePath = p.join(directory.path, fileName);
        await File(processedImagePath).writeAsBytes(processedImageBytes);

        // Parse the list of results into your data models
        final List<RecognitionResultModel> recognitionResults = resultsJsonList
            .map((item) =>
                RecognitionResultModel.fromJson(item as Map<String, dynamic>))
            .toList();

        // Return both pieces of data
        return (processedImagePath, recognitionResults);
      } else {
        throw Exception(
            'Failed to process image: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint("API Service Error: $e");
      rethrow;
    }
  }
}
