package dev.vz.ljod.data.library

sealed class LibraryScanState {
    data object Idle : LibraryScanState()
    data class Scanning(val itemsProcessed: Int, val totalEstimated: Int?) : LibraryScanState()
    data class Indexed(val songCount: Int, val albumCount: Int, val artistCount: Int) : LibraryScanState()
    data class Failed(val reason: String) : LibraryScanState()
}
