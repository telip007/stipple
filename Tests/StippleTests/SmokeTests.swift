import Testing

@testable import Stipple

@Test func rectIntersection() {
    let rect = Rect(x: 0, y: 0, width: 4, height: 4).intersection(Rect(x: 2, y: 2, width: 4, height: 4))
    #expect(rect == Rect(x: 2, y: 2, width: 2, height: 2))
}

@Test func hexColor() {
    #expect(Color(hex: "#f0a") == Color(red: 255, green: 0, blue: 170))
    #expect(Color(hex: "nope") == nil)
}
