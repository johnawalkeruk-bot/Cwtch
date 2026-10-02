"""Resolve local ES module imports before publishing; no network or side effects."""
import re
from pathlib import Path
IMPORT = re.compile(r"(?:\bfrom\s*|\bimport\s*(?:\(\s*)?)[\"'](\.[^\"']+)[\"']")
def include_modules(website, names):
    root = Path(website).resolve()
    result = list(dict.fromkeys(names))
    for name in result:
        file = (root / name).resolve()
        if not file.is_relative_to(root) or not file.is_file():
            raise ValueError(f'Missing or unsafe website asset: {name}')
        if file.suffix != '.js':
            continue
        for relative in IMPORT.findall(file.read_text(encoding='utf-8')):
            target = (file.parent / relative.split('?')[0].split('#')[0]).resolve()
            if not target.is_relative_to(root):
                raise ValueError(f'Module outside website: {relative}')
            dependency = target.relative_to(root).as_posix()
            if dependency not in result:
                result.append(dependency)
    return result
