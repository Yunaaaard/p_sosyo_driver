import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;

  const CustomAppBar({
    super.key,
    this.title = 'PESOPAQ',
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDefaultLogo = title == 'PESOPAQ';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFEBEBEB),
            width: 1.0,
          ),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 56,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF8A8F99),
                  size: 20,
                ),
                onPressed: () => Get.back(),
              )
            : null,
        title: Text(
          title,
          style: isDefaultLogo
              ? const TextStyle(
                  fontFamily: 'ITTENOVIANADEMO',
                  color: Color(0xFF6533E7),
                  fontSize: 26,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                )
              : const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF2F333A),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

