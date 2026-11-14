import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2

Item {
    id: ring
    property int diameter: 32
    property real percent: -1
    property color strokeColor: "#29b6f6"
    property color trackColor: "#59616a"
    property color textColor: "white"
    implicitWidth: diameter
    implicitHeight: diameter

    Canvas {
        id: canvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var context = getContext("2d")
            context.reset()
            var size = Math.min(width, height)
            var line = Math.max(4, size * 0.105)
            var radius = (size - line) / 2 - 1
            context.lineWidth = line
            context.lineCap = "round"
            context.strokeStyle = ring.trackColor
            context.beginPath()
            context.arc(width / 2, height / 2, radius, 0, Math.PI * 2)
            context.stroke()
            if (ring.percent >= 0) {
                context.strokeStyle = ring.strokeColor
                context.beginPath()
                context.arc(width / 2, height / 2, radius,
                            -Math.PI / 2,
                            -Math.PI / 2 + Math.PI * 2 * ring.percent / 100)
                context.stroke()
            }
        }
    }

    QQC2.Label {
        anchors.centerIn: parent
        text: ring.percent < 0 ? "--" : Math.round(ring.percent) + "%"
        color: ring.textColor
        font.pixelSize: ring.diameter < 40 ? 9 : 16
        font.bold: true
    }

    onPercentChanged: canvas.requestPaint()
    onStrokeColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
}
