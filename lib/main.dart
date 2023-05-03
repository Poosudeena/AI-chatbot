import 'dart:async';
import 'dart:convert';
import 'package:telephony/telephony.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:reflex/reflex.dart';
import 'package:http/http.dart' as http;

import 'utils/custom_values.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({
    Key? key,
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<ReflexEvent>? _subscription;
  final List<ReflexEvent> _notificationLogs = [];
  final List<ReflexEvent> _autoReplyLogs = [];
  bool isListening = false;
  String message = '';
  final telephony = Telephony.instance;
  List<Contact>? contacts;
  late bool permissionsGranted;
  String question='',answer='',name=''; 
  String baseUrl ='http://192.168.43.84/ai_bot/';

  @override
  void initState() {
    super.initState();
    initPlatformState();
    getContacts();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    startListening();
  }

  void onData(ReflexEvent event) {
    setState(() {
      if (event.type == ReflexEventType.notification) {
        _notificationLogs.add(event);
        fetchAnswer(event.message.toString(),event.title.toString());
      } else if (event.type == ReflexEventType.reply) {
        _autoReplyLogs.add(event);
      }
    });
    debugPrint(event.toString());
    setState(() {});
  }

  getMessage(msg) {
    return msg;
  }

  void startListening() async {
    try {
      Reflex reflex = Reflex(
        debug: true,
        packageNameList: ["com.whatsapp", "com.tyup","com.message"],
        packageNameExceptionList: ["com.facebook"],
      );
      _subscription = reflex.notificationStream!.listen(onData);
      setState(() {
        isListening = true;
      });
    } on ReflexException catch (exception) {
      debugPrint(exception.toString());
    }
  }

 
  void stopListening() {
    _subscription?.cancel();
    setState(() => isListening = false);
  }

  getContacts() async {
    if (await FlutterContacts.requestPermission()) {
      if ((await telephony.requestPhoneAndSmsPermissions)!) {
        contacts = await FlutterContacts.getContacts(withProperties: true);
      }
    }
  }

  getNumber(String name,answer_q) {
    // try {
      print(name);
      for (var i = 0; i < contacts!.length; i++) {
        if (contacts![i].displayName == name) {
          print(contacts![i].phones.first.number);
          if (contacts![i].phones.isNotEmpty) {
            telephony.sendSms(
                to: contacts![i].phones.first.number, message: answer_q);
          }
        }
      }
    // } catch (e) {
    //   print(e.toString());
    // }
  }

  fetchAnswer(String message,person) async {
    try {
      var response =
          await http.post(Uri.parse('${baseUrl}get-answer.php'), body: {
        "question": message,
      });
      var result = await json.decode(response.body);
      print(response.body);
      if (result['success']) {
        answer = result['answer'];
        setState(() {});
        getNumber(person,answer+" and I am in Driving Mode");
      } else {
        print(result['message']);
      }
    } catch (e) {
      print(e);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          actions: [
           Icon(Icons.settings),SizedBox(width: 20,)],
          backgroundColor: Colors.black,
          title: const Text('AI Chat BOT'),
        ),
        body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text("You are in Driving Mode",style: TextStyle(
                color: Colors.red,
                fontSize: 25,
                fontWeight: FontWeight.w600
              ),),
              notificationListener(),
              // autoReply(),
              // permissions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget permissions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          child: const Text("See Permission"),
          onPressed: () async {
            bool isPermissionGranted = await Reflex.isPermissionGranted;
            debugPrint("Notification Permission: $isPermissionGranted");
          },
          style: ElevatedButton.styleFrom(
            fixedSize: const Size(170, 8),
          ),
        ),
        ElevatedButton(
          child: const Text("Request Permission"),
          onPressed: () async {
            await Reflex.requestPermission();
          },
          style: ElevatedButton.styleFrom(
            fixedSize: const Size(170, 8),
          ),
        ),
      ],
    );
  }

  Widget notificationListener() {
    return SizedBox(
      height: 700,
      child: Column(
        children: [
          SizedBox(
            height: 600,
            child: ListView.builder(
              reverse: true,
              itemCount: _notificationLogs.length,
              itemBuilder: (BuildContext context, int index) {
                final ReflexEvent element = _notificationLogs[index];
                return ListTile(
                  title: Text(element.title ?? ""),
                  subtitle: Text(element.message ?? ""),
                  trailing: Text(
                    element.packageName.toString().split('.').last,
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black
                ),
                icon: isListening
                    ? const Icon(Icons.stop)
                    : const Icon(Icons.play_arrow),
                label: const Text("Reflex Notification Listener"),
                onPressed: () {
                  if (isListening) {
                    stopListening();
                  } else {
                    startListening();
                  }
                },
              ),
              if (_notificationLogs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      primary: Colors.red,
                    ),
                    icon: const Icon(Icons.clear),
                    label: const Text(
                      "Clear List",
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _notificationLogs.clear();
                      });
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget autoReply() {
    return SizedBox(
      height: 265,
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _autoReplyLogs.length,
              itemBuilder: (BuildContext context, int index) {
                final ReflexEvent element = _autoReplyLogs[index];
                return ListTile(
                  title: Text("AutoReply to: ${element.title}"),
                  subtitle: Text(element.message ?? ""),
                  trailing: Text(
                    element.packageName.toString().split('.').last,
                  ),
                );
              },
            ),
          ),
          if (_autoReplyLogs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  primary: Colors.red,
                ),
                icon: const Icon(Icons.clear),
                label: const Text(
                  "Clear List",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _autoReplyLogs.clear();
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}
