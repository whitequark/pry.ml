type debug_event = Instruct.debug_event =
  { mutable ev_pos: int;
    ev_module: string;
    ev_loc: Location.t [@printer Location.print_loc];
    ev_kind: debug_event_kind;
    ev_info: debug_event_info;
    ev_typenv: Env.summary [@opaque];
    ev_typsubst: Subst.t [@opaque];
    ev_compenv: Instruct.compilation_env [@opaque];
    ev_stacksize: int;
    ev_repr: debug_event_repr }

and debug_event_kind = Instruct.debug_event_kind =
    Event_before
  | Event_after of Types.type_expr [@printer Printtyp.type_expr]
  | Event_pseudo

and debug_event_info = Instruct.debug_event_info =
    Event_function
  | Event_return of int
  | Event_other

and debug_event_repr = Instruct.debug_event_repr =
    Event_none
  | Event_parent of int ref
  | Event_child of int ref

and debug_events = debug_event list
[@@deriving Show]

let () =
  let ic = open_in "data/fact.byte" in
  let di = Pry_bytecode.read ic in
  print_endline ([%derive.Show: debug_event list] di.Pry_bytecode.di_events)
