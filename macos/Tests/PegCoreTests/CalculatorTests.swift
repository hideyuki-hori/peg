import XCTest
@testable import PegCore

final class CalculatorTests: XCTestCase {
    private func result(_ input: String) -> String? {
        Calculator.calculate(input)?.result
    }

    func testCalculatesBasicOperations() {
        XCTAssertEqual(result("1+2"), "3")
        XCTAssertEqual(result("10 - 4"), "6")
        XCTAssertEqual(result("6*7"), "42")
        XCTAssertEqual(result("7/2"), "3.5")
        XCTAssertEqual(result("2^10"), "1024")
    }

    func testRespectsPrecedenceAndParentheses() {
        XCTAssertEqual(result("1+2*3"), "7")
        XCTAssertEqual(result("(1+2)*3"), "9")
        XCTAssertEqual(result("2*(3+(4-1))/3"), "4")
        XCTAssertEqual(result("10-4-3"), "3")
        XCTAssertEqual(result("2^3^2"), "512")
    }

    func testHandlesSigns() {
        XCTAssertEqual(result("-3+5"), "2")
        XCTAssertEqual(result("3*-2"), "-6")
        XCTAssertEqual(result("-2^2"), "-4")
        XCTAssertEqual(result("2^-1"), "0.5")
        XCTAssertEqual(result("1-1"), "0")
        XCTAssertEqual(result("0*-1"), "0")
    }

    func testFormatsDecimals() {
        XCTAssertEqual(result("0.1+0.2"), "0.3")
        XCTAssertEqual(result("1/3"), "0.3333333333")
        XCTAssertEqual(result(".5+.25"), "0.75")
        XCTAssertEqual(result("1.50*2"), "3")
        XCTAssertEqual(result("1000000*1000000"), "1000000000000")
        XCTAssertEqual(result("10^20"), "1e+20")
    }

    func testAcceptsFullWidthAndSeparators() {
        XCTAssertEqual(result("１＋２"), "3")
        XCTAssertEqual(result("６×７"), "42")
        XCTAssertEqual(result("８÷２"), "4")
        XCTAssertEqual(result("（１＋２）＊３"), "9")
        XCTAssertEqual(result("1,000+2,000"), "3000")
    }

    func testKeepsTrimmedExpression() {
        XCTAssertEqual(Calculator.calculate("  1 + 2 "), Calculation(expression: "1 + 2", result: "3"))
    }

    func testIgnoresInputThatIsNotCalculation() {
        XCTAssertNil(result(""))
        XCTAssertNil(result("42"))
        XCTAssertNil(result("-5"))
        XCTAssertNil(result("(3)"))
        XCTAssertNil(result("chrome"))
        XCTAssertNil(result("1+"))
        XCTAssertNil(result("1+a"))
        XCTAssertNil(result("(1+2"))
        XCTAssertNil(result("1+2)"))
        XCTAssertNil(result("1..2+3"))
        XCTAssertNil(result("1/0"))
        XCTAssertNil(result("0^-1"))
        XCTAssertNil(result("iTerm2"))
    }
}
