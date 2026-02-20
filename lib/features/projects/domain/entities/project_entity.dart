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
    required this.alias,
    required this.color,
    this.isDefault = false,
  });

  /// Identificador único del proyecto.
  final String id;

  /// Nombre del proyecto (también nombre de la carpeta).
  final String name;

  /// Alias corto (2–4 letras) mostrado en el botón flotante.
  final String alias;

  /// Color ARGB identificador del proyecto.
  final int color;

  /// Si es el proyecto predeterminado.
  final bool isDefault;

  /// Crea una copia con los campos especificados modificados.
  ProjectEntity copyWith({
    String? name,
    String? alias,
    int? color,
    bool? isDefault,
  }) {
    return ProjectEntity(
      id: id,
      name: name ?? this.name,
      alias: alias ?? this.alias,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  List<Object?> get props => [id, name, alias, color, isDefault];
}
