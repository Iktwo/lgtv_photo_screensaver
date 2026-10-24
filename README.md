# Photo Screen Saver for rooted LG webOS TVs

A replacement for LG's screen saver that shows your own photos as framed,
matted prints, the way a gallery would hang them. It runs as the TV's own
screen saver: it comes on when LG's would, and any key on the remote closes it.

- Your photos, full screen, in one of six frames (gilded, silver, walnut, light
  oak, black, black with a gold liner) chosen per photo, with a cream mat and a
  lighter cut edge round the print.
- Photos from a USB drive: plug in a drive with an `LGTV_4K` folder and those
  replace the built-in ones. Up to four drives, shuffled together.
- A slow crossfade between photos, and nothing else moves.
- Gentle on an OLED: a black veil over the picture lowers power and panel wear
  (each OLED pixel makes its own light), and the frame shifts a few pixels with
  each photo, so it never sits on the same pixels for hours.
- Nothing on the TV's read-only system is changed. Turning it off brings back
  LG's screen saver at once.

## Requirements

- An LG webOS TV with **root** and the
  [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel), with
  SSH enabled and your key in `/home/root/.ssh/authorized_keys`. This project
  does not explain how to root a TV.
- LG's screen saver must be a QML app, as it is up to at least webOS 6. The
  install script checks and refuses otherwise. On webOS 10 and later it is a
  Flutter app, so this does not work there.
- A Mac or Linux computer with `ssh` and `tar` for installing.
  [ImageMagick 7](https://imagemagick.org) if you want to prepare photos or
  rebuild the frames.

Developed on an LG OLED C1 (webOS 6.3.2, Qt 5.12) and also installed on an
OLED E8 (webOS 4.4.1, Qt 5.6).

## Install

1. Put a few `.jpg` photos in `photos/`. They are built into the screen saver
   and show whenever no USB drive has photos. See [Preparing photos](#preparing-photos).
2. Try it out until the next reboot:

   ```sh
   ./deploy.sh 192.168.1.50 install
   ```

   Then start the screen saver, or leave the TV idle until LG's would come on.
   [GlassHouse](https://github.com/rorygallagher2024/glasshouse) has a *Start
   screen saver* button in its Screensaver tab.
3. Keep it across reboots:

   ```sh
   ./deploy.sh 192.168.1.50 enable
   ```

Run `deploy.sh` again after any change. It copies everything fresh and keeps
the boot hook as it was.

## Photos on USB

Copy your photos into a folder named `LGTV_4K` (or `Screensaver`) at the top
of a USB drive, and plug it into the TV. FAT32, exFAT and NTFS all work.

- The TV finds the drive within about 15 seconds. The next screen saver shows
  only the USB photos, shuffled across every connected drive.
- With no drive, or none with photos, the built-in photos show instead.
- The `._` files macOS leaves on USB drives are ignored.

## Preparing photos

Photos look best as 3840×2160 sRGB JPEGs. ImageMagick does it in one step:
turn the photo upright, convert its colours to sRGB (iPhone photos are Display
P3), fill and centre-crop to 16:9, and drop the metadata.

```sh
magick input.heic -auto-orient \
  -profile "/System/Library/ColorSync/Profiles/sRGB Profile.icc" \
  -resize '3840x2160^' -gravity center -extent 3840x2160 \
  -strip -interlace JPEG -sampling-factor 4:2:0 -quality 88 output.jpg
```

On Linux, point `-profile` at any sRGB ICC profile, such as `sRGB.icc` from
your distribution's colour profiles package. This averages about 1.3 MB per
photo. The TV's compositor draws at 1920×1080, so each photo is decoded at
that size. Bigger files only cost space.

## Settings

Edit these, then run `deploy.sh` again.

In `qml/main.qml`:

| Setting | Default | What it does |
|---|---|---|
| `frameStyle` | `"frames"` | `"frames"` for a different frame with each photo; one frame name for always that frame; `"none"` for no frame or mat |
| `frameSet` | all six | the frames `"frames"` picks from: `gold`, `silver`, `walnut`, `oak`, `black`, `blackgold` |
| `showMs` | `40000` | how long each photo shows, in milliseconds |
| `fadeMs` | `2500` | how long the crossfade takes |
| `dim` | `0.4` | the black veil over the picture: 0 for none, 1 for black |

In `qml/Slide.qml`:

| Setting | Default | What it does |
|---|---|---|
| `mat` | `true` | the mat inside the frame |
| `matWidth` | `40` | mat width, in 1920×1080 layout pixels |
| `matColor`, `bevelColor` | cream | the mat's face and its cut edge |
| `jitter` | `8` | how far the picture may sit off centre, a new spot per photo |
| `kenBurns` | `false` | a slow zoom and pan of each photo |

## Frames

The frame overlays in `qml/frames/` are built by `frames/build_frames.sh`
from the four molding strips in `frames/src/`. The black frames are drawn by
the script. Each strip is:

1. trimmed,
2. evened out where its lighting changes along its length (tiling would turn
   that into a repeating band),
3. made seamless by crossfading its end into its start (ornaments are cut at
   a whole number of repeats),
4. tiled along the four sides and mitred at 45° with a faint joint line,
5. given a soft shadow onto the photo.

Every frame shows 60 px of molding on screen (`F` in the script, `frameWidth`
in `Slide.qml`), so they read as one set. Each overhangs the screen by the
jitter.

To add a frame, generate or photograph a straight 2048×512 strip of molding
on black, outer edge at the top. Add it to the script like the others and to
`frames` in `Slide.qml`, then run:

```sh
frames/build_frames.sh
```

## How it works

LG's screen saver lives in the read-only system at
`/usr/palm/applications/com.webos.app.screensaver`. `photo-screensaver.sh`
stages a folder in `/var/lib/photoscreensaver/stage` with LG's own manifest,
unchanged, and this QML in place of LG's. It then bind-mounts that folder over
the app, the way GlassHouse mounts its screen savers. The TV launches the
screen saver as usual and gets this one.

- The **boot hook**, `/var/lib/webosbrew/init.d/70-photo-screensaver`, mounts
  the folder at startup and returns at once. A background watcher keeps the
  links `stage/usb0` to `usb3` pointing at the photo folders on whatever USB
  drives are mounted (`/tmp/usb/sdX/sdXN`). The Homebrew Channel puts the TV
  in failsafe mode if a boot hook hangs, so nothing in the hook waits.
- If something else is already mounted over the screen saver, such as a
  GlassHouse screen saver, it is left alone. To use this one with GlassHouse,
  set GlassHouse's screen saver to *LG default*.
- The screen saver app is only closed, to load new files, while the TV is
  plainly *Active*. If it is closed while showing, the TV's power service never
  hears that it went away. It then stays in "Screen Saver Ready", ignores every
  new screen saver and answers "power is busy" until a key press or a reboot.

## Commands on the TV

```sh
sh /var/lib/photoscreensaver/photo-screensaver.sh status    # what is active, how many photos it sees
sh /var/lib/photoscreensaver/photo-screensaver.sh disable   # LG's screen saver back, and no boot hook
sh /var/lib/photoscreensaver/photo-screensaver.sh enable    # mount now and at every boot
```

To remove it completely, run `disable`, then `rm -rf /var/lib/photoscreensaver`.

## Troubleshooting

- **LG's screen saver still shows.** Run `status`. *Something else is mounted
  over it* means another tool's screen saver is active. A screen saver already
  on screen keeps the old files until it is dismissed.
- **"com.webos.service.tvpower/power is busy".** The power service lost track
  of a screen saver. Press any key on the remote, or reboot the TV.
- **Black screen or missing frames.** QML errors are in the system log:
  `grep qml-runner /var/log/messages | grep -i screensaver | tail`.
- **USB photos do not show.** Check the folder name and that it sits at the top
  of the drive. `status` lists each drive the watcher found. The log is
  `/tmp/photo-screensaver.log`.

## OLED burn-in

Burn-in comes from the same bright content on the same pixels for many hours.
Photos that change every 40 seconds even out. The frame and mat are what every
photo shares, which is why the picture shifts a few pixels with each photo and
the black veil is on. Keep the TV's own protections on too: Settings → General
→ OLED Care → Screen Shift and Adjust Logo Brightness. Also let the TV's
power-off timers end long idle stretches.

## Credits

- The approach of bind-mounting over LG's screen saver comes from
  [GlassHouse](https://github.com/rorygallagher2024/glasshouse).
- The molding strips in `frames/src/` were generated with Krea 2. Check the
  model's terms if you reuse them outside this project.

## License

MIT. See [LICENSE](LICENSE). Use at your own risk: this runs as root on a
modified TV, and it comes with no warranty. It is not affiliated with or
endorsed by LG Electronics. webOS is a trademark of LG Electronics.
