let pp_ident_tbl pp fmt tbl =
  Format.fprintf fmt "{@[<hov> ";
  tbl |> Ident.iter (fun id x ->
    Format.fprintf fmt "%s.%d => %a;@ " id.Ident.name id.Ident.stamp pp x);
  Format.fprintf fmt " @]}"

type compilation_env = Instruct.compilation_env =
  { ce_stack: int Ident.tbl [@polyprinter pp_ident_tbl];
    ce_heap: int Ident.tbl [@polyprinter pp_ident_tbl];
    ce_rec: int Ident.tbl [@polyprinter pp_ident_tbl] }

and debug_event = Instruct.debug_event =
  { mutable ev_pos: int;
    ev_module: string;
    ev_loc: Location.t [@printer Location.print_loc];
    ev_kind: debug_event_kind;
    ev_info: debug_event_info;
    ev_typenv: Env.summary [@opaque];
    ev_typsubst: Subst.t [@opaque];
    ev_compenv: compilation_env;
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

[@@deriving Show]

let compare_debug_event { ev_pos = a } { ev_pos = b } =
  compare a b
