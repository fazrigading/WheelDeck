# HIDMaestro SDK (vendored)

Managed C# SDK + embedded UMDF2 driver payload for the Windows virtual
controller backend. See `plan/migrate-vigembus-to-hidmaestro-1.md`.

- Version: v1.7.3
- Download URL: https://github.com/hifihedgehog/HIDMaestro/releases/tag/v1.7.3
  (`HIDMaestro-v1.7.3.zip`, root `HIDMaestro.Core.dll`)
- SHA256 (`HIDMaestro.Core.dll`):
  `95c6d3ec0d41cd7b3adda80da3ffbcd19c9466cc50e08a973c7745a16c7e0bde`
- Upstream repo: https://github.com/hifihedgehog/HIDMaestro
- License: MIT

There is no NuGet feed (as of 2026-09-11); upstream instructs consumers to
reference the DLL from a release ZIP or source build.
See https://hidmaestro.org/docs/start/installation/.

To update: download the new release ZIP, replace `HIDMaestro.Core.dll`, and
update the version + SHA256 above.
