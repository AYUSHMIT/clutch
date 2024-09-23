(** * Hocap rand specs *)
From clutch.coneris Require Import coneris hocap.

Set Default Proof Using "Type*".


Class rand_spec `{!conerisGS Σ} := RandSpec
{
  (** * Operations *)
  rand_allocate_tape : val;
  rand_tape : val;
  (** * Ghost state *)
  (** The assumptions about [Σ] *)
  randG : gFunctors → Type;
  
  rand_error_name : Type;
  rand_tape_name: Type;
  (** * Predicates *)
  is_rand {L : randG Σ} (N:namespace)
    (γ1: rand_error_name) (γ2: rand_tape_name): iProp Σ;
  rand_error_auth {L : randG Σ} (γ: rand_error_name) (x:R): iProp Σ;
  rand_error_frag {L : randG Σ} (γ: rand_error_name) (x:R): iProp Σ;
  rand_tapes_auth {L : randG Σ} (γ: rand_tape_name) (m:gmap loc (nat * list nat)): iProp Σ;
  rand_tapes_frag {L : randG Σ} (γ: rand_tape_name) (α:loc) (ns: (nat * list nat)): iProp Σ;
  (** * General properties of the predicates *)
  #[global] is_rand_persistent {L : randG Σ} N γ1 γ2 ::
    Persistent (is_rand (L:=L) N γ1 γ2);
  #[global] rand_error_auth_timeless {L : randG Σ} γ x ::
    Timeless (rand_error_auth (L:=L) γ x);
  #[global] rand_error_frag_timeless {L : randG Σ} γ x ::
    Timeless (rand_error_frag (L:=L) γ x);
  #[global] rand_tapes_auth_timeless {L : randG Σ} γ m ::
    Timeless (rand_tapes_auth (L:=L) γ m);
  #[global] rand_tapes_frag_timeless {L : randG Σ} γ α ns ::
    Timeless (rand_tapes_frag (L:=L) γ α ns);
  #[global] rand_error_name_inhabited::
    Inhabited rand_error_name;
  #[global] rand_tape_name_inhabited::
    Inhabited rand_tape_name;

  rand_error_auth_exclusive {L : randG Σ} γ x1 x2:
    rand_error_auth (L:=L) γ x1 -∗ rand_error_auth (L:=L) γ x2 -∗ False;
  rand_error_frag_split {L : randG Σ} γ (x1 x2:nonnegreal):
  rand_error_frag (L:=L) γ x1 ∗ rand_error_frag (L:=L) γ x2 ⊣⊢
  rand_error_frag (L:=L) γ (x1+x2)%R ;
  rand_error_auth_valid {L : randG Σ} γ x:
    rand_error_auth (L:=L) γ x -∗ ⌜(0<=x<1)%R⌝;
  rand_error_frag_valid {L : randG Σ} γ x:
    rand_error_frag (L:=L) γ x -∗ ⌜(0<=x<1)%R⌝;
  rand_error_ineq {L : randG Σ} γ x1 x2:
    rand_error_auth (L:=L) γ x1 -∗ rand_error_frag (L:=L) γ x2 -∗ ⌜(x2 <= x1)%R ⌝;
  rand_error_decrease {L : randG Σ} γ (x1 x2:nonnegreal):
     rand_error_auth (L:=L) γ x1 -∗ rand_error_frag (L:=L) γ x2 ==∗ rand_error_auth (L:=L) γ (x1-x2)%R;
  rand_error_increase {L : randG Σ} γ (x1 x2:nonnegreal):
    (x1+x2<1)%R -> ⊢ rand_error_auth (L:=L) γ x1 ==∗
    rand_error_auth (L:=L) γ (x1+x2) ∗ rand_error_frag (L:=L) γ x2;

  rand_tapes_auth_exclusive {L : randG Σ} γ m m':
  rand_tapes_auth (L:=L) γ m -∗ rand_tapes_auth (L:=L) γ m' -∗ False;
  rand_tapes_frag_exclusive {L : randG Σ} γ α ns ns':
  rand_tapes_frag (L:=L) γ α ns -∗ rand_tapes_frag (L:=L) γ α ns' -∗ False;
  rand_tapes_agree {L : randG Σ} γ α m ns:
  rand_tapes_auth (L:=L) γ m -∗ rand_tapes_frag (L:=L) γ α ns -∗ ⌜ m!! α = Some (ns) ⌝;
  rand_tapes_valid {L : randG Σ} γ1 γ2 α N E tb ns:
    ⌜↑N⊆E⌝ ∗ is_rand (L:=L) N γ1 γ2 ∗ rand_tapes_frag (L:=L) γ2 α (tb, ns) ={E}=∗
    ⌜Forall (λ n, n<=tb)%nat ns⌝;
  rand_tapes_update {L : randG Σ} γ α m ns ns':
    rand_tapes_auth (L:=L) γ m -∗ rand_tapes_frag (L:=L) γ α ns ==∗
    rand_tapes_auth (L:=L) γ (<[α := ns']> m) ∗ rand_tapes_frag (L:=L) γ α ns';

  (** * Program specs *)
  rand_inv_create_spec {L : randG Σ} N E:
  ⊢ wp_update E (∃ γ1 γ2, is_rand (L:=L) N γ1 γ2);
  rand_err_convert_spec1 {L : randG Σ} N E ε γ1 γ2:
  ↑N ⊆ E->
  is_rand (L:=L) N γ1 γ2 -∗
  ↯ ε -∗
  wp_update E (rand_error_frag (L:=L) γ1 ε);
  rand_err_convert_spec2 {L : randG Σ} N E ε γ1 γ2:
  ↑N ⊆ E->
  is_rand (L:=L) N γ1 γ2 -∗
  rand_error_frag (L:=L) γ1 ε -∗
  wp_update E (↯ ε);
  rand_allocate_tape_spec {L: randG Σ} N E (tb:nat) γ1 γ2:
    ↑N ⊆ E->
    {{{ is_rand (L:=L) N γ1 γ2 }}}
      rand_allocate_tape #tb @ E
      {{{ (v:val), RET v;
          ∃ (α:loc), ⌜v=#lbl:α⌝ ∗ rand_tapes_frag (L:=L) γ2 α (tb, [])
      }}};
  rand_tape_spec_some {L: randG Σ} N E γ1 γ2 (P: iProp Σ) (Q:iProp Σ) (α:loc) (n:nat) (tb:nat) ns:
    ↑N⊆E ->
    {{{ is_rand (L:=L) N γ1 γ2 ∗
        □ (∀ (m:gmap loc (nat * list nat)), P ∗
           rand_tapes_auth (L:=L) γ2 m
            ={E∖↑N}=∗ ⌜m!!α=Some (tb, n::ns)⌝ ∗ Q ∗ rand_tapes_auth (L:=L) γ2 (<[α:=(tb, ns)]> m)) ∗
        P
    }}}
      rand_tape #lbl:α #tb @ E
                       {{{ RET #n; Q }}}; 
  rand_presample_spec {L: randG Σ} N E ns α (tb:nat)
     (ε2 : list (fin (S tb)) -> R)
    (P : iProp Σ) num T γ1 γ2 ε :
    ↑N ⊆ E ->
    (∀ l, length l = num ->  0<= ε2 l)%R ->
    (SeriesC (λ l, if bool_decide (l ∈ enum_uniform_fin_list tb num) then ε2 l else 0) /((S tb)^num) <= ε)%R->
    is_rand (L:=L) N γ1 γ2 -∗
    (□∀ (ε':R) ns', (P ∗ rand_error_auth (L:=L) γ1 (ε')%R ∗ ⌜length ns' = num⌝) ={E∖↑N}=∗
                  ∃ diff: R, ⌜(0<=diff)%R⌝ ∗ ⌜(ε' = ε+diff)%R⌝ ∗  
        (⌜(1<=ε2 ns' + diff)%R⌝ ∨ (rand_error_auth (L:=L) γ1 (ε2 ns' + diff)%R ∗ T ns')))
        -∗
    P -∗ rand_tapes_frag (L:=L) γ2 α (tb, ns)-∗
        wp_update E (∃ n, T n ∗ rand_tapes_frag (L:=L) γ2 α (tb, ns++(fin_to_nat <$> n)))
}.

Section impl.
  Local Opaque INR.
  (* (** Instantiate rand *) *)
  Class randG1 Σ := RandG1 { flipG1_error::hocap_errorGS Σ;
                             flipG1_tapes:: hocap_tapesGS Σ;
                      }.
  Local Definition rand_inv_pred1 `{!conerisGS Σ, !hocap_errorGS Σ, !hocap_tapesGS Σ} γ1 γ2:=
    (∃ (ε:R) (m:gmap loc (nat * list nat)) ,
        ↯ ε ∗ ●↯ ε @ γ1  ∗
        ([∗ map] α ↦ t ∈ m, α ↪N ( t.1 ; t.2 )) ∗
        ●m@γ2
    )%I.

  #[local] Program Definition rand_spec1 `{!conerisGS Σ}: rand_spec :=
    {| rand_allocate_tape:= (λ: "N", alloc "N");
      rand_tape:= (λ: "α" "N", rand("α") "N"); 
      randG := randG1;
      rand_error_name := gname;
      rand_tape_name := gname;
      is_rand _ N γ1 γ2 := inv N (rand_inv_pred1 γ1 γ2);
      rand_error_auth _ γ x := ●↯ x @ γ;
      rand_error_frag _ γ x := ◯↯ x @ γ;
      rand_tapes_auth _ γ m := (●m@γ)%I;
      rand_tapes_frag _ γ α ns := (α ◯↪N (ns.1; ns.2) @ γ)%I;
    |}.
  Next Obligation.
    simpl.
    iIntros.
    iApply (hocap_error_auth_exclusive with "[$][$]").
  Qed.
  Next Obligation.
    simpl.
    iIntros.
    iApply (hocap_error_frag_split).
  Qed.
  Next Obligation.
    simpl.
    iIntros (?????) "H".
    iApply (hocap_error_auth_valid with "[$]").
  Qed.
  Next Obligation.
    simpl.
    iIntros (?????) "H".
    iApply (hocap_error_frag_valid with "[$]").
  Qed.
  Next Obligation.
    simpl.
    iIntros (??????) "H1 H2".
    iApply (hocap_error_ineq with "[$][$]").
  Qed.
  Next Obligation.
    iIntros.
    iApply (hocap_error_decrease with "[$][$]"). 
  Qed.
  Next Obligation.
    iIntros.
    by iApply (hocap_error_increase with "[$]").
  Qed.
  Next Obligation.
    simpl.
    iIntros (??????) "H1 H2".
    by iDestruct (ghost_map_auth_valid_2 with "[$][$]") as "[%H _]".
  Qed.
  Next Obligation.
    simpl.
    iIntros (???????) "H1 H2".
    iDestruct (ghost_map_elem_frac_ne with "[$][$]") as "%"; last done.
    rewrite dfrac_op_own dfrac_valid_own. by intro.
  Qed.
  Next Obligation.
    simpl.
    iIntros (??????[]) "??".
    by iDestruct (hocap_tapes_agree with "[$][$]") as "%H".
  Qed.
  Next Obligation.
    simpl.
    iIntros (??????????) "(%&#Hinv&?)".
    iInv "Hinv" as ">(%&%&?&?&?&?)" "Hclose".
    iDestruct (hocap_tapes_agree with "[$][$]") as "%".
    iDestruct (big_sepM_lookup_acc with "[$]") as "[H H']"; first done.
    iDestruct (tapeN_ineq with "[$]") as "%".
    iMod ("Hclose" with "[-]"); last done.
    iFrame.
    by iApply "H'".
  Qed.
  Next Obligation.
    iIntros (???????[]) "??".
    iMod (hocap_tapes_update with "[$][$]") as "[??]".
    by iFrame.
  Qed.
  Next Obligation.
    simpl.
    iIntros (?????).
    iApply fupd_wp_update_ret.
    unshelve iMod (hocap_error_alloc (nnreal_zero)) as "(%γ1 & ? & ?)"; simpl; [rewrite INR_0; lra|].
    iMod ec_zero as "?".
    iMod (hocap_tapes_alloc ∅) as "(%γ2 & H4 & H5)".
    iMod (inv_alloc _ _ (rand_inv_pred1 γ1 γ2) with "[-]").
    { iFrame. by iNext. }
    by iFrame.
  Qed.
  Next Obligation.
    simpl.
    iIntros (????? ε ???) "#Hinv Herr".
    iApply fupd_wp_update_ret.
    iInv "Hinv" as ">(%ε'&%&H1&?&?&?)" "Hclose".
    iDestruct (ec_valid with "[$Herr]") as "%".
    iCombine "Herr H1" as "?".
    iDestruct (ec_valid with "[$]") as "[% %]".
    simpl in *.
    unshelve iMod (hocap_error_increase _ _ (mknonnegreal ε _) with "[$]") as "[? Hfrag]"; [naive_solver|simpl;lra|].
    simpl.
    iMod ("Hclose" with "[-Hfrag]") as "_"; last done.
    iFrame. iApply (ec_eq with "[$]"). lra.
  Qed.
  Next Obligation. 
    simpl.
    iIntros (????? ε ???) "#Hinv Herr".
    iApply fupd_wp_update_ret.
    iInv "Hinv" as ">(%ε'&%&H1&?&?&?)" "Hclose".
    iDestruct (hocap_error_frag_valid with "[$]") as "%".
    iDestruct (ec_valid with "[$]") as "%".
    iDestruct (hocap_error_ineq with "[$][$]") as "%".
    unshelve iMod (hocap_error_decrease with "[$][$]") as "?".
    iDestruct (ec_eq with "[$]") as "?"; last first.
    { iDestruct (ec_split with "[$]") as "[? H]"; last first.
      - iMod ("Hclose" with "[-H]") as "_"; last done.
        iFrame.
      - naive_solver.
      - lra.
    }
    lra.
  Qed.
  Next Obligation.
    simpl.
    iIntros (????????? Φ) "#Hinv HΦ".
    wp_pures.
    iInv "Hinv" as "(%&%&?&?&?&?)" "Hclose".
    wp_apply (wp_alloc_tape); first done.
    iIntros (α) "Hα".
    iDestruct (hocap_tapes_notin with "[$][$]") as "%".
    iMod (hocap_tapes_new _ _ α tb [] with "[$]") as "[?H]"; first done.
    iMod ("Hclose" with "[-H HΦ]").
    { iModIntro. iFrame.
      rewrite big_sepM_insert; [iFrame|done].
    }
    iApply "HΦ".
    by iFrame.
  Qed.
  Next Obligation.
    simpl.
  Admitted.
  Next Obligation.
    simpl.
  Admitted.
  
  
End impl.

