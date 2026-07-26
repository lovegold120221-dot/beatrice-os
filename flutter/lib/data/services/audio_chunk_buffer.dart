import 'dart:typed_data';

/// A simple fixed-capacity ring buffer for audio chunks.
///
/// Designed to hold audio chunks during brief disconnects so that no
/// audio data is lost while a connection is re-established. When the
/// buffer reaches its [capacity], the oldest chunks are dropped first.
class AudioChunkBuffer {
  /// Maximum number of chunks the buffer will hold before dropping
  /// the oldest entries. The default of 5 chunks corresponds to
  /// roughly 200 ms of audio at 40 ms per chunk.
  final int capacity;

  final List<Uint8List> _chunks = [];

  /// Creates a new buffer that holds at most [capacity] chunks.
  ///
  /// [capacity] defaults to 5, which represents approximately 200 ms
  /// of audio when each chunk is 40 ms in duration.
  AudioChunkBuffer({this.capacity = 5});

  /// Adds [chunk] to the end of the buffer.
  ///
  /// If the buffer already contains [capacity] chunks, the oldest
  /// chunk (at the front) is removed before the new one is appended.
  /// This ensures the buffer never grows beyond [capacity].
  void enqueue(Uint8List chunk) {
    _chunks.add(chunk);
    while (_chunks.length > capacity) {
      _chunks.removeAt(0);
    }
  }

  /// Returns a copy of all buffered chunks and clears the buffer.
  ///
  /// Returns an empty list if no chunks are currently buffered.
  /// The returned list is a new instance; modifying it has no effect
  /// on the internal storage.
  List<Uint8List> drain() {
    final drained = List<Uint8List>.of(_chunks);
    _chunks.clear();
    return drained;
  }

  /// Discards all currently buffered chunks.
  void clear() {
    _chunks.clear();
  }

  /// Whether the buffer currently holds no chunks.
  bool get isEmpty => _chunks.isEmpty;

  /// The current number of buffered chunks.
  int get length => _chunks.length;
}
