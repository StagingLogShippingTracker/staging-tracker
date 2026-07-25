import base64, json, os, sqlite3, ctypes
from ctypes import wintypes
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

class DATA_BLOB(ctypes.Structure):
    _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_char))]

def dpapi_decrypt(encrypted: bytes) -> bytes:
    crypt32 = ctypes.windll.crypt32
    kernel32 = ctypes.windll.kernel32
    blob_in = DATA_BLOB(len(encrypted), ctypes.create_string_buffer(encrypted, len(encrypted)))
    blob_out = DATA_BLOB()
    if not crypt32.CryptUnprotectData(ctypes.byref(blob_in), None, None, None, None, 0, ctypes.byref(blob_out)):
        raise OSError(ctypes.GetLastError())
    try:
        return ctypes.string_at(blob_out.pbData, blob_out.cbData)
    finally:
        kernel32.LocalFree(blob_out.pbData)

def get_chrome_key() -> bytes:
    local_state = Path(os.environ["APPDATA"]) / "Cursor" / "Local State"
    data = json.loads(local_state.read_text(encoding="utf-8"))
    enc_key = base64.b64decode(data["os_crypt"]["encrypted_key"])
    if enc_key.startswith(b"DPAPI"):
        enc_key = enc_key[5:]
    return dpapi_decrypt(enc_key)

def decrypt_v10(blob: bytes, key: bytes) -> bytes:
    if not blob.startswith(b"v10"):
        raise ValueError("not v10")
    nonce = blob[3:15]
    ciphertext = blob[15:]
    return AESGCM(key).decrypt(nonce, ciphertext, None)

TOKEN_KEY = (
    "mcpOAuth.secret.W3BsdWdpbi1zdXBhYmFzZS1zdXBhYmFzZTo6bWNwU2NvcGU6"
    "cHJvZmlsZTpaR1ZtWVhWc2RBXSBtY3BfdG9rZW5z"
)
db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
row = con.execute("SELECT value FROM ItemTable WHERE key = ?", (TOKEN_KEY,)).fetchone()
con.close()
data = json.loads(row[0])
raw = bytes(data["data"])
key = get_chrome_key()
plain = decrypt_v10(raw, key)
parsed = json.loads(plain.decode())
print("keys", parsed.keys())
print("access_len", len(parsed.get("access_token","")))
