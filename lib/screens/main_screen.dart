import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'comparison_screen.dart';
import 'record_screen.dart';
import 'leaderboard_screen.dart';
import 'chat_screen.dart';
import '../services/navigation_provider.dart';

import '../theme/style_constants.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Widget> _pages = [
    const HomeScreen(), // Tab 1: Log
    const ComparisonScreen(), // Tab 2: Comparison
    const RecordScreen(), // Tab 3: Record
    const LeaderboardScreen(), // Tab 4: Leaderboard
    const ChatScreen(), // Tab 5: Chat
  ];

  @override
  Widget build(BuildContext context) {
    final nav = Provider.of<NavigationProvider>(context);

    return Scaffold(
      backgroundColor: VelocityColors.black,
      body: IndexedStack(index: nav.currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: VelocityColors.textDim.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: nav.currentIndex,
          onTap: (index) {
            nav.setTab(index);
          },
          backgroundColor: VelocityColors.black,
          selectedItemColor: VelocityColors.textBody,
          unselectedItemColor: VelocityColors.textDim,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: VelocityTextStyles.dimBody.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: VelocityTextStyles.dimBody.copyWith(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.analytics_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.analytics),
              ),
              label: 'LOG',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.insights_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.insights),
              ),
              label: 'COMPARE',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.add_circle_outline),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.add_circle),
              ),
              label: 'RECORD',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.emoji_events_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.emoji_events),
              ),
              label: 'RANK',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.chat_bubble_outline),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.chat_bubble),
              ),
              label: 'COACH',
            ),
          ],
        ),
      ),
    );
  }
}
