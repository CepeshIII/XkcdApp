import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(
        title: 'Xkcd app',
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<Data> data = fetchImage();

  @override
  Widget build(BuildContext context) {
    var body = FutureBuilder<Data>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          if (snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView(children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      snapshot.data!.header,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 40.0,
                          color: Colors.black,
                          fontFamily: "Caveat",
                          fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 20.0),
                    snapshot.data!.img,
                    const SizedBox(height: 20.0),
                    Text(
                      snapshot.data!.text,
                      textAlign: TextAlign.justify,
                      style: const TextStyle(
                          fontSize: 16.0,
                          color: Colors.black,
                          fontFamily: "Caveat",
                          fontWeight: FontWeight.w300),
                    )
                  ],
                )
              ]),
            );
          } else if (snapshot.hasError) {
            return Image.asset('assets/404.jpg');
          }

          return const CircularProgressIndicator();
        });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title),
      ),
      body: Center(child: body),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: () {
          setState(() {
            data = fetchImage();
          });
        },
        child: const Icon(Icons.update),
      ),
    );
  }
}

class Data {
  late Image img;
  late String header;
  late String text;
  late Uint8List rawImg;

  Data({
    required this.rawImg,
    required this.header,
    this.text = '',
  }) {
    img = Image.memory(rawImg);
  }
}

Future<int> fetchCount() async {
  final response = await http.get(Uri.parse('https://xkcd.com/info.0.json'));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data["num"];
  } else {
    throw Exception('Failed to load album');
  }
}

Future<Data> fetchRandomImage() async {
  final num = await fetchCount();

  var rng = Random();
  var i = rng.nextInt(num) + 1;

  final response = await http.get(Uri.parse('https://xkcd.com/$i/info.0.json'));
  if (response.statusCode != 200) {
    throw Exception('Failed to load album');
  }
  var data = jsonDecode(response.body);
  var image = await http.get(Uri.parse(data["img"]));

  return Data(
      rawImg: image.bodyBytes, header: data["title"], text: data["alt"]);
}

Future saveData(Data data) async {
  final prefs = await SharedPreferences.getInstance();
  prefs.setString("header", data.header);
  prefs.setString("text", data.text);
  prefs.setString("img", base64.encode(data.rawImg));
}

Future<Data?> loadData() async {
  final prefs = await SharedPreferences.getInstance();
  var header = prefs.getString("header");
  var text = prefs.getString("text");
  var imgBase64 = prefs.getString("img");
  if (header == null || text == null || imgBase64 == null) {
    return null;
  }

  var img = base64.decode(imgBase64);

  return Data(rawImg: img, header: header, text: text);
}

Future<Data> fetchImage() async {
  try {
    var r = await fetchRandomImage();
    await saveData(r);
    return r;
  } catch (e) {
    var data = await loadData();
    if (data != null) {
      return data;
    } else {
      throw Exception("Error");
    }
  }
}
