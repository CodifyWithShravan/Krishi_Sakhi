import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:http/http.dart' as http;
// Important: Make sure this package name matches your project's name in pubspec.yaml
import 'package:krishi_sakhi/secrets.dart'; 
import 'package:speech_to_text/speech_to_text.dart';

class ChatAdvisorPage extends StatefulWidget {
  const ChatAdvisorPage({super.key});

  @override
  State<ChatAdvisorPage> createState() => _ChatAdvisorPageState();
}

class _ChatAdvisorPageState extends State<ChatAdvisorPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  // Voice Recognition variables
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech(); // Initialize speech recognition
    _messages.add({
      'isUser': false,
      'text':
          'Hello! I am your AI Krishi Sakhi. How can I help you with your crops today?'
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- Voice Recognition Functions ---
  void _initSpeech() async {
    await _speechToText.initialize();
    setState(() {});
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          localeId: 'ml_IN', // Listen for Malayalam
          onResult: (result) => setState(() {
            _controller.text = result.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }
  
  // --- Send Message to AI Function ---
  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final userMessage = _controller.text;
    setState(() {
      _messages.add({'isUser': true, 'text': userMessage});
      _isLoading = true;
      if (_isListening) {
        _speechToText.stop();
        _isListening = false;
      }
    });
    _controller.clear();

    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$geminiApiKey');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text":
                    "You are Krishi Sakhi, a friendly and helpful AI assistant for farmers in Kerala, India. Provide concise, practical advice. Respond in the same language as the user's query (Malayalam or English)."
              },
              {"text": userMessage}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200 && mounted) {
      final responseBody = jsonDecode(response.body);
      final aiResponse =
          responseBody['candidates'][0]['content']['parts'][0]['text'];
      setState(() {
        _messages.add({'isUser': false, 'text': aiResponse});
      });
    } else {
      if (mounted) {
        setState(() {
          _messages.add({
            'isUser': false,
            'text': 'Sorry, I am having trouble connecting. Please try again.'
          });
        });
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- UI Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Crop Advisor')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                return ChatBubble(
                  clipper: ChatBubbleClipper1(
                      type: message['isUser']
                          ? BubbleType.sendBubble
                          : BubbleType.receiverBubble),
                  alignment: message['isUser']
                      ? Alignment.topRight
                      : Alignment.topLeft,
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  backGroundColor: message['isUser']
                      ? Theme.of(context).primaryColor
                      : Colors.white,
                  child: Text(
                    message['text'],
                    style: TextStyle(
                        color: message['isUser'] ? Colors.white : Colors.black),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator()),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Listening...'
                          : 'Ask about your crops...',
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: Icon(_isListening ? Icons.stop_circle_outlined : Icons.mic_none_outlined),
                  onPressed: _listen,
                  tooltip: 'Speak',
                  color: _isListening ? Colors.red : Theme.of(context).primaryColor,
                  iconSize: 30,
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  tooltip: 'Send',
                  color: Theme.of(context).primaryColor,
                  iconSize: 30,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}