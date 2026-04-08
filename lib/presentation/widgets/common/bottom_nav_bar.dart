import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.only(left: 10, right: 10, top: 6, bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(50),
          ),
          child: BottomNavigationBar(
            currentIndex: selectedIndex,
            onTap: onItemTapped,
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.black,
            unselectedItemColor: Colors.black54,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedFontSize: 14,
            unselectedFontSize: 14,
            iconSize: 26,
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.only(top: 4),
                  child: const Icon(Icons.map_outlined),
                ),
                label: AppStrings.map,
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.only(top: 4),
                  child: const Icon(Icons.explore_outlined),
                ),
                label: AppStrings.explore,
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.only(top: 4),
                  child: const Icon(Icons.notifications_outlined),
                ),
                label: AppStrings.updates,
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.only(top: 4),
                  child: const Icon(Icons.person_outline),
                ),
                label: AppStrings.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}