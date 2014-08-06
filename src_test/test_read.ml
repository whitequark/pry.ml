let () =
  let ic = open_in Sys.argv.(1) in
  let di = Pry_bytecode.read ic in
  let rec loop events =
    match events with
    | [] -> ()
    | event :: events ->
      Format.printf "%a@." Pry_bytecode.pp_debug_event event;
      loop events
  in
  loop di.Pry_bytecode.di_events
