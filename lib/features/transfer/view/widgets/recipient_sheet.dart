import 'package:flutter/services.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../home/data/quick_contacts.dart';
import '../../data/recipient.dart';

/// "Send to": pick a saved contact or type a new name and mobile number.
class RecipientSheet extends StatefulWidget {
  const RecipientSheet({super.key});

  static Future<Recipient?> show(BuildContext context) =>
      showModalBottomSheet<Recipient>(
        context: context,
        backgroundColor: AppColors.surface,
        isScrollControlled: true,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        builder: (_) => const RecipientSheet(),
      );

  @override
  State<RecipientSheet> createState() => _RecipientSheetState();
}

class _RecipientSheetState extends State<RecipientSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _mobileFocus = FocusNode();

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _mobileFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(
      context,
    ).pop(Recipient.custom(name: _name.text, mobile: _mobile.text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11.sp,
      letterSpacing: 1.2,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20.w,
          0,
          20.w,
          20.h + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('SEND TO', style: theme.textTheme.titleLarge),
            SizedBox(height: 14.h),
            Text('SAVED CONTACTS', style: caption),
            SizedBox(height: 6.h),
            for (final contact in quickContacts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () =>
                    Navigator.of(context).pop(Recipient.fromContact(contact)),
                leading: Container(
                  width: 42.r,
                  height: 42.r,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    contact.initials,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: contact.isBusiness
                          ? AppColors.secondary
                          : AppColors.primary,
                    ),
                  ),
                ),
                title: Text(contact.name),
                subtitle: Text(contact.upiId, style: theme.textTheme.bodySmall),
                trailing: const Icon(Icons.chevron_right),
              ),
            SizedBox(height: 10.h),
            Divider(color: AppColors.border.withValues(alpha: 0.6)),
            SizedBox(height: 10.h),
            Text('NEW RECIPIENT', style: caption),
            SizedBox(height: 12.h),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'Name',
                    hint: 'As on their account',
                    controller: _name,
                    prefixIcon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    validator: Validators.beneficiaryName,
                    onFieldSubmitted: (_) => _mobileFocus.requestFocus(),
                  ),
                  SizedBox(height: 14.h),
                  AppTextField(
                    label: 'Mobile number',
                    hint: '10-digit mobile number',
                    controller: _mobile,
                    focusNode: _mobileFocus,
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: Validators.mobile,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  SizedBox(height: 18.h),
                  AppButton(
                    label: 'CONTINUE',
                    icon: Icons.arrow_forward,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
