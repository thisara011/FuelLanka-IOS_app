import Testing
@testable import FuelLanka

struct DeliveryReceiptTextParserTests {
    @Test func extractsCommonReceiptFields() {
        let result = DeliveryReceiptTextParser.parse("""
        CEYPETCO DELIVERY NOTE
        Reference: DEL-10482
        Product Petrol 92
        Quantity 12,500 L
        """)

        #expect(result.reference == "DEL-10482")
        #expect(result.quantity == "12500")
        #expect(result.fuel == .petrol92)
    }

    @Test func leavesUnknownValuesEmpty() {
        let result = DeliveryReceiptTextParser.parse("Thank you")

        #expect(result.reference == nil)
        #expect(result.quantity == nil)
        #expect(result.fuel == nil)
    }
}
