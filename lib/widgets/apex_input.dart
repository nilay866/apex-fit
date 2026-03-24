import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class ApexInput extends StatefulWidget {
  final String? label;
  final String? placeholder;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;
  final bool obscure;
  final bool mono;
  final int? maxLines;
  final bool small;
  final TextEditingController? controller;

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
    this.controller,
  });

  @override
  State<ApexInput> createState() => _ApexInputState();
}

class _ApexInputState extends State<ApexInput> {
  late TextEditingController _controller;
  bool _usingInternalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.value);
      _usingInternalController = true;
    }
  }

  @override
  void didUpdateWidget(ApexInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_usingInternalController && widget.value != oldWidget.value) {
      final currentText = _controller.text;
      if (currentText != widget.value) {
        _controller.text = widget.value;
        _controller.selection = TextSelection.collapsed(
          offset: widget.value.length,
        );
      }
    }
  }

  @override
  void dispose() {
    if (_usingInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              widget.label!.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ApexColors.t2,
                letterSpacing: 0.7,
              ),
            ),
          ),
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscure,
          maxLines: widget.obscure ? 1 : (widget.maxLines ?? 1),
          style: (widget.mono ? GoogleFonts.dmMono : GoogleFonts.inter)(
            fontSize: widget.small ? 12 : 13,
            color: ApexColors.t1,
          ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: widget.small ? 7 : 10,
            ),
          ),
        ),
      ],
    );
  }
}
