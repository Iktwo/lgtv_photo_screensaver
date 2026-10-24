#!/bin/sh
# Builds the frame overlays (PNG, transparent centre) from molding strips.
#
# The strips in src/ were generated with Krea 2 (2048x512, a straight piece of
# molding on black). Each is trimmed of its black margin, then made
# seamless, scaled to the molding width, tiled along the four sides, and the
# sides are mitred at 45 degrees. The shadow the molding casts on the photo is
# baked in. Sizes are in the screen saver's 1920x1080 layout pixels.
#
# Each frame lies over the whole screen and overhangs it by JITTER px on every
# side, so qml/Slide.qml can nudge it by up to that much per photo without an
# edge showing. Molding widths here include the overhang.
#
#   ./build_frames.sh        (needs ImageMagick 7)
set -e
cd "$(dirname "$0")"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# seamless SRC X0 W OVERLAP OUT: crop W columns from X0, then crossfade the
# OVERLAP columns after them into the first ones, so the end runs into the start.
seamless() {
  src=$1 x0=$2 w=$3 o=$4 out=$5
  h=$(magick identify -format %h "$src")
  magick "$src" -crop "${w}x${h}+${x0}+0" +repage "$T/main.png"
  magick "$src" -crop "${o}x${h}+${x0}+0" +repage "$T/head.png"
  magick "$src" -crop "${o}x${h}+$((x0 + w))+0" +repage "$T/tail.png"
  magick -size "${h}x${o}" gradient:black-white -rotate -90 "$T/ramp.png"
  magick "$T/tail.png" "$T/head.png" "$T/ramp.png" -composite "$T/seam.png"
  magick "$T/main.png" "$T/seam.png" -geometry +0+0 -composite "$out"
}

# evenlight SRC OUT: takes out light that changes along the strip (brighter at
# one end), which tiling would turn into a repeating band, while keeping the
# light across it that gives the molding its shape.
evenlight() {
  w=$(magick identify -format %w "$1"); h=$(magick identify -format %h "$1")
  magick "$1" -resize "12x${h}!" -resize "${w}x${h}!" "$T/along.png"
  magick "$1" -resize "1x${h}!" -resize "${w}x${h}!" "$T/across.png"
  magick "$1" "$T/along.png" "$T/across.png" -fx "u * u[2] / max(v, 0.02)" "$2"
}

# ring STRIP F OW OH OUT: a mitred frame OW x OH with molding width F.
ring() {
  strip=$1 f=$2 ow=$3 oh=$4 out=$5
  magick "$strip" -resize "x$f" "$T/s.png"
  magick -size "${ow}x${f}" tile:"$T/s.png" "$T/top.png"
  magick -size "${oh}x${f}" tile:"$T/s.png" "$T/side.png"
  magick "$T/top.png" -rotate 180 "$T/bottom.png"
  magick "$T/side.png" -rotate -90 "$T/left.png"
  magick "$T/side.png" -rotate 90 "$T/right.png"

  # piece IMG X Y POLYGON: IMG placed at X,Y, kept only inside POLYGON.
  piece() {
    magick -size "${ow}x${oh}" xc:none "$1" -geometry "+$2+$3" -composite \
      \( -size "${ow}x${oh}" xc:black -fill white -draw "polygon $4" -alpha off \) \
      -compose CopyOpacity -composite "$5"
  }
  piece "$T/top.png" 0 0 "0,0 $ow,0 $((ow - f)),$f $f,$f" "$T/p1.png"
  piece "$T/bottom.png" 0 $((oh - f)) "0,$oh $ow,$oh $((ow - f)),$((oh - f)) $f,$((oh - f))" "$T/p2.png"
  piece "$T/left.png" 0 0 "0,0 $f,$f $f,$((oh - f)) 0,$oh" "$T/p3.png"
  piece "$T/right.png" $((ow - f)) 0 "$ow,0 $((ow - f)),$f $((ow - f)),$((oh - f)) $ow,$oh" "$T/p4.png"

  magick "$T/p1.png" "$T/p2.png" -compose over -composite "$T/p3.png" -composite "$T/p4.png" -composite \
    -stroke "rgba(0,0,0,0.45)" -strokewidth 1.5 \
    -draw "line 0,0 $f,$f" -draw "line $ow,0 $((ow - f)),$f" \
    -draw "line 0,$oh $f,$((oh - f))" -draw "line $ow,$oh $((ow - f)),$((oh - f))" \
    "$T/ring.png"

  # Shadow on the photo: the ring's own shape, blurred and nudged down-right.
  magick "$T/ring.png" -alpha extract -blur 0x7 -level 0,70% -alpha off "$T/shmask.png"
  magick -size "${ow}x${oh}" xc:black "$T/shmask.png" -compose CopyOpacity -composite \
    -channel A -evaluate multiply 0.6 +channel "$T/shadow.png"
  magick -size "${ow}x${oh}" xc:none "$T/shadow.png" -geometry +3+5 -composite \
    "$T/ring.png" -composite "$out"
  echo "built $out (${ow}x${oh}, molding ${f}px)"
}

JITTER=8
# Molding on screen, the same for every frame so they read as one set.
F=60
FJ=$((F + JITTER))
OW=$((1920 + 2 * JITTER)); OH=$((1080 + 2 * JITTER))
mkdir -p ../qml/frames
rm -f ../qml/frames/*.png

# The molding without the black around it. Crop offsets below count from here.
for m in gold silver walnut oak; do
  magick "src/$m-raw.png" -fuzz 12% -trim +repage "$T/$m-band.png"
done

# Gilded: 5 repeats of the 294 px acanthus ornament.
seamless "$T/gold-band.png" 200 1470 60 "$T/gold-strip.png"
ring "$T/gold-strip.png" $FJ $OW $OH ../qml/frames/gold.png

# Silver: the scrollwork comes round every ~1031 px; one round, a wide crossfade.
evenlight "$T/silver-band.png" "$T/silver-even.png"
seamless "$T/silver-even.png" 300 1031 120 "$T/silver-strip.png"
ring "$T/silver-strip.png" $FJ $OW $OH ../qml/frames/silver.png

# Walnut: no repeat to match, so a longer crossfade for the grain.
evenlight "$T/walnut-band.png" "$T/walnut-even.png"
seamless "$T/walnut-even.png" 100 1600 200 "$T/walnut-strip.png"
ring "$T/walnut-strip.png" $FJ $OW $OH ../qml/frames/walnut.png

# Oak: the board has rounded ends, so cut from its middle. It came out lit
# flat, so a rounded profile is shaded in: light along the outer edge, a
# shadow at the inner step.
evenlight "$T/oak-band.png" "$T/oak-even.png"
seamless "$T/oak-even.png" 150 1600 200 "$T/oak-flat.png"
h=$(magick identify -format %h "$T/oak-flat.png")
magick -size 1600x$h gradient:"#ffffff"-"#b4b4b4" \
  \( -size 1600x$((h / 8)) gradient:"#8c8c8c"-"#c4c4c4" \) -gravity south -composite "$T/oak-shade.png"
magick "$T/oak-flat.png" "$T/oak-shade.png" -compose multiply -composite "$T/oak-strip.png"
ring "$T/oak-strip.png" $FJ $OW $OH ../qml/frames/oak.png

# Black: drawn, a soft top light, a darker body, a highlight line near the
# outer edge and a step before the inner edge.
magick -size 64x$FJ gradient:"#383838"-"#0b0b0b" \
  -fill "#565656" -draw "line 0,$((JITTER + 2)) 63,$((JITTER + 2))" \
  -fill "#1e1e1e" -draw "rectangle 0,$((FJ - 12)) 63,$((FJ - 1))" \
  -fill "#050505" -draw "line 0,$((FJ - 1)) 63,$((FJ - 1))" "$T/black-strip.png"
ring "$T/black-strip.png" $FJ $OW $OH ../qml/frames/black.png

# Black and gold: the black body with the gilded frame's bead row as a liner
# along the inner edge.
seamless "$T/gold-band.png" 200 1470 60 "$T/gold-full.png"
magick "$T/gold-full.png" -crop 1470x110+0+329 +repage -resize "x16!" "$T/liner.png"
lw=$(magick identify -format %w "$T/liner.png")
magick -size ${lw}x$((FJ - 16)) gradient:"#383838"-"#0b0b0b" \
  -fill "#565656" -draw "line 0,$((JITTER + 2)) $lw,$((JITTER + 2))" "$T/bg-body.png"
magick "$T/bg-body.png" "$T/liner.png" -append "$T/blackgold-strip.png"
ring "$T/blackgold-strip.png" $FJ $OW $OH ../qml/frames/blackgold.png
