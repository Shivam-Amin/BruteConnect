// A simple data model for file metadata
class FileMetadata {
  final String name;
  final int size;
  
  FileMetadata({required this.name, required this.size});

  // Convert to JSON for socket transmission
  Map<String, dynamic> toJson() => {
    'name': name,
    'size': size,
  };
  
  // Convert from JSON to an object
  factory FileMetadata.fromJson(Map<String, dynamic> json) {
    return FileMetadata(
      name: json['name'] as String,
      size: json['size'] as int,
    );
  }
}