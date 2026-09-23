"""Public GitHub release installer: verified downloads and staged updates."""
import argparse
import hashlib
import json
import re
import shutil
import sys
import uuid
import time
from contextlib import contextmanager
import urllib.request
import zipfile
from pathlib import Path

HEADERS = {'User-Agent': 'CWTCH-Launcher', 'Accept': 'application/vnd.github+json'}

def read_url(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=60) as response:
        return response.read()

def safe_extract(archive, destination):
    destination = Path(destination).resolve()
    with zipfile.ZipFile(archive) as package:
        for entry in package.infolist():
            relative = Path(entry.filename.replace('\\', '/'))
            target = (destination / relative).resolve()
            if relative.is_absolute() or ':' in entry.filename or not target.is_relative_to(destination):
                raise ValueError('Unsafe path in release archive.')
            if ((entry.external_attr >> 16) & 0o170000) == 0o120000:
                raise ValueError('Links are not allowed in release archives.')
        package.extractall(destination)


@contextmanager
def download_directory(root):
    # Use inherited Windows permissions; restrictive temporary-directory ACLs
    # can prevent a sandboxed updater reading its own files.
    root=Path(root).resolve()
    target=root/('download-'+uuid.uuid4().hex)
    target.mkdir()
    try:
        yield target
    finally:
        if target.resolve().parent != root:
            raise ValueError('Unexpected temporary directory location.')
        shutil.rmtree(target)

def install(root, repository, progress=None):
    def report(stage, **values):
        if progress:
            progress(dict(stage=stage, **values))
    report('checking')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Invalid repository setting.')
    root = Path(root).resolve()
    root.mkdir(parents=True, exist_ok=True)
    release = json.loads(read_url('https://api.github.com/repos/' + repository + '/releases/latest'))
    version = release['tag_name']
    if not re.fullmatch(r'v\d+\.\d+\.\d+', version):
        raise ValueError('Unsupported release version.')
    report('available', version=version)
    assets = {asset['name']: asset for asset in release['assets']}
    destination = root / 'Versions' / version
    if not (destination / 'CWTCH.exe').is_file() or not (destination / 'CWTCH.pck').is_file():
        expected = read_url(assets['CWTCH-Windows.zip.sha256']['browser_download_url']).decode().split()[0].lower()
        if not re.fullmatch('[a-f0-9]{64}', expected):
            raise ValueError('Invalid release checksum.')
        with download_directory(root) as temporary:
            archive = Path(temporary) / 'release.zip'
            request = urllib.request.Request(assets['CWTCH-Windows.zip']['browser_download_url'], headers=HEADERS)
            with urllib.request.urlopen(request, timeout=120) as response, open(archive, 'wb') as output:
                total = int(response.headers.get('Content-Length') or assets['CWTCH-Windows.zip'].get('size') or 0)
                received = 0
                started = time.monotonic()
                last_report = started
                report('downloading', downloaded=0, total=total, speed=0)
                while chunk := response.read(256 * 1024):
                    output.write(chunk)
                    received += len(chunk)
                    now = time.monotonic()
                    if now - last_report >= 0.1:
                        report('downloading', downloaded=received, total=total, speed=received / max(now-started, 0.001))
                        last_report = now
                report('downloading', downloaded=received, total=total, speed=received / max(time.monotonic()-started, 0.001))
            report('verifying')
            with open(archive, 'rb') as source:
                actual = hashlib.file_digest(source, 'sha256').hexdigest()
            if actual != expected:
                raise ValueError('Download verification failed. The installed game was not changed.')
            stage = Path(temporary) / 'game'
            report('installing')
            safe_extract(archive, stage)
            if not (stage / 'CWTCH.exe').is_file() or not (stage / 'CWTCH.pck').is_file():
                raise ValueError('Game files are missing from this release.')
            destination.parent.mkdir(exist_ok=True)
            if destination.exists():
                raise ValueError('An incomplete version folder needs checking: ' + str(destination))
            shutil.move(str(stage), str(destination))
    result = {'version': version, 'executable': str(destination / 'CWTCH.exe')}
    pending = root / 'installed.tmp.json'
    pending.write_text(json.dumps(result), encoding='utf-8')
    pending.replace(root / 'installed.json')
    report('ready', version=version)
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', required=True)
    parser.add_argument('--result', required=True)
    parser.add_argument('--progress', action='store_true')
    args = parser.parse_args()
    try:
        config = json.loads((Path(__file__).parent / 'repository.json').read_text(encoding='utf-8-sig'))
        progress = (lambda event: print(json.dumps(event), flush=True)) if args.progress else None
        result = install(args.root, config['repository'], progress)
        result['ok'] = True
    except Exception as error:
        result = {'ok': False, 'message': str(error)}
    Path(args.result).write_text(json.dumps(result), encoding='utf-8')
    sys.exit(0 if result['ok'] else 1)
