mixin HolderReferencing {
  String get sourceID;
  String? get destinationID;

  Set<String> get holderIDs => {sourceID, ?destinationID};

  bool references(String id) => sourceID == id || destinationID == id;

  bool touches(Set<String> ids) => holderIDs.intersection(ids).isNotEmpty;
}
