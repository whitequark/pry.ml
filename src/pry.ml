open CamomileLibraryDyn
open React

type ui_context = {
  ui_term    : LTerm.t;
  ui_history : LTerm_history.t;

  ui_frame   : Pry_agent.frame;
}

let make_prompt size =
  LTerm_text.(eval [
    B_bold true; S "# "; B_bold false;
  ])

let lexbuf_of_string eof str =
  let pos = ref 0 in
  let lexbuf =
    Lexing.from_function
      (fun buf len ->
        if !pos = String.length str then begin
          eof := true;
          0
        end else begin
          let len = min len (String.length str - !pos) in
          String.blit str !pos buf 0 len;
          pos := !pos + len;
          len
        end)
  in
  Location.init lexbuf "//toplevel//";
  lexbuf

let parse ?(allow_eof=true) input =
  let eof    = ref false in
  let lexbuf = lexbuf_of_string eof input in
  match Parse.toplevel_phrase lexbuf with
  | result -> `Ok result
  | exception _ when !eof && allow_eof -> `More
  | exception exn ->
    match Location.error_of_exn exn with
    | Some error -> `Error error
    | None -> raise exn

let range_of_loc ?(subtract_bol=false) loc =
  let base = if subtract_bol then loc.Location.loc_start.Lexing.pos_bol else 0 in
  (loc.Location.loc_start.Lexing.pos_cnum - base,
   loc.Location.loc_end.Lexing.pos_cnum - base)

let extract_code loc =
  let { Lexing.pos_fname; pos_bol; pos_cnum } = loc.Location.loc_start
  and { Lexing.pos_cnum = pos_cnum' } = loc.Location.loc_end in
  let chan = open_in pos_fname in
  seek_in chan pos_bol;
  let fragment = really_input_string chan (pos_cnum' - pos_cnum) in
  let pos = pos_in chan in
  let fragment' =
    try  input_line chan
    with End_of_file ->
      seek_in chan pos;
      really_input_string chan (in_channel_length chan - pos)
  in
  fragment ^ fragment'

let restyle styled (lft, rgt) f =
  for i = lft to rgt - 1 do
    let ch, style = styled.(i) in
    styled.(i) <- (ch, f style)
  done

class read_line { ui_term; ui_history; ui_frame } = object(self)
  inherit [[ `Ok of Parsetree.toplevel_phrase | `Error of Location.error]]
          LTerm_read_line.engine ~history:(LTerm_history.contents ui_history) () as super
  inherit [[ `Ok of Parsetree.toplevel_phrase | `Error of Location.error]]
          LTerm_read_line.term ui_term as super_term

  val mutable return_value = None

  method eval =
    match return_value with
    | Some x -> x
    | None   -> assert false

  method exec actions =
    match actions with
    | LTerm_read_line.Accept :: actions
        when S.value self#mode = LTerm_read_line.Edition ->
      begin
        Zed_macro.add self#macro LTerm_read_line.Accept;
        (* Try to parse the input. *)
        let input = Zed_rope.to_string (Zed_edit.text self#edit) in
        match parse input with
        | (`Ok _ | `Error _) as result ->
          return_value <- Some result;
          LTerm_history.add ui_history input;
          Lwt.return result
        | `More ->
          (* Input not finished, continue. *)
          self#insert (Camomile.UChar.of_char '\n');
          self#exec actions
      end
    | actions -> super_term#exec actions

  method stylise last =
    let styled, position = super#stylise last in
    match return_value with
    | Some (`Error error) ->
      let rec collect_loc error =
        error.Location.loc ::
        List.concat (List.map collect_loc error.Location.sub)
      in
      error |> collect_loc |> List.map range_of_loc |>
      List.iter (fun range ->
        restyle styled range (fun style -> { style with LTerm_style.underline = Some true }));
      styled, position
    | _ ->
      styled, position

  method show_box =
    false

  initializer
    self#set_prompt (S.l1 (fun size -> make_prompt size) self#size)
end

let rec repl ({ ui_term; ui_history; ui_frame } as context) =
  match%lwt (new read_line context)#run with
  | exception Sys.Break ->
    let%lwt () = LTerm.fprintl ui_term "Interrupted." in
    repl context
  | exception LTerm_read_line.Interrupt -> (* ^D *)
    Lwt.return_unit
  | `Error error ->
    let rec print_error fmt { Location.msg; if_highlight; sub; } =
      Format.pp_print_string fmt (if if_highlight <> "" then if_highlight else msg);
      sub |> List.iter (fun err -> Format.fprintf fmt "@\n@[<2>%a@]" print_error err)
    in
    let desc = Format.asprintf "@[%a@]@." print_error error in
    LTerm.fprintl ui_term desc >>
    repl context
  | `Ok (Parsetree.Ptop_dir ("backtrace", Parsetree.Pdir_none)) ->
    Pry_agent.fold_frames (fun thr frame ->
        let { Instruct.ev_loc } = Pry_agent.debug_event_of_frame frame in
        let desc  = LTerm_text.of_string (Format.asprintf "%a:@." Location.print_loc ev_loc) in
        let code  = LTerm_text.of_string (extract_code ev_loc ^ "\n") in
        let range = range_of_loc ~subtract_bol:true ev_loc in
        restyle code range (fun style -> { style with LTerm_style.underline = Some true });
        thr >> LTerm.fprints ui_term (Array.append desc code))
      Lwt.return_unit ui_frame >>
    repl context
  | `Ok phrase ->
    (* let idents = Pry_agent.frame_locals frame in
    let n  = List.find (fun { Ident.name } -> name = "n") idents in
    let nv = Pry_agent.frame_local frame n in
    let env = Pry_agent.frame_env frame in
    let vd = Env.find_value (Path.Pident n) env in
    Printf.printf "n=%d\n" (Obj.magic nv) *)
    repl context

let callback `Breakpoint frame =
  (* skip breakpoint *)
  let frame =
    match Pry_agent.up_frame frame with
    | Some frame -> frame
    | None -> assert false
  in
  Lwt_main.run (
    LTerm_inputrc.load () >>
    let%lwt ui_term = Lazy.force LTerm.stdout in
    let history_file = Filename.concat LTerm_resources.home ".pry-ml-history" in
    let ui_context = { ui_term; ui_history = LTerm_history.create []; ui_frame = frame } in
    LTerm_history.load ui_context.ui_history history_file >>
    repl ui_context >>
    LTerm_history.save ui_context.ui_history history_file)

let breakpoint = Pry_agent.breakpoint

let () =
  Pry_agent.callback := callback
