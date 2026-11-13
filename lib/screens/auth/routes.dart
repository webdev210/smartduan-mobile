import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import 'forgot_password.dart';
import 'login.dart';
import 'register.dart';

final Map<String, Widget Function(BuildContext, GoRouterState)> authScreens = {
  '/dang-nhap': (context, state) => _page(
    'Đăng nhập',
    LoginScreen(notice: state.uri.queryParameters['notice']),
  ),
  '/dang-ky': (context, state) => _page('Đăng ký', const RegisterScreen()),
  '/quen-mat-khau': (context, state) =>
      _page('Quên mật khẩu', const ForgotPasswordScreen()),
};

Widget _page(String title, Widget child) => Scaffold(
  appBar: AppBar(title: Text(title)),
  body: SafeArea(top: false, child: child),
);
