From clutch.prob_lang.typing Require Import tychk.
From clutch.approxis Require Import approxis map list.
From clutch.approxis.examples Require Import security_aux.
Set Default Proof Using "Type*".


Section bounded_oracle.
  Local Opaque INR.

  (** Bounded Oracles. [q_calls MAX Q f x] calls [f x] for the first [Q] invocations
      if 0 <= x <= MAX, and returns None otherwise. *)
  Definition q_calls_poly (MAX : Z) : val :=
    Λ: λ:"Q" "f",
      let: "counter" := ref #0 in
      λ:"x", if: (BinOp AndOp (! "counter" < "Q") (BinOp AndOp (#0 ≤ "x") ("x" ≤ #MAX)))
             then ("counter" <- !"counter" + #1 ;; SOME ("f" "x"))
             else NONEV.

  Definition q_calls (MAX : Z) : val :=
    λ:"Q" "f",
      let: "counter" := ref #0 in
      λ:"x", if: (BinOp AndOp (! "counter" < "Q") (BinOp AndOp (#0 ≤ "x") ("x" ≤ #MAX)))
             then ("counter" <- !"counter" + #1 ;; SOME ("f" "x"))
             else NONEV.


  Fact q_calls_typed_int (MAX : Z) (B : type) :
    ⊢ᵥ q_calls MAX : (TInt → (TInt → B) → TInt → TOption B)%ty.
  Proof.
    rewrite /q_calls. tychk.
  Qed.

  Fact q_calls_typed_nat (MAX : Z) (B : type) :
    ⊢ᵥ q_calls MAX : (TInt → (TNat → B) → TNat → TOption B).
  Proof.
    rewrite /q_calls.
    type_val 8 ; try by tychk.
    all: type_expr 1 ; try by tychk.
    all: apply Subsume_int_nat. all: tychk.
  Qed.

  Fact q_calls_poly_typed (MAX : Z) :
    (⊢ᵥ q_calls_poly MAX : ∀: (TInt → (TInt → #0) → TInt → TOption #0))%ty.
  Proof.
    rewrite /q_calls_poly.
    apply TLam_val_typed.
    tychk.
  Qed.

End bounded_oracle.

Class MaxCalls := { Q : nat }.
Class DomainUpperBound := { F_MAX : nat }.

Section link.
  Context {max_calls : MaxCalls}.
  Context {upper_bound : DomainUpperBound}.
  Definition compose (g f : expr) := (λ:"x", g (f "x"))%E.
  Definition restr (F : expr) := (q_calls (Q) (Val #F_MAX) F).
  Definition link (A F : expr) := compose A (restr F).
End link.

#[global]
  Hint Unfold compose : core.

(* Infix " ∘ " := link : expr_scope. *)
Infix " ∘ " := compose : expr_scope.
(* Notation "F '^Q'" := (restr F) (at level 9) : expr_scope. *)
(* Notation "F 'ꟴ'" := (restr F) (at level 9, format "F ꟴ") : expr_scope. *)
Notation "F '^q'" := (restr F) (at level 9) : expr_scope.
Notation "F '𐞥'" := (restr F) (at level 9, format "F 𐞥") : expr_scope.

Section link_test.
  Context {max_calls : MaxCalls}.
  Context {upper_bound : DomainUpperBound}.
  Open Scope expr_scope.

  (* Check Q.
     Check (λ A F, (App A (q_calls Q F))).

     Check λ A F G : expr, A (G F).
     Check λ A F G : expr, A ∘ (G ∘ F).
     Check λ A F G : expr, A ((G (F 𐞥))𐞥).
     Check λ A F G : expr, A (G F 𐞥)𐞥.
     Check λ A F G : expr, A ∘ (G ∘ F^q)^q = (A ∘ G^q) ∘ F^q . *)

End link_test.
