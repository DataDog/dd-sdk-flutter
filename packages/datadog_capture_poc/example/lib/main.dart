import 'package:datadog_capture_poc/datadog_capture_poc.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Key captureKey = GlobalKey();
  final DatadogCaptureManager _captureManager =
      DatadogCaptureManager('http://localhost:9000');
  int _counter = 0;

  void _incrementCounter() {
    _captureManager.performCapture();
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DatadogCapturingWidget(
      key: captureKey,
      manager: _captureManager,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(
                height: 200,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FlutterLogo(
                    size: 100,
                  ),
                  SizedBox.square(
                    dimension: 100,
                    child: Image.asset('assets/dd_icon_rgb.png'),
                  ),
                ],
              ),
              const Text(
                'You have pushed the button this many times:',
              ),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headline4,
              ),
              const SizedBox(
                height: 200,
              ),
              const Text("More text down here"),
              const SizedBox(
                height: 200,
              ),
              const Text("Even More text down here"),
              const Center(
                child: FlutterLogo(size: 150),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _incrementCounter,
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
