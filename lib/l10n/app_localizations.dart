import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Título principal de la app
  ///
  /// In es, this message translates to:
  /// **'QAVision'**
  String get appTitle;

  /// Título de la pantalla de configuración
  ///
  /// In es, this message translates to:
  /// **'Configuración del Sistema'**
  String get settingsTitle;

  /// Label de la sección carpeta raíz
  ///
  /// In es, this message translates to:
  /// **'Carpeta raíz de capturas'**
  String get settingsRootFolder;

  /// Botón para seleccionar carpeta raíz
  ///
  /// In es, this message translates to:
  /// **'Seleccionar Carpeta'**
  String get settingsSelectFolder;

  /// Sección del botón flotante
  ///
  /// In es, this message translates to:
  /// **'Botón flotante'**
  String get settingsFloatingButton;

  /// Checkbox mostrar botón flotante
  ///
  /// In es, this message translates to:
  /// **'Mostrar botón flotante'**
  String get settingsShowFloatingButton;

  /// Checkbox iniciar con Windows
  ///
  /// In es, this message translates to:
  /// **'Iniciar con Windows'**
  String get settingsStartWithWindows;

  /// Label selector de color
  ///
  /// In es, this message translates to:
  /// **'Color del botón flotante'**
  String get settingsFloatingButtonColor;

  /// Sección formato
  ///
  /// In es, this message translates to:
  /// **'Formato de guardado'**
  String get settingsSaveFormat;

  /// Descripción del formato
  ///
  /// In es, this message translates to:
  /// **'Todas las capturas se guardan como JPG (alta resolución).'**
  String get settingsSaveFormatDescription;

  /// Sección calidad
  ///
  /// In es, this message translates to:
  /// **'Calidad JPG'**
  String get settingsJpgQuality;

  /// Opción calidad alta
  ///
  /// In es, this message translates to:
  /// **'Alta'**
  String get settingsQualityHigh;

  /// Opción calidad máxima
  ///
  /// In es, this message translates to:
  /// **'Máxima'**
  String get settingsQualityMax;

  /// Sección máscara de nombre
  ///
  /// In es, this message translates to:
  /// **'Formato de nombre de archivo'**
  String get settingsFileNameFormat;

  /// Label campo máscara
  ///
  /// In es, this message translates to:
  /// **'Máscara de nombre'**
  String get settingsFileNameMask;

  /// Sección post-captura
  ///
  /// In es, this message translates to:
  /// **'Después de capturar'**
  String get settingsAfterCapture;

  /// Radio opción visor
  ///
  /// In es, this message translates to:
  /// **'Guardar y abrir visor'**
  String get settingsSaveAndOpenViewer;

  /// Radio opción miniatura
  ///
  /// In es, this message translates to:
  /// **'Guardar y mostrar miniatura (3s)'**
  String get settingsSaveAndShowThumbnail;

  /// Radio opción silencioso
  ///
  /// In es, this message translates to:
  /// **'Guardar silencioso (sin visor ni miniatura)'**
  String get settingsSaveSilent;

  /// Checkbox portapapeles
  ///
  /// In es, this message translates to:
  /// **'Copiar automáticamente al portapapeles después de capturar'**
  String get settingsCopyToClipboard;

  /// Sección hotkeys
  ///
  /// In es, this message translates to:
  /// **'Atajos de teclado'**
  String get settingsHotkeys;

  /// Label hotkey tradicional
  ///
  /// In es, this message translates to:
  /// **'Captura Tradicional'**
  String get settingsHotkeyTraditional;

  /// Label hotkey clip
  ///
  /// In es, this message translates to:
  /// **'Modo Clip ON/OFF'**
  String get settingsHotkeyClipMode;

  /// Label hotkey visor
  ///
  /// In es, this message translates to:
  /// **'Abrir Visor'**
  String get settingsHotkeyOpenViewer;

  /// Botón guardar config
  ///
  /// In es, this message translates to:
  /// **'Guardar configuración'**
  String get settingsSaveConfig;

  /// Botón reset
  ///
  /// In es, this message translates to:
  /// **'Restablecer valores por defecto'**
  String get settingsResetDefaults;

  /// Mensaje de conflicto de hotkey
  ///
  /// In es, this message translates to:
  /// **'Esta combinación ya está en uso. Elige otra.'**
  String get settingsHotkeyConflict;

  /// Sección modo clip
  ///
  /// In es, this message translates to:
  /// **'Modo Clip'**
  String get settingsClipMode;

  /// Checkbox clic izquierdo
  ///
  /// In es, this message translates to:
  /// **'Capturar solo clic izquierdo'**
  String get settingsClipLeftClick;

  /// Checkbox ignorar scroll
  ///
  /// In es, this message translates to:
  /// **'Ignorar clic en barras de desplazamiento'**
  String get settingsClipIgnoreScrollbar;

  /// Checkbox intervalo
  ///
  /// In es, this message translates to:
  /// **'Capturar cada X segundos (intervalo)'**
  String get settingsClipInterval;

  /// Label campo intervalo
  ///
  /// In es, this message translates to:
  /// **'Intervalo (segundos)'**
  String get settingsClipIntervalSeconds;

  /// Sección visor
  ///
  /// In es, this message translates to:
  /// **'Visor / Editor'**
  String get settingsViewer;

  /// Checkbox tira recientes
  ///
  /// In es, this message translates to:
  /// **'Mostrar tira de \"Capturas recientes\" (últimas 5)'**
  String get settingsShowRecentStrip;

  /// Checkbox indicador guardado
  ///
  /// In es, this message translates to:
  /// **'Mostrar indicador \"Guardado\"'**
  String get settingsShowSavedIndicator;

  /// Título pantalla proyectos
  ///
  /// In es, this message translates to:
  /// **'Proyectos'**
  String get projectsTitle;

  /// Botón nuevo proyecto
  ///
  /// In es, this message translates to:
  /// **'Nuevo Proyecto'**
  String get projectsNewProject;

  /// Título modal crear
  ///
  /// In es, this message translates to:
  /// **'Crear proyecto'**
  String get projectsCreate;

  /// Título modal editar
  ///
  /// In es, this message translates to:
  /// **'Editar proyecto'**
  String get projectsEdit;

  /// Label nombre
  ///
  /// In es, this message translates to:
  /// **'Nombre del proyecto'**
  String get projectsName;

  /// Label alias
  ///
  /// In es, this message translates to:
  /// **'Alias corto (2–4 letras)'**
  String get projectsAlias;

  /// Label color
  ///
  /// In es, this message translates to:
  /// **'Color del proyecto'**
  String get projectsColor;

  /// Checkbox predeterminado
  ///
  /// In es, this message translates to:
  /// **'Establecer como predeterminado'**
  String get projectsSetDefault;

  /// Botón crear
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get projectsCreateButton;

  /// Botón cancelar
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get projectsCancelButton;

  /// Botón editar
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get projectsEditButton;

  /// Botón abrir carpeta
  ///
  /// In es, this message translates to:
  /// **'Abrir Carpeta'**
  String get projectsOpenFolder;

  /// Botón set default
  ///
  /// In es, this message translates to:
  /// **'Establecer Predeterminado'**
  String get projectsSetDefaultButton;

  /// Tooltip del botón flotante
  ///
  /// In es, this message translates to:
  /// **'Proyecto activo: {projectName}'**
  String floatingButtonTooltip(String projectName);

  /// Título del panel flotante
  ///
  /// In es, this message translates to:
  /// **'Capturas'**
  String get floatingPanelTitle;

  /// Label proyecto activo
  ///
  /// In es, this message translates to:
  /// **'Proyecto activo'**
  String get floatingActiveProject;

  /// Botón cambiar proyecto
  ///
  /// In es, this message translates to:
  /// **'Cambiar proyecto'**
  String get floatingChangeProject;

  /// Botón ver todos
  ///
  /// In es, this message translates to:
  /// **'Ver todos los proyectos'**
  String get floatingViewAllProjects;

  /// Botón crear proyecto
  ///
  /// In es, this message translates to:
  /// **'Crear nuevo proyecto'**
  String get floatingCreateProject;

  /// Botón capturar
  ///
  /// In es, this message translates to:
  /// **'Capturar'**
  String get floatingCapture;

  /// Botón modo clip
  ///
  /// In es, this message translates to:
  /// **'Modo Clip'**
  String get floatingClipMode;

  /// Texto modo clip activo
  ///
  /// In es, this message translates to:
  /// **'Modo Clip activo'**
  String get floatingClipModeActive;

  /// Botón abrir visor
  ///
  /// In es, this message translates to:
  /// **'Abrir Visor'**
  String get floatingOpenViewer;

  /// Botón abrir carpeta
  ///
  /// In es, this message translates to:
  /// **'Abrir carpeta del proyecto actual'**
  String get floatingOpenProjectFolder;

  /// Dropdown post-captura
  ///
  /// In es, this message translates to:
  /// **'Comportamiento post-captura'**
  String get floatingPostCapture;

  /// Opción usar config
  ///
  /// In es, this message translates to:
  /// **'Usar configuración'**
  String get floatingUseConfig;

  /// Título del visor
  ///
  /// In es, this message translates to:
  /// **'Editor de Captura'**
  String get viewerTitle;

  /// Botón agregar imagen
  ///
  /// In es, this message translates to:
  /// **'Agregar imagen al frame'**
  String get viewerAddImage;

  /// Indicador de guardado
  ///
  /// In es, this message translates to:
  /// **'Guardado'**
  String get viewerSaved;

  /// Herramienta seleccionar
  ///
  /// In es, this message translates to:
  /// **'Seleccionar'**
  String get viewerSelect;

  /// Herramienta flecha
  ///
  /// In es, this message translates to:
  /// **'Flecha'**
  String get viewerArrow;

  /// Herramienta rectángulo
  ///
  /// In es, this message translates to:
  /// **'Rectángulo'**
  String get viewerRectangle;

  /// Herramienta círculo
  ///
  /// In es, this message translates to:
  /// **'Círculo'**
  String get viewerCircle;

  /// Herramienta resaltador
  ///
  /// In es, this message translates to:
  /// **'Resaltador'**
  String get viewerHighlighter;

  /// Herramienta lápiz
  ///
  /// In es, this message translates to:
  /// **'Lápiz'**
  String get viewerPencil;

  /// Herramienta texto
  ///
  /// In es, this message translates to:
  /// **'Texto'**
  String get viewerText;

  /// Herramienta burbuja
  ///
  /// In es, this message translates to:
  /// **'Burbuja de comentario'**
  String get viewerComment;

  /// Herramienta numerador
  ///
  /// In es, this message translates to:
  /// **'Numerador de pasos'**
  String get viewerStepNumber;

  /// Herramienta blur
  ///
  /// In es, this message translates to:
  /// **'Blur'**
  String get viewerBlur;

  /// Herramienta borrador
  ///
  /// In es, this message translates to:
  /// **'Borrador'**
  String get viewerEraser;

  /// Herramienta deshacer
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get viewerUndo;

  /// Herramienta rehacer
  ///
  /// In es, this message translates to:
  /// **'Rehacer'**
  String get viewerRedo;

  /// Propiedad color
  ///
  /// In es, this message translates to:
  /// **'Color'**
  String get viewerColor;

  /// Propiedad grosor
  ///
  /// In es, this message translates to:
  /// **'Grosor'**
  String get viewerThickness;

  /// Propiedad tamaño
  ///
  /// In es, this message translates to:
  /// **'Tamaño'**
  String get viewerSize;

  /// Mensaje de primer uso
  ///
  /// In es, this message translates to:
  /// **'Configura la carpeta raíz para comenzar a usar QAVision.'**
  String get firstUseMessage;

  /// Advertencia al cancelar primer uso
  ///
  /// In es, this message translates to:
  /// **'Debes configurar una carpeta raíz para continuar.'**
  String get firstUseCancelWarning;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
