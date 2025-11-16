import Foundation

open class BaseService {
    public unowned let client: BosBaseClient

    public init(client: BosBaseClient) {
        self.client = client
    }
}
