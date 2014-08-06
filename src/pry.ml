let breakpoint = Pry_agent.breakpoint

let callback `Breakpoint frame =
  let rec loop frame =
    let event = Pry_agent.debug_event_of_frame frame in
    (* Format.printf "%a@." Pry_bytecode.pp_debug_event event; *)
    Format.printf "%a@." Location.print_loc event.Instruct.ev_loc;
    match Pry_agent.up_frame frame with
    | Some frame -> loop frame
    | None -> Format.printf "(end of backtrace)@."
  in
  loop frame

let () =
  Pry_agent.callback := callback
