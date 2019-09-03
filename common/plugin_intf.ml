(** Base class type that all trait should follow.

    For single type declaration

    [
    type ('a, 'b, ...) typ = ...
    ]

    plugin generate a {i plugin class} called [traitnname_typ_t] and
    a {i transformation function} called [traitname_t].

    Generated transformation functions can make use of inherited attribute for type
    parameter (which is being generated by method {!method:typ_g#inh_of_param})
    or simply ignore it.
    For example, transformation function for type parameter ['a] can have types
    either ['a -> 'sa] (see plugins {!Show} and {!Gmap} as examples) or
    ['ia -> 'a -> 'sa].
*)

type plugin_args = (Ppxlib.longident * Ppxlib.expression) list
(** A type that stores additional arguments passed to each plugin. *)

(** Base class type for all plugins.

    Is parametrized by output AST types for convenience. All plugins receive input data as
    OCaml AST and return pieces specific for backend.

*)
class virtual ['loc, 'exp, 'typ, 'type_arg, 'ctf, 'cf, 'str, 'sign ] typ_g = object

  (** {1 Methods that are specific for a concrete plugin implementation } *)

  (* They are very likely will need to be implemented when new plugin is added. *)

  (** Name of a trait (and of plugin too). It is used for constructing new classes and
    * functions related to plugin.
    *)
  method virtual trait_name : string

  (** Inherited attribute for whole type declaration. Is is defined by plugin kind. *)
  method virtual inh_of_main : loc:'loc -> Ppxlib.type_declaration -> 'typ

  (** Synthesized attribute for whole type declaration. Is is defined by plugin kind. *)
  method virtual syn_of_main : loc:'loc -> ?in_class:bool ->
    Ppxlib.type_declaration -> 'typ

  (** [syn_of_param ~loc name] constructs synthethized attribute for type paramter [name]. *)
  method virtual syn_of_param : loc:'loc -> string -> 'typ

  (** [inh_of_param ~loc tdecl name ] constructs inherited attribute for type parameter [name]. *)
  method virtual inh_of_param : loc:'loc -> Ppxlib.type_declaration -> string -> 'typ

  (** The parameters that the plugin class will have in its definition.
    * Add ['extra] manually if needed. *)
  method virtual plugin_class_params: Ppxlib.type_declaration -> 'type_arg list

  (** Arguments of inherit class field that will be generated using the types
      applied in the RHS of type definition. *)
  method virtual alias_inherit_type_params: loc:'loc ->
    Ppxlib.type_declaration -> Ppxlib.core_type list -> 'typ list

  (* These methods will be implemented in plugin.ml *)

  (** Adds a few extra members to a plugin class. Could be some constraints that are
      difficult to add in place where type parameters are declared. *)
  method virtual extra_class_sig_members: Ppxlib.type_declaration -> 'ctf list
  (** The same as [extra_class_sig_members] but for structures. *)
  method virtual extra_class_str_members: Ppxlib.type_declaration -> 'cf  list

  (** {1 Methods that are specific for all plugins and unlikely will need to be override } *)

  (** Generate signature items for single type definition. *)
  method virtual do_single_sig :
    loc:'loc ->
    is_rec:bool ->
    Ppxlib.type_declaration ->
    'sign list

  (** Generate structure items for single type definition. *)
  method virtual do_single :
    loc:'loc ->
    is_rec:bool ->
    Ppxlib.type_declaration ->
    'str list

  (** Generate structure items a type extension. Beta feature. *)
  (* method virtual do_typext_str: loc:'loc -> Ppxlib.type_extension -> 'str list *)

  (** Generate name for transformation function. *)
  method virtual make_trans_function_name: Ppxlib.type_declaration -> string
  (** Generate type of a transformation function. *)
  method virtual make_trans_function_typ : loc:'loc -> Ppxlib.type_declaration -> 'typ

  (** Generate structure items for mutally recursive type declarations. *)
  method virtual do_mutuals :
    loc:'loc ->
    is_rec:bool ->
    Ppxlib.type_declaration list -> 'str list

  method virtual do_mutuals_sigs : loc:'loc -> is_rec:bool -> 'sign list


  method virtual need_inh_attr : bool

  method virtual eta_and_exp: center:'exp -> Ppxlib.type_declaration -> 'exp
  method virtual make_final_trans_function_typ : loc:'loc -> Ppxlib.type_declaration -> 'typ

end

(** Functor that takes AST construction functions for a specific backend and
    constructs a plugin object. *)
module Make(AstHelpers : GTHELPERS_sig.S) = struct
  open AstHelpers

  class virtual g = object
    inherit [loc, Exp.t, Typ.t, type_arg, Ctf.t, Cf.t, Str.t, Sig.t] typ_g
  end
end


module type MAKE =
  functor (AstHelpers : GTHELPERS_sig.S) ->
  sig
    open AstHelpers
    val trait_name : string
    val create : plugin_args -> Ppxlib.type_declaration list ->
      (loc, Exp.t, Typ.t, type_arg, Ctf.t, Cf.t, Str.t, Sig.t) typ_g
  end
