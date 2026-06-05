import 'package:flutter/material.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';

class CustomButton extends StatelessWidget {
	const CustomButton({
		super.key,
		required this.label,
		required this.onPressed,
		this.enabled = true,
	});

	final String label;
	final VoidCallback onPressed;
	final bool enabled;

	@override
	Widget build(BuildContext context) {
		return SizedBox(
			width: double.infinity,
			height: 65,
			child: ElevatedButton(
				onPressed: enabled ? onPressed : null,
				style: enabled ? AppThemes.primaryButtonStyle : AppThemes.unaccessibleButtonStyle,
				child: Text(label),
			),
		);
	}
}