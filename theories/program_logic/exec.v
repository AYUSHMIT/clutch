From Coq Require Import Reals Psatz.
From Coquelicot Require Import Rcomplements Rbar Series Lim_seq Hierarchy.
From stdpp Require Import relations fin_maps functions.
From self.prelude Require Import classical.
From self.program_logic Require Export language.
From self.prob Require Export distribution couplings.

(** Distribution for [n]-step partial evaluation *)
Section exec.
  Context {Λ : language}.
  Implicit Types ρ : cfg Λ.
  Implicit Types e : expr Λ.
  Implicit Types σ : state Λ.

  Definition prim_step_or_val (ρ : cfg Λ) : distr (cfg Λ) :=
    match to_val ρ.1 with
    | Some v => dret ρ
    | None => prim_step ρ.1 ρ.2
    end.

  Definition exec (n : nat) ρ : distr (cfg Λ) := iterM n prim_step_or_val ρ.

  Lemma exec_O ρ :
    exec 0 ρ = dret ρ.
  Proof. done. Qed.

  Lemma exec_Sn ρ n :
    exec (S n) ρ = prim_step_or_val ρ ≫= exec n.
  Proof. done. Qed.

  Lemma exec_plus ρ n m :
    exec (n + m) ρ = exec n ρ ≫= exec m.
  Proof. rewrite /exec iterM_plus //.  Qed.

  Lemma exec_1 :
    exec 1 = prim_step_or_val.
  Proof.
    extensionality ρ; destruct ρ as [e σ].
    rewrite exec_Sn /exec /= dret_id_right //.
  Qed.

  Lemma exec_Sn_r e σ n :
    exec (S n) (e, σ) = exec n (e, σ) ≫= prim_step_or_val.
  Proof.
    assert (S n = n + 1)%nat as -> by lia.
    rewrite exec_plus exec_1 //.
  Qed.

  Lemma exec_det_step n ρ e1 e2 σ1 σ2 :
    prim_step e1 σ1 (e2, σ2) = 1 →
    exec n ρ (e1, σ1) = 1 →
    exec (S n) ρ (e2, σ2) = 1.
  Proof.
    destruct ρ as [e0 σ0].
    rewrite exec_Sn_r.
    intros H ->%pmf_1_eq_dret.
    rewrite dret_id_left /=.
    case_match; [|done].
    assert (to_val e1 = None); [|simplify_eq].
    eapply val_stuck. erewrite H. lra.
  Qed.

  Lemma exec_det_step_ctx K `{!LanguageCtx K} n ρ e1 e2 σ1 σ2 :
    prim_step e1 σ1 (e2, σ2) = 1 →
    exec n ρ (K e1, σ1) = 1 →
    exec (S n) ρ (K e2, σ2) = 1.
  Proof.
    intros. eapply exec_det_step; [|done].
    rewrite -fill_step_prob //.
    eapply (val_stuck _ σ1 (e2, σ2)). lra.
  Qed.

  Lemma exec_PureExec_ctx K `{!LanguageCtx K} (P : Prop) m n ρ e e' σ :
    P →
    PureExec P n e e' →
    exec m ρ (K e, σ) = 1 →
    exec (m + n) ρ (K e', σ) = 1.
  Proof.
    move=> HP /(_ HP).
    destruct ρ as [e0 σ0].
    revert e e' m. induction n=> e e' m.
    { rewrite -plus_n_O. by inversion 1. }
    intros (e'' & Hsteps & Hpstep)%nsteps_inv_r Hdet.
    specialize (IHn _ _ m Hsteps Hdet).
    rewrite -plus_n_Sm.
    eapply exec_det_step_ctx; [done| |done].
    apply Hpstep.
  Qed.

End exec.

Global Arguments exec {_} _ _ : simpl never.

(** Distribution for evaluation ending in a value in less than [n]-step *)
Section prim_exec.
  Context {Λ : language}.
  Implicit Types ρ : cfg Λ.
  Implicit Types e : expr Λ.
  Implicit Types σ : state Λ.

  Fixpoint prim_exec (n : nat) (ρ : cfg Λ) {struct n} : distr (cfg Λ) :=
    match to_val ρ.1, n with
      | Some v, _ => dret ρ
      | None, 0 => dzero
      | None, S n => prim_step ρ.1 ρ.2 ≫= prim_exec n
    end.

  Lemma prim_exec_unfold (n : nat) :
    prim_exec n = λ ρ,
      match to_val ρ.1, n with
      | Some v, _ => dret ρ
      | None, 0 => dzero
      | None, S n => prim_step ρ.1 ρ.2 ≫= prim_exec n
      end.
  Proof. by destruct n. Qed.

  Lemma prim_exec_is_val e σ n :
    is_Some (to_val e) → prim_exec n (e, σ) = dret (e, σ).
  Proof. destruct n; simpl; by intros [? ->]. Qed.

  Lemma prim_step_or_val_no_val e σ :
    to_val e = None → prim_step_or_val (e, σ) = prim_step e σ.
  Proof. rewrite /prim_step_or_val /=. by intros ->. Qed.

  Lemma prim_step_or_val_is_val e σ :
    is_Some (to_val e) → prim_step_or_val (e, σ) = dret (e, σ).
  Proof. rewrite /prim_step_or_val /=. by intros [? ->]. Qed.

  Lemma prim_exec_Sn (ρ : cfg Λ) (n: nat) :
    prim_exec (S n) ρ = prim_step_or_val ρ ≫= prim_exec n.
  Proof.
    destruct ρ as [e σ].
    rewrite /prim_step_or_val /=.
    destruct (to_val e) eqn:Hv=>/=; [|done].
    rewrite dret_id_left -/prim_exec.
    rewrite prim_exec_is_val //.
  Qed.

  Lemma prim_exec_Sn_not_val e σ n :
    to_val e = None →
    prim_exec (S n) (e, σ) = prim_step e σ ≫= prim_exec n.
  Proof. intros ?. rewrite prim_exec_Sn prim_step_or_val_no_val //. Qed.

  Lemma prim_exec_plus ρ n m :
    prim_exec (n + m) ρ = exec n ρ ≫= prim_exec m.
  Proof.
    revert ρ; induction n; intros ρ.
    - rewrite exec_O dret_id_left -/prim_exec //.
    - rewrite plus_Sn_m prim_exec_Sn exec_Sn.
      rewrite -dbind_assoc -/prim_exec -/exec.
      apply dbind_eq; [|done].
      intros ??. eapply IHn.
  Qed.

 (** Restating results for prim_exec_val *)

  Fixpoint prim_exec_val (n : nat) (ρ : cfg Λ) {struct n} : distr (val Λ) :=
    match to_val ρ.1, n with
      | Some v, _ => dret v
      | None, 0 => dzero
      | None, S n => prim_step ρ.1 ρ.2 ≫= prim_exec_val n
    end.

  Lemma prim_exec_val_unfold (n : nat) :
    prim_exec_val n = λ ρ,
      match to_val ρ.1, n with
      | Some v, _ => dret v
      | None, 0 => dzero
      | None, S n => prim_step ρ.1 ρ.2 ≫= prim_exec_val n
      end.
  Proof. by destruct n. Qed.

  Lemma prim_exec_val_is_val e σ n v:
    to_val e = Some v → prim_exec_val n (e, σ) = dret v.
  Proof. destruct n; simpl; by intros ->. Qed.

  Lemma prim_exec_val_Sn (ρ : cfg Λ) (n: nat) :
    prim_exec_val (S n) ρ = prim_step_or_val ρ ≫= prim_exec_val n.
  Proof.
    destruct ρ as [e σ].
    rewrite /prim_step_or_val /=.
    destruct (to_val e) eqn:Hv=>/=; [|done].
    rewrite dret_id_left -/prim_exec.
    fold prim_exec_val.
    erewrite prim_exec_val_is_val; eauto.
  Qed.

  Lemma prim_exec_val_Sn_not_val e σ n :
    to_val e = None →
    prim_exec_val (S n) (e, σ) = prim_step e σ ≫= prim_exec_val n.
  Proof. intros ?. rewrite prim_exec_val_Sn prim_step_or_val_no_val //. Qed.

 (*
  Lemma prim_exec_val_plus ρ n m :
    prim_exec_val (n + m) ρ = exec n ρ ≫= prim_exec_val m.
  Proof.
    revert ρ; induction n; intros ρ.
    - rewrite exec_O dret_id_left -/prim_exec //.
    - rewrite plus_Sn_m prim_exec_Sn exec_Sn.
      rewrite -dbind_assoc -/prim_exec -/exec.
      apply dbind_eq; [|done].
      intros ??. eapply IHn.
  Qed.
*)

End prim_exec.

(** Limit of [prim_exec]  *)
Section prim_exec_lim.
  Context {Λ : language}.
  Implicit Types ρ : cfg Λ.
  Implicit Types e : expr Λ.
  Implicit Types v : val Λ.
  Implicit Types σ : state Λ.

  Program Definition lim_prim_exec ρ : distr (cfg Λ):= MkDistr (λ ρ', Lim_seq (λ n, prim_exec n ρ ρ')) _ _ _.
  Next Obligation. Admitted.
  Next Obligation. Admitted.
  Next Obligation. Admitted.

  (* needed in [adequacy.v] *)
  Lemma lim_prim_exec_exec n ρ :
    lim_prim_exec ρ = exec n ρ ≫= lim_prim_exec.
  Proof. Admitted.

  Lemma lim_prim_exec_exec_val n ρ v σ :
    exec n ρ (of_val v, σ) = 1 →
    lim_prim_exec ρ = dret (of_val v, σ).
  Proof. Admitted.

  Lemma lim_prim_exec_continous ρ1 ρ2 r :
    (∀ n, prim_exec n ρ1 ρ2 <= r) → lim_prim_exec ρ1 ρ2 <= r.
  Proof. Admitted.

  Program Definition lim_prim_exec_val (ρ : cfg Λ) : distr (val Λ):= MkDistr (λ v, Lim_seq (λ n, prim_exec_val n ρ v)) _ _ _.
  Next Obligation. Admitted.
  Next Obligation. Admitted.
  Next Obligation. Admitted.


  Lemma bind_lim_prim_exec (ρ : cfg Λ) :
    dbind (λ ρ', lim_prim_exec_val ρ') (prim_step_or_val ρ) = (lim_prim_exec_val ρ).
  Proof. Admitted.


  Lemma lim_prim_exec_exec n (ρ : cfg Λ) :
    lim_prim_exec_val ρ = exec n ρ ≫= lim_prim_exec_val.
  Proof. Admitted.


  Lemma lim_prim_exec_exec_val n ρ (v : val Λ) σ :
    exec n ρ (of_val v, σ) = 1 →
    lim_prim_exec_val ρ = dret v.
  Proof. Admitted.

End prim_exec_lim.
