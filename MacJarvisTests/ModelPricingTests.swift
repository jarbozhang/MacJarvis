import XCTest
@testable import MacJarvis

final class ModelPricingTests: XCTestCase {
    func testTimeBucketCyclesFromAllThroughShorterWindows() {
        XCTAssertEqual(TimeBucket.all.next, .day)
        XCTAssertEqual(TimeBucket.day.next, .week)
        XCTAssertEqual(TimeBucket.week.next, .month)
        XCTAssertEqual(TimeBucket.month.next, .all)
    }

    func testAggregateTokensAllIncludesEveryRecord() {
        let now = Date()
        let records = [
            TokenRecord(date: now.addingTimeInterval(-90 * 24 * 60 * 60), inputTokens: 10, outputTokens: 20, totalTokens: 30),
            TokenRecord(date: now, inputTokens: 40, outputTokens: 50, totalTokens: 90),
        ]

        let aggregate = aggregateTokens(records, bucket: .all, now: now)

        XCTAssertEqual(aggregate.inputTokens, 50)
        XCTAssertEqual(aggregate.outputTokens, 70)
        XCTAssertEqual(aggregate.totalTokens, 120)
    }

    func testParseOpenClawGatewayUsage() {
        let json = """
        {
          "daily": [
            {
              "date": "2026-05-01",
              "input": 100,
              "output": 20,
              "cacheRead": 30,
              "cacheWrite": 4,
              "totalTokens": 154
            },
            {
              "date": "2026-05-02",
              "input": 200,
              "output": 40,
              "cacheRead": 0,
              "cacheWrite": 0,
              "totalTokens": 240
            }
          ]
        }
        """

        let records = TokenService.parseOpenClawGatewayUsage(data: Data(json.utf8))

        XCTAssertEqual(records?.count, 2)
        XCTAssertEqual(records?.first?.inputTokens, 100)
        XCTAssertEqual(records?.first?.outputTokens, 20)
        XCTAssertEqual(records?.first?.totalTokens, 154)
        XCTAssertEqual(records?.last?.totalTokens, 240)
    }
}
