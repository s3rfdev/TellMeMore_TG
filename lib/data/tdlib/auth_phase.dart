/// Фазы авторизации TDLib — общие для нативной и web-версии.
enum AuthPhase {
  idle,
  connecting,
  waitQr,
  waitPhone,
  waitCode,
  waitPassword,
  ready,
  error,
}
