"""Apply the provided logo to the portable Windows executable's icon resources."""
import ctypes
import struct
from ctypes import wintypes

def apply_icon(executable, icon):
    dll = ctypes.WinDLL('kernel32', use_last_error=True)
    dll.LoadLibraryExW.argtypes = [wintypes.LPCWSTR, wintypes.HANDLE, wintypes.DWORD]
    dll.LoadLibraryExW.restype = wintypes.HMODULE
    dll.FreeLibrary.argtypes = [wintypes.HMODULE]
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HMODULE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ssize_t)
    language_callback = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HMODULE, ctypes.c_void_p, ctypes.c_void_p, wintypes.WORD, ctypes.c_ssize_t)
    dll.EnumResourceLanguagesW.argtypes = [wintypes.HMODULE, ctypes.c_void_p, ctypes.c_void_p, language_callback, ctypes.c_ssize_t]
    dll.EnumResourceNamesW.argtypes = [wintypes.HMODULE, ctypes.c_void_p, callback_type, ctypes.c_ssize_t]
    dll.BeginUpdateResourceW.argtypes = [wintypes.LPCWSTR, wintypes.BOOL]
    dll.BeginUpdateResourceW.restype = wintypes.HANDLE
    dll.UpdateResourceW.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_void_p, wintypes.WORD, ctypes.c_void_p, wintypes.DWORD]
    dll.EndUpdateResourceW.argtypes = [wintypes.HANDLE, wintypes.BOOL]
    groups = []
    @language_callback
    def collect_language(module, kind, name, language, param):
        groups.append((name if name < 65536 else ctypes.wstring_at(name), language))
        return True
    @callback_type
    def collect(module, kind, name, param):
        dll.EnumResourceLanguagesW(module, 14, name, collect_language, 0)
        return True
    module = dll.LoadLibraryExW(str(executable), None, 2)
    if not module:
        raise ctypes.WinError(ctypes.get_last_error())
    dll.EnumResourceNamesW(module, 14, collect, 0)
    dll.FreeLibrary(module)
    data = icon.read_bytes()
    width, height, colors, reserved, planes, bits, size, offset = struct.unpack_from('<BBBBHHII', data, 6)
    pixels = data[offset:offset+size]
    group = struct.pack('<HHHBBBBHHIH', 0, 1, 1, width, height, colors, reserved, planes, bits, size, 65000)
    handle = dll.BeginUpdateResourceW(str(executable), False)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        def put(kind, name, language, payload):
            key = name if isinstance(name, int) else ctypes.cast(ctypes.c_wchar_p(name), ctypes.c_void_p)
            buffer = ctypes.create_string_buffer(payload)
            if not dll.UpdateResourceW(handle, kind, key, language, buffer, len(payload)):
                raise ctypes.WinError(ctypes.get_last_error())
        for name, language in groups or [(1, 1033)]:
            put(3, 65000, language, pixels)
            put(14, name, language, group)
    except BaseException:
        dll.EndUpdateResourceW(handle, True)
        raise
    if not dll.EndUpdateResourceW(handle, False):
        raise ctypes.WinError(ctypes.get_last_error())
