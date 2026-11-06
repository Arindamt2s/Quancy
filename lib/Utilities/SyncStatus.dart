/// State of one download task shown in the smart loader.
enum SyncStatus {
  /// Not started yet
  pending,

  /// API call in progress
  loading,

  /// Downloaded and saved to the database
  done,

  /// API failed, but saved data from an earlier sync is available
  offline,

  /// API failed and there is no saved data
  failed,
}

extension SyncStatusX on SyncStatus {
  bool get isFinished =>
      this == SyncStatus.done ||
      this == SyncStatus.offline ||
      this == SyncStatus.failed;

  bool get isProblem => this == SyncStatus.offline || this == SyncStatus.failed;
}