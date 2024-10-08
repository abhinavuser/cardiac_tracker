import 'package:flutter/material.dart';

void main() => runApp(CardiacMonitoringApp());

class CardiacMonitoringApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real-Time Cardiac Monitoring',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomeScreen(),
    DiscoverScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cardiac Monitoring'),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Home Screen: Displays real-time heart rate and other vital information
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double heartRate = 72.0;

  @override
  void initState() {
    super.initState();
    // Simulate real-time heart rate changes
    Future.delayed(Duration.zero, _updateHeartRate);
  }

  void _updateHeartRate() {
    setState(() {
      heartRate = 60 + (20 * (1 + (heartRate % 40) / 40)); // Simulated change
    });
    Future.delayed(Duration(seconds: 2), _updateHeartRate); // Simulate updates
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Real-Time Heart Rate',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Text(
            '$heartRate bpm',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: heartRate > 100 ? Colors.red : Colors.green,
            ),
          ),
          SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              // Future button for detailed monitoring or sensor connection
            },
            child: Text('View Detailed Report'),
          ),
        ],
      ),
    );
  }
}

// Discover Screen: Health tips and resources
class DiscoverScreen extends StatelessWidget {
  final List<Map<String, String>> healthTips = [
    {'title': 'Stay Active', 'description': 'Exercise regularly to keep your heart healthy.'},
    {'title': 'Healthy Diet', 'description': 'A balanced diet helps maintain your cardiovascular health.'},
    {'title': 'Stay Hydrated', 'description': 'Drinking plenty of water ensures better bodily functions.'},
    {'title': 'Regular Checkups', 'description': 'Visit your doctor regularly for heart checkups.'},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: healthTips.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: Icon(Icons.favorite, color: Colors.red),
          title: Text(healthTips[index]['title']!, style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(healthTips[index]['description']!),
        );
      },
    );
  }
}

// Profile Screen: User information and health data tracking
class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage(
                'https://www.w3schools.com/w3images/avatar2.png'), // Placeholder image
          ),
          SizedBox(height: 20),
          Text(
            'John Doe',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text('Age: 30'),
          SizedBox(height: 5),
          Text('Height: 175 cm'),
          SizedBox(height: 5),
          Text('Weight: 70 kg'),
          SizedBox(height: 20),
          Text(
            'Recent Health Data:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ListTile(
            title: Text('Heart Rate'),
            subtitle: Text('72 bpm'),
            leading: Icon(Icons.favorite, color: Colors.red),
          ),
          ListTile(
            title: Text('Blood Pressure'),
            subtitle: Text('120/80 mmHg'),
            leading: Icon(Icons.healing, color: Colors.blue),
          ),
          ListTile(
            title: Text('Steps Walked Today'),
            subtitle: Text('8,000 steps'),
            leading: Icon(Icons.directions_walk, color: Colors.green),
          ),
        ],
      ),
    );
  }
}
