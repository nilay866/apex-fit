import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class ApexInput extends StatelessWidget {
  final String? label;
  final String? placeholder;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;
  final bool obscure;
  final bool mono;
  final int? maxLines;
  final bool small;

  const ApexInput({
    super.key,
    this.label,
    this.placeholder,
    required this.value,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
    this.mono = false,
    this.maxLines,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              label!.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ApexColors.t2,
                letterSpacing: 0.7,
              ),
            ),
          ),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          keyboardType: keyboardType,
          obscureText: obscure,
          maxLines: obscure ? 1 : (maxLines ?? 1),
          style: (mono ? GoogleFonts.dmMono : GoogleFonts.spaceGrotesk)(
            fontSize: small ? 12 : 13,
            color: ApexColors.t1,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: small ? 7 : 10,
            ),
          ),
        ),
      ],
    );
  }
}
