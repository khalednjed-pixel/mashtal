import '../models/models.dart';

/// Shared online storage for the shop data (Firestore in the app).
///
/// The backend keeps working on its in-memory lists exactly as before; a
/// [RemoteStore] fills those lists from the server and receives every change,
/// so all phones see the same nurseries, listings and plants.
///
/// Collections and fields are described in docs/data-model.md. Document ids
/// are passed separately and are not part of [RemoteWrite.data].
abstract interface class RemoteStore {
  /// Starts (or restarts, after sign-in or sign-out) listening to what
  /// [viewer] may read. [onData] receives the full current list of documents
  /// of one collection each time it changes; each map includes its `id`.
  void watch(AppUser? viewer, void Function(String collection, List<Map<String, dynamic>> docs) onData);

  /// Applies [writes] together. Writes that depend on earlier ones (a
  /// listing on a new plant) must be sent in a later call.
  Future<void> commit(List<RemoteWrite> writes);

  /// Whether the shared demo data has been uploaded yet.
  Future<bool> isSeeded();

  Future<void> markSeeded();

  void dispose();
}

class RemoteWrite {
  const RemoteWrite.put(this.collection, this.id, Map<String, dynamic> this.data);
  const RemoteWrite.delete(this.collection, this.id) : data = null;

  final String collection;
  final String id;

  /// Null deletes the document.
  final Map<String, dynamic>? data;

  @override
  String toString() => data == null ? 'delete $collection/$id' : 'put $collection/$id';
}
