#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr int kMinimumClientWidth = 900;
constexpr int kMinimumClientHeight = 600;
constexpr double kBaseDpi = 96.0;
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_GETMINMAXINFO: {
      const UINT dpi = GetDpiForWindow(hwnd);
      if (dpi == 0) break;
      const double scale = dpi / kBaseDpi;
      RECT frame = {0, 0, static_cast<LONG>(kMinimumClientWidth * scale),
                    static_cast<LONG>(kMinimumClientHeight * scale)};
      AdjustWindowRectExForDpi(
          &frame, static_cast<DWORD>(GetWindowLong(hwnd, GWL_STYLE)), FALSE,
          static_cast<DWORD>(GetWindowLong(hwnd, GWL_EXSTYLE)), dpi);
      MINMAXINFO* info = reinterpret_cast<MINMAXINFO*>(lparam);
      info->ptMinTrackSize.x = frame.right - frame.left;
      info->ptMinTrackSize.y = frame.bottom - frame.top;
      return 0;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
