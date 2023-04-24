(** Core relational rules *)
From stdpp Require Import coPset namespaces.
From iris.proofmode Require Import proofmode.
From iris.algebra Require Import list.
From self.program_logic Require Import ectx_lifting.
From self.prob_lang Require Import lang spec_rules spec_tactics proofmode.
From self.logrel Require Import model.

Section rules.
  Context `{!prelogrelGS Σ}.
  Implicit Types A : lrel Σ.
  Implicit Types e : expr.
  Implicit Types v w : val.

  Local Existing Instance pure_exec_fill.

  (** * Primitive rules *)

  (** ([fupd_refines] is defined in [logrel_binary.v]) *)

  (** ** Forward reductions on the LHS *)

  Lemma refines_pure_l E n
    (K' : list ectx_item) e e' t A ϕ :
    PureExec ϕ n e e' →
    ϕ →
    ▷^n (REL fill K' e' << t @ E : A)
    ⊢ REL fill K' e << t @ E : A.
  Proof.
    intros Hpure Hϕ.
    rewrite refines_eq /refines_def.
    iIntros "IH" (j) "Hs Hnais".
    wp_pures. iApply ("IH" with "Hs Hnais").
  Qed.

  Lemma refines_wp_l E K e1 t A :
    (WP e1 {{ v,
        REL fill K (of_val v) << t @ E : A }})%I -∗
    REL fill K e1 << t @ E : A.
  Proof.
    rewrite refines_eq /refines_def.
    iIntros "He" (K') "Hs Hnais /=".
    iApply wp_bind.
    iApply (wp_wand with "He").
    iIntros (v) "Hv".
    iApply ("Hv" with "Hs Hnais").
  Qed.

  Lemma refines_atomic_l (E E' : coPset) K e1 t A
    (Hatomic : Atomic WeaklyAtomic e1) :
    (∀ K', refines_right K' t ={⊤, E'}=∗
             WP e1 @ E' {{ v,
              |={E', ⊤}=> ∃ t', refines_right K' t' ∗
              REL fill K (of_val v) << t' @ E : A }})%I -∗
   REL fill K e1 << t @ E : A.
  Proof.
    rewrite refines_eq /refines_def.
    iIntros "Hlog" (K') "Hs Hnais /=".
    iApply wp_bind. iApply wp_atomic; auto.
    iMod ("Hlog" with "Hs") as "He". iModIntro.
    iApply (wp_wand with "He").
    iIntros (v) "Hlog".
    iMod "Hlog" as (t') "[Hr Hlog]".
    iApply ("Hlog" with "Hr Hnais").
  Qed.

  (** ** Forward reductions on the RHS *)

  Lemma refines_pure_r E K' e e' t A n
    (Hspec : nclose specN ⊆ E) ϕ :
    PureExec ϕ n e e' →
    ϕ →
    (REL t << fill K' e' @ E : A)
    ⊢ REL t << fill K' e @ E : A.
  Proof.
    rewrite refines_eq /refines_def => Hpure Hϕ.
    iIntros "Hlog" (j) "Hj Hnais /=".
    tp_pures ; auto.
    iApply ("Hlog" with "Hj Hnais").
  Qed.

  Lemma refines_right_bind K' K e :
    refines_right K' (fill K e) ≡ refines_right (K ++ K') e.
  Proof. rewrite /refines_right /=. by rewrite fill_app. Qed.

  Definition refines_right_bind' := refines_right_bind.

  (* A helper lemma for proving the stateful reductions for the RHS below *)
  Lemma refines_step_r E K' e1 e2 A :
    (∀ k, refines_right k e2 ={⊤}=∗
         ∃ v, refines_right k (of_val v) ∗ REL e1 << fill K' (of_val v) @ E : A) -∗
    REL e1 << fill K' e2 @ E : A.
  Proof.
    rewrite refines_eq /refines_def /=.
    iIntros "He" (K'') "Hs Hnais /=".
    rewrite refines_right_bind /=.
    iMod ("He" with "Hs") as (v) "[Hs He]".
    rewrite -refines_right_bind'.
    iSpecialize ("He" with "Hs Hnais").
    by iApply "He".
  Qed.

  Lemma refines_alloc_r E K e v t A :
    IntoVal e v →
    (∀ l : loc, l ↦ₛ v -∗ REL t << fill K (of_val #l) @ E : A)%I
    -∗ REL t << fill K (ref e) @ E : A.
  Proof.
    rewrite /IntoVal. intros <-.
    iIntros "Hlog". simpl.
    iApply refines_step_r ; simpl.
    iIntros (K') "HK'".
    tp_alloc as l "Hl".
    iModIntro. iExists _. iFrame. by iApply "Hlog".
  Qed.

  Lemma refines_load_r E K l q v t A :
    l ↦ₛ{q} v -∗
    (l ↦ₛ{q} v -∗ REL t << fill K (of_val v) @ E : A)
    -∗ REL t << (fill K !#l) @ E : A.
  Proof.
    iIntros "Hl Hlog".
    iApply refines_step_r.
    iIntros (k) "Hk".
    tp_load.
    iModIntro. iExists _. iFrame. by iApply "Hlog".
  Qed.

  Lemma refines_store_r E K l e e' v v' A :
    IntoVal e' v' →
    l ↦ₛ v -∗
    (l ↦ₛ v' -∗ REL e << fill K (of_val #()) @ E : A) -∗
    REL e << fill K (#l <- e') @ E : A.
  Proof.
    rewrite /IntoVal. iIntros (<-) "Hl Hlog".
    iApply refines_step_r.
    iIntros (k) "Hk". simpl.
    tp_store. iModIntro. iExists _. iFrame.
    by iApply "Hlog".
  Qed.

  Lemma refines_alloctape_r E K (n:nat) t A :
    (∀ α : loc, α ↪ₛ (n,[]) -∗ REL t << fill K (of_val #lbl:α) @ E : A)%I
    -∗ REL t << fill K (alloc (Val #n)) @ E : A.
  Proof.
    rewrite /IntoVal.
    iIntros "Hlog".
    iApply refines_step_r.
    iIntros (K') "HK'".
    tp_alloctape as α "Hα".
    iModIntro. iExists _. iFrame. by iApply "Hlog".
  Qed.

  Lemma refines_rand_r E K α n b bs t A :
    α ↪ₛ (n, b :: bs)
    -∗ (α ↪ₛ (n, bs) -∗ REL t << fill K (of_val #b) @ E : A)
    -∗ REL t << (fill K (rand #lbl:α)) @ E : A.
  Proof.
    iIntros "Hα Hlog".
    iApply refines_step_r.
    iIntros (k) "Hk".
    tp_flip.
    iModIntro. iExists _. iFrame. by iApply "Hlog".
  Qed.

  (** This rule is useful for proving that functions refine each other *)
  Lemma refines_arrow_val (v v' : val) A A' :
    □(∀ v1 v2, A v1 v2 -∗
      REL App v (of_val v1) << App v' (of_val v2) : A') -∗
    REL (of_val v) << (of_val v') : (A → A')%lrel.
  Proof.
    iIntros "#H".
    iApply refines_ret. iModIntro.
    iModIntro. iIntros (v1 v2) "HA".
    iSpecialize ("H" with "HA").
    by iApply "H".
  Qed.

  (** * Some derived (symbolic execution) rules *)

  (** ** Stateful reductions on the LHS *)

  Lemma refines_alloc_l K E e v t A :
    IntoVal e v →
    (▷ (∀ l : loc, l ↦ v -∗
           REL fill K (of_val #l) << t @ E : A))
    -∗ REL fill K (ref e) << t @ E : A.
  Proof.
    iIntros (<-) "Hlog".
    iApply refines_wp_l.
    wp_alloc l. by iApply "Hlog".
  Qed.

  Lemma refines_load_l K E l q t A :
    (∃ v',
      ▷(l ↦{q} v') ∗
      ▷(l ↦{q} v' -∗ (REL fill K (of_val v') << t @ E : A)))
    -∗ REL fill K (! #l) << t @ E : A.
  Proof.
    iIntros "[%v' [Hl Hlog]]".
    iApply refines_wp_l.
    wp_load. by iApply "Hlog".
  Qed.

  Lemma refines_store_l K E l e v' t A :
    IntoVal e v' →
    (∃ v, ▷ l ↦ v ∗
      ▷(l ↦ v' -∗ REL fill K (of_val #()) << t @ E : A))
    -∗ REL fill K (#l <- e) << t @ E : A.
  Proof.
    iIntros (<-) "[%v [Hl Hlog]]".
    iApply refines_wp_l.
    wp_store. by iApply "Hlog".
  Qed.

  Lemma refines_alloctape_l K E (n:nat) t A :
    (▷ (∀ α : loc, α ↪ (n, []) -∗
           REL fill K (of_val #lbl:α) << t @ E : A))%I
    -∗ REL fill K (alloc (Val #n)) << t @ E : A.
  Proof.
    iIntros "Hlog".
    iApply refines_wp_l.
    by wp_apply (wp_alloc_tape with "[//]").
  Qed.

  Lemma refines_rand_l E K α n b bs t A :
    (▷ α ↪ (n, b :: bs) ∗
     ▷ ( ⌜ b <= n ⌝ ∗ α ↪ (n, bs) -∗ REL fill K (of_val #b) << t @ E : A))
    -∗ REL fill K (rand #lbl:α) << t @ E : A.
  Proof.
    iIntros "[Hα Hlog]".
    iApply refines_wp_l.
    by wp_apply (wp_rand_tape with "Hα").
  Qed.

  Lemma refines_wand E e1 e2 A A' :
    (REL e1 << e2 @ E : A) -∗
    (∀ v1 v2, A v1 v2 ={⊤}=∗ A' v1 v2) -∗
    REL e1 << e2 @ E : A'.
  Proof.
    iIntros "He HAA".
    iApply (refines_bind [] [] with "He").
    iIntros (v v') "HA /=". iApply refines_ret.
    by iApply "HAA".
  Qed.

  Lemma refines_arrow (v v' : val) A A' :
    □ (∀ v1 v2 : val, □(REL of_val v1 << of_val v2 : A) -∗
      REL App v (of_val v1) << App v' (of_val v2) : A') -∗
    REL (of_val v) << (of_val v') : (A → A')%lrel.
  Proof.
    iIntros "#H".
    iApply refines_arrow_val; eauto.
    iModIntro. iIntros (v1 v2) "#HA".
    iApply "H". iModIntro.
    by iApply refines_ret.
  Qed.

  Lemma refines_couple_tapes E e1 e2 A α αₛ n bs bsₛ :
    to_val e1 = None →
    (αₛ ↪ₛ (n, bsₛ) ∗ α ↪ (n,bs) ∗
       (∀ b, αₛ ↪ₛ (n, bsₛ ++ [b]) ∗ α ↪ (n, bs ++ [b])
       -∗ REL e1 << e2 @ E : A))
    ⊢ REL e1 << e2 @ E : A.
  Proof.
    iIntros (e1ev) "(Hαs & Hα & Hlog)".
    rewrite refines_eq /refines_def.
    iIntros (K2) "[#Hs He2] Hnais /=".
    wp_apply wp_couple_tapes_eq; [done|done|].
    iFrame "Hα Hαs".
    iSplit; [done|].
    iIntros "[%b [Hαs Hα]]".
    iApply ("Hlog" with "[$Hα $Hαs] [$Hs $He2] Hnais").
  Qed.

  Lemma refines_couple_tape_rand K' E α A n bs e :
    to_val e = None →
    α ↪ (n,bs) ∗
      (∀ (b : nat), ⌜b <= n⌝ ∗ α ↪ (n, bs ++ [b]) -∗ REL e << fill K' (Val #b) @ E : A)
    ⊢ REL e << fill K' (rand #n) @ E : A.
  Proof.
    iIntros (?) "[Hα Hcnt]".
    rewrite {2}refines_eq.
    rewrite {1}/refines_def.
    iIntros (K2) "[#Hs Hspec] Hnais /=".
    wp_apply wp_couple_tape_rand_eq; [done|done|].
    rewrite -fill_app.
    iFrame "Hs Hα Hspec".
    iIntros (b) "[Hleq [Hα Hspec]]".
    rewrite fill_app.
    rewrite refines_eq /refines_def /refines_right.
    (* TODO: Write using proper syntax *)
    iSpecialize ("Hcnt" with "[$Hleq $Hα] [Hs Hspec] Hnais"); auto.
    wp_apply (wp_mono); last first.
    - iApply "Hcnt".
    - iIntros (v) "[% ([? ?] &?&?)]".
      iExists _. iFrame.
  Qed.

  Lemma refines_couple_rand_tape K E α A n bs e :
    α ↪ₛ (n,bs) ∗
      (∀ (b : nat), ⌜b <= n⌝ ∗ α ↪ₛ (n, bs ++ [b]) -∗ REL fill K (Val #b) << e @ E : A)
    ⊢ REL fill K (rand #n) << e @ E : A.
  Proof.
    iIntros "[Hα Hcnt]".
    rewrite refines_eq /refines_def.
    iIntros (K2) "[#Hs Hspec] Hnais /=".
    wp_apply wp_bind.
    wp_apply wp_couple_rand_tape_eq; [done|].
    iFrame "Hs Hα".
    iIntros (b) "Hα".
    iSpecialize ("Hcnt" with "Hα [$Hs $Hspec] Hnais").
    (* We should be able to just [iApply] "Hcnt" here??? *)
    wp_apply (wp_mono with "Hcnt").
    iIntros (v) "[% ([? ?] &?&?)]".
    iExists _. iFrame.
  Qed.

  Corollary refines_couple_rands_l K K' E α A n :
    α ↪ (n,[]) ∗
      (∀ (b : nat), ⌜b <= n⌝ ∗ α ↪ (n,[]) -∗ REL fill K (Val #b) << fill K' (Val #b) @ E : A)
    ⊢ REL fill K (rand #lbl:α) << fill K' (rand #n) @ E : A.
  Proof.
    iIntros "(α & H)".
    iApply refines_couple_tape_rand.
    1: rewrite fill_not_val //.
    iFrame => /=. iIntros (b) "[Hleq α]".
    iApply refines_rand_l.
    iSplitL "α". 1: iFrame.
    iApply "H".
  Qed.

  Corollary refines_couple_rands_r K K' E α A n :
    α ↪ₛ (n,[]) ∗
      (∀ (b : nat), ⌜b <= n⌝ ∗ α ↪ₛ (n,[]) -∗ REL fill K (Val #b) << fill K' (Val #b) @ E : A)
    ⊢ REL fill K (rand #n) << fill K' (rand #lbl:α) @ E : A.
  Proof.
    iIntros "(α & H)".
    iApply refines_couple_rand_tape.
    iFrame => /=. iIntros (b) "[Hleq α]".
    iApply (refines_rand_r with "α").
    iIntros "α".
    iApply "H"; auto.
  Qed.

  Lemma refines_couple_rands_lr K K' E A n:
      (∀ (b : nat), ⌜b <= n⌝ -∗ REL fill K (Val #b) << fill K' (Val #b) @ E : A)
    ⊢ REL fill K (rand #n) << fill K' (rand #n) @ E : A.
  Proof.
    iIntros "Hcnt".
    rewrite refines_eq /refines_def.
    iIntros (K2) "[#Hs Hspec] Hnais /=".
    wp_apply wp_bind.
    wp_apply wp_couple_rand_rand_eq; [done|].
    rewrite -fill_app.
    iFrame "Hs Hspec".
    iIntros (b) "[Hleq Hspec]".
    iApply wp_value.
    rewrite fill_app.
    iSpecialize ("Hcnt" with "Hleq [$Hspec $Hs] Hnais").
    wp_apply (wp_mono with "Hcnt").
    iIntros (v) "[% ([? ?] &?&?)]".
    iExists _. iFrame.
  Qed.

  Lemma refines_rand_empty_l K E α A n e :
    α ↪ (n, []) ∗
      (∀ (b : nat), ⌜b <= n⌝ ∗ α ↪ (n, []) -∗ REL fill K (Val #b) << e @ E : A)
    ⊢ REL fill K (rand #lbl:α) << e @ E : A.
  Proof.
    iIntros "[Hα H]".
    rewrite refines_eq /refines_def.
    iIntros (K2) "[#Hs Hspec] Hnais /=".
    wp_apply wp_bind.
    wp_apply (wp_rand_tape_empty with "Hα").
    iIntros (b) "Hα".
    simpl.
    rewrite /refines_right.
    iSpecialize ("H" with "Hα [$Hs $Hspec] Hnais").
    iExact "H".
  Qed.

  Lemma refines_flip_empty_r K E α A n e :
    to_val e = None →
    α ↪ₛ (n,[]) ∗
      (∀ (b : nat), ⌜b <= n⌝ ∗ α ↪ₛ (n,[]) -∗ REL e << fill K (Val #b) @ E : A)
    ⊢ REL e << fill K (rand #lbl:α) @ E : A.
  Proof.
    iIntros (ev) "[Hα H]".
    rewrite refines_eq /refines_def.
    iIntros (K2) "[#Hs Hspec] Hnais /=".
    wp_apply wp_rand_empty_r ; auto.
    iFrame. iSplitR. 1: iAssumption.
    unfold refines_right.
    rewrite -fill_app. iFrame.
    iIntros "(α & _ & %b & Hleq & Hb)".
    rewrite fill_app.
    by iApply ("H" $! _ with "[Hleq $α] [$Hs $Hb]").
  Qed.

End rules.
