
import 'package:dart_jts/dart_jts.dart' as JTS;



import 'epsilon.dart';
import 'types.dart';

class SegmentChainer {
  late List<List<JTS.Coordinate>> chains;
  List<List<JTS.Coordinate>>? regions;
  Match? first_match;
  Match? second_match;
  Match? next_match;

  List<List<JTS.Coordinate>>? chain(SegmentList segments) {
    this.chains = [];
    this.regions = [];

    for (var seg in segments) {
      var pt1 = seg!.start!;
      var pt2 = seg.end!;

      if (Epsilon().pointsSame(pt1, pt2)) {
        print(
            "PolyBool: Warning: Zero-length segment detected; your epsilon is probably too small or too large");
        continue;
      }

      // if (buildLog != null) {
      //   buildLog.chainStart(seg);
      // }

      first_match = Match(index: 0, matches_head: false, matches_pt1: false);

      second_match =
          new Match(index: 0, matches_head: false, matches_pt1: false);

      next_match = first_match;

      for (var i = 0; i < chains.length; i++) {
        var chain = chains[i];
        var head = chain[0];
        var head2 = chain[1];

        var tail = chain[chain.length - 1];
        var tail2 = chain[chain.length - 2];

        if (Epsilon().pointsSame(head, pt1)) {
          if (setMatch(i, true, true)) break;
        } else if (Epsilon().pointsSame(head, pt2)) {
          if (setMatch(i, true, false)) break;
        } else if (Epsilon().pointsSame(tail, pt1)) {
          if (setMatch(i, false, true)) break;
        } else if (Epsilon().pointsSame(tail, pt2)) {
          if (setMatch(i, false, false)) break;
        }
      }

      if (next_match == first_match) {
        // we didn't match anything, so create a new chain
        List<JTS.Coordinate> pointList = [];
        pointList.add(pt1);
        pointList.add(pt2);
        chains.add(pointList);

        // if (buildLog != null) {
        //   buildLog.chainNew(pt1, pt2);
        // }

        continue;
      }

      if (next_match == second_match) {
        // we matched a single chain

        // if( buildLog != null )
        // buildLog.chainMatch( first_match.index );

        // add the other point to the apporpriate end, and check to see if we've closed the
        // chain into a loop

        var index = first_match!.index;
        var pt = first_match!.matches_pt1
            ? pt2
            : pt1; // if we matched pt1, then we add pt2, etc
        var addToHead = first_match!
            .matches_head; // if we matched at head, then add to the head

        var chain = chains[index];
        var grow = addToHead ? chain[0] : chain[chain.length - 1];
        var grow2 = addToHead ? chain[1] : chain[chain.length - 2];
        var oppo = addToHead ? chain[chain.length - 1] : chain[0];
        var oppo2 = addToHead ? chain[chain.length - 2] : chain[1];

        if (Epsilon().pointsCollinear(grow2, grow, pt)) {
          // grow isn't needed because it's directly between grow2 and pt:
          // grow2 ---grow---> pt
          if (addToHead) {
            // if (buildLog != null)
            //   buildLog.chainRemoveHead(first_match.index, pt);

            chain.removeAt(0);
          } else {
            // if (buildLog != null)
            //   buildLog.chainRemoveTail(first_match.index, pt);

            chain.removeAt(chain.length - 1);
          }
          grow = grow2; // old grow is gone... new grow is what grow2 was
        }

        if (Epsilon().pointsSame(oppo, pt)) {
          // we're closing the loop, so remove chain from chains
          chains.removeAt(index);

          if (Epsilon().pointsCollinear(oppo2, oppo, grow)) {
            // oppo isn't needed because it's directly between oppo2 and grow:
            // oppo2 ---oppo--->grow
            if (addToHead) {
              // if (buildLog != null)
              //   buildLog.chainRemoveTail(first_match.index, grow);

              chain.removeAt(chain.length - 1);
            } else {
              // if (buildLog != null)
              //   buildLog.chainRemoveHead(first_match.index, grow);

              chain.removeAt(0);
            }
          }

          // if (buildLog != null) buildLog.chainClose(first_match.index);

          // we have a closed chain!
          regions!.add(chain);
          continue;
        }

        // not closing a loop, so just add it to the apporpriate side
        if (addToHead) {
          //   if (buildLog != null) buildLog.chainAddHead(first_match.index, pt);

          chain.insert(0, pt);
        } else {
          // if (buildLog != null) buildLog.chainAddTail(first_match.index, pt);

          chain.add(pt);
        }

        continue;
      }

      // otherwise, we matched two chains, so we need to combine those chains together

      var F = first_match!.index;
      var S = second_match!.index;

      // if (buildLog != null) {
      //   buildLog.chainConnect(F, S);
      // }

      var reverseF = chains[F].length <
          chains[S].length; // reverse the shorter chain, if needed
      if (first_match!.matches_head) {
        if (second_match!.matches_head) {
          if (reverseF) {
            // <<<< F <<<< --- >>>> S >>>>
            reverseChain(F);
            // >>>> F >>>> --- >>>> S >>>>
            appendChain(F, S);
          } else {
            // <<<< F <<<< --- >>>> S >>>>
            reverseChain(S);
            // <<<< F <<<< --- <<<< S <<<<   logically same as:
            // >>>> S >>>> --- >>>> F >>>>
            appendChain(S, F);
          }
        } else {
          // <<<< F <<<< --- <<<< S <<<<   logically same as:
          // >>>> S >>>> --- >>>> F >>>>
          appendChain(S, F);
        }
      } else {
        if (second_match!.matches_head) {
          // >>>> F >>>> --- >>>> S >>>>
          appendChain(F, S);
        } else {
          if (reverseF) {
            // >>>> F >>>> --- <<<< S <<<<
            reverseChain(F);
            // <<<< F <<<< --- <<<< S <<<<   logically same as:
            // >>>> S >>>> --- >>>> F >>>>
            appendChain(S, F);
          } else {
            // >>>> F >>>> --- <<<< S <<<<
            reverseChain(S);
            // >>>> F >>>> --- >>>> S >>>>
            appendChain(F, S);
          }
        }
      }
    }

    return regions;
  }

  void reverseChain(int index) {
    //chains[index].reversed;
    //if (buildLog != null) buildLog.chainReverse(index);

    List<JTS.Coordinate> pointList = [];
    pointList.addAll(chains[index].reversed.toList());
    chains[index] = pointList; // gee, that's easy
  }

  bool setMatch(int index, bool matchesHead, bool matchesPt1) {
    // return true if we've matched twice
    next_match!.index = index;
    next_match!.matches_head = matchesHead;
    next_match!.matches_pt1 = matchesPt1;

    if (next_match == first_match) {
      next_match = second_match;
      return false;
    }

    next_match = null;

    return true; // we've matched twice, we're done here
  }

  void appendChain(int index1, int index2) {
    // index1 gets index2 appended to it, and index2 is removed
    var chain1 = chains[index1];
    var chain2 = chains[index2];
    var tail = chain1[chain1.length - 1];
    var tail2 = chain1[chain1.length - 2];
    var head = chain2[0];
    var head2 = chain2[1];

    if (Epsilon().pointsCollinear(tail2, tail, head)) {
      // tail isn't needed because it's directly between tail2 and head
      // tail2 ---tail---> head
      //if (buildLog != null) buildLog.chainRemoveTail(index1, tail);

      chain1.removeAt(chain1.length - 1);
      tail = tail2; // old tail is gone... new tail is what tail2 was
    }

    if (Epsilon().pointsCollinear(tail, head, head2)) {
      // head isn't needed because it's directly between tail and head2
      // tail ---head---> head2
      //  if (buildLog != null) buildLog.chainRemoveHead(index2, head);

      chain2.removeAt(0);
    }

    // if (buildLog != null) buildLog.chainJoin(index1, index2);

    chain1.addAll(chain2);
    chains.removeAt(index2);
  }
}

class Match {
  int index;
  bool matches_head;
  bool matches_pt1;

  Match({this.index = 0, this.matches_head = false, this.matches_pt1 = false});
}
