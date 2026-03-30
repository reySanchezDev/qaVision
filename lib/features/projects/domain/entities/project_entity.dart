import 'package:equatable/equatable.dart';

/// Entidad de proyecto para organizar capturas.
///
/// Cada proyecto corresponde a una carpeta física dentro
/// de la carpeta raíz y agrupa capturas relacionadas (§5).
class ProjectEntity extends Equatable {
  /// Crea una instancia de [ProjectEntity].
  const ProjectEntity({
    required this.id,
    required this.name,
    required this.folderPath,
    required this.alias,
    required this.color,
    this.isDefault = false,
    this.usageCount = 0,
    this.lastUsedAt = 0,
  });

  /// Identificador único del proyecto.
  final String id;

  /// Nombre del proyecto (también nombre de la carpeta).
  final String name;

  /// Ruta absoluta de la carpeta real del proyecto.
  final String folderPath;

  /// Alias corto (2–4 letras) mostrado en el botón flotante.
  final String alias;

  /// Color ARGB identificador del proyecto.
  final int color;

  /// Si es el proyecto predeterminado.
  final bool isDefault;

  /// Cantidad de veces que el proyecto fue utilizado para capturar.
  final int usageCount;

  /// Timestamp epoch ms del último uso.
  final int lastUsedAt;

  /// Crea una copia con los campos especificados modificados.
  ProjectEntity copyWith({
    String? id,
    String? name,
    String? folderPath,
    String? alias,
    int? color,
    bool? isDefault,
    int? usageCount,
    int? lastUsedAt,
  }) {
    return ProjectEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      folderPath: folderPath ?? this.folderPath,
      alias: alias ?? this.alias,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      usageCount: usageCount ?? this.usageCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    folderPath,
    alias,
    color,
    isDefault,
    usageCount,
    lastUsedAt,
  ];
}
