import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/log.dart';
import 'board_group/group_data.dart';
import 'reorder_flex/reorder_flex.dart';
import 'reorder_phantom/phantom_controller.dart';

typedef OnMoveGroup =
    void Function(
      String fromGroupId,
      int fromIndex,
      String toGroupId,
      int toIndex,
    );

typedef OnMoveGroupItem =
    void Function(String groupId, int fromIndex, int toIndex);

typedef OnMoveGroupItemToGroup =
    void Function(
      String fromGroupId,
      int fromIndex,
      String toGroupId,
      int toIndex,
    );

typedef OnStartDraggingCard = void Function(String groupId, int index);

/// A controller for [BoardPanel] widget.
///
/// A [BoardPanelController] can be used to provide an initial value of
/// the board by calling `addGroup` method with the passed in parameter
/// [BoardPanelGroupData]. A [BoardPanelGroupData] represents one
/// group data. Whenever the user modifies the board, this controller will
/// update the corresponding group data.
///
/// Also, you can register the callbacks that receive the changes.
/// [onMoveGroup] will get called when moving the group from one position to
/// another.
///
/// [onMoveGroupItem] will get called when moving the group's items.
///
/// [onMoveGroupItemToGroup] will get called when moving the group's item from
/// one group to another group.
// ignore: must_be_immutable
class BoardPanelController extends ChangeNotifier
    with EquatableMixin
    implements BoardPhantomControllerDelegate, ReoderFlexDataSource {
  BoardPanelController({
    this.onMoveGroup,
    this.onMoveGroupItem,
    this.onMoveGroupItemToGroup,
    this.onStartDraggingCard,
  });

  final List<BoardPanelGroupData<dynamic>> _groupDatas = [];

  /// [onMoveGroup] will get called when moving the group from one position to
  /// another.
  final OnMoveGroup? onMoveGroup;

  /// [onMoveGroupItem] will get called when moving the group's items.
  final OnMoveGroupItem? onMoveGroupItem;

  /// [onMoveGroupItemToGroup] will get called when moving the group's item from
  /// one group to another group.
  final OnMoveGroupItemToGroup? onMoveGroupItemToGroup;

  final OnStartDraggingCard? onStartDraggingCard;

  /// The board layout axis currently resolved by [BoardPanel] (horizontal
  /// kanban columns on desktop/tablet, vertical stack on phones when
  /// `BoardPanelConfig.responsiveDirection` is configured).
  ///
  /// Updated by the board widget after each breakpoint change; listen to it
  /// to adapt business UI (headers, toolbars) to the active direction.
  ValueListenable<Axis> get layoutDirection => _layoutDirection;
  final ValueNotifier<Axis> _layoutDirection = ValueNotifier(Axis.horizontal);

  /// Called by [BoardPanel] when the responsive layout direction changes.
  /// No-op (and no notification) when the direction is unchanged.
  void updateLayoutDirection(Axis direction) {
    if (_layoutDirection.value == direction) return;
    _layoutDirection.value = direction;
  }

  @override
  void dispose() {
    _layoutDirection.dispose();
    super.dispose();
  }

  /// Returns the unmodifiable list of [BoardPanelGroupData]
  UnmodifiableListView<BoardPanelGroupData<dynamic>> get groupDatas =>
      UnmodifiableListView(_groupDatas);

  /// Returns list of group id
  List<String> get groupIds =>
      _groupDatas.map((groupData) => groupData.id).toList();

  final LinkedHashMap<String, BoardPanelGroupController> _groupControllers =
      LinkedHashMap();

  /// Adds a new group to the end of the current group list.
  ///
  /// If you don't want to notify the listener after adding a new group, the
  /// [notify] should set to false. Default value is true.
  void addGroup(BoardPanelGroupData<dynamic> groupData, {bool notify = true}) {
    if (_groupControllers[groupData.id] != null) return;

    final controller = BoardPanelGroupController(groupData: groupData);
    _groupDatas.add(groupData);
    _groupControllers[groupData.id] = controller;
    _applyGroupDraggability(groupData);
    if (notify) notifyListeners();
  }

  /// Inserts a new group at the given index
  ///
  /// If you don't want to notify the listener after inserting the new group, the
  /// [notify] should set to false. Default value is true.
  void insertGroup(
    int index,
    BoardPanelGroupData<dynamic> groupData, {
    bool notify = true,
  }) {
    if (_groupControllers[groupData.id] != null) return;

    final controller = BoardPanelGroupController(groupData: groupData);
    _groupDatas.insert(index, groupData);
    _groupControllers[groupData.id] = controller;
    _applyGroupDraggability(groupData);
    if (notify) notifyListeners();
  }

  /// Adds a list of groups to the end of the current group list.
  ///
  /// If you don't want to notify the listener after adding the groups, the
  /// [notify] should set to false. Default value is true.
  void addGroups(
    List<BoardPanelGroupData<dynamic>> groups, {
    bool notify = true,
  }) {
    for (final column in groups) {
      addGroup(column, notify: false);
    }

    if (groups.isNotEmpty && notify) notifyListeners();
  }

  /// Removes the group with id [groupId]
  ///
  /// If you don't want to notify the listener after removing the group, the
  /// [notify] should set to false. Default value is true.
  void removeGroup(String groupId, {bool notify = true}) {
    final index = _groupDatas.indexWhere((group) => group.id == groupId);
    if (index == -1) {
      Log.warn(
        'Try to remove Group:[$groupId] failed. Group:[$groupId] does not exist',
      );
    }

    if (index != -1) {
      _groupDatas.removeAt(index);
      _groupControllers.remove(groupId);

      if (notify) notifyListeners();
    }
  }

  /// Removes a list of groups
  ///
  /// If you don't want to notify the listener after removing the groups, the
  /// [notify] should set to false. Default value is true.
  void removeGroups(List<String> groupIds, {bool notify = true}) {
    for (final groupId in groupIds) {
      removeGroup(groupId, notify: false);
    }

    if (groupIds.isNotEmpty && notify) notifyListeners();
  }

  /// Remove all the groups controller.
  ///
  /// This method should get called when you want to remove all the current
  /// groups or get ready to reinitialize the [BoardPanel].
  void clear() {
    _groupDatas.clear();
    for (final group in _groupControllers.values) {
      group.dispose();
    }
    _groupControllers.clear();

    notifyListeners();
  }

  /// Whether whole groups (columns) may be dragged around.
  ///
  /// Only when the host registered [onMoveGroup]: without it a group drag
  /// cannot be written back anywhere, so it would just shuffle the board
  /// visually. Hosts that need finer control can still call
  /// [enableGroupDragging] afterwards.
  bool get _groupsAreDraggable => onMoveGroup != null;

  void _applyGroupDraggability(BoardPanelGroupData<dynamic> groupData) {
    if (groupData.draggable.value != _groupsAreDraggable) {
      groupData.draggable.value = _groupsAreDraggable;
    }
  }

  /// Returns the [BoardPanelGroupController] with id [groupId].
  BoardPanelGroupController? getGroupController(String groupId) {
    final groupController = _groupControllers[groupId];
    if (groupController == null) {
      Log.warn('Group:[$groupId] \'s controller is not exist');
    }

    return groupController;
  }

  /// Moves the group controller from [fromIndex] to [toIndex] and notify the
  /// listeners.
  ///
  /// If you don't want to notify the listener after moving the group, the
  /// [notify] should set to false. Default value is true.
  void moveGroup(int fromIndex, int toIndex, {bool notify = true}) {
    final toGroupData = _groupDatas[toIndex];
    final fromGroupData = _groupDatas.removeAt(fromIndex);

    _groupDatas.insert(toIndex, fromGroupData);
    onMoveGroup?.call(fromGroupData.id, fromIndex, toGroupData.id, toIndex);
    if (notify) notifyListeners();
  }

  /// Moves the group's item from [fromIndex] to [toIndex]
  /// If the group with id [groupId] is not exist, this method will do nothing.
  void moveGroupItem(String groupId, int fromIndex, int toIndex) {
    if (getGroupController(groupId)?.move(fromIndex, toIndex) ?? false) {
      onMoveGroupItem?.call(groupId, fromIndex, toIndex);
    }
  }

  /// Adds the [BoardPanelGroupItem] to the end of the group
  ///
  /// If the group with id [groupId] is not exist, this method will do nothing.
  void addGroupItem(String groupId, BoardPanelGroupItem item) {
    getGroupController(groupId)?.add(item);
  }

  /// Inserts the [BoardPanelGroupItem] at [index] in the group
  ///
  /// It will do nothing if the group with id [groupId] is not exist
  void insertGroupItem(String groupId, int index, BoardPanelGroupItem item) {
    getGroupController(groupId)?.insert(index, item);
  }

  /// Removes the item with id [itemId] from the group
  ///
  /// It will do nothing if the group with id [groupId] is not exist
  void removeGroupItem(String groupId, String itemId) {
    getGroupController(groupId)?.removeWhere((item) => item.id == itemId);
  }

  /// Replaces or inserts the [BoardPanelGroupItem] to the end of the group.
  ///
  /// If the group with id [groupId] is not exist, this method will do nothing.
  void updateGroupItem(String groupId, BoardPanelGroupItem item) {
    getGroupController(groupId)?.replaceOrInsertItem(item);
  }

  void enableGroupDragging(bool isEnable) {
    for (final groupController in _groupControllers.values) {
      groupController.enableDragging(isEnable);
    }
  }

  /// Moves the item at [fromGroupIndex] in group with id [fromGroupId] to
  /// group with id [toGroupId] at [toGroupIndex]
  @override
  @protected
  void moveGroupItemToAnotherGroup(
    String fromGroupId,
    int fromGroupIndex,
    String toGroupId,
    int toGroupIndex,
  ) {
    final fromGroupController = getGroupController(fromGroupId)!;
    final toGroupController = getGroupController(toGroupId)!;
    final fromGroupItem = fromGroupController.removeAt(fromGroupIndex);
    if (fromGroupItem == null) return;

    if (toGroupController.items.length > toGroupIndex) {
      assert(toGroupController.items[toGroupIndex] is PhantomGroupItem);

      toGroupController.replace(toGroupIndex, fromGroupItem);
      onMoveGroupItemToGroup?.call(
        fromGroupId,
        fromGroupIndex,
        toGroupId,
        toGroupIndex,
      );
    }
  }

  @override
  List<Object?> get props => [_groupDatas];

  @override
  BoardPanelGroupController? controller(String groupId) =>
      _groupControllers[groupId];

  @override
  String get identifier => '$BoardPanelController';

  @override
  UnmodifiableListView<ReoderFlexItem> get items =>
      UnmodifiableListView(_groupDatas);

  @override
  @protected
  bool removePhantom(String groupId) {
    final groupController = getGroupController(groupId);
    if (groupController == null) {
      Log.warn('Can not find the group controller with groupId: $groupId');
      return false;
    }
    final index = groupController.items.indexWhere((item) => item.isPhantom);
    final isExist = index != -1;
    if (isExist) {
      groupController.removeAt(index);

      Log.debug(
        '[$BoardPanelController] Group:[$groupId] remove phantom, current count: ${groupController.items.length}',
      );
    }
    return isExist;
  }

  @override
  @protected
  void updatePhantom(String groupId, int newIndex) {
    final groupController = getGroupController(groupId)!;
    final index = groupController.items.indexWhere((item) => item.isPhantom);

    if (index != -1) {
      if (index != newIndex) {
        Log.trace(
          '[$BoardPhantomController] update $groupId:$index to $groupId:$newIndex',
        );
        final item = groupController.removeAt(index, notify: false);
        if (item != null) {
          groupController.insert(newIndex, item, notify: false);
        }
      }
    }
  }

  @override
  @protected
  void insertPhantom(String groupId, int index, PhantomGroupItem item) =>
      getGroupController(groupId)!.insert(index, item);
}
