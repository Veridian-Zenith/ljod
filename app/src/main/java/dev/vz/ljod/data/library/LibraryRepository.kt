package dev.vz.ljod.data.library

import android.content.ContentUris
import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.vz.ljod.core.data.scanner.AudioItem
import dev.vz.ljod.core.data.scanner.MediaScanner
import dev.vz.ljod.data.database.AlbumDao
import dev.vz.ljod.data.database.ArtistDao
import dev.vz.ljod.data.database.FavoriteDao
import dev.vz.ljod.data.database.HistoryDao
import dev.vz.ljod.data.database.MusicDao
import dev.vz.ljod.data.database.PlaylistDao
import dev.vz.ljod.data.model.Album
import dev.vz.ljod.data.model.AlbumEntity
import dev.vz.ljod.data.model.Artist
import dev.vz.ljod.data.model.ArtistEntity
import dev.vz.ljod.data.model.FavoriteEntity
import dev.vz.ljod.data.model.PlayCountEntity
import dev.vz.ljod.data.model.PlayHistoryEntity
import dev.vz.ljod.data.model.Playlist
import dev.vz.ljod.data.model.PlaylistEntity
import dev.vz.ljod.data.model.Song
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class LibraryRepository
    @Inject
    constructor(
        @ApplicationContext private val context: Context,
        private val scanner: MediaScanner,
        private val musicDao: MusicDao,
        private val albumDao: AlbumDao,
        private val artistDao: ArtistDao,
        private val favoriteDao: FavoriteDao,
        private val playlistDao: PlaylistDao,
        private val historyDao: HistoryDao,
    ) {
        private val handler = Handler(Looper.getMainLooper())
        private val mediaObserver =
            object : ContentObserver(handler) {
                override fun onChange(
                    selfChange: Boolean,
                    uri: Uri?,
                ) {
                    Timber.d("MediaStore change detected: $uri")
                }
            }

        init {
            context.contentResolver.registerContentObserver(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                true,
                mediaObserver,
            )
        }

        suspend fun scan(): List<AudioItem> =
            withContext(Dispatchers.IO) {
                val items = scanner.scan()
                val songs = items.map { it.toEntity() }
                musicDao.upsertAll(songs)
                val existingIds = songs.map { it.id }
                if (existingIds.isNotEmpty()) {
                    musicDao.deleteMissing(existingIds)
                }
                val albums =
                    items
                        .groupBy { it.albumId ?: 0L }
                        .map { (albumId, list) ->
                            AlbumEntity(
                                id = albumId,
                                name = list.first().album,
                                artist = list.first().artist,
                                songCount = list.size,
                                totalDurationMs = list.sumOf { it.duration },
                                coverUri =
                                    if (albumId > 0) {
                                        ContentUris.withAppendedId(albumArtUri, albumId).toString()
                                    } else {
                                        null
                                    },
                            )
                        }.filter { it.id > 0 }
                albumDao.upsertAll(albums)
                val existingAlbumIds = albums.map { it.id }
                if (existingAlbumIds.isNotEmpty()) albumDao.deleteMissing(existingAlbumIds)

                val artistMap = items.groupBy { it.artist.lowercase() }
                val artists =
                    artistMap.values.map { list ->
                        ArtistEntity(
                            name = list.first().artist,
                            songCount = list.size,
                            albumCount = list.mapNotNull { it.albumId }.distinct().size,
                        )
                    }
                artistDao.deleteAll()
                artistDao.upsertAll(artists)
                items
            }

        suspend fun search(query: String): List<Song> =
            withContext(Dispatchers.IO) {
                if (query.isBlank()) emptyList() else musicDao.search(query)
            }

        fun observeSongs(): Flow<List<Song>> = musicDao.observeAll()

        fun observeAlbums(): Flow<List<Album>> =
            albumDao.observeAll().map { list ->
                list.map {
                    Album(
                        id = it.id,
                        name = it.name,
                        artist = it.artist,
                        songCount = it.songCount,
                        totalDurationMs = it.totalDurationMs,
                        coverUri = it.coverUri,
                    )
                }
            }

        fun observeArtists(): Flow<List<Artist>> =
            artistDao.observeAll().map { list ->
                list.map { Artist(it.name, it.songCount, it.albumCount) }
            }

        fun observeFavorites(): Flow<List<Song>> = favoriteDao.observeFavorites()

        suspend fun observeSongsOnce(): List<Song> = withContext(Dispatchers.IO) { musicDao.observeAll().first() }

        suspend fun observeAlbumsOnce(): List<Album> = withContext(Dispatchers.IO) {
            albumDao.observeAll().first().map {
                Album(
                    id = it.id,
                    name = it.name,
                    artist = it.artist,
                    songCount = it.songCount,
                    totalDurationMs = it.totalDurationMs,
                    coverUri = it.coverUri,
                )
            }
        }

        suspend fun observeArtistsOnce(): List<Artist> = withContext(Dispatchers.IO) {
            artistDao.observeAll().first().map { Artist(it.name, it.songCount, it.albumCount) }
        }

        fun observeFavoriteIds(): Flow<Set<Long>> = favoriteDao.observeFavoriteIds().map { it.toSet() }

        fun observeIsFavorite(songId: Long): Flow<Boolean> = favoriteDao.observeIsFavorite(songId)

        suspend fun toggleFavorite(songId: Long) = favoriteDao.toggle(songId)

        suspend fun isFavorite(songId: Long): Boolean = favoriteDao.isFavorite(songId)

        fun observePlaylists(): Flow<List<Playlist>> =
            combine(
                playlistDao.observeAll(),
                playlistDao.observeAll(),
            ) { playlists, _ ->
                playlists.map { p ->
                    Playlist(
                        id = p.id,
                        name = p.name,
                        songCount = playlistDao.songCount(p.id),
                        coverUri = p.coverUri,
                        createdAt = p.createdAt,
                        updatedAt = p.updatedAt,
                    )
                }
            }.distinctUntilChanged()

        suspend fun createPlaylist(name: String): Long {
            val now = System.currentTimeMillis()
            return playlistDao.insert(PlaylistEntity(name = name, createdAt = now, updatedAt = now))
        }

        suspend fun deletePlaylist(id: Long) = playlistDao.delete(id)

        suspend fun renamePlaylist(
            id: Long,
            name: String,
        ) = playlistDao.rename(id, name, System.currentTimeMillis())

        suspend fun addToPlaylist(
            playlistId: Long,
            songId: Long,
        ) {
            val next = playlistDao.maxPosition(playlistId) + 1
            playlistDao.addEntry(
                dev.vz.ljod.data.model.PlaylistEntry(
                    playlistId = playlistId,
                    songId = songId,
                    position = next,
                    addedAt = System.currentTimeMillis(),
                ),
            )
            playlistDao.rename(playlistId, playlistDao.getById(playlistId)?.name ?: "Playlist", System.currentTimeMillis())
        }

        suspend fun removeFromPlaylist(
            playlistId: Long,
            songId: Long,
        ) = playlistDao.removeEntry(playlistId, songId)

        fun observePlaylistSongs(id: Long): Flow<List<Song>> = playlistDao.observeSongs(id)

        suspend fun songsInPlaylist(id: Long): List<Song> = playlistDao.songsOnce(id)

        suspend fun songsForAlbum(albumId: Long): List<Song> = albumDao.songsForAlbum(albumId)

        suspend fun songsForArtist(name: String): List<Song> = artistDao.songsForArtist(name)

        suspend fun recordPlay(
            songId: Long,
            completedMs: Long,
            durationMs: Long,
        ) = withContext(Dispatchers.IO) {
            historyDao.addHistory(
                PlayHistoryEntity(
                    songId = songId,
                    playedAt = System.currentTimeMillis(),
                    completedMs = completedMs,
                    durationMs = durationMs,
                ),
            )
            val existing = historyDao.getCount(songId) ?: 0
            historyDao.upsertCount(
                PlayCountEntity(
                    songId = songId,
                    count = existing + 1,
                    lastPlayedAt = System.currentTimeMillis(),
                ),
            )
        }

        fun observeRecentHistory(limit: Int = 100): Flow<List<PlayHistoryEntity>> = historyDao.observeRecent(limit)

        fun observeMostPlayed(limit: Int = 50): Flow<List<PlayCountEntity>> = historyDao.observeMostPlayed(limit)

        suspend fun songById(id: Long): Song? = musicDao.getById(id)

        suspend fun songCount(): Int = musicDao.count()

        private val albumArtUri: Uri = Uri.parse("content://media/external/audio/albumart")
    }

private fun AudioItem.toEntity(): Song =
    Song(
        id = id,
        title = title,
        artist = artist,
        album = album,
        duration = duration,
        uri = uri.toString(),
        dateAdded = dateAdded,
        albumId = albumId,
    )
