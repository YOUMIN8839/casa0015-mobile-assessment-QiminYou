import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Pages/login_screen.dart';
import 'Pages/register_screen.dart';
import 'main_page/calendar/calendar_screen.dart';
import 'Pages/input_page/input_page.dart';
import 'main_page/map_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/Pages/tutorial.dart';
import '/Pages/feedback_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isFirstLaunch = (prefs.getBool('first_launch') ?? true);

  Widget homeScreen = isFirstLaunch ? TutorialScreen() : MainScreen();

  if (isFirstLaunch) {
    await prefs.setBool('first_launch', false);
  }

  runApp(MyApp(homeScreen: homeScreen));
}

class MyApp extends StatelessWidget {
  final Widget homeScreen;

  MyApp({required this.homeScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: homeScreen,
      routes: {
        '/MainScreen': (context) => MainScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/choicePage': (context) => ChoicePage(),
        '/calendar': (context) => CalendarScreen(),
        '/map': (context) => MapScreen(),

      },
    );
  }
}



class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _children = [
    CalendarScreen(),
    MapScreen(),
  ];

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Drawer buildDrawer() {
    final User? user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(user?.displayName ?? "Guest"),
            accountEmail: Text(user?.email ?? "Please log in"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user?.displayName?.isNotEmpty == true ? user!.displayName!.substring(0, 1) : "G",
                style: TextStyle(fontSize: 40.0),
              ),
            ),
          ),
          if (user == null) ...[
            ListTile(
              leading: Icon(Icons.login),
              title: Text('Login'),
              onTap: () {
                Navigator.pushNamed(context, '/login');
              },
            ),
            ListTile(
              leading: Icon(Icons.app_registration),
              title: Text('Register'),
              onTap: () {
                Navigator.pushNamed(context, '/register');
              },
            ),
          ] else ...[
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => MainScreen()),
                );
                setState(() {});
              },
            ),
            ListTile(
              leading: Icon(Icons.account_circle),
              title: Text('Account Details'),
              onTap: () {
                // Navigate to account details or similar
              },
            ),
            ListTile(
              leading: Icon(Icons.feedback),
              title: Text('Feedback'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FeedbackScreen()),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Discount Manager"),
        centerTitle: true,),
      drawer: buildDrawer(), // Add the drawer here
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/choicePage');
        },
        child: Icon(Icons.add),
      ),
      body: _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        onTap: onTabTapped,
        currentIndex: _currentIndex,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
      ),
    );
  }
}
