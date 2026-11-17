import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/session/session_cubit.dart';
import '../../../core/extensions/spacing_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../view_model/login_cubit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<LoginCubit, LoginState>(
    listener: _onStateChanged,
    builder: (context, state) =>
        Scaffold(body: SafeArea(child: _buildBody(state))),
  );

  Widget _buildBody(LoginState state) => LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.symmetric(
          horizontal: 20.w.clamp(16, 40),
          vertical: 16.h,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _buildContent(state),
          ),
        ),
      );
    },
  );

  Widget _buildContent(LoginState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _buildBrand(),
      24.sizedBoxHeight(),
      _buildHero(),
      28.sizedBoxHeight(),
      _buildHeading(),
      22.sizedBoxHeight(),
      _buildCard(state),
      24.sizedBoxHeight(),
      _buildFooter(),
      8.sizedBoxHeight(),
    ],
  );

  Widget _buildBrand() => Row(
    children: [
      Container(
        padding: EdgeInsets.all(9.r),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(
          Icons.account_balance_wallet_outlined,
          color: AppColors.surface,
          size: 22.r,
        ),
      ),
      10.sizedBoxWidth(),
      Text('jWallet', style: Theme.of(context).textTheme.titleLarge),
      8.sizedBoxWidth(),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Text(
          'LITE',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontSize: 9.sp, letterSpacing: 1.5),
        ),
      ),
      const Spacer(),
      Icon(Icons.north_east, size: 22.r, color: AppColors.secondary),
    ],
  );

  Widget _buildHero() => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20.r),
      color: AppColors.primary,
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppGradients.hero),
          ),
        ),
        Padding(padding: EdgeInsets.all(24.r), child: _buildHeroContent()),
      ],
    ),
  );

  Widget _buildHeroContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'A LITTLE WALLET. A LOT OF POSSIBILITY.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.tertiary,
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          12.sizedBoxWidth(),
          Icon(Icons.blur_on, color: AppColors.primary, size: 30.r),
        ],
      ),
      32.sizedBoxHeight(),
      Text(
        'Your money.\nYour rhythm.',
        style: Theme.of(context).textTheme.displaySmall
            ?.copyWith(color: AppColors.surface),
      ),
      18.sizedBoxHeight(),
      Text(
        'Move it. Track it. Make it yours.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.tertiary),
      ),
    ],
  );

  Widget _buildHeading() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Welcome back.', style: Theme.of(context).textTheme.headlineMedium),
      6.sizedBoxHeight(),
      Text(
        'Sign in to your little corner of finance.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );

  Widget _buildCard(LoginState state) => Container(
    padding: EdgeInsets.all(20.r),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20.r),
      border: Border.all(color: AppColors.border),
    ),
    child: AutofillGroup(
      child: Form(key: _formKey, child: _buildFormFields(state)),
    ),
  );

  Widget _buildFormFields(LoginState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppTextField(
        label: 'Email address',
        hint: 'you@example.com',
        controller: _email,
        prefixIcon: Icons.alternate_email,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.username],
        validator: Validators.email,
        enabled: !state.isSubmitting,
        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
      ),
      20.sizedBoxHeight(),
      AppTextField(
        label: 'Password',
        hint: 'Enter your password',
        controller: _password,
        prefixIcon: Icons.lock_outline,
        isPassword: true,
        focusNode: _passwordFocus,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
        validator: Validators.password,
        enabled: !state.isSubmitting,
        onFieldSubmitted: (_) => _submit(),
      ),
      24.sizedBoxHeight(),
      AppButton(
        label: 'Sign in',
        icon: Icons.arrow_forward,
        isLoading: state.isSubmitting,
        onPressed: _submit,
      ),
    ],
  );

  Widget _buildFooter() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.lock_outline, size: 14.r, color: AppColors.textSecondary),
      7.sizedBoxWidth(),
      Flexible(
        child: Text(
          'Your wallet. A secure space.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );

  void _submit() {
    if (context.read<LoginCubit>().state.isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    context.read<LoginCubit>().submit(
      email: _email.text,
      password: _password.text,
    );
  }

  void _onStateChanged(BuildContext context, LoginState state) {
    if (state.status == LoginStatus.failure && state.message != null) {
      // Server failures arrive here with the API's own meta.message.
      AppSnackbar.show(context, state.message!, isError: true);
      return;
    }
    if (state.status != LoginStatus.success) return;
    TextInput.finishAutofillContext();
    _password.clear();
    context.read<SessionCubit>().loggedIn(
      pinSet: state.pinSet,
      biometricEnrolled: state.biometricEnrolled,
      offerBiometricSetup: state.offerBiometricSetup,
    );
  }
}
