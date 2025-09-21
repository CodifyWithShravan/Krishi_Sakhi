import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:krishi_sakhi/secrets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // State variables for Supabase, Voice Assistant, and Dashboard
  final _supabase = Supabase.instance.client;
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _lastWords = '';
  String _intent = '';
  String _weatherSnippet = 'Loading weather...';
  Map<String, dynamic>? _latestNews;
  String _userName = 'Farmer';
  bool _isLoadingDashboard = true;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _loadDashboardData(); // This will fetch all our data
  }

  // --- Dashboard Data Loading Functions ---

  Future<void> _loadDashboardData() async {
    await _getWeatherSnippet();
    await _getLatestNews();
    await _getUserName();
    if (mounted) {
      setState(() {
        _isLoadingDashboard = false;
      });
    }
  }

  // In lib/home_page.dart, find and replace this function

Future<void> _getUserName() async {
  try {
    final userId = _supabase.auth.currentUser!.id;
    // Now we select the 'username' column
    final data = await _supabase.from('profiles').select('username').eq('id', userId).single();
    final username = data['username'];
    
    if (username != null && username.isNotEmpty) {
      if (mounted) setState(() => _userName = username);
    } else {
      // Fallback to email if username is not set
      if (mounted) setState(() => _userName = _supabase.auth.currentUser?.email ?? 'Farmer');
    }
  } catch (e) {
    // Fallback to email if profile doesn't exist or an error occurs
    if (mounted) setState(() => _userName = _supabase.auth.currentUser?.email ?? 'Farmer');
  }
}
  Future<void> _getWeatherSnippet() async {
    const lat = 9.9312; // Kochi
    const lon = 76.2673;
    final weatherUri = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$openWeatherApiKey&units=metric&lang=ml');
    try {
      final weatherResponse = await http.get(weatherUri);
      if (weatherResponse.statusCode == 200 && mounted) {
        final weatherData = jsonDecode(weatherResponse.body);
        final description = weatherData['weather'][0]['description'];
        final temperature = weatherData['main']['temp'];
        setState(() => _weatherSnippet = '$temperature°C, $description');
      }
    } catch (e) {
      if (mounted) setState(() => _weatherSnippet = 'Could not fetch weather.');
    }
  }

  Future<void> _getLatestNews() async {
    try {
      final data = await _supabase.from('news_schemes').select().order('created_at', ascending: false).limit(1).single();
      if (mounted) setState(() => _latestNews = data);
    } catch (e) {
      // Silently handle error or no news found
    }
  }

  // --- Voice Assistant Functions ---

  void _initTts() async {
    await _flutterTts.setLanguage("ml-IN");
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _initSpeech() async {
    await Permission.microphone.request();
    await _speechToText.initialize();
    if (mounted) setState(() {});
  }

  void _startListening() async {
    setState(() {
      _lastWords = '';
      _intent = '';
    });
    await _speechToText.listen(
      onResult: (result) => setState(() => _lastWords = result.recognizedWords),
      localeId: 'ml_IN',
    );
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
    if (_lastWords.isNotEmpty) _getIntentFromWitAi(_lastWords);
  }

  Future<void> _getIntentFromWitAi(String text) async {
    try {
      final encodedText = Uri.encodeComponent(text);
      final uri = Uri.parse('https://api.wit.ai/message?q=$encodedText');
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $witAiServerToken'});
      if (response.statusCode == 200 && mounted) {
        final responseBody = jsonDecode(response.body);
        String intentName = 'No intent found';
        if (responseBody['intents'] != null && responseBody['intents'].isNotEmpty) {
          intentName = responseBody['intents'][0]['name'];
        }
        setState(() => _intent = intentName);
        _actOnIntent(intentName);
      }
    } catch (e) {
      // Handle error
    }
  }

// In lib/home_page.dart, find and replace this function

Future<void> _actOnIntent(String intent) async {
  String responseText = '';
  final supabase = Supabase.instance.client;

  switch (intent) {
    case 'get_weather':
      // The assistant's "brain" for weather advice
      String advice = '';
      try {
        // First, get the user's profile to know their crop
        final userId = supabase.auth.currentUser!.id;
        final profileData = await supabase.from('profiles').select('crop_type').eq('id', userId).single();
        final userCrop = profileData['crop_type'] as String?;

        // Then, get the live weather
        const lat = 9.9312; // Kochi
        const lon = 76.2673;
        final weatherUri = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$openWeatherApiKey&units=metric&lang=ml');
        final weatherResponse = await http.get(weatherUri);

        if (weatherResponse.statusCode == 200) {
          final weatherData = jsonDecode(weatherResponse.body);
          final mainWeather = weatherData['weather'][0]['main'].toString().toLowerCase();
          final temperature = weatherData['main']['temp'];

          // Construct the basic weather report
          responseText = 'ഇപ്പോഴത്തെ താപനില $temperature ഡിഗ്രി സെൽഷ്യസ് ആണ്.';

          // --- ADVISORY LOGIC STARTS HERE ---
          if (mainWeather.contains('rain')) {
            advice = ' മഴ പ്രതീക്ഷിക്കുന്നതിനാൽ, വളപ്രയോഗം, കീടനാശിനി തളിക്കൽ എന്നിവ ഒഴിവാക്കുന്നതാണ് നല്ലത്.';
          } else if (mainWeather.contains('clear') && temperature > 30) {
            advice = ' നല്ല വെയിലുള്ള ദിവസമാണ്. വിളകൾക്ക് ആവശ്യത്തിന് ജലസേചനം ഉറപ്പാക്കുക.';
            if (userCrop != null && userCrop.toLowerCase() == 'rice') {
              advice += ' നെൽപ്പാടങ്ങളിൽ വെള്ളം നിലനിർത്താൻ പ്രത്യേകം ശ്രദ്ധിക്കുക.';
            }
          } else if (mainWeather.contains('wind')) {
            advice = ' ശക്തമായ കാറ്റിന് സാധ്യതയുണ്ട്. മരുന്ന് തളിക്കുന്നത് ഒഴിവാക്കുക.';
          } else {
            advice = ' കൃഷിപ്പണിക്ക് അനുയോജ്യമായ കാലാവസ്ഥയാണ്.';
          }
          responseText += advice; // Add the advice to the report
        } else {
          responseText = 'ക്ഷമിക്കണം, എനിക്ക് കാലാവസ്ഥ ലഭിച്ചില്ല.';
        }
      } catch (e) {
        responseText = 'ക്ഷമിക്കണം, ഉപദേശം നൽകുന്നതിൽ ഒരു പിശകുണ്ടായി.';
      }
      break;

    case 'log_activity':
      // ... (This case remains the same)
      try {
        final userId = supabase.auth.currentUser!.id;
        await supabase.from('activities').insert({'activity_description': _lastWords, 'user_id': userId});
        responseText = 'നിങ്ങളുടെ പ്രവർത്തനം വിജയകരമായി രേഖപ്പെടുത്തിയിരിക്കുന്നു.';
      } catch (error) {
        responseText = 'ക്ഷമിക്കണം, നിങ്ങളുടെ പ്രവർത്തനം രേഖപ്പെടുത്തുന്നതിൽ ഒരു പിശകുണ്ടായി.';
      }
      break;

    default:
      responseText = 'ക്ഷമിക്കണം, എനിക്ക് മനസ്സിലായില്ല. ദയവായി ഒന്നുകൂടി പറയുക.';
      break;
  }
  _speak(responseText); // Speak the final combined response
}

  // --- Build Method for the UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Krishi Sakhi Dashboard'),
        actions: [
          // NEW BUTTON STARTS HERE
    IconButton(
      onPressed: () {
        Navigator.of(context).pushNamed('/pest_id');
      },
      icon: const Icon(Icons.bug_report_outlined),
      tooltip: 'Pest & Disease ID',
    ),
    // NEW BUTTON ENDS HERE
          IconButton(onPressed: () => Navigator.of(context).pushNamed('/calendar'), icon: const Icon(Icons.calendar_today), tooltip: 'Crop Calendar'),
          IconButton(onPressed: () => Navigator.of(context).pushNamed('/news'), icon: const Icon(Icons.article), tooltip: 'News & Schemes'),
          IconButton(onPressed: () => Navigator.of(context).pushNamed('/profile'), icon: const Icon(Icons.person), tooltip: 'Profile'),
          IconButton(onPressed: () async { await _supabase.auth.signOut(); if (context.mounted) Navigator.of(context).pushReplacementNamed('/login'); }, icon: const Icon(Icons.logout), tooltip: 'Logout'),
        ],
      ),
      body: _isLoadingDashboard
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Theme.of(context).primaryColor,
                  child: Padding(padding: const EdgeInsets.all(20.0), child: Text('Welcome,\n$_userName', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Weather (Kochi)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).primaryColor)),
                        const SizedBox(height: 8),
                        Text(_weatherSnippet, style: const TextStyle(fontSize: 18)),
                      ],
                    ),
                  ),
                ),
                if (_latestNews != null)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: const Text('Latest News', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_latestNews!['title']),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => Navigator.of(context).pushNamed('/news'),
                    ),
                  ),
                const SizedBox(height: 24),
                const Center(child: Text('Press the microphone to ask a question or log an activity', style: TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center,)),
                const SizedBox(height: 12),
                Center(child: Text(_lastWords, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
                const SizedBox(height: 12),
                Center(child: Text(_intent, style: TextStyle(fontSize: 18, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _isListening ? _stopListening : _startListening,
        tooltip: 'Ask Krishi Sakhi',
        child: Icon(_isListening ? Icons.mic_off : Icons.mic),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
  
}