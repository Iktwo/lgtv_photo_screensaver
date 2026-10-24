/*
 * One photo layer of the slideshow: a framed print filling the screen.
 *
 * Unless the style is "none", a frame (frames/*.png, built by
 * frames/build_frames.sh) lies over the screen's edges with `frameWidth` px of
 * molding on screen, and inside it a cream mat `matWidth` px wide with a
 * lighter cut edge round the photo, as a gallery would mount a print.
 *
 * Pictures hold still. The frame and mat are the shapes every photo shares, so
 * each photo hangs the whole picture up to `jitter` px off centre - a new spot
 * per photo, changed only under the crossfade - and they never sit on the same
 * pixels for hours; the TV's own Screen Shift does the rest. The frame PNGs
 * overhang the screen, and the mat colour fills it, by that much, so no edge
 * ever shows.
 *
 * `kenBurns` turns on a slow zoom and pan of the photo; its zoom never drops
 * below zMin, which leaves a margin the pan can use without showing the mat.
 */
import QtQuick 2.4

Item {
    id: slide

    property int motionMs: 45000
    property real zoom: 0.08
    property bool kenBurns: false
    property int jitter: 8
    property string frameStyle: "none"

    property bool mat: true
    property int frameWidth: 60
    property int matWidth: 40
    property color matColor: "#c9c2b4"
    property color bevelColor: "#e4dfd3"
    property int bevelWidth: 4

    signal ready()
    signal failed()

    opacity: 0

    // All 60 px of molding on screen, so any of them reads as the same frame size.
    readonly property var frames: ({
        "gold": "frames/gold.png", "silver": "frames/silver.png",
        "walnut": "frames/walnut.png", "oak": "frames/oak.png",
        "black": "frames/black.png", "blackgold": "frames/blackgold.png"
    })
    readonly property bool framed: !!frames[frameStyle]
    readonly property bool matted: framed && mat
    // Where the photo starts: inside the molding and the mat.
    readonly property int inset: matted ? frameWidth + matWidth : 0

    function load(url, style) {
        frameStyle = style || "none";
        img.source = "";
        img.source = url;
    }

    // Frees the decoded picture once the layer is hidden.
    function release() {
        motion.stop();
        img.source = "";
    }

    function rand(span) { return (Math.random() * 2 - 1) * span; }

    function startMotion() {
        // Where this picture hangs while it shows.
        group.x = framed ? rand(jitter) : 0;
        group.y = framed ? rand(jitter) : 0;

        motion.stop();
        if (!kenBurns) {
            img.scale = 1; img.x = 0; img.y = 0;
            return;
        }
        var zMin = 1 + zoom * 0.4;
        var zMax = 1 + zoom;
        var zoomIn = Math.random() < 0.5;
        // At zMin the photo overhangs each edge of its box by (zMin - 1) / 2 of its size.
        var roomX = photoBox.width * (zMin - 1) / 2;
        var roomY = photoBox.height * (zMin - 1) / 2;
        scaleAnim.from = zoomIn ? zMin : zMax;
        scaleAnim.to = zoomIn ? zMax : zMin;
        xAnim.from = rand(roomX); xAnim.to = rand(roomX);
        yAnim.from = rand(roomY); yAnim.to = rand(roomY);
        motion.start();
    }

    Rectangle {
        anchors.fill: parent
        visible: slide.matted
        color: slide.matColor
    }

    Item {
        id: group
        width: slide.width
        height: slide.height

        // The mat's cut edge, lighter than its face.
        Rectangle {
            visible: slide.matted
            x: slide.inset - slide.bevelWidth
            y: x
            width: slide.width - 2 * x
            height: slide.height - 2 * y
            color: slide.bevelColor
        }

        Item {
            id: photoBox
            x: slide.inset
            y: slide.inset
            width: slide.width - 2 * slide.inset
            height: slide.height - 2 * slide.inset
            clip: slide.matted || slide.kenBurns

            Image {
                id: img
                width: photoBox.width
                height: photoBox.height
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true
                // Decoded at the size drawn: the compositor works at 1920x1080,
                // so decoding the full 3840x2160 would only cost memory.
                sourceSize.width: photoBox.width
                sourceSize.height: photoBox.height

                onStatusChanged: {
                    if (status === Image.Ready) slide.ready();
                    else if (status === Image.Error) slide.failed();
                }
            }
        }

        Image {
            x: -slide.jitter
            y: -slide.jitter
            width: slide.width + 2 * slide.jitter
            height: slide.height + 2 * slide.jitter
            source: slide.frames[slide.frameStyle] || ""
            visible: slide.framed
            smooth: true
        }
    }

    ParallelAnimation {
        id: motion
        NumberAnimation { id: scaleAnim; target: img; property: "scale"; duration: slide.motionMs; easing.type: Easing.InOutSine }
        NumberAnimation { id: xAnim; target: img; property: "x"; duration: slide.motionMs; easing.type: Easing.InOutSine }
        NumberAnimation { id: yAnim; target: img; property: "y"; duration: slide.motionMs; easing.type: Easing.InOutSine }
    }
}
