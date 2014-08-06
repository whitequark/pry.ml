type agent_event =
| Event_count
| Breakpoint
| Program_start (* never observed *)
| Program_exit
| Trap_barrier
| Uncaught_exc

type frame = Obj.t * Instruct.debug_event

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
  !debug_events |> List.find (fun { Instruct.ev_pos } -> ev_pos = pc_of_frame frame)

let debug_event_of_frame = snd

let up_frame (frame, event) =
  let nlocals = event.Instruct.ev_stacksize in
  let offset  = (extra_of_frame frame) + 3 + nlocals in
  let frame'  = offset_frame frame offset in
  if in_bounds ~low:(stack_low ()) ~high:(stack_high ()) frame' then
    Some (frame', find_event frame')
  else
    None

let set_breakpoint { Instruct.ev_pos } =
  set_instruction (pc_to_code ev_pos) Opcodes.opBREAK

let reset_breakpoint { Instruct.ev_pos } =
  reset_instruction (pc_to_code ev_pos)

let breakpoint = fun () -> ()

let callback : ([ `Breakpoint ] -> frame -> unit) ref = ref (fun _ _ -> ())

let () =
  set_instruction (Obj.field (Obj.repr breakpoint) 0) Opcodes.opBREAK;
  Callback.register "Pry_agent.callback" (fun agent_event frame ->
    let frame = offset_frame frame 1 in
    match agent_event with
    | Breakpoint -> !callback `Breakpoint (frame, find_event frame)
    | _ -> ());
  let chan = open_in Sys.executable_name in
  debug_events := Pry_bytecode.((read chan).di_events);
  close_in chan
