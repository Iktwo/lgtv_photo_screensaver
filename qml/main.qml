/*
 * Photo screen saver.
 *
 * Mounted over com.webos.app.screensaver by photo-screensaver.sh, so it runs
 * as the platform's own screen saver and any key dismisses it, as with LG's.
 *
 * Photos come from usb0..usb3, links the boot hook points at a photo folder on
 * each USB drive (or at nothing), shuffled together. With no photos on USB,
 * the ones built in (photos/ beside this folder) show instead.
 */
import QtQuick 2.4
import Qt.labs.folderlistmodel 2.1
import Eos.Window 0.1

WebOSWindow {
    id: win

    // The compositor's layout size; Screen can report smaller on some sets.
    width: 1920
    height: 1080

    windowType: "_WEBOS_WINDOW_TYPE_SCREENSAVER"
    appId: "com.webos.app.screensaver"
    title: "Screen Saver"
    visible: true
    color: "black"

    readonly property string appDir: "file:///usr/palm/applications/com.webos.app.screensaver"

    // A frame from Slide.qml's set ("gold", "silver", "walnut", "oak", "black",
    // "blackgold"), "none", or "frames" for a different frame with each photo.
    property string frameStyle: "frames"
    readonly property var frameSet: ["gold", "silver", "walnut", "oak", "black", "blackgold"]
    property string lastFrame: ""

    // How long each photo stays, and how long the crossfade between two takes.
    property int showMs: 40000
    property int fadeMs: 2500
    // How far the slow zoom goes (0.08 = 8%).
    property real zoom: 0.08
    // A black veil over everything (0 = none, 1 = black). On an OLED each pixel
    // makes its own light, so this saves power and panel wear as dimming would,
    // with no TV setting to change and put back.
    property real dim: 0.4

    property var playlist: []
    property int nextIndex: 0
    property var front: null
    property int failures: 0

    function shuffle(list) {
        for (var i = list.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var t = list[i]; list[i] = list[j]; list[j] = t;
        }
        return list;
    }

    function photosIn(models) {
        var list = [];
        for (var m = 0; m < models.length; m++) {
            for (var i = 0; i < models[m].count; i++) {
                var name = models[m].get(i, "fileName");
                // macOS leaves "._name.jpg" metadata files on USB drives.
                if (name.indexOf("._") === 0) continue;
                list.push(models[m].get(i, "fileURL"));
            }
        }
        return list;
    }

    // Rebuilt whenever a folder's contents change, such as a USB drive coming
    // in. Photos on USB replace the built-in ones; those are only the fallback.
    function collect() {
        var list = photosIn([usb0, usb1, usb2, usb3]);
        if (list.length === 0) list = photosIn([embedded]);
        playlist = shuffle(list);
        nextIndex = 0;
        if (front === null && playlist.length > 0) advance();
    }

    function advance() {
        if (playlist.length === 0) return;
        if (nextIndex >= playlist.length) {
            playlist = shuffle(playlist);
            nextIndex = 0;
        }
        var back = (front === slideA) ? slideB : slideA;
        var style = frameStyle;
        if (style === "frames") {
            // Any of the set but the one just shown.
            do {
                style = frameSet[Math.floor(Math.random() * frameSet.length)];
            } while (style === lastFrame && frameSet.length > 1);
            lastFrame = style;
        }
        back.load(playlist[nextIndex], style);
        nextIndex++;
    }

    function reveal(slide) {
        failures = 0;
        slide.startMotion();
        fadeIn.target = slide;
        fadeOut.target = front;
        crossfade.start();
        front = slide;
        showTimer.restart();
    }

    function skip(slide) {
        // Every photo failing would otherwise loop for good.
        failures++;
        if (failures < Math.max(1, playlist.length)) advance();
    }

    Slide {
        id: slideA
        width: win.width
        height: win.height
        zoom: win.zoom
        motionMs: win.showMs + win.fadeMs * 2
        onReady: win.reveal(slideA)
        onFailed: win.skip(slideA)
    }

    Slide {
        id: slideB
        width: win.width
        height: win.height
        zoom: win.zoom
        motionMs: win.showMs + win.fadeMs * 2
        onReady: win.reveal(slideB)
        onFailed: win.skip(slideB)
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: win.dim
    }

    ParallelAnimation {
        id: crossfade
        NumberAnimation { id: fadeIn; property: "opacity"; to: 1; duration: win.fadeMs; easing.type: Easing.InOutQuad }
        NumberAnimation { id: fadeOut; property: "opacity"; to: 0; duration: win.fadeMs; easing.type: Easing.InOutQuad }
        onStopped: if (fadeOut.target) fadeOut.target.release()
    }

    Timer {
        id: showTimer
        interval: win.showMs
        onTriggered: win.advance()
    }

    // Folder models fill in asynchronously and one at a time: wait for them to settle.
    Timer {
        id: settle
        interval: 1500
        onTriggered: win.collect()
    }

    FolderListModel {
        id: embedded
        folder: win.appDir + "/photos"
        nameFilters: ["*.jpg", "*.jpeg", "*.JPG", "*.JPEG"]
        showDirs: false
        onCountChanged: settle.restart()
    }
    FolderListModel {
        id: usb0
        folder: win.appDir + "/usb0"
        nameFilters: ["*.jpg", "*.jpeg", "*.JPG", "*.JPEG"]
        showDirs: false
        onCountChanged: settle.restart()
    }
    FolderListModel {
        id: usb1
        folder: win.appDir + "/usb1"
        nameFilters: ["*.jpg", "*.jpeg", "*.JPG", "*.JPEG"]
        showDirs: false
        onCountChanged: settle.restart()
    }
    FolderListModel {
        id: usb2
        folder: win.appDir + "/usb2"
        nameFilters: ["*.jpg", "*.jpeg", "*.JPG", "*.JPEG"]
        showDirs: false
        onCountChanged: settle.restart()
    }
    FolderListModel {
        id: usb3
        folder: win.appDir + "/usb3"
        nameFilters: ["*.jpg", "*.jpeg", "*.JPG", "*.JPEG"]
        showDirs: false
        onCountChanged: settle.restart()
    }

    Component.onCompleted: settle.start()
}
