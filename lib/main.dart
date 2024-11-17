import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:fl_chart/fl_chart.dart'; // Make sure the package is imported

void main() => runApp(CardiacMonitoringApp());

class CardiacMonitoringApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real-Time Cardiac Monitoring',
      theme: ThemeData(
        primarySwatch: Colors.red,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Colors.orangeAccent,
        ),
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
        title: Text('Cardiac Monitoring', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
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
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

/// Home Screen: Displays real-time heart rate and other vital information
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late WebSocketChannel channel;
  double heartRate = 0.0;
  List<FlSpot> ecgPoints = [];
  bool isConnected = false;
  Timer? updateTimer;
  
  @override
  void initState() {
    super.initState();
    connectWebSocket();
  }

  void connectWebSocket() {
    print('Connecting to WebSocket...');
    channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.29.127:5000/socket.io/?EIO=4&transport=websocket'),
    );
    
    channel.sink.add('40');
    
    channel.stream.listen(
      (dynamic message) {
        print('Received message: $message');
        handleSocketMessage(message);
      },
      onError: (error) {
        print('WebSocket error: $error');
        setState(() {
          isConnected = false;
        });
        Future.delayed(Duration(seconds: 5), connectWebSocket);
      },
      onDone: () {
        print('WebSocket connection closed');
        setState(() {
          isConnected = false;
        });
        Future.delayed(Duration(seconds: 5), connectWebSocket);
      },
    );
  }

  void handleSocketMessage(dynamic message) {
    if (!mounted) return;

    // Handle connection messages
    if (message.toString().startsWith('0') || message.toString().startsWith('40')) {
      setState(() {
        isConnected = true;
      });
      return;
    }

    // Handle ping messages
    if (message.toString() == '2') {
      channel.sink.add('3');
      return;
    }

    try {
      // Handle data messages
      if (message.toString().startsWith('42')) {
        String jsonStr = message.toString().substring(2);
        print('Processing JSON: $jsonStr');
        
        // Parse the outer message structure
        List<dynamic> outerData = json.decode(jsonStr);
        if (outerData[0] == "message") {
          // Extract and parse the inner message
          String innerMessage = outerData[1];
          if (innerMessage.startsWith('42')) {
            String innerJsonStr = innerMessage.substring(2);
            List<dynamic> data = json.decode(innerJsonStr);
            
            if (data[0] == "ecg_data" && data[1] is Map) {
              final Map<String, dynamic> ecgData = data[1];
              final double value = (ecgData['value'] as num).toDouble();
              final double newHeartRate = (ecgData['heart_rate'] as num).toDouble();
              
              print('Processed value: $value, heart rate: $newHeartRate');
              
              setState(() {
                heartRate = newHeartRate;
                
                // Add new point to the graph
                if (ecgPoints.length > 100) {
                  ecgPoints.removeAt(0);
                }
                ecgPoints.add(FlSpot(
                  ecgPoints.isEmpty ? 0 : ecgPoints.length.toDouble(),
                  value
                ));
                
                // Reindex x-coordinates
                ecgPoints = List.generate(
                  ecgPoints.length,
                  (index) => FlSpot(index.toDouble(), ecgPoints[index].y),
                );
              });
            }
          }
        }
      }
    } catch (e, stackTrace) {
      print('Error processing message: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Color _getHeartRateColor(double heartRate) {  // Renamed parameter for clarity
    if (heartRate < 60) return Colors.blue;  // Bradycardia
    if (heartRate > 100) return Colors.red;  // Tachycardia
    return Colors.green;  // Normal
  }

  Widget _buildGraph() {
    return Container(
      height: 300,
      padding: EdgeInsets.all(16),
      child: ecgPoints.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Waiting for ECG data...'),
                ],
              ),
            )
          : LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: true),
                minX: 0,
                maxX: 100,
                minY: -2,
                maxY: 2,
                lineBarsData: [
                  LineChartBarData(
                    spots: ecgPoints,
                    isCurved: true,
                    barWidth: 1,
                    color: Colors.red,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Real-Time Heart Rate',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 40,
                          ),
                          SizedBox(width: 10),
                          Text(
                            '${heartRate.toStringAsFixed(0)} BPM',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: _getHeartRateColor(heartRate),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildGraph(),
                  ),
                ),
                SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ReportScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text(
                    'View Detailed Report',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    channel.sink.close();
    updateTimer?.cancel();
    super.dispose();
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Messages from Doctor',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: healthTips.length + 1,
              itemBuilder: (context, index) {
                if (index < healthTips.length) {
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: Icon(Icons.favorite, color: Colors.red),
                      title: Text(
                        healthTips[index]['title']!,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(healthTips[index]['description']!),
                    ),
                  );
                } else {
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: Icon(Icons.medication, color: Colors.blue),
                      title: Text(
                        'Medicines',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Daily prescriptions: Aspirin, Metoprolol, Atorvastatin'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ReportScreen()),
                        );
                      },
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
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
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(
                  'https://www.w3schools.com/w3images/avatar2.png'), // Placeholder image
            ),
          ),
          SizedBox(height: 20),
          Center(
            child: Text(
              'Srinath Sathyadas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 10),
          Text('Age: 30'),
          SizedBox(height: 5),
          Text('Height: 175 cm'),
          SizedBox(height: 5),
          Text('Weight: 70 kg'),
          SizedBox(height: 20),
          SizedBox(height: 20),
          Text(
            'Recent Health Data:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ListTile(
              leading: Icon(Icons.favorite, color: Colors.red),
              title: Text('Heart Rate'),
              subtitle: Text('72 bpm'),
            ),
          ),
          SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ListTile(
              leading: Icon(Icons.healing, color: Colors.blue),
              title: Text('Blood Pressure'),
              subtitle: Text('120/80 mmHg'),
            ),
          ),
          SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ListTile(
              leading: Icon(Icons.directions_walk, color: Colors.green),
              title: Text('Steps Walked Today'),
              subtitle: Text('8,000 steps'),
            ),
          ),
        ],
      ),
    );
  }
}


class ReportScreen extends StatelessWidget {
  final List<double> bpmData = [72, 70, 68, 75, 77, 76, 73]; // Mock BPM data for a week

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detailed Report', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Patient Information'),
              _buildInfoCard([
                _buildInfoRow(Icons.person, 'Name', 'Srinath Sathyadas'),
                _buildInfoRow(Icons.cake, 'Age', '30'),
                _buildInfoRow(Icons.height, 'Height', '175 cm'),
                _buildInfoRow(Icons.monitor_weight, 'Weight', '70 kg'),
              ]),
              SizedBox(height: 20),
              _buildSectionHeader('Recent Health Data'),
              _buildInfoCard([
                _buildInfoRow(Icons.favorite, 'Heart Rate', '72 bpm'),
                _buildInfoRow(Icons.local_hospital, 'Blood Pressure', '120/80 mmHg'),
                _buildInfoRow(Icons.directions_walk, 'Steps Walked Today', '8,000'),
              ]),
              SizedBox(height: 20),
              _buildSectionHeader('Prescribed Medicines'),
              _buildInfoCard([
                _buildInfoRow(Icons.medication, 'Medicines', 'Aspirin, Metoprolol, Atorvastatin'),
              ]),
              SizedBox(height: 20),
              _buildSectionHeader('Heart Rate for the Past Week'),
              _buildLineChart(),
            ],
          ),
        ),
      ),
    );
  }

  // Section header with consistent style
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  // Information card with rows of data
  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  // A row representing a single piece of information
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.red, size: 24),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // Line chart for weekly heart rate data
  Widget _buildLineChart() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  switch (value.toInt()) {
                    case 0:
                      return Text('Mon');
                    case 1:
                      return Text('Tue');
                    case 2:
                      return Text('Wed');
                    case 3:
                      return Text('Thu');
                    case 4:
                      return Text('Fri');
                    case 5:
                      return Text('Sat');
                    case 6:
                      return Text('Sun');
                    default:
                      return Text('');
                  }
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: bpmData.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), e.value);
              }).toList(),
              isCurved: true,
              gradient: LinearGradient(colors: [Colors.red, Colors.orange]),
              barWidth: 3,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}
