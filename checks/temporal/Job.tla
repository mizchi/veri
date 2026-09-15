------------------------------ MODULE Job ------------------------------
VARIABLES
  \* @type: Bool;
  pending,
  \* @type: Bool;
  done

\* @type: <<Bool, Bool>>;
vars == <<pending, done>>
Init == pending = FALSE /\ done = FALSE

Request ==
  /\ ~pending /\ ~done
  /\ pending' = TRUE /\ done' = FALSE

CanComplete == pending /\ ~done
Complete ==
  /\ CanComplete
  /\ pending' = FALSE /\ done' = TRUE

Drop ==
  /\ CanComplete
  /\ pending' = FALSE /\ done' = FALSE

\* Stuttering is explicit, including the successful terminal state.
Next == Request \/ Complete \/ UNCHANGED vars
DropNext == Next \/ Drop

Safe == ~(pending /\ done)
Response == [](pending => <>done)

\* Manual expansion of WF_vars(Complete). CanComplete is exactly the enabling
\* condition of this state-changing action; it is not an arbitrary assumption.
WeakFairComplete == ([]<>(~CanComplete)) \/ ([]<><<Complete>>_vars)
FairResponse == WeakFairComplete => Response
=============================================================================
