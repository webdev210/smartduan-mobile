const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://smartduan.vn/m/api/v1',
);
const wsUrl = String.fromEnvironment(
  'WS_URL',
  defaultValue: 'wss://smartduan.vn/m/socket',
);
const webUrl = String.fromEnvironment(
  'WEB_URL',
  defaultValue: 'https://smartduan.vn',
);
final originUrl = apiUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
const appVersion = '1.0.7';
