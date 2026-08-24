from pathlib import Path
from PIL import Image

project = Path(__file__).resolve().parents[1]
source = project / 'assets' / 'branding' / 'arabic360.png'
image = Image.open(source).convert('RGBA')

windows_icon = project / 'windows' / 'runner' / 'resources' / 'app_icon.ico'
windows_icon.parent.mkdir(parents=True, exist_ok=True)
image.save(windows_icon, format='ICO', sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

mac_dir = project / 'macos' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
for size in (16, 32, 64, 128, 256, 512, 1024):
    image.resize((size, size), Image.Resampling.LANCZOS).save(
        mac_dir / f'app_icon_{size}.png',
        format='PNG',
    )

linux_icon = project / 'linux' / 'runner' / 'resources' / 'arabic360.png'
linux_icon.parent.mkdir(parents=True, exist_ok=True)
image.resize((512, 512), Image.Resampling.LANCZOS).save(linux_icon, format='PNG')
