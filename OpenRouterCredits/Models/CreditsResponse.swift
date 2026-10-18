import Foundation

/// The shape of `GET https://openrouter.ai/api/v1/credits`.
///
/// The totals are optional so a partial or newly introduced response shape can
/// still be displayed. Missing values are treated as zero.
struct CreditsResponse: Decodable {
    struct CreditsData: Decodable {
        let totalCredits: Decimal?
        let totalUsage: Decimal?

        enum CodingKeys: String, CodingKey {
            case totalCredits = "total_credits"
            case totalUsage = "total_usage"
        }
    }

    let data: CreditsData

    var snapshot: CreditsSnapshot {
        CreditsSnapshot(
            totalCredits: data.totalCredits ?? 0,
            totalUsage: data.totalUsage ?? 0
        )
    }
}
