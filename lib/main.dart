import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:quincy/Dashboard/View/DashboardScreen.dart';
import 'package:quincy/Dashboard/View/ModeSelectionDialog.dart';
import 'package:quincy/Dashboard/ViewModel/DashboardViewModel.dart';
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/Food/Schedule/ViewModel/FoodInspectionScheduleViewModel.dart';
import 'package:quincy/Inspections/Food/ViewMOdel/FoodCheckListViewModel.dart';
import 'package:quincy/Inspections/Food/ViewMOdel/FoodInspectionViewModel.dart';
import 'package:quincy/Inspections/Food/ViewMOdel/FoodPermitViewModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodOperationTypeViewModel.dart';
import 'package:quincy/Inspections/MobileFood/Schedule/ViewModel/MobileFoodInspectionScheduleViewModel.dart';
import 'package:quincy/Inspections/MobileFood/ViewModel/MobileFoodCheckListViewModel.dart';
import 'package:quincy/Inspections/MobileFood/ViewModel/MobileFoodInspectionViewModel.dart';
import 'package:quincy/Inspections/MobileFood/ViewModel/MobileFoodPermitViewModel.dart';
import 'package:quincy/Inspections/TempFood/Schedule/ViewModel/TempFoodInspectionScheduleViewModel.dart';
import 'package:quincy/Inspections/TempFood/ViewModel/TempFoodChecklistViewModel.dart';
import 'package:quincy/Inspections/TempFood/ViewModel/TempFoodInspectionViewModel.dart';
import 'package:quincy/Inspections/TempFood/ViewModel/TempFoodPermitViewModel.dart';
import 'package:quincy/Inspector/ViewModel/InspectorViewModel.dart';
import 'package:quincy/Login/View/login.dart';
import 'package:quincy/Login/ViewModel/LoginViewModel.dart';
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
final dbPath = join(await getDatabasesPath(), 'quincy_auth.db');
  debugPrint('📂 DB path: $dbPath');
  // ---- Auto login check ----
  Widget startScreen = const LoginScreen();

  try {
    final db = DBManager.instance;
    if (await db.isLoggedIn()) {
      final savedMode = await db.getAppMode();
      final mode = savedMode == AppMode.ai.name ? AppMode.ai : AppMode.normal;
      startScreen = DashboardScreen(mode: mode);
    }
  } catch (e) {
    debugPrint('❌ Auto login check failed: $e');
    // fall back to LoginScreen
  }

  runApp(
    MultiProvider(
      providers: [
        //-------Mobile Food
      ChangeNotifierProvider(create: (_) => LoginViewModel()),
      ChangeNotifierProvider(create: (_) => DashboardViewModel()),
      ChangeNotifierProvider(create: (_) => MobileFoodPermitViewModel()),
      ChangeNotifierProvider(create: (_) => MobileFoodInspectionViewModel()),
      ChangeNotifierProvider(create: (_) => MobileFoodChecklistViewModel()),
      ChangeNotifierProvider(create: (_) => MobileFoodOperationTypeViewModel()),
      ChangeNotifierProvider(create: (_) => InspectorViewModel()),
      ChangeNotifierProvider(create: (_) => MobileFoodInspectionScheduleViewModel()),
      ChangeNotifierProvider(create: (_) => MobileFoodChecklistViewModel()),
      ChangeNotifierProvider(create: (_) => MobileFoodPermitViewModel()),

      // ---- Food ----
      ChangeNotifierProvider(create: (_) => FoodPermitViewModel()),
      ChangeNotifierProvider(create: (_) => FoodChecklistViewModel()),
      ChangeNotifierProvider(create: (_) => FoodInspectionViewModel()),
      ChangeNotifierProvider(create: (_) => FoodInspectionScheduleViewModel()),

      // ---- Temporary Food ----
        ChangeNotifierProvider(create: (_) => TempFoodPermitViewModel()),
        ChangeNotifierProvider(create: (_) => TempFoodChecklistViewModel()),
        ChangeNotifierProvider(create: (_) => TempFoodInspectionViewModel()),
        ChangeNotifierProvider(
            create: (_) => TempFoodInspectionScheduleViewModel()),
      ],
      child: MyApp(startScreen: startScreen),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget startScreen;

  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quincy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: startScreen,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
