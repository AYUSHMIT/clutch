From iris.algebra Require Import frac_auth.
From iris.base_logic.lib Require Import invariants.
From clutch.coneris Require Import coneris hocap.

Set Default Proof Using "Type*".

Section impl1.

  Definition new_counter : val:= λ: "_", ref #0.
  Definition incr_counter : val := λ: "l", let: "n" := rand #3 in (FAA "l" "n", "n").
  Definition allocate_tape : val := λ: "_", AllocTape #3.
  Definition incr_counter_tape :val := λ: "l" "α", let: "n" := rand("α") #3 in (FAA "l" (rand("α") #3), "n").

  Context `{!conerisGS Σ, !hocap_errorGS Σ, !hocap_tapesGS Σ, !inG Σ (frac_authR ZR)}.
  Definition counter_inv_pred (c:val) γ1 γ2 γ3:=
    (∃ (ε:R) m (l:loc) (z:Z),
        ↯ ε ∗ ●↯ ε @ γ1 ∗
        [∗ map] α ↦ t ∈ m, α ↪N ( t.1 ; t.2 ) ∗ ●m@γ2 ∗  
        ⌜c=#l⌝ ∗ l ↦ #z ∗ own γ3 (●F z)
    )%I.

  Definition counter_nroot := nroot.@"counter".

  Lemma new_counter_spec ε:
    {{{ ↯ ε }}}
      new_counter #()
      {{{ (c:val), RET c;
          ∃ γ1 γ2 γ3, inv counter_nroot (counter_inv_pred c γ1 γ2 γ3) ∗
                      ◯↯ε @ γ1 ∗ own γ3 (◯F 0%Z)
      }}}.
  Proof.
    rewrite /new_counter.
    iIntros (Φ) "Hε HΦ".
    wp_pures.
    wp_alloc l as "Hl".
    iDestruct (ec_valid with "[$]") as "%".
    unshelve iMod (hocap_error_alloc (mknonnegreal ε _)) as "[%γ1 [??]]".
    { lra. }
    simpl.
  Abort.
    
  
End impl1.
