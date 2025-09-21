import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:krishi_sakhi/secrets.dart';

class PestIdPage extends StatefulWidget {
  const PestIdPage({super.key});

  @override
  State<PestIdPage> createState() => _PestIdPageState();
}

class _PestIdPageState extends State<PestIdPage> {
  File? _image;
  String _result = 'No image selected.';
  bool _loading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _result = 'Image selected. Click Identify.';
      });
    }
  }

  Future<void> _identifyPest() async {
    if (_image == null) return;
    setState(() {
      _loading = true;
      _result = 'Analyzing...';
    });

    // 1. Read image as bytes and encode to Base64
    final imageBytes = await _image!.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    // 2. Prepare the API request
    final uri = Uri.parse('$roboflowModelEndpoint?api_key=$roboflowApiKey');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: base64Image,
    );

    // 3. Parse the response
    if (response.statusCode == 200 && mounted) {
      final responseBody = jsonDecode(response.body);
      if (responseBody['predictions'] != null && responseBody['predictions'].isNotEmpty) {
        final topPrediction = responseBody['predictions'][0];
        final diseaseName = topPrediction['class'];
        final confidence = (topPrediction['confidence'] * 100).toStringAsFixed(1);
        setState(() {
          _result = 'Detected: $diseaseName\nConfidence: $confidence%';
        });
      } else {
        setState(() { _result = 'Could not identify any disease.'; });
      }
    } else {
       setState(() { _result = 'Error connecting to the AI model.'; });
    }

    setState(() { _loading = false; });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pest & Disease ID')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              if (_image != null)
                Image.file(_image!, height: 250, width: 250, fit: BoxFit.cover)
              else
                Container(
                  height: 250,
                  width: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('Pick an image to preview')),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Pick from Gallery'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _image != null ? _identifyPest : null,
                icon: const Icon(Icons.biotech),
                label: const Text('Identify Disease'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary, // Uses theme's accent color
                ),
              ),
              const SizedBox(height: 30),
              _loading
                  ? const CircularProgressIndicator()
                  : Text(
                      _result,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}