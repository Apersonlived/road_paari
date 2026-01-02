import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class LocationSearchField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final Function(String) onSearch;

  const LocationSearchField({
    Key? key,
    required this.controller,
    required this.icon,
    required this.hint,
    required this.onSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.black54),
          suffixIcon: IconButton(
            icon: Icon(Icons.search, color: Colors.black54),
            onPressed: () => onSearch(controller.text),
          ),
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onSubmitted: onSearch,
      ),
    );
  }
}