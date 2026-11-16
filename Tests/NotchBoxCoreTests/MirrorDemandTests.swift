import Testing
@testable import NotchBoxCore

struct MirrorDemandTests {
    @Test func theCameraIsOffUntilTheMirrorIsOpened() {
        var demand = MirrorDemand()
        demand.setColumnVisible(true)
        #expect(!demand.wantsCamera)
        demand.toggleInPanel()
        #expect(demand.wantsCamera)
        demand.toggleInPanel()
        #expect(!demand.wantsCamera)
    }

    @Test func closingThePanelClosesTheMirrorForTheNextOpening() {
        var demand = MirrorDemand()
        demand.setColumnVisible(true)
        demand.toggleInPanel()
        demand.setColumnVisible(false)
        #expect(!demand.wantsCamera)
        demand.setColumnVisible(true)
        #expect(!demand.wantsCamera)
        #expect(!demand.isOpenInPanel)
    }

    @Test func theMirrorCannotBeOpenedWhileItsWidgetIsNotShown() {
        var demand = MirrorDemand()
        demand.toggleInPanel()
        demand.setColumnVisible(true)
        #expect(!demand.wantsCamera)
    }

    @Test func fullScreenKeepsTheCameraOnWhenThePanelCloses() {
        var demand = MirrorDemand()
        demand.setColumnVisible(true)
        demand.toggleInPanel()
        demand.setFullScreen(true)
        demand.setColumnVisible(false)
        #expect(demand.wantsCamera)
        demand.setFullScreen(false)
        #expect(!demand.wantsCamera)
    }

    @Test func leavingFullScreenWithTheMirrorStillOpenInThePanelKeepsTheCameraOn() {
        var demand = MirrorDemand()
        demand.setColumnVisible(true)
        demand.toggleInPanel()
        demand.setFullScreen(true)
        demand.setFullScreen(false)
        #expect(demand.wantsCamera)
    }
}
