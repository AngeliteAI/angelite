class Mesher {
    private let maxConcurrentChunks = 64
    private let maxBuckets = 1024
    private let facesPerBucket = 1024

    private var chunkProcessQueue: [ChunkProcessRequest] = []
    private var activeChunks: [ChunkID: ChunkStatus] = [:]
}
