import 'package:flutter/material.dart';
import 'package:vitality/screens/add_reading_page.dart';
import 'package:vitality/screens/history_page.dart';
import 'package:vitality/screens/home_page.dart';
import 'package:vitality/screens/insights_page.dart';
import 'package:vitality/screens/profile_page.dart';
import 'package:vitality/theme.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  Key _homeKey = UniqueKey();
  Key _historyKey = UniqueKey();
  Key _insightsKey = UniqueKey();
  Key _profileKey = UniqueKey();

  void _showAddReadingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: AddReadingPage(
            onReadingAdded: () {
              setState(() {
                _homeKey = UniqueKey();
                _historyKey = UniqueKey();
                _insightsKey = UniqueKey();
                _profileKey = UniqueKey();
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(key: _homeKey),
          HistoryPage(key: _historyKey),
          InsightsPage(key: _insightsKey),
          ProfilePage(key: _profileKey),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReadingSheet,
        child: Icon(
          Icons.add,
          color: Theme.of(context).floatingActionButtonTheme.foregroundColor,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined),
              activeIcon: Icon(Icons.insights),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
