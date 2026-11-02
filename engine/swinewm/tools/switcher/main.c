#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <tlhelp32.h>

#define SHELL_KEY L"Software\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon"
#define SHELL_VALUE L"Shell"
#define ENGINE L"swinewm.exe"
#define EXPLORER L"explorer.exe"

static HWND g_status;
static HWND g_install;
static HWND g_restore;
static HFONT g_font;

static BOOL registry_shell(wchar_t *out, DWORD cap)
{
        HKEY key;
        DWORD sz = cap * sizeof(wchar_t);
        LONG rc = RegOpenKeyExW(HKEY_CURRENT_USER, SHELL_KEY, 0, KEY_QUERY_VALUE, &key);
        if (rc != ERROR_SUCCESS) {
                return FALSE;
        }
        rc = RegQueryValueExW(key, SHELL_VALUE, NULL, NULL, (BYTE *)out, &sz);
        RegCloseKey(key);
        return rc == ERROR_SUCCESS && out[0];
}

static BOOL process_running(const wchar_t *name)
{
        HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        PROCESSENTRY32W pe;
        BOOL found = FALSE;
        if (snap == INVALID_HANDLE_VALUE) {
                return FALSE;
        }
        pe.dwSize = sizeof(pe);
        if (Process32FirstW(snap, &pe)) {
                do {
                        if (lstrcmpiW(pe.szExeFile, name) == 0) {
                                found = TRUE;
                        }
                } while (!found && Process32NextW(snap, &pe));
        }
        CloseHandle(snap);
        return found;
}

static void kill_by_name(const wchar_t *name)
{
        HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        PROCESSENTRY32W pe;
        if (snap == INVALID_HANDLE_VALUE) {
                return;
        }
        pe.dwSize = sizeof(pe);
        if (Process32FirstW(snap, &pe)) {
                do {
                        if (lstrcmpiW(pe.szExeFile, name) == 0) {
                                HANDLE p = OpenProcess(PROCESS_TERMINATE | SYNCHRONIZE,
                                        FALSE, pe.th32ProcessID);
                                if (p) {
                                        TerminateProcess(p, 0);
                                        WaitForSingleObject(p, 5000);
                                        CloseHandle(p);
                                }
                        }
                } while (Process32NextW(snap, &pe));
        }
        CloseHandle(snap);
}

static BOOL spawn(const wchar_t *exe)
{
        wchar_t cmd[32768];
        STARTUPINFOW si;
        PROCESS_INFORMATION pi;
        lstrcpynW(cmd, exe, 32767);
        ZeroMemory(&si, sizeof(si));
        si.cb = sizeof(si);
        if (!CreateProcessW(NULL, cmd, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
                return FALSE;
        }
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        return TRUE;
}

static void run_hidden(const wchar_t *cmdline)
{
        wchar_t cmd[32768];
        STARTUPINFOW si;
        PROCESS_INFORMATION pi;
        lstrcpynW(cmd, cmdline, 32767);
        ZeroMemory(&si, sizeof(si));
        si.cb = sizeof(si);
        si.dwFlags = STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_HIDE;
        if (CreateProcessW(NULL, cmd, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL,
                NULL, &si, &pi)) {
                WaitForSingleObject(pi.hProcess, 5000);
                CloseHandle(pi.hThread);
                CloseHandle(pi.hProcess);
        }
}

static void engine_path(wchar_t *out, DWORD cap)
{
        wchar_t dir[MAX_PATH];
        wchar_t *cut;
        GetModuleFileNameW(NULL, dir, MAX_PATH);
        cut = wcsrchr(dir, L'\\');
        if (cut) {
                *cut = 0;
        }
        lstrcpynW(out, dir, cap);
        lstrcatW(out, L"\\");
        lstrcatW(out, ENGINE);
}

static void update_status(void)
{
        wchar_t shell[MAX_PATH];
        wchar_t text[512];
        BOOL custom = registry_shell(shell, MAX_PATH);
        wsprintfW(text,
                L"Оболочка: %s\r\nswinewm.exe: %s\r\nexplorer.exe: %s",
                custom ? L"Meraki (назначен в реестре)" : L"Explorer (по умолчанию)",
                process_running(ENGINE) ? L"запущен" : L"не запущен",
                process_running(EXPLORER) ? L"запущен" : L"не запущен");
        SetWindowTextW(g_status, text);
}

static void on_install(void)
{
        wchar_t path[MAX_PATH * 2];
        wchar_t cmd[MAX_PATH * 2 + 32];
        engine_path(path, MAX_PATH * 2 - 2);
        if (GetFileAttributesW(path) == INVALID_FILE_ATTRIBUTES) {
                MessageBoxW(NULL, L"swinewm.exe не найден рядом со switcher.exe",
                        L"Meraki", MB_ICONERROR);
                return;
        }
        wsprintfW(cmd, L"\"%s\" --set-shell", path);
        run_hidden(cmd);
        kill_by_name(EXPLORER);
        if (!process_running(ENGINE) && !spawn(path)) {
                MessageBoxW(NULL, L"Не удалось запустить swinewm.exe", L"Meraki",
                        MB_ICONERROR);
        }
        update_status();
}

static void on_restore(void)
{
        wchar_t path[MAX_PATH * 2];
        wchar_t cmd[MAX_PATH * 2 + 32];
        engine_path(path, MAX_PATH * 2 - 2);
        if (GetFileAttributesW(path) != INVALID_FILE_ATTRIBUTES) {
                wsprintfW(cmd, L"\"%s\" --unset-shell", path);
                run_hidden(cmd);
        }
        kill_by_name(ENGINE);
        if (!process_running(EXPLORER) && !spawn(L"explorer.exe")) {
                MessageBoxW(NULL, L"Не удалось запустить explorer.exe", L"Meraki",
                        MB_ICONERROR);
        }
        update_status();
}

static LRESULT CALLBACK wnd_proc(HWND wnd, UINT msg, WPARAM wp, LPARAM lp)
{
        switch (msg) {
        case WM_CREATE:
                g_font = CreateFontW(-15, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
                g_status = CreateWindowExW(0, L"STATIC", L"...",
                        WS_CHILD | WS_VISIBLE | SS_LEFT,
                        20, 18, 284, 64, wnd, NULL, NULL, NULL);
                g_install = CreateWindowExW(0, L"BUTTON", L"Поставить Meraki",
                        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                        20, 92, 284, 36, wnd, (HMENU)(INT_PTR)1, NULL, NULL);
                g_restore = CreateWindowExW(0, L"BUTTON", L"Вернуть Explorer",
                        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                        20, 136, 284, 36, wnd, (HMENU)(INT_PTR)2, NULL, NULL);
                SendMessageW(g_status, WM_SETFONT, (WPARAM)g_font, TRUE);
                SendMessageW(g_install, WM_SETFONT, (WPARAM)g_font, TRUE);
                SendMessageW(g_restore, WM_SETFONT, (WPARAM)g_font, TRUE);
                update_status();
                return 0;
        case WM_COMMAND:
                if (LOWORD(wp) == 1) {
                        on_install();
                } else if (LOWORD(wp) == 2) {
                        on_restore();
                }
                return 0;
        case WM_DESTROY:
                DeleteObject(g_font);
                PostQuitMessage(0);
                return 0;
        default:
                return DefWindowProcW(wnd, msg, wp, lp);
        }
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE prev, PWSTR cmdline, int show)
{
        WNDCLASSW wc;
        HWND wnd;
        MSG msg;

        (void)prev;
        (void)cmdline;
        ZeroMemory(&wc, sizeof(wc));
        wc.lpfnWndProc = wnd_proc;
        wc.hInstance = inst;
        wc.hCursor = LoadCursorW(NULL, IDC_ARROW);
        wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
        wc.lpszClassName = L"MerakiSwitcher";
        RegisterClassW(&wc);
        wnd = CreateWindowExW(0, wc.lpszClassName,
                L"Meraki — переключатель оболочки",
                WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
                CW_USEDEFAULT, CW_USEDEFAULT, 336, 246, NULL, NULL, inst, NULL);
        if (!wnd) {
                return 1;
        }
        ShowWindow(wnd, show);
        UpdateWindow(wnd);
        while (GetMessageW(&msg, NULL, 0, 0) > 0) {
                TranslateMessage(&msg);
                DispatchMessageW(&msg);
        }
        return (int)msg.wParam;
}
