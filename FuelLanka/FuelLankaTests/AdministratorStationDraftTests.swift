import Testing
@testable import FuelLanka

struct AdministratorStationDraftTests {
    @Test func requiresStationName() {
        var draft = AdministratorStationDraft()
        draft.address = "Colombo"

        #expect(!draft.isValid)
    }

    @Test func acceptsEmptyOrValidCoordinates() {
        var draft = AdministratorStationDraft()
        draft.name = "Colombo Fuel Station"

        #expect(draft.isValid)

        draft.latitude = "6.9271"
        draft.longitude = "79.8612"

        #expect(draft.isValid)
        #expect(draft.latitudeValue == 6.9271)
        #expect(draft.longitudeValue == 79.8612)
    }

    @Test func rejectsCoordinatesOutsideEarthBounds() {
        var draft = AdministratorStationDraft()
        draft.name = "Invalid Location"
        draft.latitude = "91"
        draft.longitude = "181"

        #expect(!draft.isValid)
    }
}
