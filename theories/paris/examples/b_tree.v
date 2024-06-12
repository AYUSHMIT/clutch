From Coq.Program Require Import Wf.
From stdpp Require Import list.
From clutch.paris Require Import paris list.
Set Default Proof Using "Type*".
Open Scope R.

Section aux_lemmas.
  Local Lemma pow_pos x y:
    (0<x)%nat -> (0<x^y)%nat.
  Proof.
    intros. 
    apply Nat.lt_le_trans with (x^0)%nat.
    - simpl; lia.
    - apply Nat.pow_le_mono_r; lia.
  Qed.

  Lemma filter_replicate_is_nil {X} (x:X) n P {_:forall x, Decision (P x)}:
    ¬ P x -> filter P (replicate n x) = [].
  Proof.
    intros. induction n; first by simpl.
    simpl. rewrite filter_cons.
    case_match; first done.
    done.
  Qed.
    
End aux_lemmas.

Section stage1.
  (** stage 1 is relating a naive exact rand, with a big rand, via a rejection sampler *)
  Fixpoint index_list {A} (l:list A):=
    match l with
    | [] => []
    | x::l' => (0%nat, x) :: ((prod_map S id) <$> index_list l')
    end.
  
  Local Lemma elem_of_index_list {A} (l:list A) x b:
    l!!x = Some b ->
    (x, b) ∈ index_list l.
  Proof.
    revert x b; induction l.
    - simpl. set_solver.
    - intros x b Hl.
      rewrite lookup_cons_Some in Hl. destruct Hl as [[-> ->]|[H Hl]].
      + simpl. set_solver.
      + simpl. apply elem_of_list_further.
        rewrite elem_of_list_fmap.
        exists ((x-1)%nat, b). simpl; split.
        * f_equal. lia.
        * apply IHl. done.
  Qed.

  Local Lemma filter_list_length {A} l:
    length (filter (λ x:nat*option A, is_Some x.2) l) =
    length (filter (λ x, is_Some x.2) ((prod_map S id) <$> l)).
  Proof.
    induction l; simpl; first done.
    rewrite !filter_cons; simpl.
    do 2 case_match; try done; simpl; rewrite IHl; done.
  Qed.

  Local Lemma filter_list_length' {A} l:
    length (filter (λ x, is_Some x ) l) =
    length (filter (λ x : nat * option A, is_Some x.2 ) (index_list l)).
  Proof.
    induction l; first (by simpl).
    rewrite !filter_cons; do 2 case_match; try done; simpl;
      rewrite IHl filter_list_length; done.
  Qed.
  
  Local Lemma filter_index_list_relate_aux {A} (l:list (nat*option A)):
    filter (λ x0 : nat * option A, is_Some x0.2) (prod_map S id <$> l) =
    prod_map S id <$> (filter (λ x0 : nat * option A, is_Some x0.2) (l)).
  Proof.
    remember (length l) as n.
    revert l Heqn.
    induction n.
    - intros. rewrite (nil_length_inv l); last done.
      simpl. rewrite filter_nil. done.
    - intros. destruct l.
      + simpl in Heqn. lia.
      + destruct p as [? []].
        * simpl. rewrite filter_cons_True; last done.
          f_equal. simpl in Heqn. rewrite (IHn); last lia. done.
        * simpl. rewrite !filter_cons_False; [|done|done].
          f_equal. simpl in Heqn. rewrite IHn; [done|lia].
  Qed.
  
  Local Lemma filter_index_list_relate {A} x l:
    (x<length (filter (λ x0 : option A, is_Some x0) l))%nat -> 
    l !! (filter (λ x0 : nat * option A, is_Some x0.2) (index_list l) !!! x).1 =
    filter (λ x0 : option A, is_Some x0) l !! x.
  Proof.
    revert x.
    induction l.
    - simpl. lia.
    - simpl. destruct a; simpl.
      + intros x Hx. rewrite !filter_cons_True; [|done|done].
        destruct x; simpl; first done.
        rewrite -IHl; last lia.
        replace (l!!_) with ((Some a::l)!!S((filter (λ x0 : nat * option A, is_Some x0.2) (index_list l) !!! x).1)) by done.
        f_equal.
        rewrite filter_index_list_relate_aux.
        rewrite list_lookup_total_fmap; last first.
        { rewrite -filter_list_length'. lia. }
        done.
      + intros x. rewrite !filter_cons_False; [|done|done]. intros Hx.
        rewrite -IHl; last lia.
        rewrite filter_index_list_relate_aux.
        rewrite list_lookup_total_fmap; last first.
        { rewrite -filter_list_length'. lia. }
        done.
  Qed.
  

  Local Lemma index_list_range {A} (x:nat * A) l:
    x ∈ index_list l -> (x.1 < length l)%nat.
  Proof.
    revert x.
    induction l.
    - simpl. simpl. set_solver.
    - simpl. intros x H.
      rewrite elem_of_cons in H.
      destruct H as [->|H]; simpl; first lia.
      rewrite elem_of_list_fmap in H.
      destruct H as [y [-> Hy]]. simpl.
      pose proof IHl _ Hy. lia.
  Qed.

  Local Lemma index_list_lookup_lemma {A}(x:_*option A) l:
    is_Some (x.2) -> x∈index_list l -> ∃ v, (l!!x.1) = Some (Some v).
  Proof.
    revert x.
    induction l; simpl; first set_solver.
    intros x. rewrite elem_of_cons.
    intros [] [->|H0]; simpl in *; first naive_solver.
    rewrite elem_of_list_fmap in H0.
    destruct H0 as [y [-> H0]].
    simpl in H.
    by apply IHl.
  Qed.

  Local Lemma filter_prod_map_lemma {A} x (l:list (nat * option A)):
    (x < length (filter (λ x, is_Some (x.2)) l))%nat ->
    (filter (λ x, is_Some (x.2)) (prod_map S id <$> l) !!! x).1 =
    S ((filter (λ x, is_Some (x.2))  l) !!! x).1.
  Proof.
    revert x.
    induction l; first (simpl; lia).
    intros x. rewrite !filter_cons.
    case_match; case_match; try done; simpl; last first.
    - intros. apply IHl. done.
    - intros. destruct x; simpl; first done.
      apply IHl; lia.
  Qed.

  Local Lemma index_list_inj {A} x y l:
    (x < length (filter (λ x : nat * option A, is_Some (x.2)) (index_list l)))%nat ->
    (y < length (filter (λ x, is_Some (x.2)) (index_list l)))%nat ->
    (filter (λ x, is_Some (x.2)) (index_list l) !!! x).1 =
    (filter (λ x, is_Some (x.2)) (index_list l) !!! y).1 ->
    x = y.
  Proof.
    revert x y; induction l; simpl; first lia.
    rewrite !filter_cons; simpl.
    case_match; simpl; intros x y Hx Hy H'; last first.
    - rewrite -filter_list_length in Hx, Hy.
      apply IHl; try done.
      rewrite !filter_prod_map_lemma in H'; lia.
    - destruct x, y; simpl in H'; try done.
      + exfalso.
        cut (0%nat<(filter (λ x, is_Some (x.2)) (prod_map S id <$> index_list l) !!! y).1)%nat.
        * rewrite -H'. lia.
        * clear H'. apply Forall_lookup_total_1; last lia.
          rewrite Forall_forall.
          intros x H0. rewrite elem_of_list_filter in H0.
          destruct H0 as [? H0].
          rewrite elem_of_list_fmap in H0.
          destruct H0 as [?[->?]]. simpl. lia.
      + exfalso.
        cut (0%nat<(filter (λ x, is_Some (x.2)) (prod_map S id <$> index_list l) !!! x).1)%nat.
        * rewrite H'. lia.
        * clear H'. apply Forall_lookup_total_1; last lia.
          rewrite Forall_forall.
          intros y H0. rewrite elem_of_list_filter in H0.
          destruct H0 as [? H0].
          rewrite elem_of_list_fmap in H0.
          destruct H0 as [?[->?]]. simpl. lia.
      + f_equal. apply IHl.
        * rewrite filter_list_length. lia.
        * rewrite filter_list_length. lia.
        * rewrite !filter_prod_map_lemma in H'; first lia.
          -- rewrite filter_list_length. lia.
          -- rewrite filter_list_length. lia.
  Qed.
  
  Lemma inj_function_exists {A} l M N:
    length l = M ->
    length (filter (λ x:option A, is_Some x) l) = N ->
    exists f: (fin N -> fin M), Inj eq eq f /\
                          (forall x, (∃ v, (l !! fin_to_nat (f x)) = Some (Some v))
                                /\
                                  l!!fin_to_nat (f x) = filter (λ x, is_Some x) l !! fin_to_nat x
                          ) /\
                          (forall x, (forall y, x≠f y) -> l!!fin_to_nat (x) = Some None).
  Proof.
    intros Hlen1 Hlen2.
    pose (l' := filter (λ x, is_Some (x.2)) (index_list l)).
    assert (forall x:fin N, x<length l')%nat.
    { intros x.
      pose proof fin_to_nat_lt x.
      replace (length l') with N; first done.
      rewrite -Hlen2.
      rewrite /l'.
      clear.
      induction l; simpl; first done.
      rewrite !filter_cons; simpl; case_match; simpl; by rewrite IHl -filter_list_length.
    }
    assert (forall (x:fin N), (l'!!!(fin_to_nat x)).1 < M)%nat as K; last first.
    - exists (λ x, nat_to_fin (K x)).
      split; last split.
      + (* prove injection *)
        intros x y Hf. apply (f_equal fin_to_nat) in Hf.
        rewrite !fin_to_nat_to_fin in Hf.
        rewrite /l' in Hf, H.
        apply fin_to_nat_inj.
        by eapply index_list_inj.
      + (* prove domain is true *)
        intros x. rewrite fin_to_nat_to_fin.
        split.
        * apply Forall_lookup_total_1; last auto.
          rewrite Forall_forall.
          rewrite /l'.
          intros x'. rewrite elem_of_list_filter.
          intros [??]. by apply index_list_lookup_lemma.
        * rewrite /l'.
          apply filter_index_list_relate.
          rewrite /l' in H. specialize (H x).
          rewrite filter_list_length'. done.
      + (* prove if not in domain, it must be false *)
        intros x Hx.
        destruct (l!!fin_to_nat x) eqn :Heqn1; last first.
        { apply lookup_ge_None_1 in Heqn1.
          pose proof fin_to_nat_lt x. rewrite Hlen1 in Heqn1. lia.
        }
        destruct o as [|a]; last done.
        exfalso.
        cut ((fin_to_nat x, Some a) ∈ l').
        * rewrite /l'. rewrite elem_of_list_lookup.
          intros [i Hi].
          cut (i<N)%nat.
          -- intros Hproof.
             cut (x=nat_to_fin (K (nat_to_fin Hproof))); first naive_solver.
             apply fin_to_nat_inj. rewrite fin_to_nat_to_fin.
             rewrite /l'.
             rewrite fin_to_nat_to_fin.
             apply list_lookup_total_correct in Hi.
             by rewrite Hi.
          -- apply lookup_lt_Some in Hi.
             rewrite -Hlen2. rewrite -filter_list_length' in Hi. lia.
        * rewrite /l'. rewrite elem_of_list_filter; simpl; split; first done.
          apply elem_of_index_list. done.
    - (* prove first projection is indeed smaller than length l, i.e. M *)
      intros x.
      apply Forall_lookup_total_1; last auto.
      rewrite Forall_forall.
      rewrite /l'.
      intros x' Hx'.
      rewrite elem_of_list_filter in Hx'.
      destruct Hx' as [? Hx'].
      rewrite -Hlen1; by apply index_list_range.
  Qed.
  
End stage1.


Section stage2.
  (** Stage 2 is relating the big state step with many small steps, via Rcoupl_state_state_exp *)
  Context {N:nat}.

  Fixpoint decoder_aux (l:list (fin (S N))) :=
    match l with
    | [] => 0%nat
    | x::l' => (fin_to_nat x + (S N) * decoder_aux l')%nat
    end.

  
  Local Lemma decoder_aux_ineq l:
    (decoder_aux l < (S N)^ (length l))%nat.
  Proof.
    induction l; first (simpl; lia).
    pose proof fin_to_nat_lt a. rewrite /decoder_aux.
    rewrite cons_length.
    rewrite -/decoder_aux.
    apply Nat.lt_le_trans with (S N + S N * decoder_aux l)%nat; first lia.
    assert (1<=S N ^ length l)%nat.
    { pose proof pow_pos (S N) (length l). lia. }
    assert ((decoder_aux l) <= S N ^ length l - 1)%nat as H' by lia.
    trans (S N + S N * (S N ^ length l - 1))%nat.
    - apply Nat.add_le_mono_l. 
      apply Nat.mul_le_mono_pos_l; lia.
    - rewrite Nat.pow_succ_r'. 
      cut (S N * (1+ S N ^ length l - 1) <= S N * S N ^ length l)%nat; last lia.
      intros; etrans; last exact.
      rewrite Nat.add_sub'.
      rewrite Nat.mul_sub_distr_l.
      rewrite Nat.mul_1_r.
      rewrite -Nat.le_add_sub; first lia.
      rewrite <-Nat.mul_1_r at 1.
      apply Nat.mul_le_mono_l. lia.
  Qed.

  Local Lemma decoder_aux_inj l1 l2:
    length l1 = length l2 -> decoder_aux l1 = decoder_aux l2 -> l1 = l2.
  Proof.
    clear.
    revert l2; induction l1.
    - simpl. intros. symmetry. apply nil_length_inv. done.
    - intros l2 Hlen2 H. destruct l2; first (simpl in *; lia).
      cut (fin_to_nat a=fin_to_nat t/\decoder_aux l1=decoder_aux l2).
      { intros [?%fin_to_nat_inj ?].
        f_equal; subst; last apply IHl1; try done.
        simplify_eq. done.
      } eapply Nat.mul_split_r.
      + apply fin_to_nat_lt.
      + apply fin_to_nat_lt.
      + simpl in H. lia.
  Qed.
  
  Context {M p: nat}.
  Context {Heq : (S N ^ p = S M)%nat}.
  Definition decoder l :=
    match lt_dec (decoder_aux (rev l)) (S M) with
    | left Hproof => nat_to_fin Hproof
    | _ => 0%fin
    end.
  
  Local Lemma decoder_inj l1 l2:
    length l1 = p -> length l2 = p -> decoder l1 = decoder l2 -> l1 = l2.
  Proof.
    intros Hlen1 Hlen2. rewrite /decoder.
    case_match eqn:Heq1; case_match eqn:Heq2; last first.
    - pose proof decoder_aux_ineq (rev l1) as H. rewrite rev_length Hlen1 Heq in H. lia.
    - pose proof decoder_aux_ineq (rev l1) as H. rewrite rev_length Hlen1 Heq in H. lia.
    - pose proof decoder_aux_ineq (rev l2) as H. rewrite rev_length Hlen2 Heq in H. lia.
    - intros H. apply (f_equal fin_to_nat) in H. rewrite !fin_to_nat_to_fin in H.
      apply rev_inj.
      apply decoder_aux_inj; last done.
      rewrite !rev_length. trans p; done.
  Qed.
  
End stage2.

Section b_tree.
  Context `{!parisGS Σ}.
  Context {min_child_num' : nat}.
  Context {depth : nat}.
  Local Definition min_child_num := S min_child_num'.
  Local Definition max_child_num := (2*min_child_num)%nat.

  
  Local Lemma min_child_num_pos: (0<min_child_num)%nat.
  Proof. rewrite /min_child_num. lia. Qed.
  Local Lemma max_child_num_pos: (0<max_child_num)%nat.
  Proof. rewrite /max_child_num /min_child_num. lia. Qed.
  Local Lemma pow_max_child_num (n:nat): (0<max_child_num^n)%nat.
  Proof.
    apply pow_pos. apply max_child_num_pos.
  Qed.
  Opaque max_child_num min_child_num.

  (** For this example, intermediate nodes do not store keys themselves
      If the depth is 0, the node is a leaf, storing a single key value
      otherwise, if the depth is S n, it has stores a list of k children, each pointing to a tree of depth n
      where k varies from min_child_num to 2* min_child_num inclusive
      (We force min_child_num to be at least 1 for simplicity)
   *)

  Local Unset Elimination Schemes.
  Inductive ab_tree :=
  | Lf (v: val)
  | Br (l:list ab_tree).

  Lemma ab_tree_ind P:
    (∀ v : val, P (Lf v)) →
    (∀ l : list ab_tree,
       Forall (λ x, P x) l -> P (Br l)) →
    ∀ a : ab_tree, P a.
  Proof.
    clear.
    move => ?? t.
    generalize dependent P => P.
    generalize dependent t.
    fix FIX 1.
    move => [] ?? Hcall; first naive_solver.
    apply Hcall.
    apply Forall_true => ?. by apply FIX.
  Qed.
  
  Instance ab_tree_dec: EqDecision ab_tree.
  Proof. solve_decision. Qed.
  
  Inductive is_ab_b_tree : nat -> list (option val) -> ab_tree -> Prop :=
  | is_ab_b_tree_lf v: is_ab_b_tree 0%nat [Some v] (Lf v)
  | is_ab_b_tree_br n (l:list (list(option val) * ab_tree)) :
    Forall (λ x, is_ab_b_tree n x.1 x.2) l ->
    (min_child_num <= length l <= max_child_num)%nat ->
    is_ab_b_tree (S n)
      (flat_map id (fst <$> l) ++ replicate ((max_child_num-length l)*max_child_num ^ n)%nat None)
      (Br (snd <$> l)).

  Lemma is_ab_b_tree_ind P:
    (∀ v : val, P 0%nat [Some v] (Lf v))
    → (∀ (n : nat) (l : list (list (option val) * ab_tree)),
         Forall (λ x : list (option val) * ab_tree, is_ab_b_tree n x.1 x.2) l ->
         Forall (λ x, P n x.1 x.2) l
         → (min_child_num <= length l <= max_child_num)%nat
           → P (S n)
               (flat_map id l.*1 ++ replicate ((max_child_num - length l) * max_child_num ^ n) None)
               (Br l.*2))
      → ∀ (n : nat) (l : list (option val)) (a : ab_tree), is_ab_b_tree n l a → P n l a.
  Proof.
    move => ?? n l t ?.
    generalize dependent P => P.
    generalize dependent n.
    generalize dependent l.
    generalize dependent t.
    fix FIX 4. move => t l n [ ]; first naive_solver.
    move => ????? Hcall.
    apply Hcall; [done| |done].
    eapply Forall_impl; first done.
    intros. by apply FIX.
  Qed.

  
  Local Set Elimination Schemes.
  
  Lemma ab_b_tree_list_length n l t:
    is_ab_b_tree n l t-> length l = (max_child_num ^ n)%nat.
  Proof.
    clear. intros H. induction H.
    - by simpl.
    - rewrite app_length.
      erewrite flat_map_constant_length; last first.
      { apply List.Forall_forall. rewrite Forall_fmap. eapply Forall_impl; first done.
        simpl. done.
      }
      rewrite replicate_length.
      rewrite Nat.pow_succ_r'.
      rewrite -Nat.mul_add_distr_r.
      rewrite fmap_length.
      rewrite -Nat.le_add_sub; lia.
  Qed.

  Definition succ (x y : ab_tree) : Prop :=
    match y with
    | Lf v => False
    | Br l => x ∈ l
    end.

  Instance succ_dec x y: Decision (succ x y).
  Proof.
    rewrite /succ.
    destruct y.
    - right. naive_solver.
    - apply _.
  Qed.
  Lemma succ_wf : well_founded succ.
  Proof.
    intros t. induction t; apply Acc_intro.
    - rewrite /succ. done. 
    - intros t ? => /=. by eapply Forall_forall.
  Qed.

  Program Fixpoint relate_ab_tree_with_v (t:ab_tree) (v:val) {wf succ t} : iProp Σ :=
    match t with
    | Lf v' => ⌜v = InjLV v'⌝
    | Br tlis => ∃ v' loc_lis v_lis,
      ⌜v = InjRV v'⌝ ∗
      ⌜length tlis = length loc_lis⌝ ∗
      ⌜length tlis = length v_lis⌝ ∗
      ⌜is_list loc_lis v'⌝ ∗
      ([∗ list] x ∈ combine loc_lis v_lis, x.1 ↦ x.2) ∗
      ([∗ list] x ∈ combine tlis v_lis,
        match decide (succ x.1 t)
        with
        |left Hproof => relate_ab_tree_with_v x.1 x.2
        | _ => True
        end)
    end.
  Solve Obligations with auto using succ_wf.

  Lemma relate_ab_tree_with_v_Lf v v' :
    relate_ab_tree_with_v (Lf v') v ≡ ⌜v = InjLV v'⌝%I.
  Proof.
    rewrite /relate_ab_tree_with_v /relate_ab_tree_with_v_func.
    rewrite WfExtensionality.fix_sub_eq_ext //.  
  Qed.

  Lemma relate_ab_tree_with_v_Br v tlis :
    relate_ab_tree_with_v (Br tlis) v ≡
      (∃ v' loc_lis v_lis,
      ⌜v = InjRV v'⌝ ∗
      ⌜length tlis = length loc_lis⌝ ∗
      ⌜length tlis = length v_lis⌝ ∗
      ⌜is_list loc_lis v'⌝ ∗
      ([∗ list] x ∈ combine loc_lis v_lis, x.1 ↦ x.2) ∗
      ([∗ list] x ∈ combine tlis v_lis,
         relate_ab_tree_with_v x.1 x.2))%I.
  Proof.
    rewrite {1}/relate_ab_tree_with_v /relate_ab_tree_with_v_func.
    rewrite WfExtensionality.fix_sub_eq_ext /=.
    do 11 f_equiv.
    iSplit.
    - iIntros "H". iApply (big_sepL_impl with "[$]").
      iModIntro. iIntros. case_match; first done.
      exfalso.
      assert (x.1 ∈tlis); last done.
      rewrite elem_of_list_In.
      eapply in_combine_l.
      rewrite -elem_of_list_In.
      eapply elem_of_list_lookup_2. erewrite H.
      f_equal. apply surjective_pairing.
    - iIntros "H". iApply (big_sepL_impl with "[$]").
      iModIntro. iIntros. case_match; done.
  Qed.

  Fixpoint children_num t:=
    match t with
    | Lf _ => 1%nat
    | Br l => fold_right (λ x y, children_num x + y)%nat 0%nat l
    end.

  Lemma ab_tree_children_num t n l:
    is_ab_b_tree n l t -> children_num t = length (filter (λ x, is_Some x) l).
  Proof.
    intros H. induction H; first done.
    rewrite filter_app app_length.
    replace (length (filter _(replicate _ _))) with 0%nat; last first.
    { symmetry. rewrite length_zero_iff_nil.
      eapply filter_replicate_is_nil. done.
    }
    clear H1.
    revert H H0.
    induction l.
    - simpl. done.
    - rewrite !Forall_cons.
      intros [] [].
      simpl. rewrite filter_app app_length.
      rewrite H1.
      rewrite Nat.add_0_r.
      f_equal.
      specialize (IHl H0 H2).
      rewrite Nat.add_0_r in IHl. rewrite -IHl. done.
  Qed.

  Lemma children_num_pos n l t:
    is_ab_b_tree n l t -> (0<children_num t)%nat.
  Proof.
    revert n l.
    induction t.
    - intros. simpl. lia.
    - intros n l' Hl'. simpl.
      inversion Hl'; subst.
      clear Hl'.
      revert H H1 H4.
      induction l0.
      + simpl. pose proof min_child_num_pos; lia.
      + simpl. intros. apply Nat.add_pos_l.
        rewrite !Forall_cons in H H1.
        destruct H, H1.
        naive_solver.
  Qed.

      (** Intermediate nodes of ranked b-trees store extra info, specifically for each branch it has as a child, 
      the number of leafs it has *)

  Program Fixpoint relate_ab_tree_with_ranked_v (t:ab_tree) (v:val) {wf succ t} : iProp Σ :=
    match t with
    | Lf v' => ⌜v = (#1%nat, InjLV v')%V⌝
    | Br tlis =>
        ∃ (total:nat) v' loc_lis v_lis num_lis,
      ⌜ v = (#total, InjRV (v'))%V⌝ ∗
      ⌜length tlis = length loc_lis⌝ ∗
      ⌜length tlis = length v_lis⌝ ∗
      ⌜length tlis = length num_lis⌝ ∗
      ⌜(total = list_sum num_lis)%nat⌝ ∗
      ⌜is_list (combine num_lis loc_lis) v'⌝ ∗
      ([∗ list] x ∈ combine loc_lis v_lis, x.1 ↦ x.2) ∗
      ([∗ list] x ∈ combine tlis num_lis, ⌜children_num x.1 = x.2⌝) ∗
      ([∗ list] x ∈ combine tlis v_lis,
        match decide (succ x.1 t)
        with
        |left Hproof => relate_ab_tree_with_ranked_v x.1 x.2
        | _ => True
        end)
    end.
  Solve Obligations with auto using succ_wf.

  Lemma relate_ab_tree_with_ranked_v_Lf v v' :
    relate_ab_tree_with_ranked_v (Lf v') v ≡ ⌜v = (#1%nat, InjLV v')%V⌝%I.
  Proof.
    rewrite /relate_ab_tree_with_ranked_v /relate_ab_tree_with_ranked_v_func.
    rewrite WfExtensionality.fix_sub_eq_ext //.  
  Qed.

  Lemma relate_ab_tree_with_ranked_v_Br v tlis :
    relate_ab_tree_with_ranked_v (Br tlis) v ≡
      (∃ (total:nat) v' loc_lis v_lis num_lis,
      ⌜ v = (#total, InjRV (v'))%V ⌝ ∗
      ⌜length tlis = length loc_lis⌝ ∗
      ⌜length tlis = length v_lis⌝ ∗
      ⌜length tlis = length num_lis⌝ ∗
      ⌜(total = list_sum num_lis)%nat⌝ ∗
      ⌜is_list (combine num_lis loc_lis) v'⌝ ∗
      ([∗ list] x ∈ combine loc_lis v_lis, x.1 ↦ x.2) ∗
      ([∗ list] x ∈ combine tlis num_lis, ⌜children_num x.1 = x.2⌝) ∗
      ([∗ list] x ∈ combine tlis v_lis, relate_ab_tree_with_ranked_v x.1 x.2))%I.
  Proof.
    rewrite {1}/relate_ab_tree_with_ranked_v /relate_ab_tree_with_ranked_v_func.
    rewrite WfExtensionality.fix_sub_eq_ext /=.
    do 18 f_equiv.
    iSplit.
    - iIntros "H". iApply (big_sepL_impl with "[$]").
      iModIntro. iIntros. case_match; first done.
      exfalso.
      assert (x.1 ∈tlis); last done.
      rewrite elem_of_list_In.
      eapply in_combine_l.
      rewrite -elem_of_list_In.
      eapply elem_of_list_lookup_2. erewrite H.
      f_equal. apply surjective_pairing.
    - iIntros "H". iApply (big_sepL_impl with "[$]").
      iModIntro. iIntros. case_match; done.
  Qed.

  
  Local Lemma list_sum_foldr l l':
    length l = length l' ->
    (forall k x, combine l l' !!k = Some x -> children_num x.1 = x.2) ->
    list_sum l' = foldr  (λ (x : ab_tree) (y : nat), (children_num x + y)%nat) 0%nat l.
  Proof.
    revert l'. induction l.
    - intros []; by simpl.
    - intros []; first by simpl.
      simpl. intros. rewrite IHl; [|lia|]; last first.
      + intros. apply H0 with (S k). by simpl.
      + epose proof (H0 0%nat (_, _) _). simpl in *.
        rewrite H1. done.
        Unshelve.
        all: cycle 1.
        * simpl. done.
  Qed.
  
  Lemma relate_ab_tree_with_ranked_v_child_num n l tree v:
    is_ab_b_tree n l tree ->
    relate_ab_tree_with_ranked_v tree v -∗
    ⌜∃ v', v = (#(children_num tree), v')%V⌝.
  Proof.
    clear. revert n l v.
    induction tree.
    - intros ??? H. inversion H. subst.
      rewrite relate_ab_tree_with_ranked_v_Lf. iPureIntro. intros.
      subst. simpl. naive_solver.
    - revert H. induction l.
      + simpl. intros ???? H. inversion H. subst.
        rewrite relate_ab_tree_with_ranked_v_Br.
        iIntros "(%&%&%&%&%&%&%&%&%&%&%&H1&%&H2)". subst. iPureIntro.
        rewrite (nil_length_inv num_lis); first naive_solver.
        rewrite -H7. rewrite H1. done.
      + rewrite Forall_cons; intros [].
        intros ??? K. inversion K. subst.
        rewrite relate_ab_tree_with_ranked_v_Br.
        iIntros "(%&%&%&%&%&%&%&%&%&%&%&H1&%&H2)". subst.
        rewrite H1 in H4 H6 H7. rewrite H1. simpl in *.
        destruct loc_lis, v_lis, num_lis; try done. simpl.
        iAssert (⌜n=children_num a⌝)%I as "->".
        * rewrite H1 in H10. epose proof (H10 0%nat (_,_) _). done.
        * iAssert (⌜list_sum num_lis =
                   foldr (λ (x : ab_tree) (y : nat), children_num x + y)%nat 0%nat l⌝)%I as "->"; last (iPureIntro; naive_solver).
           iPureIntro. rewrite H1 in H10.
           apply list_sum_foldr.
          -- simpl in *. lia.
          -- intros. apply H10 with (S k). simpl. done.
             Unshelve.
             simpl. done.
  Qed.


  Lemma relate_ab_tree_with_ranked_v_same_num tree v1 v2 v3 v4:
    relate_ab_tree_with_ranked_v tree (v1, v2) -∗
    relate_ab_tree_with_ranked_v tree (v3, v4) -∗
    ⌜v1=v3⌝.
  Proof.
    revert v1 v2 v3 v4. induction tree.
    - intros. rewrite !relate_ab_tree_with_ranked_v_Lf. iIntros (??).
      simplify_eq. done.
    - intros. erewrite !relate_ab_tree_with_ranked_v_Br.
      revert v1 v2 v3 v4 H.
      induction l. 
      + simpl. iIntros (?????) "(%&%&%&%&%&%&%&%&%&%&%&H1&%&H2) (%&%&%&%&%&%&%&%&%&%&%&H3&%&H4)".
        simplify_eq.
        erewrite (nil_length_inv num_lis), (nil_length_inv num_lis0); first done.
        all: lia.
      + iIntros (v1 v2 v3 v4). rewrite Forall_cons. intros [].
        iIntros "(%&%&%&%&%&%&%&%&%&%&%&H1&%&H2) (%&%&%&%&%&%&%&%&%&%&%&H3&%&H4)".
        simplify_eq. 
        destruct num_lis; first done. destruct num_lis0; first done.
        destruct loc_lis; first done. destruct v_lis; first done.
        destruct loc_lis0; first done. destruct v_lis0; first done.
        simpl.
        iDestruct "H1" as "[H1 H1']". iDestruct "H2" as "[H2 H2']".
        iDestruct "H3" as "[H3 H3']". iDestruct "H4" as "[H4 H4']".
        simpl.
        destruct H13 as (?&?&?); destruct H6 as (?&?&?); subst.
        iAssert (⌜#(list_sum num_lis) = #(list_sum num_lis0)⌝)%I as "%".
        * iApply (IHl with "[H1' H2'][H3' H4']"); first done.
          -- iFrame.
             iExists (list_sum num_lis), _, _. iPureIntro. simpl in *. repeat split; try lia; try done.
             intros; eapply H7 with (S k). rewrite -H1. done.
          -- iFrame.
             iExists _, _, _. iPureIntro. simpl in *. repeat split; try lia; try done.
             intros. eapply H14 with (S k). rewrite -H1. done.
        * iAssert (⌜n=n0⌝)%I as "->".
          -- simpl in *.
             epose proof (H7 0%nat (a, n) _) as K. simpl in K. rewrite <-K.
             epose proof (H14 0%nat (a, n0) _) as K'. simpl in K'. by rewrite <-K'.
          -- iPureIntro. f_equal. simplify_eq. rewrite H1. done.
             Unshelve.
             all: by simpl.
  Qed.

  (** power *)
  Definition pow : val :=
    rec: "pow" "x" "y":=
      if: "y"=#0%nat then #(1%nat) else "x" * ("pow" "x" ("y"-#1)).

  Lemma wp_pow (n m:nat):
    {{{ True }}}
      pow #n #m
      {{{(x:nat), RET (#x); ⌜x = (n^m)%nat⌝ }}}.
  Proof.
    iIntros (Φ) "_ HΦ".
    iLöb as "IH" forall (Φ n m).
    rewrite /pow.
    wp_pures. rewrite -/pow.
    case_bool_decide; wp_pures.
    - iModIntro. iApply "HΦ".
      simplify_eq. done.
    - replace (Z.of_nat m - 1)%Z with (Z.of_nat (m-1)); last first.
      + rewrite Nat2Z.inj_sub; first lia.
        destruct m; last lia. done.
      + wp_apply ("IH"). 
        iIntros (x) "%".
        wp_pures.
        iModIntro.
        replace (_*_)%Z with (Z.of_nat (n*x)); last first.
        * rewrite Nat2Z.inj_mul. f_equal.
        * iApply "HΦ". iPureIntro. subst.
          rewrite -PeanoNat.Nat.pow_succ_r'. f_equal. 
          destruct m; try done. lia.
  Qed.

  Lemma spec_pow (n m:nat) K E:
    ⤇ fill K (pow #n #m) -∗ spec_update E (∃ (x:nat), ⤇ fill K #x ∗ ⌜x=(n^m)%nat⌝).
  Proof.
    iInduction m as [|] "IH" forall (K).
    - iIntros. rewrite /pow. tp_pures.
      { naive_solver. }
      iApply spec_update_ret. iFrame.
      done.
    - iIntros. rewrite /pow.
      tp_pure. rewrite -/pow.
      tp_pures; [naive_solver|..].
      replace (_(S m) - _)%Z with (Z.of_nat m); last lia.
      tp_bind (pow _ _)%E.
      iMod ("IH" with "[$]") as "[% [K ->]]".
      simpl. tp_pures.
      iApply spec_update_ret.
      replace (_ * _)%Z with (Z.of_nat (n^(m+1))%nat).
      + iFrame. iPureIntro. rewrite Nat.pow_add_r. simpl. lia.
      + rewrite Nat.pow_add_r. simpl. lia.
  Qed.
  
  (** The naive algorithm for ranked b -tree is to sample from the sum of the total number of children, 
      and then traverse down to find that particular value *)

  Definition naive_sampler_list_search_prog :val :=
    rec: "f" "l" "num" :=
      match: list_head "l" with
      | SOME "p" =>
          let, ("child_num", "t") := "p" in
          let: "l'" := list_tail "l" in
          if: "num" < "child_num"
          then (#0, #0)
          else
            let, ("prefix_sum", "idx") := "f" "l'" ("num" - "child_num") in
            ("child_num"+"prefix_sum", "idx"+#1)
      | NONE => #() (* not possible *)
      end
  .
  
  Definition naive_sampler_rec_prog: val:=
    rec: "f" "t" "num" :=
      match: Snd "t" with
      | InjL "v" => "v"
      | InjR "l" =>
          let, ("prefix_sum","idx")  := naive_sampler_list_search_prog "l" "num" in
          match: list_nth "l" "idx" with
          | SOME "p" =>
              "f" "p" ("num"-"prefix_sum")
          | NONE => #() (* not possible *)
          end
      end
  .

  Definition naive_sampler_prog: val :=
    λ: "t" "_",
      let: "samp" := rand (Fst "t"-#1) in
      naive_sampler_rec_prog "t" "samp".

  Definition naive_sampler_annotated_prog : val :=
    λ: "t" "_",
      let: "α" := alloc (Fst "t"-#1) in
      let: "samp" := rand("α") (Fst "t"-#1) in
      naive_sampler_rec_prog "t" "samp".

  (** The intermediate algorithm for non-ranked b_tree is that at the beginning
      we sample from max_child_num^depth, and walk down the branches as if the tree is full.
      If we cannot find the particular node, we repeat from the start
   *)

  (* Definition intermediate_sampler_list_search_prog :val:= *)
  (*   rec: "f" "l" "num" "depth":= *)
  (*     match: list_head "l" with *)
  (*     | SOME "p" => *)
  (*         let, ("child_num", "t") := "p" in *)
  (*         let: "l'" := list_tail "l" in *)
  (*         if: "num" < pow #max_child_num "depth" *)
  (*         then #0 *)
  (*         else *)
  (*           let: "idx" := "f" "l'" ("num" - (pow #max_child_num "depth")) "depth "in *)
  (*           "idx"+#1 *)
  (*     | NONE => #() (* not possible *) *)
  (*     end. *)

  Definition intermediate_sampler_rec_prog: val:=
    rec: "f" "t" "num" "d":=
      match: "t" with
      | InjL "v" => SOME "v"
      | InjR "l" =>
          let: "idx":= "num" `quot` (pow #max_child_num "depth") in
          match: list_nth "l" "idx" with
          | SOME "p" =>
              "f" "p" ("num"-"idx"*(pow #max_child_num "depth")) ("d"-#1)
          | NONE => NONE
          end
      end
  .

  Definition intermediate_sampler_annotated_prog : val :=
    λ: "t",
      let: "α" := alloc #(max_child_num^depth-1)%nat in
      rec: "f" "_":=
      let: "samp" := rand("α") #(max_child_num^depth-1)%nat in
      match: intermediate_sampler_rec_prog "t" "samp" #depth with
      | SOME "v" => "v"
      | NONE => "f" #()
      end.

  (** The optimized algorithm for non-ranked b-tree is at each node, sample from 2*min_child_num 
      then walk down that branch. If the number exceeds the total number of children, repeat from the root
   *)

  (** The intuition is that we assume we are sampling from a "full" tree that has max children,
      but repeat if the child does not exist
   *)

  Definition optimized_sampler_rec_annotated_prog: val:=
    λ: "α", 
    rec: "f" "t":=
      match: "t" with
      | InjL "v" => SOME "v"
      | InjR "l" =>
          let: "num" := rand("α") #(max_child_num-1) in
          let: "item" := list_nth "l" "num" in
          match: "item" with
          | SOME "t'" => "f" "t'"
          | NONE => NONE
          end
      end
  .

  Definition optimized_sampler_annotated_prog : val :=
    λ: "t",
    rec: "f" "_":=
      let: "α" := alloc #(max_child_num-1)%nat in
      match: optimized_sampler_rec_annotated_prog "α" "t" with
      | SOME "v" => "v"
      | NONE => "f" #()
      end.

  Definition optimized_sampler_rec_prog: val:=
    rec: "f" "t":=
      match: "t" with
      | InjL "v" => SOME "v"
      | InjR "l" =>
          let: "num" := rand #(max_child_num-1)%nat in
          let: "item" := list_nth "l" "num" in
          match: "item" with
          | SOME "t'" => "f" "t'"
          | NONE => NONE
          end
      end
  .

  Definition optimized_sampler_prog : val :=
    λ: "t", 
    rec: "f" "_":=
      match: optimized_sampler_rec_prog "t" with
      | SOME "v" => "v"
      | NONE => "f" #()
      end.

  (** lemmas about fst of treev **)
  Lemma wp_fst_ranked_tree E d tree l treev:
    is_ab_b_tree d l tree ->
    {{{ relate_ab_tree_with_ranked_v tree treev }}} 
    (Fst treev)@ E {{{ (v:nat), RET (#v); ⌜∃ v', treev = (#v, v')%V ⌝ ∗ relate_ab_tree_with_ranked_v tree treev }}}.
  Proof.
    iIntros "%Htree %Φ Hrelate HΦ".
    destruct tree; inversion Htree; subst.
    - erewrite relate_ab_tree_with_ranked_v_Lf. iDestruct "Hrelate" as "->".
      wp_pures. iApply "HΦ". iModIntro. iSplit.
      + iPureIntro. naive_solver.
      + rewrite relate_ab_tree_with_ranked_v_Lf. naive_solver.
    - erewrite relate_ab_tree_with_ranked_v_Br. iDestruct "Hrelate" as "(%&%&%&%&%&->&H)".
      wp_pures. iApply "HΦ". iModIntro. iSplit.
      + iPureIntro. naive_solver.
      + rewrite relate_ab_tree_with_ranked_v_Br. iFrame. done.
  Qed.

  Lemma spec_fst_ranked_tree E K d tree l treev:
    is_ab_b_tree d l tree ->
    relate_ab_tree_with_ranked_v tree treev -∗
    ⤇ fill K (Fst treev) -∗
    spec_update E (∃ (v:nat), ⤇ fill K (# v) ∗ ⌜∃ v', treev = (#v, v')%V⌝ ∗ relate_ab_tree_with_ranked_v tree treev).
  Proof.
    iIntros "%Htree Hrelate Hspec".
    destruct tree.
    - erewrite relate_ab_tree_with_ranked_v_Lf. iDestruct "Hrelate" as "->".
      tp_pures. iModIntro. iFrame. rewrite relate_ab_tree_with_ranked_v_Lf.
      iPureIntro. naive_solver.
    - erewrite relate_ab_tree_with_ranked_v_Br. iDestruct "Hrelate" as "(%&%&%&%&%&->&H)".
      tp_pures. iModIntro. iFrame. rewrite relate_ab_tree_with_ranked_v_Br. iFrame.
      iPureIntro. naive_solver.
  Qed.

  
  (** To prove that the optimized algorithm refines the naive one
      we show that for each "run", the depth number of (2*min_child_num) state step samples can be coupled
      with a single (2*min_child_num)^depth state step sample
      and that can be sampled with a single (total number of children) state step via a fragmental coupling 
      and appeal to Löb induction.
      To be more precise, one needs to find an injective function, from the total number of children to the single (2*min_child_num)^depth set
      The function is the one that maps i, to the index of the i-th children if the tree is full

      The other direction is the same, except one would need to amplify errors and use a continuity argument to close the proof 
   *)

  (** REFINEMENTS**)

  (** Stage 0 *)
  
  Lemma wp_naive_sampler_rec_prog (n:nat) l tree treev:
    (n<length(filter(λ x, is_Some x) l))%nat ->
    is_ab_b_tree depth l tree ->
    {{{ relate_ab_tree_with_ranked_v tree treev }}}
      (naive_sampler_rec_prog treev #n)
      {{{ (v:val), RET v; ⌜Some (Some v) = filter (λ x, is_Some x) l !! n⌝ ∗
            relate_ab_tree_with_ranked_v tree treev
      }}}.
  Proof.
  Admitted.

  Lemma spec_naive_sampler_rec_prog (n:nat) l tree treev E:
    (n<length(filter(λ x, is_Some x) l))%nat ->
    is_ab_b_tree depth l tree ->
    relate_ab_tree_with_ranked_v tree treev -∗
    ⤇ (naive_sampler_rec_prog treev #n) -∗
    spec_update E
      (∃ v:val, ⤇ v ∗
            ⌜Some (Some v) = filter (λ x, is_Some x) l !! n⌝ ∗
            relate_ab_tree_with_ranked_v tree treev)
      .
  Proof.
  Admitted.
  
  Lemma naive_annotated_naive_refinement tree l treev treev':
    (0<children_num tree)%nat -> 
    is_ab_b_tree depth l tree ->
    relate_ab_tree_with_ranked_v tree treev -∗
    relate_ab_tree_with_ranked_v tree treev' -∗
    ⤇ (naive_sampler_prog treev' #()) -∗
    € nnreal_zero -∗
    WP (naive_sampler_annotated_prog treev #()) {{ v,  ⤇ (Val v)  }}
  .
  Proof.
    iIntros (Hgt Htree) "Hrelate Hrelate' Hspec Hε".
    rewrite /naive_sampler_annotated_prog /naive_sampler_prog.
    wp_pures.
    tp_pures.
    tp_bind (Fst _).
    wp_bind (Fst _)%E.
    iApply (wp_fst_ranked_tree with "[$Hrelate]"); first done.
    iIntros "!> %v' ([% %]&Hrelate)"; simplify_eq.
    iMod (spec_fst_ranked_tree with "[$Hrelate'][$]") as "(%&Hspec&[%%]&Hrelate')"; first done.
    wp_pures. simpl. tp_pures.
    iDestruct (relate_ab_tree_with_ranked_v_child_num with "[$Hrelate]") as "(%&%)"; first done.
    iDestruct (relate_ab_tree_with_ranked_v_child_num with "[$Hrelate']") as "(%&%)"; first done.
    simplify_eq; simpl. 
    wp_apply (wp_alloc_tape); first done.
    iIntros (α) "Hα".
    tp_bind (rand _)%E.
    wp_pures.
    iApply (wp_couple_tape_rand with "[$Hα $Hspec Hrelate Hrelate']"); first done.
    simpl. iIntros (?) "[Hα Hspec]".
    tp_pures.
    wp_apply (wp_rand_tape with "[$]"). iIntros "Hα".
    wp_pures.
    pose proof ab_tree_children_num _ _ _ Htree.
    iDestruct (spec_naive_sampler_rec_prog with "[$][$]") as ">(%v&Hspec&%&Hrelate')"; [|done|].
    { eapply Nat.lt_le_trans; first apply fin_to_nat_lt.
      rewrite -H. lia. }
    wp_apply (wp_naive_sampler_rec_prog with "[$Hrelate]"); [|done|].
    { eapply Nat.lt_le_trans; first apply fin_to_nat_lt.
      rewrite -H. lia. }
    iIntros (v') "[%?]".
    replace (v) with v'; first done.
    do 2 apply Some_inj. etrans; first exact. done.
  Qed. 


  Lemma annotated_naive_naive_refinement tree l treev treev': 
    (0<children_num tree)%nat -> 
    is_ab_b_tree depth l tree ->
    relate_ab_tree_with_ranked_v tree treev -∗
    relate_ab_tree_with_ranked_v tree treev' -∗
    ⤇ (naive_sampler_annotated_prog treev' #()) -∗
    € nnreal_zero -∗
    WP (naive_sampler_prog treev #()) {{ v,  ⤇ (Val v)  }}
  .
  Proof.
    iIntros (Hgt Htree) "Hrelate Hrelate' Hspec Hε".
    rewrite /naive_sampler_annotated_prog /naive_sampler_prog.
    wp_pures.
    tp_pures.
    tp_bind (Fst _).
    wp_bind (Fst _)%E.
    iApply (wp_fst_ranked_tree with "[$Hrelate]"); first done.
    iIntros "!> %v' ([% %]&Hrelate)"; simplify_eq.
    iMod (spec_fst_ranked_tree with "[$Hrelate'][$]") as "(%&Hspec&[%%]&Hrelate')"; first done.
    simpl. subst.
    iDestruct (relate_ab_tree_with_ranked_v_same_num with "[$][$]") as "->".
    iDestruct (relate_ab_tree_with_ranked_v_child_num with "[$Hrelate]") as "(%&%)"; first done.
    simplify_eq; simpl.
    tp_pures; wp_pures.
    tp_alloctape as α "Hα".
    tp_pures.
    tp_bind (rand(_) _)%E.
    wp_apply (wp_couple_rand_tape with "[$Hα Hrelate Hspec Hε Hrelate']").
    iModIntro. iIntros (n) "Hα". simpl.
    wp_pures. tp_bind (rand(_) _)%E.
    (** imod doesnt work *)
    iDestruct (step_rand with "[$Hspec $Hα]") as "Hspec".
    iApply elim_modal_spec_update_wp; first done; iFrame; simpl.
    iIntros "[Hspec Hα]". tp_pures.
    pose proof ab_tree_children_num _ _ _ Htree.
    iDestruct (spec_naive_sampler_rec_prog with "[$Hrelate'][$]") as ">(%v1&Hspec&%&Hrelate')"; [|done|].
    { eapply Nat.lt_le_trans; first apply fin_to_nat_lt.
      rewrite -H. lia. }
    wp_apply (wp_naive_sampler_rec_prog with "[$Hrelate]"); [|done|].
    { eapply Nat.lt_le_trans; first apply fin_to_nat_lt.
      rewrite -H. lia. }
    iIntros (v2) "[%?]".
    replace (v1) with v2; first done.
    do 2 apply Some_inj. etrans; first exact. done.
  Qed.

  (** Stage 1 *)
  (** This is a refinement between the naive annotated algo, and a rejection sampler one
      From LHS to RHS, we need ε>0
      From RHS to LHS, ε can be 0
   *)
  
  Lemma annotated_naive_intermediate_refinement tree l treev treev' (ε:nonnegreal):
    (0<children_num tree)%nat -> 
    (0<ε)%R -> 
    is_ab_b_tree depth l tree ->
    relate_ab_tree_with_ranked_v tree treev -∗
    relate_ab_tree_with_v tree treev' -∗
    ⤇ (intermediate_sampler_annotated_prog treev' #()) -∗
    € ε -∗
    WP (naive_sampler_annotated_prog treev #()) {{ v,  ⤇ (Val v)  }}
  .
  Proof.
    iIntros (Hgt Hε Htree) "Hrelate Hrelate' Hspec Hε".
    rewrite /intermediate_sampler_annotated_prog /naive_sampler_annotated_prog.
    tp_pures.
    wp_pures.
    iDestruct (relate_ab_tree_with_ranked_v_child_num with "[$]") as "(%&->)"; first done.
    wp_pures.
    wp_apply (wp_alloc_tape); first done.
    iIntros (α) "Hα".
    wp_pures.
    tp_alloctape as α' "Hα'".
    do 2 tp_pure.
    pose proof ab_tree_children_num _ _ _ Htree as H.
    assert (children_num tree <= max_child_num^depth)%nat as Hineq.
    { pose proof ab_b_tree_list_length _ _ _ Htree as K.
      rewrite <-K.
      rewrite H. apply filter_length.
    }
    rewrite Nat.lt_eq_cases in Hineq.
    destruct Hineq as [Hineq|Hsame].
    - (* do error ampl  *)
      iRevert "Hrelate Hrelate' Hspec Hα Hα'".
      iApply (ec_ind_amp with "[][$Hε]"); [lra|..]; last first.
      + iModIntro.
        clear ε Hε.
        iIntros (ε) "%Hε #IH Hε Hrelate Hrelate' Hspec Hα Hα'".
        replace (Z.to_nat (Z.of_nat (children_num tree) - 1)) with (children_num tree - 1)%nat by lia.
        replace (Z.to_nat (Z.of_nat (max_child_num ^ depth) - 1)) with (max_child_num ^ depth - 1)%nat; last first.
        { pose proof pow_max_child_num depth. lia. }
        epose proof inj_function_exists l (S (max_child_num ^ depth-1))%nat (S (children_num tree-1))%nat _ _ as (f & Hinj & Hf1 & Hf2).
        rewrite Nat2Z.id.
        iApply (wp_couple_fragmented_rand_rand_inj_rev' _ _ f with "[$Hα $Hα' $Hε Hspec Hrelate Hrelate']"); [|done|..].
        { pose proof pow_max_child_num depth.
          apply lt_INR. lia.
        }
        iIntros (m).
        case_bool_decide as K.
        * (* hit somthing on the right!*)
          destruct K as [n <-].
          iIntros (?) "(Hα & Hα' & %Hfsame)".
          apply Hinj in Hfsame. subst. simpl.
          wp_apply (wp_rand_tape with "[$]").
          { replace (Z.to_nat (Z.of_nat (children_num tree) - 1)) with (children_num tree - 1)%nat; first done. lia. }
          iIntros "Hα".
          wp_pures. tp_pures.
          tp_bind (rand(_) _)%E.
          iDestruct (step_rand with "[$Hspec $Hα']") as "Hspec".
          iApply elim_modal_spec_update_wp; first done; iFrame; simpl.
          iIntros "[Hspec Hα']".
          tp_pures.
          specialize (Hf1 n) as [[v Hvsome] Hvsame].
          admit.
        * (* missed! *)
          iIntros (ε') "(%&Hα & Hα'&Hε)".
          (** only step RHS *)
          assert (l!!(fin_to_nat m)=Some None) as Hnone.
          { apply Hf2. intros. intro. apply K. subst. naive_solver. }
          tp_pures.
          tp_bind (rand(_) _)%E.
          iDestruct (step_rand with "[$Hspec $Hα']") as "Hspec".
          iApply elim_modal_spec_update_wp; first done; iFrame; simpl.
          iIntros "[Hspec Hα']".
          tp_pures.
          admit.
      + (* prove that the factor is larger than 1*)
        admit.
    - (* do a normal no error fragmented sampling and reject second case since the tree is populated *)
      tp_pures.
      epose proof inj_function_exists l (S (max_child_num ^ depth-1))%nat (S (children_num tree-1))%nat _ _ as (f & Hinj & Hf1 & Hf2).
      replace (Z.to_nat (Z.of_nat (children_num tree) - 1)) with (children_num tree - 1)%nat by lia.
      rewrite !Nat2Z.id.
      iApply (wp_couple_fragmented_rand_rand_inj_rev _ _ f with "[$Hα $Hα' Hspec Hrelate Hrelate']"); [|done|..].
      { rewrite Hsame. done. }
      iIntros (m).
      case_bool_decide as K.
      + destruct K as [n <-].
        iIntros (?) "(Hα & Hα' & %Hfsame)".
        apply Hinj in Hfsame. subst. simpl.
        wp_apply (wp_rand_tape with "[$]").
        { replace (Z.to_nat (Z.of_nat (children_num tree) - 1)) with (children_num tree - 1)%nat; first done. lia. }
        iIntros "Hα".
        wp_pures. tp_pures.
        tp_bind (rand(_) _)%E.
        iDestruct (step_rand with "[$Hspec $Hα']") as "Hspec".
        iApply elim_modal_spec_update_wp; first done; iFrame; simpl.
        iIntros "[Hspec Hα']".
        tp_pures.
        specialize (Hf1 n) as [[v Hvsome] Hvsame].
        admit.
      + (** contradiction since RHS is populated *)
        exfalso. apply K.
        apply finite_inj_surj; first done.
        rewrite !fin_card. rewrite H. lia.
        Unshelve.
  Admitted.
  
  Lemma intermediate_annotated_naive_refinement tree l treev treev': 
    (0<children_num tree)%nat -> 
    is_ab_b_tree depth l tree ->
    relate_ab_tree_with_v tree treev -∗
    relate_ab_tree_with_ranked_v tree treev' -∗
    ⤇ (naive_sampler_annotated_prog treev' #()) -∗
    € 0%NNR -∗
    WP (intermediate_sampler_annotated_prog treev #()) {{ v,  ⤇ (Val v)  }}
  .
  Proof.
    iIntros (Hgt Htree) "Hrelate Hrelate' Hspec Hε".
    rewrite /intermediate_sampler_annotated_prog /naive_sampler_annotated_prog.
    tp_pures.
    wp_pures.
    iDestruct (relate_ab_tree_with_ranked_v_child_num with "[$]") as "(%&->)"; first done.
    tp_pures.
    wp_pures.
    wp_apply (wp_alloc_tape); first done.
    iIntros (α) "Hα".
    do 2 wp_pure.
    tp_alloctape as α' "Hα'".
    tp_pures.
    (* iLöb *)
    iLöb as "IH".
    wp_pures.
    replace (Z.to_nat (Z.of_nat (children_num tree) - 1)) with (children_num tree - 1)%nat by lia.
    epose proof inj_function_exists l (S (max_child_num ^ depth-1))%nat (S (children_num tree-1))%nat _ _ as (f & Hinj & Hf1 & Hf2).
    pose proof ab_tree_children_num _ _ _ Htree as H.
    assert (children_num tree <= max_child_num^depth)%nat as Hineq.
    { pose proof ab_b_tree_list_length _ _ _ Htree as K.
      rewrite <-K.
      rewrite H. apply filter_length.
    }
    iApply (wp_couple_fragmented_rand_rand_inj _ _ f with "[$Hα $Hα' Hspec Hrelate Hrelate']"); [|done|..].
    { apply le_INR. lia. }
    iIntros (m).
    case_bool_decide as K.
    - (* hit somthing on the right!*)
      destruct K as [n <-].
      iIntros (?) "(Hα & Hα' & %Hfsame)".
      apply Hinj in Hfsame. subst. simpl.
      wp_apply (wp_rand_tape with "[$]").
      iIntros "Hα".
      wp_pures. tp_pures.
      tp_bind (rand(_) _)%E.
      iDestruct (step_rand with "[$Hspec $Hα']") as "Hspec".
      { replace (Z.to_nat (Z.of_nat (children_num tree) - 1)) with (children_num tree - 1)%nat; first done. lia. }
      iApply elim_modal_spec_update_wp; first done; iFrame; simpl.
      iIntros "[Hspec Hα']".
      tp_pures.
      specialize (Hf1 n) as [[v Hvsome] Hvsame].
      admit.
    - (* missed! *)
      iIntros "(Hα & Hα')".
      (** only step LHS *)
      assert (l!!(fin_to_nat m)=Some None) as Hnone.
      { apply Hf2. intros. intro. apply K. subst. naive_solver. }
      wp_apply (wp_rand_tape with "[$]").
      iIntros "Hα".
      wp_pures.
      admit.
      Unshelve.
  Admitted.

  (** Stage 2 *)
  (** This is a refinement between the rejection sampler one and the optimized one 
      It uses the lemma Rcoupl_state_state_exp
   *)
  Lemma intermediate_annotated_optimized_refinement tree l treev treev':
    (0<children_num tree)%nat -> 
    is_ab_b_tree depth l tree ->
    relate_ab_tree_with_v tree treev -∗
    relate_ab_tree_with_v tree treev' -∗
    ⤇ (optimized_sampler_annotated_prog treev' #()) -∗
    € 0%NNR -∗
    WP (intermediate_sampler_annotated_prog treev #()) {{ v,  ⤇ (Val v)  }}
  .
  Proof.
    iIntros (Hgt Htree) "Hrelate Hrelate' Hspec Hε".
    rewrite /intermediate_sampler_annotated_prog /optimized_sampler_annotated_prog.
    wp_pures. do 2 tp_pure.
    wp_apply (wp_alloc_tape); first done.
    iIntros (α) "Hα".
    do 2 wp_pure.
    (* iLöb *)
  Admitted.

  
  Lemma annotated_optimized_intermediate_refinement tree l treev treev': 
    (0<children_num tree)%nat -> 
    is_ab_b_tree depth l tree ->
    relate_ab_tree_with_v tree treev -∗
    relate_ab_tree_with_v tree treev' -∗
    ⤇ (intermediate_sampler_annotated_prog treev' #()) -∗
    € 0%NNR -∗
    WP (optimized_sampler_annotated_prog treev #()) {{ v,  ⤇ (Val v)  }}
  .
  Proof.
    iIntros (Hgt Htree) "Hrelate Hrelate' Hspec Hε".
    rewrite /intermediate_sampler_annotated_prog /optimized_sampler_annotated_prog.
    wp_pure. tp_pures.
    tp_alloctape as α' "Hα'".
    do 2 tp_pure.
  Admitted.

  
  (** Stage 3*)
  Lemma optimized_annotated_optimized_refinement tree l treev treev': 
    (0<children_num tree)%nat -> 
    is_ab_b_tree depth l tree ->
    relate_ab_tree_with_v tree treev -∗
    relate_ab_tree_with_v tree treev' -∗
    ⤇ (optimized_sampler_prog treev' #()) -∗
    € nnreal_zero -∗
    WP (optimized_sampler_annotated_prog treev #()) {{ v,  ⤇ (Val v)  }}.
  Proof.
    iIntros (Hgt Htree) "Hrelate Hrelate' Hspec Hε".
    rewrite /optimized_sampler_annotated_prog /optimized_sampler_prog.
    do 2 (wp_pure; tp_pure).
    (** iLöb *)
    (* wp_pures. *)
    (* tp_pures. *)
    (* wp_apply (wp_alloc_tape); first done. *)
    (* iIntros (α) "Hα". *)
    (* wp_pures. *)
    (* (** löb induction*) *)
    (* iLöb as "IH" forall (depth tree l treev treev' Htree) "Hrelate Hrelate' Hspec Hα". *)
    (* rewrite /optimized_sampler_rec_annotated_prog /optimized_sampler_rec_prog. *)
    (* wp_pure. tp_pure. *)
    (* rewrite -/optimized_sampler_rec_annotated_prog -/optimized_sampler_rec_prog. *)
    (* inversion Htree. *)
    (* - (** we have a lf*) *)
    (*   subst. rewrite !relate_ab_tree_with_v_Lf. *)
    (*   iDestruct "Hrelate" as "->". iDestruct "Hrelate'" as "->". *)
    (*   tp_pures. wp_pures. *)
    (*   done. *)
    (* - (** branch *) *)
    (*   subst. rewrite !relate_ab_tree_with_v_Br. *)
    (*   wp_pures; tp_pures. *)
    (*   iDestruct "Hrelate" as "(%&%&%&%&%&%&%&H1&H2)". *)
    (*   iDestruct "Hrelate'" as "(%&%&%&%&%&%&%&H3&H4)". subst. *)
    (*   wp_pures. tp_pures. tp_bind (rand _)%E. *)
    (*   wp_apply (wp_couple_tape_rand with "[$Hα $Hspec]"); first done. *)
    (*   simpl. iIntros (x) "[Hα Hspec]". wp_apply (wp_rand_tape with "[$Hα]"). *)
    (*   iIntros "Hα". wp_pures. *)
    (*   tp_pures. *)
    (*   wp_apply (wp_list_nth); first done. *)
    (*   iIntros (v) "[?|?]". *)
  Admitted.

  Lemma annotated_optimized_optimized_refinement tree l treev treev': 
    (0<children_num tree)%nat -> 
    is_ab_b_tree depth l tree ->
    relate_ab_tree_with_v tree treev -∗
    relate_ab_tree_with_v tree treev' -∗
    ⤇ (optimized_sampler_annotated_prog treev' #()) -∗
    € nnreal_zero -∗
    WP (optimized_sampler_prog treev #()) {{ v,  ⤇ (Val v)  }}.
  Proof.
    iIntros (Hgt Htree) "Hrelate Hrelate' Hspec Hε".
    rewrite /optimized_sampler_annotated_prog /optimized_sampler_prog.
    do 2 (tp_pure; wp_pure).
  Admitted.
  
End b_tree.


