import 'package:appunits_core/appunits_core.dart';

class ChatUtils {
  static RegExp urlReg = RegExp(
      r"([hH][tT]{2}[pP]:\/\/|[hH][tT]{2}[pP][sS]:\/\/|[wW]{3}.|[wW][aA][pP].|[fF][tT][pP].|[fF][iI][lL][eE].)[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]");

  /// Group member display name priority: nameCard > friendRemark > nickname > userID
  static String memberDisplayName(GroupMember member) {
    if (member.nameCard != null && member.nameCard!.isNotEmpty) return member.nameCard!;
    if (member.friendRemark != null && member.friendRemark!.isNotEmpty) return member.friendRemark!;
    if (member.nickname != null && member.nickname!.isNotEmpty) return member.nickname!;
    return member.userID;
  }
}