import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';

/// Optional note ("Dinner split & groceries"), up to 100 characters.
class RemarksField extends StatefulWidget {
  const RemarksField({super.key, required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<RemarksField> createState() => _RemarksFieldState();
}

class _RemarksFieldState extends State<RemarksField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 14.w),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(4.r),
    ),
    child: Row(
      children: [
        Icon(Icons.edit_note, color: AppColors.textSecondary, size: 22.r),
        SizedBox(width: 10.w),
        Expanded(
          child: TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            maxLength: 100,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Add a note (optional)',
              counterText: '',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14.h),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _controller.text.isEmpty
              ? const SizedBox.shrink()
              : Semantics(
                  button: true,
                  label: 'Clear note',
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: _clear,
                    radius: 20.r,
                    child: Padding(
                      padding: EdgeInsets.all(6.r),
                      child: Icon(
                        Icons.close,
                        size: 18.r,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}
