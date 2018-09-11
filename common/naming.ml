open Base
open Printf

let self_arg_name = "fself"
let gcata_name_for_typ name = Printf.sprintf "gcata_%s" name
let class_name_for_typ name = Printf.sprintf "%s_t" name
let trait_class_name_for_typ ~trait name =
  class_name_for_typ (if String.equal trait ""
                      then name
                      else Printf.sprintf "%s_%s" trait name)
let meth_name_for_constructor = Printf.sprintf "c_%s"
let fix_name ~plugin_name = sprintf "%s_fix"
(* 1st structure is planned to contain transformation function *)
let typ1_for_class_arg ~plugin = sprintf "%s_t_%s_1" plugin
let trf_field ~plugin = sprintf "%s_%s_trf" plugin
(* Should contain object for transforming mutally declared type *)
let typ2_for_class_arg ~plugin_name = sprintf "%s_t_%s_2" plugin_name
let mut_ofield ~plugin = sprintf "%s_o%s_func" plugin
(* Largest. Containt not fully initialized stib class *)
let typ3_for_class_arg ~plugin_name = sprintf "%s_t_%s_3" plugin_name
let mut_oclass_field ~plugin = sprintf "%s_%s_func" plugin

let extra_param_name = "self"
let self_arg_name = "fself"

let make_extra_param = sprintf "%s_%s" extra_param_name


open Ppxlib

let trf_function trait tdecl = Printf.sprintf "%s_%s" trait tdecl.ptype_name.txt
let stub_class_name ~plugin tdecl =
  sprintf "%s_%s_t_stub" plugin tdecl.ptype_name.txt
let make_fix_name ~plugin tdecls =
  assert (List.length tdecls > 0);
  let names = List.map tdecls ~f:(fun t -> t.ptype_name.txt) in
  String.concat ~sep:"_" (plugin :: "fix" :: names)

let name_fix_generated_object ~plugin tdecl =
  sprintf "%s_o_%s" plugin tdecl.ptype_name.txt

let mut_arg_name ~plugin = sprintf "for_%s_%s" plugin
(* let mut_class_stubname ~plugin tdecl =
 *   sprintf "%s_%s_stub" plugin_name tdecl.ptype_name.txt *)

let fix_result tdecl =
  sprintf "fix_result_%s" tdecl.ptype_name.txt