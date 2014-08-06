(** A (mostly) type-safe interface to debugging machinery *)

(** Type of stack frames. *)
type frame

(** [debug_event_of_frame] returns the debugging event corresponding
    to [frame]. *)
val debug_event_of_frame : frame -> Instruct.debug_event

(** [up_frame frame] returns [Some frame'] if there is a parent frame,
    or [None] if [frame] is the topmost one. *)
val up_frame : frame -> frame option

(** [set_breakpoint event] sets a breakpoint at [event].
    [set_breakpoint] is idempotent. *)
val set_breakpoint : Instruct.debug_event -> unit

(** [reset_breakpoint event] removes a breakpoint at [event].
    [reset_breakpoint] is idempotent and does nothing if no
    breakpoint was set. *)
val reset_breakpoint : Instruct.debug_event -> unit

(** [breakpoint] is a function that does nothing and always
    has a breakpoint set at its very beginning. *)
val breakpoint : unit -> unit

(** [callback] is a function that receives debugger events.
    The frame argument must not escape this function. *)
val callback   : ([ `Breakpoint ] -> frame -> unit) ref
