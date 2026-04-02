import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/config/app_defaults.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/features/projects/presentation/bloc/project_event.dart';
import 'package:qavision/features/projects/presentation/bloc/project_state.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/widgets/recent_strip/recent_strip_frame_defaults.dart';
import 'package:qavision/features/viewer/presentation/widgets/recent_strip/recent_strip_project_slot_control.dart';
import 'package:qavision/features/viewer/presentation/widgets/recent_strip/recent_strip_thumbnail_tile.dart';

/// Bottom strip with preferred slots and thumbnails for selected project.
class RecentCapturesStrip extends StatefulWidget {
  /// Creates [RecentCapturesStrip].
  const RecentCapturesStrip({
    this.utilityPane,
    super.key,
  });

  /// Bloque fijo de utilidades ubicado al lado derecho de la cinta.
  final Widget? utilityPane;

  @override
  State<RecentCapturesStrip> createState() => _RecentCapturesStripState();
}

class _RecentCapturesStripState extends State<RecentCapturesStrip> {
  static const double _addFolderControlWidth = 164;
  static const double _addFolderControlGap = 10;
  static const int _maxProjects = 6;

  final ScrollController _scrollController = ScrollController();
  bool _seededFromProjects = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _buildSlotSelectorRow(context),
                Expanded(child: _buildThumbnailsRow()),
              ],
            ),
          ),
          if (widget.utilityPane != null)
            Container(
              width: 260,
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Colors.white10)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: widget.utilityPane,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlotSelectorRow(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: BlocBuilder<ViewerBloc, ViewerState>(
          builder: (context, viewerState) {
            return BlocBuilder<ProjectBloc, ProjectState>(
              builder: (context, projectState) {
                final projects = projectState is ProjectLoadSuccess
                    ? projectState.projects
                    : const <ProjectEntity>[];

                _ensureSeedProjectFolder(context, viewerState, projects);

                final selectedPath = _normalizePath(
                  viewerState.recentProjectPath ?? '',
                );
                final canAddMoreProjects = projects.length < _maxProjects;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right:
                              _addFolderControlWidth +
                              _addFolderControlGap +
                              16,
                        ),
                        child: ClipRect(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ...projects.asMap().entries.map((entry) {
                                  final project = entry.value;
                                  final isSelected =
                                      _normalizePath(project.folderPath) ==
                                      selectedPath;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: RecentStripProjectSlotControl(
                                      project: project,
                                      isSelected: isSelected,
                                      onSelect: () => _selectProjectFolder(
                                        context,
                                        project.folderPath,
                                      ),
                                      onReplace: () => _replaceProjectFolder(
                                        context,
                                        entry.key,
                                        project.folderPath,
                                        selectedPath,
                                      ),
                                      onRemove: () => _removeProjectFolder(
                                        context,
                                        project.folderPath,
                                        projects,
                                        selectedPath,
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(width: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.only(
                          left: _addFolderControlGap,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0x00141414),
                              Color(0xCC141414),
                              Color(0xFF141414),
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 1,
                              height: 24,
                              color: Colors.white10,
                            ),
                            const SizedBox(width: 8),
                            const SizedBox(width: 2),
                            SizedBox(
                              width: _addFolderControlWidth,
                              child: RecentStripAddFolderControl(
                                enabled: canAddMoreProjects,
                                onPressed: () => _addProjectFolder(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildThumbnailsRow() {
    return BlocBuilder<ViewerBloc, ViewerState>(
      builder: (context, state) {
        if (state.recentCaptures.isEmpty) {
          return const Center(
            child: Text(
              'No hay capturas en esta carpeta',
              style: TextStyle(color: Colors.white38),
            ),
          );
        }

        final activeBasePath = state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstOrNull
            ?.path;

        return Row(
          children: [
            IconButton(
              tooltip: 'Scroll izquierda',
              icon: const Icon(Icons.chevron_left),
              color: Colors.white70,
              onPressed: _scrollLeft,
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: state.recentCaptures.length,
                itemBuilder: (context, index) {
                  final path = state.recentCaptures[index];
                  final selected = path == activeBasePath;
                  return RecentStripThumbnailTile(
                    path: path,
                    isSelected: selected,
                    onOpen: () => _openAsMain(context, path),
                    onInsert: () => _insertIntoFrame(context, path),
                  );
                },
              ),
            ),
            IconButton(
              tooltip: 'Scroll derecha',
              icon: const Icon(Icons.chevron_right),
              color: Colors.white70,
              onPressed: _scrollRight,
            ),
          ],
        );
      },
    );
  }

  void _ensureSeedProjectFolder(
    BuildContext context,
    ViewerState viewerState,
    List<ProjectEntity> projects,
  ) {
    if (_seededFromProjects) return;
    if ((viewerState.recentProjectPath ?? '').trim().isNotEmpty) {
      _seededFromProjects = true;
      return;
    }
    if (projects.isEmpty) return;

    final seed = projects.firstWhere(
      (project) => project.isDefault,
      orElse: () => projects.first,
    );
    _seededFromProjects = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _selectProjectFolder(context, seed.folderPath);
    });
  }

  Future<void> _addProjectFolder(BuildContext context) async {
    final projectBloc = context.read<ProjectBloc>();
    final viewerBloc = context.read<ViewerBloc>();
    final projectState = projectBloc.state;
    if (projectState is ProjectLoadSuccess &&
        projectState.projects.length >= _maxProjects) {
      return;
    }
    final selectedPath = await FilePicker.platform.getDirectoryPath();
    if (!mounted || selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }

    final normalized = selectedPath.trim();
    projectBloc.add(ProjectFolderSelected(normalized));
    viewerBloc.add(ViewerRecentCapturesRequested(projectPath: normalized));
  }

  void _removeProjectFolder(
    BuildContext context,
    String folderPath,
    List<ProjectEntity> projects,
    String selectedPath,
  ) {
    final normalizedTarget = _normalizePath(folderPath);
    context.read<ProjectBloc>().add(ProjectFolderRemoved(folderPath));

    final remaining = projects
        .where(
          (project) => _normalizePath(project.folderPath) != normalizedTarget,
        )
        .toList(growable: false);

    final viewerBloc = context.read<ViewerBloc>();
    if (selectedPath != normalizedTarget) {
      return;
    }
    if (remaining.isEmpty) {
      viewerBloc.add(const ViewerRecentCapturesCleared());
      return;
    }
    viewerBloc.add(
      ViewerRecentCapturesRequested(projectPath: remaining.first.folderPath),
    );
  }

  Future<void> _replaceProjectFolder(
    BuildContext context,
    int slotIndex,
    String currentFolderPath,
    String selectedPath,
  ) async {
    final projectBloc = this.context.read<ProjectBloc>();
    final viewerBloc = this.context.read<ViewerBloc>();
    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (!mounted ||
        selectedDirectory == null ||
        selectedDirectory.trim().isEmpty) {
      return;
    }

    final normalizedNewPath = selectedDirectory.trim();
    projectBloc.add(
      ProjectFolderReplacedAt(
        slotIndex: slotIndex,
        folderPath: normalizedNewPath,
      ),
    );

    if (_normalizePath(currentFolderPath) != selectedPath) {
      return;
    }

    viewerBloc.add(
      ViewerRecentCapturesRequested(projectPath: normalizedNewPath),
    );
  }

  void _selectProjectFolder(BuildContext context, String folderPath) {
    context.read<ViewerBloc>().add(
      ViewerRecentCapturesRequested(projectPath: folderPath),
    );
  }

  void _openAsMain(BuildContext context, String path) {
    final defaults = _frameDefaults(context);
    context.read<ViewerBloc>().add(
      ViewerStarted(
        imagePath: path,
        defaultFrameBackgroundColor: defaults.backgroundColor,
        defaultFrameBackgroundOpacity: defaults.backgroundOpacity,
        defaultFrameBorderColor: defaults.borderColor,
        defaultFrameBorderWidth: defaults.borderWidth,
        defaultFramePadding: defaults.padding,
      ),
    );
  }

  void _insertIntoFrame(BuildContext context, String path) {
    final defaults = _frameDefaults(context);
    context.read<ViewerBloc>().add(
      ViewerImageAdded(
        imagePath: path,
        projectPath: File(path).parent.path,
        defaultFrameBackgroundColor: defaults.backgroundColor,
        defaultFrameBackgroundOpacity: defaults.backgroundOpacity,
        defaultFrameBorderColor: defaults.borderColor,
        defaultFrameBorderWidth: defaults.borderWidth,
        defaultFramePadding: defaults.padding,
      ),
    );
  }

  Future<void> _scrollLeft() async {
    if (!_scrollController.hasClients) return;
    final next = (_scrollController.offset - 260).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _scrollRight() async {
    if (!_scrollController.hasClients) return;
    final next = (_scrollController.offset + 260).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  String _normalizePath(String path) {
    var normalized = path.trim().replaceAll(r'\', '/').toLowerCase();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  RecentStripFrameDefaults _frameDefaults(BuildContext context) {
    return const RecentStripFrameDefaults(
      backgroundColor: kDefaultViewerFrameBackgroundColor,
      backgroundOpacity: kDefaultViewerFrameBackgroundOpacity,
      borderColor: kDefaultViewerFrameBorderColor,
      borderWidth: kDefaultViewerFrameBorderWidth,
      padding: kDefaultViewerFramePadding,
    );
  }
}
