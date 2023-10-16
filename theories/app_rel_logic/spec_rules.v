(** Rules for updating the specification program. *)
From stdpp Require Import namespaces.
From iris.proofmode Require Import proofmode.
From clutch.prelude Require Import stdpp_ext.
From clutch.app_rel_logic Require Import lifting ectx_lifting.
From clutch.prob_lang Require Import lang notation tactics metatheory.
From clutch.rel_logic Require Export spec_ra.
From clutch.app_rel_logic Require Export app_weakestpre primitive_laws.

Section rules.
  Context `{!clutchGS Σ}.
  Implicit Types P Q : iProp Σ.
  Implicit Types Φ : val → iProp Σ.
  Implicit Types σ : state.
  Implicit Types e : expr.
  Implicit Types v : val.
  Implicit Types l : loc.

  (** Pure reductions *)
  Lemma step_pure E K e e' (P : Prop) n :
    P →
    PureExec P n e e' →
    nclose specN ⊆ E →
    spec_ctx ∗ ⤇ fill K e ={E}=∗ spec_ctx ∗ ⤇ fill K e'.
  Proof.
    iIntros (HP Hex ?) "[#Hspec Hj]". iFrame "Hspec".
    iInv specN as (ρ e0 σ0 m) ">(Hspec0 & %Hexec & Hauth & Hheap & Htapes)" "Hclose".
    iDestruct (spec_prog_auth_frag_agree with "Hauth Hj") as %->.
    iMod (spec_prog_update (fill K e') with "Hauth Hj") as "[Hauth Hj]".
    iFrame "Hj". iApply "Hclose". iNext.
    iExists _, _, _, (m + n).
    iFrame.
    iPureIntro.
    by eapply (exec_PureExec_ctx (fill K) P).
  Qed.

  (** Alloc, load, and store *)
  Lemma step_alloc E K e v :
    IntoVal e v →
    nclose specN ⊆ E →
    spec_ctx ∗ ⤇ fill K (ref e) ={E}=∗ ∃ l, spec_ctx ∗ ⤇ fill K (#l) ∗ l ↦ₛ v.
  Proof.
    iIntros (<-?) "[#Hinv Hj]". iFrame "Hinv".
    iInv specN as (ρ e σ m) ">(Hspec0 & %Hexec & Hauth & Hheap & Htapes)" "Hclose".
    iDestruct (spec_prog_auth_frag_agree with "Hauth Hj") as %->.
    set (l := fresh_loc σ.(heap)).
    iMod (spec_prog_update (fill K #l) with "Hauth Hj") as "[Hauth Hj]".
    iMod (ghost_map_insert l v with "Hheap") as "[Hheap Hl]".
    { apply not_elem_of_dom, fresh_loc_is_fresh. }
    iExists l. iFrame. iMod ("Hclose" with "[-]"); [|done].
    iModIntro. rewrite /spec_inv.
    iExists _, _, (state_upd_heap <[l:=v]> σ), _.
    iFrame. iPureIntro.
    eapply exec_det_step_ctx; [apply _| |done].
    subst l.
    solve_step.
  Qed.

  Lemma step_load E K l q v:
    nclose specN ⊆ E →
    spec_ctx ∗ ⤇ fill K (!#l) ∗ l ↦ₛ{q} v
    ={E}=∗ spec_ctx ∗ ⤇ fill K (of_val v) ∗ l ↦ₛ{q} v.
  Proof.
    iIntros (?) "(#Hinv & Hj & Hl)". iFrame "Hinv".
    iInv specN as (ρ e σ m) ">(Hspec0 & %Hexec & Hauth & Hheap & Htapes)" "Hclose".
    iDestruct (spec_prog_auth_frag_agree with "Hauth Hj") as %->.
    iMod (spec_prog_update (fill K v) with "Hauth Hj") as "[Hauth Hj]".
    iDestruct (ghost_map_lookup with "Hheap Hl") as %?.
    iFrame. iMod ("Hclose" with "[-]"); [|done].
    iModIntro. iExists _, _, _, _.
    iFrame. iPureIntro.
    eapply exec_det_step_ctx; [apply _| |done].
    solve_step.
  Qed.

  Lemma step_store E K l v' e v:
    IntoVal e v →
    nclose specN ⊆ E →
    spec_ctx ∗ ⤇ fill K (#l <- e) ∗ l ↦ₛ v'
    ={E}=∗ spec_ctx ∗ ⤇ fill K #() ∗ l ↦ₛ v.
  Proof.
    iIntros (<-?) "(#Hinv & Hj & Hl)". iFrame "Hinv".
    iInv specN as (ρ e σ m) ">(Hspec0 & %Hexec & Hauth & Hheap & Htapes)" "Hclose".
    iDestruct (spec_prog_auth_frag_agree with "Hauth Hj") as %->.
    iMod (spec_prog_update (fill K #()) with "Hauth Hj") as "[Hauth Hj]".
    iDestruct (ghost_map_lookup with "Hheap Hl") as %?.
    iMod (ghost_map_update v with "Hheap Hl") as "[Hheap Hl]".
    iFrame. iMod ("Hclose" with "[-]"); [|done].
    iModIntro. iExists _, _, (state_upd_heap <[l:=v]> σ), _.
    iFrame. iPureIntro.
    eapply exec_det_step_ctx; [apply _| |done].
    solve_step.
  Qed.

  (** AllocTape and Rand (non-empty tape)  *)
  Lemma step_alloctape E K N z :
    TCEq N (Z.to_nat z) →
    nclose specN ⊆ E →
    spec_ctx ∗ ⤇ fill K (alloc #z) ={E}=∗ ∃ l, spec_ctx ∗ ⤇ fill K (#lbl: l) ∗ l ↪ₛ (N; []).
  Proof.
    iIntros (-> ?) "[#Hinv Hj]". iFrame "Hinv".
    iInv specN as (ρ e σ m) ">(Hspec0 & %Hexec & Hauth & Hheap & Htapes)" "Hclose".
    iDestruct (spec_prog_auth_frag_agree with "Hauth Hj") as %->.
    iMod (spec_prog_update (fill K #(LitLbl (fresh_loc σ.(tapes)))) with "Hauth Hj") as "[Hauth Hj]".
    iMod (ghost_map_insert (fresh_loc σ.(tapes)) ((_; []) : tape) with "Htapes") as "[Htapes Hl]".
    { apply not_elem_of_dom, fresh_loc_is_fresh. }
    iExists (fresh_loc σ.(tapes)).
    iFrame. iMod ("Hclose" with "[-]"); [|done].
    iModIntro.
    iExists _, _, (state_upd_tapes <[fresh_loc σ.(tapes):=_]> σ), _.
    iFrame. iPureIntro.
    eapply exec_det_step_ctx; [apply _| |done].
    (* TODO: fix tactic *)
    solve_step.
    by apply dret_1_1.
  Qed.

  Lemma step_rand E K l N z n ns :
    TCEq N (Z.to_nat z) →
    nclose specN ⊆ E →
    spec_ctx ∗ ⤇ fill K (rand #z from #lbl:l) ∗ l ↪ₛ (N; n :: ns)
    ={E}=∗ spec_ctx ∗ ⤇ fill K #n ∗ l ↪ₛ (N; ns).
  Proof.
    iIntros (-> ?) "(#Hinv & Hj & Hl)". iFrame "Hinv".
    iInv specN as (ρ e σ m) ">(Hspec0 & %Hexec & Hauth & Hheap & Htapes)" "Hclose".
    iDestruct (spec_prog_auth_frag_agree with "Hauth Hj") as %->.
    iMod (spec_prog_update (fill K #n) with "Hauth Hj") as "[Hauth Hj]".
    iDestruct (ghost_map_lookup with "Htapes Hl") as %?.
    iMod (ghost_map_update ((_; ns) : tape) with "Htapes Hl") as "[Htapes Hl]".
    iFrame. iMod ("Hclose" with "[-]"); [|done].
    iModIntro. iExists _, _, (state_upd_tapes <[l:=_]> σ), _.
    iFrame. iPureIntro.
    eapply exec_det_step_ctx; [apply _| |done].
    (* TODO: fix tactic *)
    solve_step.
    rewrite bool_decide_eq_true_2 //.
    by apply dret_1_1.
  Qed.

  Lemma ARcoupl_refRcoupl `{Countable A, Countable B}
    μ1 μ2 (ψ : A → B → Prop) : refRcoupl μ1 μ2 ψ -> ARcoupl μ1 μ2 ψ 0.
  Proof.
    intros (μ&(<-&Hrm)&Hs).
    setoid_rewrite rmarg_pmf in Hrm.
    intros f g Hf Hg Hfg.
    rewrite Rplus_0_r.
    setoid_rewrite lmarg_pmf.
    etrans; last first.
    {
      apply SeriesC_le.
      - split; last first.
        + apply Rmult_le_compat_r; [apply Hg | apply Hrm].
        + simpl. apply Rmult_le_pos; [ | apply Hg].
          by apply SeriesC_ge_0'.
      - eapply ex_seriesC_le ; [ | eapply (pmf_ex_seriesC μ2)].
        intros; split.
        * apply Rmult_le_pos; auto. apply Hg.
        * rewrite <- Rmult_1_r.
          apply Rmult_le_compat_l; auto. apply Hg.
    }
    setoid_rewrite <- SeriesC_scal_r.
    rewrite (fubini_pos_seriesC (λ '(a,n), Rmult (μ (a, n)) (g n))).
    - apply SeriesC_le.
      + intro a; split.
        * apply SeriesC_ge_0'.
          intro.
          apply Rmult_le_pos; auto. apply Hf.
        * apply SeriesC_le.
          ** intro b; split.
             *** apply Rmult_le_pos; auto.
                 apply Hf.
             *** destruct (decide ((μ(a,b) > 0)%R)) as [H3 | H4].
                 **** apply Hs, Hfg in H3.
                      by apply Rmult_le_compat_l.
                 **** apply Rnot_gt_le in H4.
                      replace (μ(a,b)) with 0%R; [ lra | by apply Rle_antisym].
          ** eapply ex_seriesC_le; [ | eapply (ex_seriesC_lmarg μ); eauto ].
             intros; split.
             *** apply Rmult_le_pos; auto.
                 apply Hg.
             *** rewrite <- Rmult_1_r.
                 apply Rmult_le_compat_l; auto.
                 apply Hg.
     + eapply ex_seriesC_le; [ | eapply (fubini_pos_seriesC_prod_ex_lr μ)]; eauto.
       * intro; simpl.
         split.
         ** apply SeriesC_ge_0'.
            intro; apply Rmult_le_pos; auto.
            apply Hg.
         ** apply SeriesC_le.
            *** intro; split.
                **** apply Rmult_le_pos; auto. apply Hg.
                **** rewrite <- Rmult_1_r.
                     apply Rmult_le_compat_l; eauto; eapply Hg.
            *** apply ex_seriesC_lmarg; auto.
    - intros; apply Rmult_le_pos; auto. apply Hg.
    - intros a.
      eapply ex_seriesC_le; [ | eapply (ex_seriesC_lmarg μ a) ]; eauto.
      intros. split.
      + apply Rmult_le_pos; auto. apply Hg.
      + rewrite <- Rmult_1_r. apply Rmult_le_compat_l; auto; apply Hg.
    - eapply ex_seriesC_le; [ | eapply (fubini_pos_seriesC_prod_ex_lr μ)]; eauto.
       + intro; simpl.
         split.
         * apply SeriesC_ge_0'.
           intro; apply Rmult_le_pos; auto.
           apply Hg.
         * apply SeriesC_le.
            ** intro; split.
                *** apply Rmult_le_pos; auto. apply Hg.
                *** rewrite <- Rmult_1_r.
                    apply Rmult_le_compat_l; eauto; eapply Hg.
            ** apply ex_seriesC_lmarg; auto.
  Qed.

  Lemma ARcoupl_exact `{Countable A, Countable B}
    μ1 μ2 (ψ : A → B → Prop) : Rcoupl μ1 μ2 ψ → ARcoupl μ1 μ2 ψ 0.
  Proof using clutchGS0 Σ.
    intros ; by eapply ARcoupl_refRcoupl, Rcoupl_refRcoupl.
  Qed.

  Lemma ARcoupl_rand_r N z (ρ1 : cfg) σ1' :
    N = Z.to_nat z →
    ARcoupl
      (dret ρ1)
      (prim_step (rand #z from #()) σ1')
      (λ ρ2 ρ2', ∃ (n : fin (S N)), ρ2 = ρ1 ∧ ρ2' = (Val #n, σ1')) (nnreal_zero).
  Proof using clutchGS0 Σ.
    intros ?.
    apply ARcoupl_exact.
    by apply Rcoupl_rand_r.
  Qed.

  (* TODO: Can we get this as a lifting of the corresponding exact relational rule? *)

  (** RHS [rand] *)
  Lemma wp_rand_r N z E e K Φ :
    TCEq N (Z.to_nat z) →
    to_val e = None →
    (∀ σ1, reducible e σ1) →
    nclose specN ⊆ E →
    spec_ctx ∗ ⤇ fill K (rand #z from #()) ∗
    (∀ n : fin (S N), ⤇ fill K #n -∗ WP e @ E {{ Φ }})
    ⊢ WP e @ E {{ Φ }}.
  Proof.
    iIntros (-> He HE Hred) "(#Hinv & Hj & Hwp)".
    iApply wp_lift_step_fupd_couple; [done|].
    iIntros (σ1 e1' σ1' ε) "[[Hh1 Ht1] [Hauth2 Herr]]".
    iInv specN as (ρ' e0' σ0' m) ">(Hspec0 & %Hexec & Hauth & Hheap & Htapes)" "Hclose".
    iDestruct (spec_interp_auth_frag_agree with "Hauth2 Hspec0") as %<-.
    iDestruct (spec_prog_auth_frag_agree with "Hauth Hj") as %->.
    iApply fupd_mask_intro; [set_solver|]; iIntros "Hclose'".
    iSplitR ; [done|].
    (* iExists nnreal_zero, ε. iSplitR ; [iPureIntro => /=; lra|]. *)

    (* assert (ε_cont = nnreal_nat 0) as hε_cont by admit. *)
    (*iExists ε_now, ε_cont. iSplitR ; [admit|].*)
    replace (ε) with (nnreal_plus nnreal_zero ε)
      by by apply nnreal_ext => /=; lra.
    iApply exec_coupl_det_r; [done|].
    (* Do a (trivially) coupled [prim_step] on the right *)

    (* Might have to pick a better ε for the continuation here than 0. Can we
       predict this or does it come from Hwp? *)
(*    replace ε_now with (nnreal_plus ε_now nnreal_zero)
      by by apply nnreal_ext => /= ; lra. *)
    iApply (exec_coupl_exec_r).
    iExists (λ _ '(e2', σ2'), ∃ n : fin (S (Z.to_nat z)), (e2', σ2') = (fill K #n, σ0')), 1.
    iSplit.
    { iPureIntro.
      rewrite exec_1.
      replace nnreal_zero with (nnreal_plus nnreal_zero nnreal_zero)
                               by by apply nnreal_ext => /= ; lra.
      rewrite prim_step_or_val_no_val /=; [|by apply fill_not_val].
      rewrite -(dret_id_right (dret _)) fill_dmap //.
      eapply (ARcoupl_dbind _ _ _ _ _ _ _ _) => /=.
      1,2: simpl ; lra.
      2: by eapply ARcoupl_rand_r.
      intros [e2 σ2] (e2' & σ2') (? & [= -> ->] & [= -> ->]).
      apply ARcoupl_dret => /=. eauto. }
    iIntros (σ2 e2' (n & [= -> ->])).
    iMod (spec_interp_update (fill K #n, σ0') with "Hauth2 Hspec0") as "[Hspec Hspec0]".
    iMod (spec_prog_update (fill K #n) with "Hauth Hj") as "[Hauth Hj]".
    simpl.                      (*     simplify_map_eq. *)
    iMod "Hclose'" as "_".
    iMod ("Hclose" with "[Hauth Hheap Hspec0 Htapes]") as "_".
    { iModIntro. rewrite /spec_inv.
      iExists _, _, _, 0. simpl.
      iFrame. rewrite exec_O dret_1_1 //. }
    iSpecialize ("Hwp" with "Hj").
    rewrite !wp_unfold /wp_pre /= He.
    (* replace ε with (nnreal_plus ε nnreal_zero) *)
    (*   by by apply nnreal_ext => /= ; lra. *)
    iMod ("Hwp" $! _ with "[$Hh1 $Hspec $Ht1 $Herr]") as "Hwp".
    replace (nnreal_plus nnreal_zero ε) with (ε)
      by by apply nnreal_ext => /= ; lra.
    iModIntro.
    iDestruct "Hwp" as "[hred Hwp]".
    done.
  Qed.

(*
TODO Adapt the rest of the file below.

  (** RHS [rand(α)] with empty tape  *)
  Lemma wp_rand_empty_r N z E e K α Φ :
    TCEq N (Z.to_nat z) →
    to_val e = None →
    nclose specN ⊆ E →
    spec_ctx ∗ ⤇ fill K (rand #z from #lbl:α) ∗ α ↪ₛ (N; []) ∗
    ((α ↪ₛ (N; []) ∗ spec_ctx ∗ ∃ n : fin (S N), ⤇ fill K #n) -∗ WP e @ E {{ Φ }})
    ⊢ WP e @ E {{ Φ }}.
  Proof.
    iIntros (-> He HE) "(#Hinv & Hj & Hα & Hwp)".
    iApply wp_lift_step_fupd_couple; [done|].
    iIntros (σ1 e1' σ1') "[[Hh1 Ht1] Hauth2]".
    iInv specN as (ρ' e0' σ0' m) ">(Hspec0 & %Hexec & Hauth & Hheap & Htapes)" "Hclose".
    iDestruct (spec_interp_auth_frag_agree with "Hauth2 Hspec0") as %<-.
    iDestruct (ghost_map_lookup with "Htapes Hα") as %Hαsome.
    iDestruct (spec_prog_auth_frag_agree with "Hauth Hj") as %->.
    iApply fupd_mask_intro; [set_solver|]; iIntros "Hclose'".
    iApply exec_coupl_det_r; [done|].
    (* Do a (trivially) coupled [prim_step] on the right *)
    iApply (exec_coupl_exec_r).
    iExists (λ _ '(e2', σ2'), ∃ n : fin (S _), (e2', σ2') = (fill K #n, σ0')), 1.
    iSplit.
    { iPureIntro.
      rewrite exec_1.
      rewrite prim_step_or_val_no_val /=; [|by apply fill_not_val].
      rewrite -(dret_id_right (dret _)) fill_dmap //.
      eapply Rcoupl_dbind => /=; [|by eapply Rcoupl_rand_empty_r].
      intros [e2 σ2] (e2' & σ2') (? & [= -> ->] & [= -> ->]).
      apply Rcoupl_dret=>/=. eauto. }
    iIntros (σ2 e2' (n & [= -> ->])).
    iMod (spec_interp_update (fill K #n, σ0') with "Hauth2 Hspec0") as "[Hspec Hspec0]".
    iMod (spec_prog_update (fill K #n) with "Hauth Hj") as "[Hauth Hj]".
    simplify_map_eq.
    iMod "Hclose'" as "_".
    iMod ("Hclose" with "[Hauth Hheap Hspec0 Htapes]") as "_".
    { iModIntro. rewrite /spec_inv.
      iExists _, _, _, 0. simpl.
      iFrame. rewrite exec_O dret_1_1 //. }
    iSpecialize ("Hwp" with "[$Hα $Hinv Hj]"); [eauto|].
    rewrite !wp_unfold /wp_pre /= He.
    by iMod ("Hwp" $! _ with "[$Hh1 $Hspec $Ht1]") as "Hwp".
  Qed.

    (** RHS [rand(α)] with wrong tape  *)
  Lemma wp_rand_wrong_tape_r N M z E e K α Φ ns :
    TCEq N (Z.to_nat z) →
    N ≠ M →
    to_val e = None →
    nclose specN ⊆ E →
    spec_ctx ∗ ⤇ fill K (rand #z from #lbl:α) ∗ α ↪ₛ (M; ns) ∗
    ((α ↪ₛ (M; ns) ∗ spec_ctx ∗ ∃ n : fin (S N), ⤇ fill K #n) -∗ WP e @ E {{ Φ }})
    ⊢ WP e @ E {{ Φ }}.
  Proof.
    iIntros (-> ? He HE) "(#Hinv & Hj & Hα & Hwp)".
    iApply wp_lift_step_fupd_couple; [done|].
    iIntros (σ1 e1' σ1') "[[Hh1 Ht1] Hauth2]".
    iInv specN as (ρ' e0' σ0' m) ">(Hspec0 & %Hexec & Hauth & Hheap & Htapes)" "Hclose".
    iDestruct (spec_interp_auth_frag_agree with "Hauth2 Hspec0") as %<-.
    iDestruct (ghost_map_lookup with "Htapes Hα") as %Hαsome.
    iDestruct (spec_prog_auth_frag_agree with "Hauth Hj") as %->.
    iApply fupd_mask_intro; [set_solver|]; iIntros "Hclose'".
    iApply exec_coupl_det_r; [done|].
    (* Do a (trivially) coupled [prim_step] on the right *)
    iApply (exec_coupl_exec_r).
    iExists (λ _ '(e2', σ2'), ∃ n : fin (S _), (e2', σ2') = (fill K #n, σ0')), 1.
    iSplit.
    { iPureIntro.
      rewrite exec_1.
      rewrite prim_step_or_val_no_val /=; [|by apply fill_not_val].
      rewrite -(dret_id_right (dret _)) fill_dmap //.
      eapply Rcoupl_dbind => /=; [|by eapply Rcoupl_rand_wrong_r].
      intros [e2 σ2] (e2' & σ2') (? & [= -> ->] & [= -> ->]).
      apply Rcoupl_dret=>/=. eauto. }
    iIntros (σ2 e2' (n & [= -> ->])).
    iMod (spec_interp_update (fill K #n, σ0') with "Hauth2 Hspec0") as "[Hspec Hspec0]".
    iMod (spec_prog_update (fill K #n) with "Hauth Hj") as "[Hauth Hj]".
    simplify_map_eq.
    iMod "Hclose'" as "_".
    iMod ("Hclose" with "[Hauth Hheap Hspec0 Htapes]") as "_".
    { iModIntro. rewrite /spec_inv.
      iExists _, _, _, 0. simpl.
      iFrame. rewrite exec_O dret_1_1 //. }
    iSpecialize ("Hwp" with "[$Hα $Hinv Hj]"); [eauto|].
    rewrite !wp_unfold /wp_pre /= He.
    by iMod ("Hwp" $! _ with "[$Hh1 $Hspec $Ht1]") as "Hwp".
  Qed.

  (** * Corollaries about [refines_right]  *)
  Lemma refines_right_alloctape E K N z :
    TCEq N (Z.to_nat z) →
    nclose specN ⊆ E →
    refines_right K (alloc #z) ={E}=∗ ∃ l, refines_right K (#lbl: l) ∗ l ↪ₛ (N; []).
  Proof.
    iIntros (??) "(?&?)".
    iMod (step_alloctape with "[$]") as (l) "(?&?)"; [done|].
    iExists _; by iFrame.
  Qed.

  Lemma refines_right_rand E K l N z n ns :
    TCEq N (Z.to_nat z) →
    nclose specN ⊆ E →
    l ↪ₛ (N; n :: ns) -∗
    refines_right K (rand #z from #lbl:l) ={E}=∗ refines_right K #n ∗ l ↪ₛ (N; ns).
  Proof.
    iIntros (??) "? (?&?)".
    iMod (step_rand with "[$]") as "(?&?&?)"; [done|].
    iModIntro; iFrame.
  Qed.
*)

End rules.
