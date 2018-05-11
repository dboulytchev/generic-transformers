(*
 * OCanren: syntax extension.
 * Copyright (C) 2016-2017
 *   Dmitrii Kosarev aka Kakadu
 *   Evgeniy Moiseenko aka eucpp
 * St.Petersburg State University, JetBrains Research
 *)

open Base
open HelpersBase
open Ppxlib
open Printf
open Ast_helper

let param_name_mangler = sprintf "%s_2"

module Make(AstHelpers : GTHELPERS_sig.S) = struct

let plugin_name = "gmap"
module P = Plugin.Make(AstHelpers)
open AstHelpers

let hack_params ?(loc=noloc) ps =
  let param_names = map_type_param_names ps ~f:id in
  let rez_names = map_type_param_names ps ~f:param_name_mangler in
  let name_migrations = List.zip_exn param_names rez_names in
  let assoc s =
    try List.Assoc.find_exn ~equal:String.equal name_migrations s
    with Caml.Not_found ->
      raise_errorf "can't find new typ for param `%s" s
  in
  let blownup_params =
    List.concat_map param_names
      ~f:(fun s1 ->
           [named_type_arg ~loc s1; named_type_arg ~loc @@ assoc s1 ]
         )
  in
  (param_names, rez_names, assoc, blownup_params)

let g args = object(self: 'self)
  inherit ['self] P.generator args

  method plugin_name = plugin_name

  method default_inh ~loc _tdecl = Typ.ident ~loc "unit"
  method syn_of_param ~loc s = Typ.var ~loc @@ param_name_mangler s
  method inh_of_param tdecl _name =
    self#default_inh ~loc:(loc_from_caml tdecl.ptype_loc) tdecl

  method default_syn ~loc tdecl =
    let param_names,rez_names,find_param,blownup_params =
      hack_params tdecl.ptype_params
    in
    let ans =
      let cur_name = self#cur_name tdecl in
      let (ident,args) =
          (cur_name, rez_names)
      in
      Typ.constr ~loc (Lident ident) @@
      List.map ~f:(Typ.var ~loc) args
    in
    if is_polyvariant_tdecl tdecl
    then
      Typ.alias ~loc (openize_poly ans) "extra"
      (* [%type: ([> [%t ans]] as 'extra)] *)
    else ans


  method plugin_class_params tdecl =
    (* let loc = tdecl.ptype_loc in *)
    let param_names,_,find_param,blownup_params = hack_params tdecl.ptype_params in
    blownup_params @ [named_type_arg ~loc:(loc_from_caml tdecl.ptype_loc) Plugin.extra_param_name]

  method prepare_inherit_typ_params_for_alias ~loc tdecl rhs_args =
    let _param_names,_rez_names,find_param,_blownup_params =
      hack_params tdecl.ptype_params
    in
    let ps =
      List.concat_map rhs_args ~f:(fun t ->
          let open Ppxlib.Ast_builder.Default in
          [ t
          ; map_core_type t ~onvar:(fun s -> ptyp_var ~loc:t.ptyp_loc (find_param s))  ]
        )
    in
    (List.map ~f:Typ.from_caml ps) @
    [ Typ.ident ~loc Plugin.extra_param_name ]

  (* TODO: refactor next two functions *)
  method! extra_class_sig_members tdecl =
    let loc = loc_from_caml tdecl.ptype_loc in
    if is_polyvariant_tdecl tdecl
    then
      let _param_names,rez_names,_find_param,_blownup_params =
        hack_params tdecl.ptype_params
      in
      let right = Typ.constr ~loc
          (Lident tdecl.ptype_name.txt)
          (List.map ~f:(Typ.var ~loc) rez_names)
      in
      let right = openize_poly right in
      [Ctf.constraint_ ~loc (Typ.ident ~loc Plugin.extra_param_name) right ]
    else []

  method! extra_class_str_members tdecl =
    let loc = loc_from_caml tdecl.ptype_loc in
    if is_polyvariant_tdecl tdecl
    then
      let _param_names,rez_names,_find_param,_blownup_params =
        hack_params tdecl.ptype_params
      in
      let right = Typ.constr ~loc (Lident tdecl.ptype_name.txt)
          (List.map ~f:(Typ.var ~loc) rez_names)
      in
      let right = openize_poly right in
      [Cf.constraint_ ~loc (Typ.ident ~loc Plugin.extra_param_name) right ]
    else []

  method generate_for_polyvar_tag ~loc ~is_self_rec ~mutal_names
      constr_name bindings  einh k =
    k @@ Exp.variant ~loc constr_name @@
    List.map bindings
      ~f:(fun (name, typ) ->
          Exp.app ~loc
            (self#do_typ_gen ~loc ~is_self_rec ~mutal_names typ)
            (Exp.ident ~loc name)
        )

  method on_tuple_constr ~loc ~is_self_rec ~mutal_names tdecl constr_info ts k =
    let names = List.map ts ~f:(fun _ -> gen_symbol ()) in
    let methname = sprintf "c_%s" (match constr_info with `Normal s -> s | `Poly s -> s) in
    k [
      Cf.method_concrete ~loc methname @@
      Exp.fun_ ~loc (Pat.unit ~loc) @@

      Exp.fun_list ~loc
        (List.map names ~f:(Pat.sprintf ~loc "%s"))
        (let ctuple =
           List.map (List.zip_exn names ts)
             ~f:(fun (name, typ) ->
                 self#app_transformation_expr ~loc
                   (self#do_typ_gen ~loc ~is_self_rec ~mutal_names typ)
                   (Exp.assert_false ~loc)
                   (Exp.ident ~loc name)
               )
        in
        (match constr_info with `Normal s -> Exp.construct ~loc (lident s)
                              | `Poly s   -> Exp.variant ~loc s
        )
          ctuple
       )
  ]

  method on_record_declaration ~loc ~is_self_rec ~mutal_names tdecl labs =
    let pat = Pat.record ~loc @@
      List.map labs ~f:(fun l ->
          (Lident l.pld_name.txt, Pat.var ~loc l.pld_name.txt)
        )
    in
    let methname = sprintf "do_%s" tdecl.ptype_name.txt in
    [ Cf.method_concrete ~loc methname @@
      Exp.fun_ ~loc (Pat.unit ~loc) @@

          Exp.fun_ ~loc pat @@
          Exp.record ~loc @@ List.map labs
            ~f:(fun {pld_name; pld_type} ->
                lident pld_name.txt,
                self#app_transformation_expr ~loc
                  (self#do_typ_gen ~loc ~is_self_rec ~mutal_names pld_type)
                  (Exp.assert_false ~loc)
                  (Exp.ident ~loc pld_name.txt)

              )
    ]

end

end