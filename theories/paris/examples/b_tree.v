From clutch.paris Require Import adequacy.
From clutch Require Import paris.
Set Default Proof Using "Type*".
Open Scope R.

Section b_tree.
  Context `{!parisGS Σ}.
  Context {min_child_num' : nat}.
  Context {depth : nat}.
  Local Definition min_child_num := S min_child_num'.
  (** For this example, intermediate nodes do not store keys themselves
      If the depth is 0, the node is a leaf, storing a single key value
      otherwise, if the depth is S n, it has stores a list of k children, each pointing to a tree of depth n
      where k varies from min_child_num to 2* min_child_num inclusive
      (We force min_child_num to be at least 1 for simplicity)
   *)

  (** Intermediate nodes of ranked b-trees store extra info, specifically for each branch it has as a child, 
      the number of leafs it has *)

  (** The naive algorithm for ranked b -tree is to sample from the sum of the total number of children, 
      and then traverse down to find that particular value *)

  (** The optimized algorithm for non-ranked b-tree is at each node, sample from 2*min_child_num 
      then walk down that branch. If the number exceeds the total number of children, repeat from the root
   *)

  (** The intuition is that we assume we are sampling from a "full" tree that has max children,
      but repeat if the child does not exist
   *)
  
End b_tree.

Section proofs.
  (** To prove that the optimzed algorithm refines the naive one
      we show that for each "run", the depth number of (2*min_child_num) state step samples can be coupled
      with a single (2*min_child_num)^depth state step sample
      and that can be sampled with a single (total number of children) state step via a fragmental coupling 
      and appeal to Löb induction.
      To be more precise, one needs to find an injective function, from the total number of children to the single (2*min_child_num)^depth set
      The function is the one that maps i, to the index of the i-th children if the tree is full

      The other direction is the same, except one would need to amplify errors and use a continuity argument to close the proof 
   *)

End proofs.

