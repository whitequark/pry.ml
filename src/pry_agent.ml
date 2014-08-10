open Instruct

type agent_event =
| Event_count
| Breakpoint
| Program_start (* never observed *)
| Program_exit
| Trap_barrier
| Uncaught_exc

type frame = Obj.t * debug_event

external stack_low    : unit -> Obj.t = "pry_stack_low"
external stack_high   : unit -> Obj.t = "pry_stack_high"
external extern_sp    : unit -> Obj.t = "pry_extern_sp"
external trap_sp      : unit -> Obj.t = "pry_trapsp"
external trap_barrier : unit -> Obj.t = "pry_trap_barrier"

external set_instruction   : Obj.t -> int -> unit = "pry_set_instruction"
external reset_instruction : Obj.t -> unit        = "pry_reset_instruction"

external in_bounds    : low:Obj.t -> high:Obj.t -> Obj.t -> bool = "pry_in_bounds"
external pc_to_code   : int -> Obj.t = "pry_pc_to_code"
external pc_of_code   : Obj.t -> int = "pry_pc_of_code"

let debug_events = ref []

let pc_of_frame    frame   = pc_of_code (Obj.field frame 0)
let env_of_frame   frame   = Obj.field frame 1
let extra_of_frame frame   = ((Obj.magic (Obj.field frame 2)) : int)
let local_of_frame frame i = Obj.field frame (3 + i)

let word_size = Sys.word_size / 8
let offset_frame frame words =
  Obj.add_offset frame (Int32.of_int (words * word_size))

let find_event frame =
  !debug_events |> List.find (fun { ev_pos } -> ev_pos = pc_of_frame frame)

let debug_event_of_frame = snd

let up_frame (frame, event) =
  let nlocals = event.ev_stacksize in
  let offset  = (extra_of_frame frame) + 3 + nlocals in
  let frame'  = offset_frame frame offset in
  if in_bounds ~low:(stack_low ()) ~high:(stack_high ()) frame' then
    Some (frame', find_event frame')
  else
    None

let rec iter_frames f frame =
  f frame;
  match up_frame frame with
  | Some frame -> iter_frames f frame
  | None -> ()

let rec fold_frames f acc frame =
  let acc = f acc frame in
  match up_frame frame with
  | Some frame -> fold_frames f acc frame
  | None -> acc

let frame_env (frame, { ev_typenv; ev_typsubst }) =
  Envaux.env_from_summary ev_typenv ev_typsubst

let frame_locals (frame, { ev_compenv }) =
  let keys tbl = Ident.fold_all (fun k _ accu -> k::accu) tbl [] in
  keys ev_compenv.ce_stack @ keys ev_compenv.ce_heap @ keys ev_compenv.ce_rec

let frame_local (frame, { ev_compenv }) ident =
  match Ident.find_same ident ev_compenv.ce_stack with
  | idx -> local_of_frame frame idx
  | exception Not_found ->
    match Ident.find_same ident ev_compenv.ce_heap with
    | idx -> Obj.field (env_of_frame frame) idx
    | exception Not_found ->
      match Ident.find_same ident ev_compenv.ce_rec with
      | idx -> assert false
      | exception (Not_found as exn) -> raise exn

let set_breakpoint { ev_pos } =
  set_instruction (pc_to_code ev_pos) Opcodes.opBREAK

let reset_breakpoint { ev_pos } =
  reset_instruction (pc_to_code ev_pos)

let breakpoint = fun () -> ()

let callback : ([ `Breakpoint ] -> frame -> unit) ref = ref (fun _ _ -> ())

let () =
  set_instruction (Obj.field (Obj.repr breakpoint) 0) Opcodes.opBREAK;
  Callback.register "Pry_agent.callback" (fun agent_event frame ->
    try
      let frame = offset_frame frame 1 in
      match agent_event with
      | Breakpoint -> !callback `Breakpoint (frame, find_event frame)
      | _ -> ()
    with exn ->
      Printf.eprintf "Exception in Pry_agent.callback:\n%s\n"
                     (Printexc.to_string exn);
      Printexc.print_backtrace stderr);
  let debug_info =
    let chan = open_in Sys.executable_name in
    let data = Pry_bytecode.read chan in
    close_in chan;
    data
  in
  debug_events     := debug_info.Pry_bytecode.di_events;
  Config.load_path := Config.standard_library :: debug_info.Pry_bytecode.di_paths;
  Envaux.reset_cache ()
