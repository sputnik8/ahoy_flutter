import 'dart:io';

import 'package:ahoy_flutter/ahoy_flutter.dart';
import 'package:flutter/material.dart';

final ahoy = Ahoy(
  configuration: Configuration(
    environment: ApplicationEnvironment(
      appVersion: '1.0.0',
      deviceType: 'Mobile',
      platform: Platform.operatingSystem,
      os: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
    ),
    ahoyPath: 'api/v1',
    eventsPath: 'events/create',
    visitsPath: 'visits/upsert',
    baseUrl: 'localhost',
    port: 3001,
    scheme: 'http',
    batchConfig: const BatchConfig(
      maxBatchSize: 5,
      flushInterval: Duration(seconds: 10),
      maxRetries: 3,
    ),
  ),
  tokenStorage: const TokenManager(),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ahoy.initialize();
  await ahoy.trackVisit();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ahoy Batch Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Ahoy Batch Event Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ahoy.onAppLifecycleStateChange(state.name);
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
      ahoy.trackSingle('button_click', properties: {'counter': _counter});
    });
  }

  void _flushEvents() {
    ahoy.flush();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Tap the button to queue events:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Text(
              'Pending events: ${ahoy.pendingEventCount}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _flushEvents,
              child: const Text('Flush Events Now'),
            ),
            const SizedBox(height: 10),
            Text(
              'Auto-flush at 5 events or every 10 seconds',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Track Event',
        child: const Icon(Icons.add),
      ),
    );
  }
}
