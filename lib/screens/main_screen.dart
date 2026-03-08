import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'comparison_screen.dart';
import 'record_screen.dart';
import 'leaderboard_screen.dart';
import 'chat_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(), // Tab 1: Log
    const ComparisonScreen(), // Tab 2: Comparison
    const RecordScreen(), // Tab 3: Record
    const LeaderboardScreen(), // Tab 4: Leaderboard
    const ChatScreen(), // Tab 5: Chat
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed, // To show 5 items without shifting
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Log'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Compare',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle, size: 36),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Leaderboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        ],
      ),
    );
  }
}
