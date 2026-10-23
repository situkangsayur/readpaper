# Pemanggil server sitasi ReadPaper di 127.0.0.1:23121.
#
# Kontraknya docs/api-sitasi.md. Ekstensi LibreOffice tidak punya mesin
# JavaScript, jadi selain mencari dan mengambil data ia memakai satu alamat
# tambahan, POST /api/run: ReadPaper menjalankan inti sitasi yang sama dengan
# panel Word dan OnlyOffice atas potret dokumen yang dikirim.
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import json
import os
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_BASE_URL = 'http://127.0.0.1:23121'
TOKEN_KEY = 'readpaper:citation-server-token'


class ApiError(Exception):
    def __init__(self, code, message, status=None):
        Exception.__init__(self, message)
        self.code = code
        self.status = status


MESSAGES = {
    'offline': 'ReadPaper tidak berjalan. Buka ReadPaper desktop lalu coba lagi; '
               'server sitasinya menyala di Pengaturan.',
    'notoken': 'Token ReadPaper belum ada. Salin token dari Pengaturan ReadPaper '
               '(kartu Sitasi di Word & OnlyOffice), lalu ReadPaper → Token….',
    'unauthorized': 'Token ReadPaper salah atau sudah dibuat ulang. Salin token baru dari '
                    'Pengaturan ReadPaper, lalu ReadPaper → Token….',
}


def readpaper_data_dir():
    """Folder data ReadPaper desktop, sama dengan AppPaths di aplikasinya."""
    xdg = os.environ.get('XDG_DATA_HOME')
    if xdg:
        return os.path.join(xdg, 'readpaper')
    home = os.environ.get('HOME') or os.environ.get('USERPROFILE') or os.path.expanduser('~')
    return os.path.join(home, '.local', 'share', 'readpaper')


def discover_token():
    """Token server sitasi dari credentials.json ReadPaper di komputer ini.

    Hanya kunci token sitasi yang dibaca; isi lain berkas itu (token GitHub)
    tidak disentuh. Berkas itu milik pengguna yang sama yang menjalankan
    LibreOffice, jadi tidak ada yang dibuka lebih lebar daripada sebelumnya.
    """
    path = os.path.join(readpaper_data_dir(), 'credentials.json')
    try:
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
    except (OSError, ValueError):
        return None
    token = data.get(TOKEN_KEY) if isinstance(data, dict) else None
    return token.strip() if isinstance(token, str) and len(token.strip()) >= 32 else None


class Client:
    def __init__(self, base_url=None, token=None, timeout=10.0, token_file=None):
        self.base_url = (base_url or os.environ.get('READPAPER_URL') or DEFAULT_BASE_URL).rstrip('/')
        self.token_file = token_file
        self._token = token
        self.timeout = timeout

    # Token: yang disimpan manual menang, lalu yang ditemukan dari ReadPaper.
    def token(self):
        if self._token:
            return self._token
        saved = self._saved_token()
        return saved or discover_token()

    def _saved_token(self):
        if not self.token_file:
            return None
        try:
            with open(self.token_file, encoding='utf-8') as f:
                t = f.read().strip()
            return t or None
        except OSError:
            return None

    def save_token(self, token):
        token = (token or '').strip()
        self._token = None
        if not self.token_file:
            self._token = token or None
            return
        os.makedirs(os.path.dirname(self.token_file), exist_ok=True)
        if token:
            fd = os.open(self.token_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, 'w', encoding='utf-8') as f:
                f.write(token)
        elif os.path.exists(self.token_file):
            os.remove(self.token_file)

    def _request(self, path, method='GET', body=None, auth=True, xml=False, timeout=None):
        headers = {}
        if auth:
            token = self.token()
            if not token:
                raise ApiError('notoken', MESSAGES['notoken'])
            headers['Authorization'] = 'Bearer ' + token
        data = None
        if body is not None:
            data = json.dumps(body).encode('utf-8')
            headers['Content-Type'] = 'application/json'
        req = urllib.request.Request(self.base_url + path, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=timeout or self.timeout) as res:
                raw = res.read().decode('utf-8')
        except urllib.error.HTTPError as e:
            raw = e.read().decode('utf-8', 'replace')
            msg = None
            try:
                msg = json.loads(raw).get('error')
            except ValueError:
                pass
            if e.code == 401:
                raise ApiError('unauthorized', MESSAGES['unauthorized'], 401)
            raise ApiError('http', msg or 'Server ReadPaper menjawab galat %d.' % e.code, e.code)
        except (urllib.error.URLError, OSError):
            raise ApiError('offline', MESSAGES['offline'])
        return raw if xml else json.loads(raw)

    def ping(self):
        return self._request('/api/ping', auth=False, timeout=3)

    def search(self, q, limit=25):
        qs = urllib.parse.urlencode({'q': q or '', 'limit': limit})
        return self._request('/api/search?' + qs).get('items', [])

    def annotations(self, key):
        return self._request('/api/items/%s/annotations' % urllib.parse.quote(key, safe='')).get('annotations', [])

    def styles(self):
        return self._request('/api/styles').get('styles', [])

    def run(self, command, doc, args=None):
        """Satu perintah sitasi; melempar ApiError bila ReadPaper menolaknya."""
        r = self._request('/api/run', method='POST', body={'command': command, 'args': args or {}, 'doc': doc},
                          timeout=120)
        if not r.get('ok'):
            raise ApiError('command', r.get('error') or 'Perintah gagal di ReadPaper.')
        return r
