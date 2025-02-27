import Foundation
import Angelite

public class Socket {
    private var server: Int32 = -1
    private var client: [Int32: RunLoopSource] = [:]

    private var callbackData: DataAvailableCallback?
    private var callbackConnect: ConnectCallback?

}
