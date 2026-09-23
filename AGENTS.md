# CWTCH development

This desktop folder is the canonical project. Edit Game/ here, not older workspace copies.
Preserve source models in NPCS/, Trees/ and Tools/. Never commit .local/, credentials,
player saves, engine caches or generated release archives.

After a user-requested game version is complete, run appropriate checks, update
Game/FULL_SOURCE.md, then publish using DevTools/Publish-Version.ps1. The user has
requested that every completed new version be committed, pushed and released.
Do not publish unfinished changes. Report build, authentication or upload failures
honestly, retaining the local work. Never force-push or rewrite released tags.
