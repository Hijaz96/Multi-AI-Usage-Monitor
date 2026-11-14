import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0

Item {
    id: root


    // V3_DASHBOARD_START

    property var tokenReportV3: ({
        available: false,
        sessions: 0,
        days: []
    })

    property int reportPeriodV3: 7
    property bool reportBusyV3: false

    function refreshTokenV3() {
        if (reportBusyV3)
            return

        reportBusyV3 = true

        tokenSourceV3.connectSource(
            "/usr/bin/python3 " +
            "/home/uitm/.local/share/plasma/plasmoids/" +
            "org.local.multiaiusage/contents/scripts/token-report-v3.py"
        )
    }

    function refreshAllV3() {
        refresh()
        refreshAccountV23()
        refreshTokenV3()
    }

    function reportDaysV3() {
        var days = tokenReportV3.days || []
        return days.slice(
            Math.max(0, days.length - reportPeriodV3)
        )
    }

    function reportSumV3(key) {
        var days = reportDaysV3()
        var total = 0

        for (var i = 0; i < days.length; i++)
            total += Number(days[i][key] || 0)

        return total
    }

    function reportMaxV3() {
        var days = reportDaysV3()
        var maximum = 1

        for (var i = 0; i < days.length; i++)
            maximum = Math.max(
                maximum,
                Number(days[i].total_tokens || 0)
            )

        return maximum
    }

    function formatTokensV3(value) {
        if (value >= 1000000)
            return (value / 1000000).toFixed(2) + "M"

        if (value >= 1000)
            return (value / 1000).toFixed(1) + "K"

        return String(Math.round(value))
    }

    PlasmaCore.DataSource {
        id: tokenSourceV3
        engine: "executable"
        connectedSources: []

        onNewData: {
            try {
                root.tokenReportV3 = JSON.parse(
                    data["stdout"] || "{}"
                )
            } catch (e) {
                root.tokenReportV3 = ({
                    available: false,
                    sessions: 0,
                    days: []
                })
            }

            root.reportBusyV3 = false
            disconnectSource(sourceName)
        }
    }

    // V3_DASHBOARD_PROPERTIES_END

    // v2.3 Codex Account Manager
    property string accountEmailV23: ""
    property string accountTypeV23: ""
    property string accountMessageV23: "Checking account..."
    property bool accountConnectedV23: false
    property bool accountBusyV23: false
    property bool loginPendingV25: false
    property int loginPollCountV25: 0
    property bool accountLogoutConfirmV23: false

    PlasmaCore.DataSource {
        id: accountStatusSourceV23
        engine: "executable"
        connectedSources: []
        onNewData: {
            try {
                var r = JSON.parse(data["stdout"] || "{}")
                root.accountConnectedV23 = r.status === "connected"

                if (root.accountConnectedV23 &&
                    root.loginPendingV25) {
                    root.loginPendingV25 = false
                    loginPollV25.stop()
                    root.refresh()
                }
                root.accountEmailV23 = r.email || ""
                root.accountTypeV23 = r.type || ""
                root.accountMessageV23 =
                    r.status === "error" ? (r.message || "Account unavailable") :
                    root.accountConnectedV23 ? "Connected" : "Not logged in"
            } catch (e) {
                root.accountMessageV23 = "Account lookup failed"
            }
            root.accountBusyV23 = false
            disconnectSource(sourceName)
        }
    }

    PlasmaCore.DataSource {
        id: accountActionSourceV23
        engine: "executable"
        connectedSources: []
        onNewData: {
            try {
                var r = JSON.parse(data["stdout"] || "{}")
                root.accountMessageV23 = r.message || "Action completed"

                if (sourceName.indexOf(" login") !== -1 &&
                    r.status === "started") {
                    root.loginPendingV25 = true
                    root.loginPollCountV25 = 0
                    loginPollV25.start()
                }

                if (sourceName.indexOf(" logout") !== -1) {
                    root.loginPendingV25 = false
                    loginPollV25.stop()
                }
            } catch (e) {
                root.accountMessageV23 = "Action failed"
            }
            accountTimeoutV231.stop()
            root.accountBusyV23 = false
            root.accountLogoutConfirmV23 = false
            disconnectSource(sourceName)
            root.refreshAccountV23()
            root.refresh()
        }
    }

    function refreshAccountV23() {
        if (accountBusyV23) return
        accountBusyV23 = true
        accountStatusSourceV23.connectSource(
            "/home/uitm/.local/bin/codex-widget-account status"
        )
    }

    Timer {
        id: accountTimeoutV231
        interval: 25000
        repeat: false
        onTriggered: {
            if (!root.accountBusyV23) return
            root.accountBusyV23 = false
            root.accountLogoutConfirmV23 = false
            root.accountMessageV23 =
                "Account operation timed out. Refresh to verify status."
        }
    }

    Timer {
        id: loginPollV25
        interval: 4000
        repeat: true
        running: false

        onTriggered: {
            if (!root.loginPendingV25) {
                stop()
                return
            }

            root.loginPollCountV25++

            if (root.loginPollCountV25 >= 45) {
                root.loginPendingV25 = false
                stop()
                root.accountMessageV23 =
                    "Login check timed out. Use Account Refresh."
                return
            }

            if (!root.accountBusyV23)
                root.refreshAccountV23()
        }
    }

    function accountActionV23(action) {
        if (accountBusyV23) return
        accountBusyV23 = true
        accountTimeoutV231.restart()
        accountActionSourceV23.connectSource(
            "/home/uitm/.local/bin/codex-widget-account " + action
        )
    }


    property bool resetBusyV21: false
    property bool resetStatusBusyV21: false
    property bool resetStatusReadyV21: false
    property string resetStatusTextV21: "Checking reset status..."
    property string resetFeedbackV21: ""

    PlasmaCore.DataSource {
        id: resetStatusSourceV21
        engine: "executable"
        connectedSources: []

        onNewData: {
            var ready = false
            var message = "Could not verify reset status."

            try {
                var result = JSON.parse(data["stdout"] || "{}")
                if (data["exit code"] === 0) {
                    ready = result.status === "ready"
                    message = result.message || message
                }
            } catch (e) {
                message = "Invalid reset status response."
            }

            root.resetStatusReadyV21 = ready
            root.resetStatusTextV21 = message
            root.resetStatusBusyV21 = false
            disconnectSource(sourceName)
        }
    }

    PlasmaCore.DataSource {
        id: resetActionSourceV21
        engine: "executable"
        connectedSources: []

        onNewData: {
            try {
                var result = JSON.parse(data["stdout"] || "{}")
                root.resetFeedbackV21 =
                    result.message || "Reset result unavailable."
            } catch (e) {
                root.resetFeedbackV21 =
                    "Reset outcome uncertain. Do not retry."
            }

            root.resetBusyV21 = false
            root.resetStatusReadyV21 = false
            disconnectSource(sourceName)
            root.refresh()
            root.checkResetStatusV21()
        }
    }

    function checkResetStatusV21() {
        resetStatusReadyV21 = false
        resetStatusTextV21 = "Checking reset status..."

        if (resetBusyV21 || resetStatusBusyV21)
            return

        resetStatusBusyV21 = true
        resetStatusSourceV21.connectSource(
            "/home/uitm/.local/bin/codex-reset-credit --status"
        )
    }

    function confirmResetV21() {
        if (resetBusyV21 || resetStatusBusyV21 ||
            !resetStatusReadyV21 ||
            typeof usage.resets !== "number" ||
            usage.resets <= 0)
            return

        resetBusyV21 = true
        resetStatusReadyV21 = false
        resetFeedbackV21 = "Processing reset..."

        resetActionSourceV21.connectSource(
            "/home/uitm/.local/bin/codex-reset-credit --confirm"
        )
    }


    property bool resetPopupRequested: false

    function openResetPopup() {
        resetFeedbackV21 = ""
        resetStatusReadyV21 = false
        resetPopupRequested = true
        plasmoid.expanded = true
        checkResetStatusV21()
    }

    implicitWidth: !setupComplete ? 44 :
                   provider !== "codex" ? 76 :
                   meterStyle === "bars" ? 145 :
                  meterStyle === "rings" ? 110 : 115
    implicitHeight: 36
    width: implicitWidth
    height: implicitHeight
    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth

    property var usage: ({})
    property string status: "Checking Codex login…"
    property bool connected: false
    property bool busy: false
    property bool showSettings: false
    property string draftProvider: "codex"
    property int draftRefreshMinutes: 1
    property string draftMeterStyle: "numbers"
    property string draftAccentStyle: "theme"
    property double nowSeconds: Date.now() / 1000
    readonly property color textColor: PlasmaCore.Theme.textColor
    readonly property color mutedColor: PlasmaCore.Theme.disabledTextColor
    readonly property string provider: plasmoid.configuration.provider
    readonly property bool setupComplete: plasmoid.configuration.setupComplete
    readonly property string meterStyle: plasmoid.configuration.meterStyle
    readonly property color accentColor: colorFor(plasmoid.configuration.accentStyle)
    readonly property color previewAccentColor: colorFor(draftAccentStyle)

    function colorFor(style) {
        if (style === "cyan") return "#29b6f6"
        if (style === "green") return "#59cf86"
        if (style === "amber") return "#f3b34c"
        return PlasmaCore.Theme.highlightColor
    }

    function providerName(value) {
        if (value === "claude") return "Claude"
        if (value === "custom") return "Custom API"
        return "Codex"
    }

    function remaining(key) {
        var window = usage[key]
        if (!window || typeof window.usedPercent !== "number") return -1
        return Math.max(0, Math.min(100, 100 - window.usedPercent))
    }

    function percentage(key) {
        var value = remaining(key)
        return value < 0 ? "--" : Math.round(value) + "%"
    }

    function countdown(key) {
        var window = usage[key]
        if (!window || !window.resetsAt) return "Unavailable"
        var seconds = Math.max(0, Math.floor(window.resetsAt - nowSeconds))
        return Math.floor(seconds / 86400) + "d " +
               Math.floor(seconds % 86400 / 3600) + "h " +
               Math.floor(seconds % 3600 / 60) + "m"
    }

    function refresh() {
        if (busy || (provider !== "codex" &&
                     (!showSettings || draftProvider !== "codex"))) return
        busy = true
        status = "Checking Codex login…"
        readTimeout.restart()
        if (reader.connectedSources.length === 0)
            reader.connectSource(
                "/home/uitm/.local/share/plasma/plasmoids/org.local.multiaiusage/contents/scripts/reader.py")
    }

    function saveSelection() {
        plasmoid.configuration.provider = draftProvider
        plasmoid.configuration.refreshMinutes = draftRefreshMinutes
        plasmoid.configuration.meterStyle = draftMeterStyle
        plasmoid.configuration.accentStyle = draftAccentStyle
        plasmoid.configuration.setupComplete = true
        showSettings = false
        if (draftProvider === "codex") refresh()
    }

    PlasmaCore.DataSource {
        id: reader
        engine: "executable"
        connectedSources: []
        onNewData: {
            root.busy = false
            readTimeout.stop()
            try {
                if (data["exit code"] !== 0) throw "Reader failed"
                var result = JSON.parse(data.stdout)
                root.usage = result
                root.connected = result.connected === true
                root.status = result.message || (result.error ?
                              "Codex usage unavailable: " + result.error :
                              "Existing Codex login detected")
            } catch (error) {
                root.usage = ({})
                root.connected = false
                root.status = "Could not read Codex usage"
            }
            disconnectSource(sourceName)
        }
    }

    Timer {
        id: readTimeout
        interval: 40000
        repeat: false
        onTriggered: {
            root.busy = false
            root.connected = false
            root.status = "Codex usage check timed out; try Refresh"
            reader.connectedSources.forEach(function(source) {
                reader.disconnectSource(source)
            })
        }
    }

    Component.onCompleted: {
        draftProvider = provider
        draftRefreshMinutes = plasmoid.configuration.refreshMinutes
        draftMeterStyle = plasmoid.configuration.meterStyle
        draftAccentStyle = plasmoid.configuration.accentStyle
        if (provider === "codex") refresh()
    }

    onProviderChanged: {
        if (provider !== "codex") {
            connected = false
            usage = ({})
        } else if (setupComplete) refresh()
    }

    Timer {
        interval: Math.max(1, plasmoid.configuration.refreshMinutes) * 60000
        running: root.setupComplete && root.provider === "codex"
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1000
        running: root.setupComplete && root.provider === "codex"
        repeat: true
        onTriggered: root.nowSeconds = Date.now() / 1000
    }

    Plasmoid.preferredRepresentation: Plasmoid.compactRepresentation

    Plasmoid.compactRepresentation: Item {
        id: compactItem

        // V31_ADAPTIVE_DESKTOP_START
        readonly property bool desktopV31:
            plasmoid.location === PlasmaCore.Types.Floating

        readonly property int adaptiveModeV31:
            width < 230 || height < 95 ? 0 :
            width < 350 || height < 190 ? 1 :
            width < 490 || height < 420 ? 2 : 3

        Component.onCompleted: {
            if (desktopV31 && root.provider === "codex")
                root.refreshTokenV3()
        }

        implicitWidth: desktopV31 ? 260 : Math.max(36, compactRow.implicitWidth + 8)
        implicitHeight: desktopV31 ? 140 : 36
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        RowLayout {
            id: compactRow
            visible: !compactItem.desktopV31
            anchors.centerIn: parent
            spacing: 4

            QQC2.Label {
                color: root.textColor
                text: !root.setupComplete ? "AI" :
                      root.provider === "codex" ? "C" :
                      root.provider === "claude" ? "Cl" : "API"
                font.bold: true
                font.pixelSize: 11
            }
            QQC2.Label {
                visible: root.setupComplete && root.provider === "codex" &&
                         root.meterStyle === "numbers"
                color: root.textColor
                text: root.percentage("five") + " · " + root.percentage("weekly")
                font.pixelSize: 11
            }
            Repeater {
                model: root.setupComplete && root.provider === "codex" &&
                       root.meterStyle === "rings" ?
                       ["five", "weekly"] : []
                MeterRing {
                    diameter: 38
                    percent: root.remaining(modelData)
                    strokeColor: root.accentColor
                    trackColor: root.mutedColor
                    textColor: root.textColor
                }
            }
            ColumnLayout {
                visible: root.setupComplete && root.provider === "codex" &&
                         root.meterStyle === "bars"
                spacing: 2
                Repeater {
                    model: ["five", "weekly"]
                    RowLayout {
                        spacing: 2
                        QQC2.Label {
                            color: root.textColor
                            font.pixelSize: 9
                            text: modelData === "five" ? "5h" : "7d"
                        }
                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 5
                            radius: 3
                            color: root.mutedColor
                            Rectangle {
                                width: parent.width * Math.max(0, root.remaining(modelData)) / 100
                                height: parent.height
                                radius: parent.radius
                                color: root.accentColor
                            }
                        }
                    }
                }
            }
            QQC2.Label {
                visible: root.setupComplete && root.provider !== "codex"
                color: root.mutedColor
                text: "soon"
                font.pixelSize: 11
            }

            QQC2.Label {
                id: compactResetButton
                visible: root.setupComplete && root.provider === "codex"
                text: "↶"
                color: "#FFFFFF"
                font.pixelSize: 22
                font.bold: true
                Layout.leftMargin: 6
            }

            // V311_PANEL_ENHANCEMENT
            QQC2.Label {
                id: compactResetBalanceV311
                visible: compactResetButton.visible

                text: {
                    var value = root.usage ?
                        root.usage.resets : undefined

                    if (value === undefined ||
                        value === null ||
                        value === "" ||
                        typeof value === "boolean")
                        return "–"

                    var number = Number(value)

                    if (!isFinite(number) || number < 0)
                        return "–"

                    return String(Math.floor(number))
                }

                color: "#F1F5F9"
                font.pixelSize: 12
                font.bold: true
            }


        }

        MouseArea {
            visible: !compactItem.desktopV31
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: plasmoid.expanded = !plasmoid.expanded
        }

        MouseArea {
            visible: !compactItem.desktopV31 && compactResetButton.visible
            x: compactRow.x + compactResetButton.x
            y: compactRow.y + compactResetButton.y
            width: compactResetButton.width + compactRow.spacing + compactResetBalanceV311.width
            height: compactResetButton.height
            z: 10
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: root.openResetPopup()
        }


        // V31_ADAPTIVE_DESKTOP_VIEW
        Rectangle {
            id: adaptiveDesktopV31
            anchors.fill: parent
            visible: compactItem.desktopV31
            color: "#10151D"
            radius: 12
            clip: true

            readonly property int mode: compactItem.adaptiveModeV31

            QQC2.ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                contentWidth: availableWidth

                ColumnLayout {
                    width: Math.max(1, parent.width)
                    spacing: adaptiveDesktopV31.mode === 0 ? 3 : 9

                    // Header: all sizes
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: adaptiveDesktopV31.mode === 0 ?
                                  "Codex" : "Multi-AI Monitor"
                            color: "#F1F5F9"
                            font.bold: true
                            font.pixelSize:
                                adaptiveDesktopV31.mode === 0 ? 11 : 15
                            elide: Text.ElideRight
                        }

                        QQC2.Button {
                            visible: adaptiveDesktopV31.mode >= 1
                            text: "↻"
                            onClicked: root.refreshAllV3()
                        }

                        QQC2.Button {
                            visible: adaptiveDesktopV31.mode >= 1
                            text: "↗"
                            onClicked: plasmoid.expanded = true
                        }
                    }

                    // XS: minimal percentage display
                    RowLayout {
                        visible: adaptiveDesktopV31.mode === 0
                        Layout.fillWidth: true
                        spacing: 8

                        QQC2.Label {
                            text: "5h " + root.percentage("five")
                            color: "#53D6AF"
                            font.bold: true
                            font.pixelSize: 13
                        }

                        QQC2.Label {
                            text: "7d " + root.percentage("weekly")
                            color: "#60A5FA"
                            font.bold: true
                            font.pixelSize: 13
                        }

                        Item { Layout.fillWidth: true }

                        QQC2.Button {
                            text: "↗"
                            onClicked: plasmoid.expanded = true
                        }
                    }

                    // All other sizes: quota bars
                    GridLayout {
                        visible: adaptiveDesktopV31.mode >= 1
                        Layout.fillWidth: true
                        columns: adaptiveDesktopV31.mode >= 2 ? 2 : 1
                        columnSpacing: 8
                        rowSpacing: 7

                        Repeater {
                            model: [
                                {key: "five", label: "5-hour quota",
                                 accent: "#53D6AF"},
                                {key: "weekly", label: "Weekly quota",
                                 accent: "#60A5FA"}
                            ]

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight:
                                    adaptiveDesktopV31.mode >= 2 ? 100 : 55
                                radius: 9
                                color: "#1C2632"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true

                                        QQC2.Label {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            color: "#CBD5E1"
                                            font.pixelSize: 11
                                        }

                                        QQC2.Label {
                                            text: root.percentage(modelData.key)
                                            color: modelData.accent
                                            font.pixelSize:
                                                adaptiveDesktopV31.mode >= 2 ?
                                                21 : 15
                                            font.bold: true
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 6
                                        radius: 3
                                        color: "#344354"

                                        Rectangle {
                                            height: parent.height
                                            width: parent.width *
                                                Math.max(
                                                    0,
                                                    Math.min(
                                                        100,
                                                        root.remaining(modelData.key)
                                                    )
                                                ) / 100
                                            radius: 3
                                            color: modelData.accent
                                        }
                                    }

                                    QQC2.Label {
                                        visible: adaptiveDesktopV31.mode >= 2
                                        text: "Reset: " +
                                            root.countdown(modelData.key)
                                        color: "#94A3B8"
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }
                    }

                    // Medium / Large: account information
                    Rectangle {
                        visible: adaptiveDesktopV31.mode >= 2
                        Layout.fillWidth: true
                        Layout.preferredHeight: 65
                        radius: 9
                        color: "#1C2632"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 3

                            QQC2.Label {
                                text: root.accountConnectedV23 ?
                                    "● Connected" : "○ Disconnected"
                                color: root.accountConnectedV23 ?
                                    "#53D6AF" : "#F3B34C"
                                font.pixelSize: 11
                            }

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: root.accountConnectedV23 ?
                                    (root.accountEmailV23 ||
                                     "Email unavailable") :
                                    "Account not connected"
                                color: "#F1F5F9"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Medium / Large: token chart
                    Rectangle {
                        visible: adaptiveDesktopV31.mode >= 2
                        Layout.fillWidth: true
                        Layout.preferredHeight:
                            adaptiveDesktopV31.mode === 2 ? 165 : 235
                        radius: 9
                        color: "#1C2632"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: "Token Usage"
                                    color: "#F1F5F9"
                                    font.bold: true
                                    font.pixelSize: 13
                                }

                                QQC2.ComboBox {
                                    model: ["7 days", "30 days"]
                                    currentIndex:
                                        root.reportPeriodV3 === 7 ? 0 : 1
                                    onActivated:
                                        root.reportPeriodV3 =
                                            currentIndex === 0 ? 7 : 30
                                }
                            }

                            QQC2.Label {
                                text: root.formatTokensV3(
                                    root.reportSumV3("total_tokens")
                                ) + " tokens"
                                color: "#53D6AF"
                                font.bold: true
                                font.pixelSize: 19
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: root.reportPeriodV3 === 7 ? 6 : 1

                                Repeater {
                                    model: root.reportDaysV3()

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 2

                                        Item { Layout.fillHeight: true }

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth:
                                                root.reportPeriodV3 === 7 ?
                                                17 : 4
                                            Layout.preferredHeight:
                                                Math.max(
                                                    2,
                                                    (adaptiveDesktopV31.mode === 2 ?
                                                     65 : 105) *
                                                    Number(
                                                        modelData.total_tokens || 0
                                                    ) / root.reportMaxV3()
                                                )
                                            radius: 2
                                            color: "#53D6AF"

                                            QQC2.ToolTip.visible:
                                                tokenHoverV31.containsMouse
                                            QQC2.ToolTip.text:
                                                modelData.date + ": " +
                                                root.formatTokensV3(
                                                    modelData.total_tokens || 0
                                                ) + " tokens"

                                            MouseArea {
                                                id: tokenHoverV31
                                                anchors.fill: parent
                                                hoverEnabled: true
                                            }
                                        }

                                        QQC2.Label {
                                            Layout.alignment: Qt.AlignHCenter
                                            visible: root.reportPeriodV3 === 7
                                            text: modelData.date.slice(8)
                                            color: "#94A3B8"
                                            font.pixelSize: 9
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Large: token breakdown
                    Rectangle {
                        visible: adaptiveDesktopV31.mode === 3
                        Layout.fillWidth: true
                        Layout.preferredHeight: 135
                        radius: 9
                        color: "#1C2632"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            QQC2.Label {
                                text: "Token Breakdown"
                                color: "#F1F5F9"
                                font.bold: true
                                font.pixelSize: 13
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 8
                                columnSpacing: 15

                                Repeater {
                                    model: [
                                        {label: "Input", key: "input_tokens"},
                                        {label: "Cached", key: "cached_input_tokens"},
                                        {label: "Output", key: "output_tokens"},
                                        {label: "Reasoning", key: "reasoning_output_tokens"}
                                    ]

                                    ColumnLayout {
                                        spacing: 2

                                        QQC2.Label {
                                            text: modelData.label
                                            color: "#94A3B8"
                                            font.pixelSize: 10
                                        }

                                        QQC2.Label {
                                            text: root.formatTokensV3(
                                                root.reportSumV3(modelData.key)
                                            )
                                            color: "#F1F5F9"
                                            font.bold: true
                                            font.pixelSize: 16
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Large: action controls
                    Rectangle {
                        visible: adaptiveDesktopV31.mode === 3
                        Layout.fillWidth: true
                        Layout.preferredHeight: 115
                        radius: 9
                        color: "#1C2632"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 6

                            QQC2.Label {
                                text: "Controls"
                                color: "#F1F5F9"
                                font.bold: true
                            }

                            RowLayout {
                                QQC2.Button {
                                    text: "Reset Credit"
                                    enabled: !root.resetBusyV21
                                    onClicked: root.openResetPopup()
                                }

                                QQC2.Button {
                                    text: "Settings"
                                    onClicked: {
                                        plasmoid.expanded = true
                                        root.draftProvider = root.provider
                                        root.draftRefreshMinutes =
                                            plasmoid.configuration.refreshMinutes
                                        root.draftMeterStyle = root.meterStyle
                                        root.draftAccentStyle =
                                            plasmoid.configuration.accentStyle
                                        root.showSettings = true
                                    }
                                }

                                QQC2.Button {
                                    text: "Full Report"
                                    onClicked: plasmoid.expanded = true
                                }
                            }
                        }
                    }

                    QQC2.Label {
                        visible: adaptiveDesktopV31.mode === 3
                        text: "Local Codex token analytics"
                        color: "#94A3B8"
                        font.pixelSize: 10
                    }
                }
            }
        }
        // V31_ADAPTIVE_DESKTOP_END


    }

    Plasmoid.fullRepresentation: Item {
        Component.onCompleted: {
            root.refreshAccountV23()
            root.refreshTokenV3()
        }

        Layout.minimumWidth: 420
        Layout.minimumHeight: 600
        Layout.preferredWidth: 500
        Layout.preferredHeight: 720

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            QQC2.Label {
                Layout.fillWidth: true
                color: root.textColor
                font.pixelSize: 18
                font.bold: true
                text: !root.setupComplete ? "Set up Multi-AI Usage" :
                      root.showSettings ? "Settings" :
                      root.providerName(root.provider) + " usage"
            }

            ColumnLayout {
                visible: !root.setupComplete || root.showSettings
                Layout.fillWidth: true
                spacing: 7

                QQC2.Label {
                    Layout.fillWidth: true
                    color: root.mutedColor
                    wrapMode: Text.WordWrap
                    text: !root.setupComplete ?
                        "Choose a provider. Codex uses your existing CLI login." :
                        "Choose which provider this widget displays."
                }

                QQC2.RadioButton {
                    id: codexChoice
                    text: "Codex"
                    checked: root.draftProvider === "codex"
                    onClicked: root.draftProvider = "codex"
                    contentItem: QQC2.Label {
                        text: codexChoice.text
                        font: codexChoice.font
                        color: root.textColor
                        leftPadding: 28
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                QQC2.RadioButton {
                    id: claudeChoice
                    text: "Claude (coming soon)"
                    checked: root.draftProvider === "claude"
                    onClicked: root.draftProvider = "claude"
                    contentItem: QQC2.Label {
                        text: claudeChoice.text
                        font: claudeChoice.font
                        color: root.textColor
                        leftPadding: 28
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                QQC2.RadioButton {
                    id: customChoice
                    text: "Custom API (coming soon)"
                    checked: root.draftProvider === "custom"
                    onClicked: root.draftProvider = "custom"
                    contentItem: QQC2.Label {
                        text: customChoice.text
                        font: customChoice.font
                        color: root.textColor
                        leftPadding: 28
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    color: root.draftProvider === "codex" && root.connected ?
                           root.textColor : root.mutedColor
                    wrapMode: Text.WordWrap
                    text: root.draftProvider === "codex" ? root.status :
                          "Usage retrieval is not available for this provider yet. No credentials are requested or stored."
                }

                RowLayout {
                    visible: root.draftProvider === "codex"
                    QQC2.Label {
                        color: root.textColor
                        text: "Refresh every"
                    }
                    QQC2.ComboBox {
                        model: ["1 minute", "5 minutes", "15 minutes"]
                        currentIndex: root.draftRefreshMinutes === 15 ? 2 :
                                      root.draftRefreshMinutes === 5 ? 1 : 0
                        onActivated: root.draftRefreshMinutes =
                                     currentIndex === 2 ? 15 : currentIndex === 1 ? 5 : 1
                    }
                }

                RowLayout {
                    visible: root.draftProvider === "codex"
                    QQC2.Label {
                        color: root.textColor
                        text: "Meter design"
                    }
                    QQC2.ComboBox {
                        model: ["Numbers", "Rings", "Bars"]
                        currentIndex: root.draftMeterStyle === "rings" ? 1 :
                                      root.draftMeterStyle === "bars" ? 2 : 0
                        onActivated: root.draftMeterStyle =
                                     currentIndex === 1 ? "rings" :
                                     currentIndex === 2 ? "bars" : "numbers"
                    }
                }

                RowLayout {
                    visible: root.draftProvider === "codex"
                    QQC2.Label {
                        color: root.textColor
                        text: "Meter colour"
                    }
                    QQC2.ComboBox {
                        model: ["Theme", "Cyan", "Green", "Amber"]
                        currentIndex: root.draftAccentStyle === "cyan" ? 1 :
                                      root.draftAccentStyle === "green" ? 2 :
                                      root.draftAccentStyle === "amber" ? 3 : 0
                        onActivated: root.draftAccentStyle =
                                     currentIndex === 1 ? "cyan" :
                                     currentIndex === 2 ? "green" :
                                     currentIndex === 3 ? "amber" : "theme"
                    }
                }

                RowLayout {
                    visible: root.draftProvider === "codex"
                    spacing: 10
                    QQC2.Label {
                        color: root.mutedColor
                        text: "Preview"
                    }
                    Repeater {
                        model: root.draftMeterStyle === "rings" ? ["five", "weekly"] : []
                        MeterRing {
                            diameter: 38
                            percent: root.remaining(modelData)
                            strokeColor: root.previewAccentColor
                            trackColor: root.mutedColor
                            textColor: root.textColor
                        }
                    }
                    QQC2.Label {
                        visible: root.draftMeterStyle === "numbers"
                        color: root.previewAccentColor
                        font.bold: true
                        text: root.percentage("five") + " · " + root.percentage("weekly")
                    }
                    Rectangle {
                        visible: root.draftMeterStyle === "bars"
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 8
                        radius: 4
                        color: root.mutedColor
                        Rectangle {
                            width: parent.width * Math.max(0, root.remaining("five")) / 100
                            height: parent.height
                            radius: parent.radius
                            color: root.previewAccentColor
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Button {
                        visible: root.draftProvider === "codex"
                        text: root.busy ? "Checking…" : "Check login"
                        enabled: !root.busy
                        onClicked: root.refresh()
                    }
                    Item { Layout.fillWidth: true }
                    QQC2.Button {
                        visible: root.showSettings
                        text: "Cancel"
                        onClicked: root.showSettings = false
                    }
                    QQC2.Button {
                        text: root.showSettings ? "Save" : "Finish setup"
                        onClicked: root.saveSelection()
                    }
                }
            }

            ColumnLayout {
                visible: root.setupComplete && !root.showSettings
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    visible: root.provider === "codex"
                    Layout.fillWidth: true

                    Repeater {
                        model: [
                            {key: "five", title: "5-hour limit"},
                            {key: "weekly", title: "Weekly limit"}
                        ]
                        ColumnLayout {
                            Layout.fillWidth: true
                            RowLayout {
                                Layout.fillWidth: true
                                MeterRing {
                                    visible: root.meterStyle === "rings"
                                    diameter: 62
                                    percent: root.remaining(modelData.key)
                                    strokeColor: root.accentColor
                                    trackColor: root.mutedColor
                                    textColor: root.textColor
                                }
                                QQC2.Label {
                                    color: root.meterStyle === "numbers" ?
                                           root.accentColor : root.textColor
                                    text: modelData.title + ": " +
                                          root.percentage(modelData.key) + " left"
                                }
                            }
                            Rectangle {
                                visible: root.meterStyle === "bars"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 6
                                radius: 3
                                color: root.mutedColor
                                Rectangle {
                                    width: parent.width *
                                           Math.max(0, root.remaining(modelData.key)) / 100
                                    height: parent.height
                                    radius: parent.radius
                                    color: root.accentColor
                                }
                            }
                            QQC2.Label {
                                color: root.mutedColor
                                text: "Resets in: " + root.countdown(modelData.key)
                            }
                        }
                    }

                    QQC2.Label {
                        color: root.textColor
                        text: "Available reset credits: " +
                              (root.usage.resets === undefined ||
                               root.usage.resets === null ? "Unknown" : root.usage.resets)
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        color: root.mutedColor
                        wrapMode: Text.WordWrap
                        text: ""
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        color: root.connected ? root.textColor : root.mutedColor
                        wrapMode: Text.WordWrap
                        text: root.status
                    }
                }

                QQC2.Label {
                    visible: root.provider !== "codex"
                    Layout.fillWidth: true
                    color: root.mutedColor
                    wrapMode: Text.WordWrap
                    text: root.providerName(root.provider) +
                          " usage is coming soon. No API key or account data is collected."
                }

                RowLayout {
                    QQC2.Button {
                        visible: root.provider === "codex"
                        text: root.busy ? "Checking…" : "Refresh"
                        enabled: !root.busy
                        onClicked: root.refresh()
                    }
                    QQC2.Button {
                        visible: root.provider === "codex"
                        text: "↶ Reset"
                        enabled: root.provider === "codex" && !root.resetBusyV21
                        onClicked: root.openResetPopup()
                    }
                    QQC2.Button {
                        text: "Settings"
                        onClicked: {
                            root.draftProvider = root.provider
                            root.draftRefreshMinutes = plasmoid.configuration.refreshMinutes
                            root.draftMeterStyle = root.meterStyle
                            root.draftAccentStyle = plasmoid.configuration.accentStyle
                            root.showSettings = true
                        }
                    }
                }
            }


                // v2.3 Account Manager
                ColumnLayout {
                    visible: root.provider === "codex"
                    Layout.fillWidth: true
                    spacing: 6

                    QQC2.Label {
                        text: "Codex Account"
                        font.bold: true
                        color: root.textColor
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: root.accountEmailV23.length > 0 ?
                              root.accountEmailV23 : root.accountMessageV23
                        color: root.textColor
                        wrapMode: Text.WrapAnywhere
                    }

                    QQC2.Label {
                        text: root.accountConnectedV23 ?
                              "Logged in via " + root.accountTypeV23 :
                              root.accountMessageV23
                        color: root.mutedColor
                    }

                    RowLayout {
                        QQC2.Button {
                            text: "Account Refresh"
                            enabled: !root.accountBusyV23
                            onClicked: root.refreshAccountV23()
                        }
                        QQC2.Button {
                            text: root.loginPendingV25 ?
                                  "Logging in..." : "Login"
                            enabled: !root.accountBusyV23 &&
                                     !root.accountConnectedV23 &&
                                     !root.loginPendingV25
                            onClicked: root.accountActionV23("login")
                        }
                        QQC2.Button {
                            text: "Logout"
                            enabled: !root.accountBusyV23 &&
                                     root.accountConnectedV23
                            onClicked: root.accountLogoutConfirmV23 = true
                        }
                    }

                    QQC2.Label {
                        visible: root.accountLogoutConfirmV23
                        text: "Logout this Codex account? VS Code may also be affected."
                        color: root.textColor
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        visible: root.accountLogoutConfirmV23
                        QQC2.Button {
                            text: "Cancel"
                            onClicked: root.accountLogoutConfirmV23 = false
                        }
                        QQC2.Button {
                            text: "Confirm Logout"
                            enabled: !root.accountBusyV23
                            onClicked: root.accountActionV23("logout")
                        }
                    }
                }

            Item { Layout.fillHeight: true }
        }


        // V3_DASHBOARD_VIEW

        Rectangle {
            id: dashboardV3
            anchors.fill: parent
            color: "#10151D"

            visible: root.setupComplete &&
                     !root.showSettings &&
                     root.provider === "codex"

            z: 2

            QQC2.ScrollView {
                id: dashboardScrollV3

                anchors.fill: parent
                anchors.margins: 10
                clip: true

                contentWidth: availableWidth

                ColumnLayout {
                    width: Math.max(
                        300,
                        dashboardScrollV3.availableWidth
                    )

                    spacing: 12

                    // HEADER

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            QQC2.Label {
                                text: "Multi-AI Monitor"
                                color: "#F1F5F9"
                                font.pixelSize: 19
                                font.bold: true
                            }

                            QQC2.Label {
                                text: "Codex Analytics v3.0"
                                color: "#94A3B8"
                                font.pixelSize: 11
                            }
                        }

                        QQC2.Button {
                            text: root.busy ? "..." : "Refresh"
                            enabled: !root.busy

                            onClicked: root.refreshAllV3()
                        }

                        QQC2.Button {
                            text: "Settings"

                            onClicked: {
                                root.draftProvider = root.provider
                                root.draftRefreshMinutes =
                                    plasmoid.configuration.refreshMinutes
                                root.draftMeterStyle = root.meterStyle
                                root.draftAccentStyle =
                                    plasmoid.configuration.accentStyle

                                root.showSettings = true
                            }
                        }
                    }

                    // ACCOUNT CARD

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 98

                        radius: 12
                        color: "#1C2632"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            QQC2.Label {
                                text: root.accountConnectedV23 ?
                                    "● Account Connected" :
                                    "○ Account Disconnected"

                                color: root.accountConnectedV23 ?
                                    "#53D6AF" : "#F3B34C"

                                font.bold: true
                                font.pixelSize: 12
                            }

                            QQC2.Label {
                                Layout.fillWidth: true

                                text: root.accountConnectedV23 ?
                                    (root.accountEmailV23 ||
                                     "Email unavailable") :
                                    root.accountMessageV23

                                color: "#F1F5F9"
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            QQC2.Label {
                                text: root.accountConnectedV23 ?
                                    "Codex | " + root.accountTypeV23 :
                                    "Login to connect"

                                color: "#94A3B8"
                                font.pixelSize: 11
                            }
                        }
                    }

                    // QUOTA CARDS

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: [
                                {
                                    key: "five",
                                    label: "5-hour quota"
                                },
                                {
                                    key: "weekly",
                                    label: "Weekly quota"
                                }
                            ]

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 128

                                radius: 12
                                color: "#1C2632"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 5

                                    QQC2.Label {
                                        text: modelData.label
                                        color: "#94A3B8"
                                        font.pixelSize: 12
                                    }

                                    QQC2.Label {
                                        text: root.percentage(
                                            modelData.key
                                        )

                                        color: modelData.key === "five" ?
                                            "#53D6AF" : "#60A5FA"

                                        font.pixelSize: 27
                                        font.bold: true
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 7

                                        radius: 4
                                        color: "#344354"

                                        Rectangle {
                                            height: parent.height

                                            width: parent.width *
                                                Math.max(
                                                    0,
                                                    root.remaining(
                                                        modelData.key
                                                    )
                                                ) / 100

                                            radius: 4

                                            color: modelData.key === "five" ?
                                                "#53D6AF" : "#60A5FA"
                                        }
                                    }

                                    QQC2.Label {
                                        text: "Resets: " +
                                            root.countdown(
                                                modelData.key
                                            )

                                        color: "#94A3B8"
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }
                    }

                    // TOKEN GRAPH

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 292

                        radius: 12
                        color: "#1C2632"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: "Token Usage Report"
                                    color: "#F1F5F9"
                                    font.bold: true
                                    font.pixelSize: 15
                                }

                                QQC2.ComboBox {
                                    model: [
                                        "7 days",
                                        "30 days"
                                    ]

                                    currentIndex:
                                        root.reportPeriodV3 === 7 ? 0 : 1

                                    onActivated: {
                                        root.reportPeriodV3 =
                                            currentIndex === 0 ? 7 : 30
                                    }
                                }
                            }

                            QQC2.Label {
                                text: root.formatTokensV3(
                                    root.reportSumV3("total_tokens")
                                ) + " tokens"

                                color: "#53D6AF"
                                font.pixelSize: 22
                                font.bold: true
                            }

                            QQC2.Label {
                                visible: !root.tokenReportV3.available

                                text: root.reportBusyV3 ?
                                    "Reading sessions..." :
                                    "No local token data"

                                color: "#94A3B8"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                spacing: root.reportPeriodV3 === 7 ? 7 : 1

                                Repeater {
                                    model: root.reportDaysV3()

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 3

                                        Item {
                                            Layout.fillHeight: true
                                        }

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter

                                            Layout.preferredWidth:
                                                root.reportPeriodV3 === 7 ?
                                                22 : 5

                                            Layout.preferredHeight:
                                                Math.max(
                                                    2,
                                                    110 *
                                                    Number(
                                                        modelData.total_tokens || 0
                                                    ) /
                                                    root.reportMaxV3()
                                                )

                                            radius: 2
                                            color: "#53D6AF"

                                            QQC2.ToolTip.visible:
                                                barHoverV3.containsMouse

                                            QQC2.ToolTip.text:
                                                modelData.date + ": " +
                                                root.formatTokensV3(
                                                    modelData.total_tokens || 0
                                                ) + " tokens"

                                            MouseArea {
                                                id: barHoverV3
                                                anchors.fill: parent
                                                hoverEnabled: true
                                            }
                                        }

                                        QQC2.Label {
                                            Layout.alignment: Qt.AlignHCenter

                                            text: root.reportPeriodV3 === 7 ?
                                                modelData.date.slice(8) : ""

                                            color: "#94A3B8"
                                            font.pixelSize: 10
                                        }
                                    }
                                }
                            }

                            QQC2.Label {
                                text: "Local Codex sessions only"
                                color: "#94A3B8"
                                font.pixelSize: 10
                            }
                        }
                    }

                    // TOKEN BREAKDOWN

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150

                        radius: 12
                        color: "#1C2632"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            QQC2.Label {
                                text: "Token Breakdown"
                                color: "#F1F5F9"
                                font.bold: true
                                font.pixelSize: 15
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 8

                                Repeater {
                                    model: [
                                        {
                                            label: "Input",
                                            key: "input_tokens"
                                        },
                                        {
                                            label: "Cached input",
                                            key: "cached_input_tokens"
                                        },
                                        {
                                            label: "Output",
                                            key: "output_tokens"
                                        },
                                        {
                                            label: "Reasoning",
                                            key: "reasoning_output_tokens"
                                        }
                                    ]

                                    ColumnLayout {
                                        spacing: 2

                                        QQC2.Label {
                                            text: modelData.label
                                            color: "#94A3B8"
                                            font.pixelSize: 11
                                        }

                                        QQC2.Label {
                                            text: root.formatTokensV3(
                                                root.reportSumV3(
                                                    modelData.key
                                                )
                                            )

                                            color: "#F1F5F9"
                                            font.pixelSize: 17
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ACCOUNT AND RESET CONTROLS

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight:
                            root.accountLogoutConfirmV23 ? 235 : 180

                        radius: 12
                        color: "#1C2632"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 7

                            QQC2.Label {
                                text: "Account & Controls"
                                color: "#F1F5F9"
                                font.bold: true
                                font.pixelSize: 15
                            }

                            QQC2.Label {
                                text: "Reset credits: " +
                                    (
                                        root.usage.resets === undefined ||
                                        root.usage.resets === null ?
                                        "Unknown" :
                                        root.usage.resets
                                    )

                                color: "#CBD5E1"
                            }

                            RowLayout {
                                QQC2.Button {
                                    text: "Reset Credit"
                                    enabled: !root.resetBusyV21

                                    onClicked:
                                        root.openResetPopup()
                                }

                                QQC2.Button {
                                    text: "Account Refresh"

                                    enabled: !root.accountBusyV23

                                    onClicked:
                                        root.refreshAccountV23()
                                }
                            }

                            RowLayout {
                                QQC2.Button {
                                    text: root.loginPendingV25 ?
                                        "Logging in..." : "Login"

                                    enabled:
                                        !root.accountBusyV23 &&
                                        !root.accountConnectedV23 &&
                                        !root.loginPendingV25

                                    onClicked:
                                        root.accountActionV23("login")
                                }

                                QQC2.Button {
                                    text: "Logout"

                                    enabled:
                                        !root.accountBusyV23 &&
                                        root.accountConnectedV23

                                    onClicked:
                                        root.accountLogoutConfirmV23 = true
                                }
                            }

                            QQC2.Label {
                                visible: root.accountLogoutConfirmV23

                                text: "Logout may also affect VS Code Codex."

                                color: "#F3B34C"
                                font.pixelSize: 11
                            }

                            RowLayout {
                                visible: root.accountLogoutConfirmV23

                                QQC2.Button {
                                    text: "Cancel"

                                    onClicked:
                                        root.accountLogoutConfirmV23 = false
                                }

                                QQC2.Button {
                                    text: "Confirm Logout"

                                    enabled: !root.accountBusyV23

                                    onClicked:
                                        root.accountActionV23("logout")
                                }
                            }

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: root.accountMessageV23
                                color: "#94A3B8"
                                elide: Text.ElideRight
                                font.pixelSize: 10
                            }
                        }
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: root.status
                        color: "#94A3B8"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }

                    Item {
                        Layout.preferredHeight: 8
                    }
                }
            }
        }

        // V3_DASHBOARD_END

        Item {
            id: resetOverlayV2
            anchors.fill: parent
            visible: root.resetPopupRequested
            z: 100

            Rectangle {
                anchors.fill: parent
                color: "#99000000"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.resetPopupRequested = false
            }

            Rectangle {
                width: Math.min(parent.width - 24, 310)
                height: resetDialogContent.implicitHeight + 36
                anchors.centerIn: parent
                radius: 10
                color: PlasmaCore.Theme.backgroundColor
                border.color: PlasmaCore.Theme.textColor
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                ColumnLayout {
                    id: resetDialogContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 18
                    spacing: 14

                    QQC2.Label {
                        text: "Use usage reset?"
                        color: "#FFFFFF"
                        font.pixelSize: 16
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    QQC2.Label {
                        text: "Available reset credits: " +
                              (root.usage.resets === undefined ||
                               root.usage.resets === null ?
                               "Unknown" : root.usage.resets)
                        color: "#FFFFFF"
                        Layout.fillWidth: true
                    }

                    QQC2.Label {
                        text: "Redeem one reset credit? " +
                              "This action cannot be undone."
                        color: "#FFFFFF"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    QQC2.Label {
                        text: root.resetFeedbackV21.length > 0 ?
                              root.resetFeedbackV21 :
                              root.resetStatusTextV21
                        color: "#FFFFFF"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 8

                        QQC2.Button {
                            text: "Cancel"
                            onClicked: root.resetPopupRequested = false
                        }

                        QQC2.Button {
                            text: root.resetBusyV21 ? "Processing..." :
                                  root.resetStatusBusyV21 ? "Checking..." :
                                  root.resetStatusReadyV21 ? "Confirm reset" :
                                  "Locked"
                            enabled: !root.resetBusyV21 &&
                                     !root.resetStatusBusyV21 &&
                                     root.resetStatusReadyV21 &&
                                     typeof root.usage.resets === "number" &&
                                     root.usage.resets > 0
                            onClicked: root.confirmResetV21()
                        }
                    }
                }
            }
        }

    }
}
