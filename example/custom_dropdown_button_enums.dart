import 'dart:io';

import 'package:app/utils/style/colors.dart';
import 'package:flutter/material.dart';
import 'package:app/utils/style/text_styles.dart';
import 'package:app/utils/helpers/misc_helper.dart';

/// A custom dropdown widget for Enums with flexible styling and functionality.
/// Supports custom icons, validation, callbacks, and a dynamic list of Enum items.
/// Designed for platform-specific UI adjustments and dark mode compatibility.
class CustomDropdownButtonEnums extends StatefulWidget {
  List<Enum> itemsList;
  bool expanded;
  String hint;
  Enum? chosenValue;
  final Function? getDropdownButtonValueCallback;
  String? url;
  final String? Function(Enum?)? validatorTextInput;
  final FocusNode? focus;

  CustomDropdownButtonEnums({
    Key? key,
    required this.itemsList,
    this.expanded = false,
    required this.hint,
    this.focus,
    this.url,
    this.validatorTextInput,
    this.getDropdownButtonValueCallback,
    this.chosenValue,
  }) : super(key: key);

  @override
  State<CustomDropdownButtonEnums> createState() => _CustomDropdownButtonEnumsState();
}

class _CustomDropdownButtonEnumsState extends State<CustomDropdownButtonEnums> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: Platform.isIOS ? 1 : 4,
        bottom: Platform.isIOS ? 1 : 4,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          width: Platform.isIOS ? 1.2 : 1.5,
          color: Platform.isIOS
              ? isDark(context)
                  ? const Color.fromARGB(255, 91, 91, 93)
                  : const Color(0xFFd4d4d8)
              : isDark()
                  ? const Color(0xFF585c5d)
                  : const Color(0xFFc1c1c1),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonFormField<Enum>(
        dropdownColor: isDark(context) ? CustomColors.bg2Dark : CustomColors.bg,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        focusNode: widget.focus,
        validator: widget.validatorTextInput,
        isExpanded: true,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.zero,
          hintStyle: CustomTextTheme.inputFieldHintTxtStyle.copyWith(
            color: isDark(context)
                ? const Color.fromARGB(255, 180, 180, 180)
                : Platform.isIOS
                    ? const Color(0xFFc1c1c1)
                    : null,
          ),
          border: InputBorder.none,
          icon: widget.url != null
              ? ImageIcon(
                  AssetImage("assets/icons/${widget.url!}"),
                  color: CustomColors.inputHintColor,
                )
              : null,
        ),
        borderRadius: BorderRadius.circular(10),
        //underline: Container(), //remove underline
        icon: ImageIcon(
          const AssetImage("assets/icons/arrow_down.png"),
          size: 13,
          color: isDark(context) ? Colors.white : null,
        ),
        focusColor: Colors.white,
        value: widget.chosenValue,
        style: const TextStyle(color: Colors.white),
        iconEnabledColor: isDark(context)
            ? const Color.fromARGB(255, 180, 180, 180)
            : Platform.isIOS
                ? const Color(0xFFc1c1c1)
                : null,
        items: widget.itemsList.map<DropdownMenuItem<Enum>>((Enum value) {
          return DropdownMenuItem<Enum>(
            value: value,
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: widget.url != null ? .0 : 0),
                  child: Text(
                    translateFromString(context, value.name.toLowerCase()),
                    style: TextStyle(color: isDark(context) ? Colors.white : CustomColors.inputColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),

        hint: Text(
          widget.hint,
          style: CustomTextTheme.inputFieldHintTxtStyle.copyWith(
            fontSize: 15,
            color: isDark(context)
                ? const Color.fromARGB(255, 180, 180, 180)
                : Platform.isIOS
                    ? const Color(0xFFc1c1c1)
                    : null,
          ),
        ),
        onChanged: (Enum? value) {
          widget.chosenValue = value;
          widget.getDropdownButtonValueCallback!(value);
        },
      ),
    );
  }
}
