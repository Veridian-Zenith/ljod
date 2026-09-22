package dev.vz.ljod.data.library

import dev.vz.ljod.core.data.scanner.MediaStoreObserver
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class LibraryScanCoordinator
    @Inject
    constructor(
        private val repository: LibraryRepository,
        private val observer: MediaStoreObserver,
    ) {
        private val scope = CoroutineScope(Dispatchers.Default)
        private val _state = MutableStateFlow<LibraryScanState>(LibraryScanState.Idle)
        val state: StateFlow<LibraryScanState> = _state.asStateFlow()

        val mediaStoreChanges: SharedFlow<Unit> = observer.changes

        private var currentJob: Job? = null

        init {
            observer.register()
            scope.launch {
                observer.changes.collect { rescan() }
            }
        }

        fun rescan() {
            if (currentJob?.isActive == true) return
            currentJob =
                scope.launch {
                    _state.value = LibraryScanState.Scanning(0, null)
                    try {
                        val items = withContext(Dispatchers.IO) { repository.scan() }
                        val songs = repository.observeSongsOnce()
                        val albums = repository.observeAlbumsOnce()
                        val artists = repository.observeArtistsOnce()
                        _state.value =
                            LibraryScanState.Indexed(
                                songCount = songs.size,
                                albumCount = albums.size,
                                artistCount = artists.size,
                            )
                        Timber.d("Scan complete: ${items.size} items")
                    } catch (e: Exception) {
                        Timber.e(e, "Scan failed")
                        _state.value = LibraryScanState.Failed(e.message ?: "Unknown error")
                    }
                }
        }
    }
