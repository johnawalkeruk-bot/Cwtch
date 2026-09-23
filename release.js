'use strict';
(async () => {
  try {
    const response = await fetch('https://api.github.com/repos/johnawalkeruk-bot/Cwtch/releases/latest', {signal: AbortSignal.timeout(8000)});
    if (!response.ok) return;
    const release = await response.json();
    const launcher = release.assets.find(asset => asset.name === 'CWTCH-Launcher.zip');
    const game = release.assets.find(asset => asset.name === 'CWTCH-Windows.zip');
    if (!launcher) return;
    document.getElementById('version').textContent = release.tag_name;
    const size = (launcher.size / 1048576).toFixed(1);
    document.getElementById('download-detail').textContent = `${size} MB launcher ZIP${game ? ` · Game download: about ${Math.ceil(game.size / 1048576)} MB` : ''}. Installs the latest published game.`;
  } catch (_) { /* The permanent download link works without the version lookup. */ }
})();
