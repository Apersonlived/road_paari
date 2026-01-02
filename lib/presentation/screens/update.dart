import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../widgets/common/bottom_nav_bar.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({Key? key}) : super(key: key);

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  int _selectedIndex = 2;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.updates),
      ),
      body: Center(
        child: Text('Updates Screen'),
      ),
      //Adding the Navigation Bar module
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}