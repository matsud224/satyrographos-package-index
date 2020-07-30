(*
 * before running this program...
 *   1. Clone 'satyrographos-repo' in current directory.
 *   2. Install 'satyrographos-snapshot-stable' via opam.
 *   3. Run 'satyrographos install'.
 *   4. Copy '.satysfi/dist/docs' in current directory.
 *)

let package_root = "./satyrographos-repo/packages"
let doc_root = "./docs"

type package_type =
  Library | Class | Font | Document | Satysfi | Satyrographos | Other

type package_info = {
  name           : string;
  pkg_type       : package_type;
  synopsis       : string;
  description    : string;
  maintainer     : string;
  license        : string;
  homepage       : string;
  latest_version : string;
  dependencies   : string;
  documents      : string list;
  has_docpackage : bool;
}

let string_of_package_type t =
  match t with
  | Library       -> "Library"
  | Class         -> "Class"
  | Font          -> "Font"
  | Document      -> "Document"
  | Satysfi       -> "Satysfi"
  | Satyrographos -> "Satyrographos"
  | Other         -> "Other"

let remove_head n str = String.sub str n ((String.length str) - n)

let get_package_list () =
  Sys.readdir package_root |> Array.to_list

let get_version_list name =
  let pkgname_part_len = String.length (name ^ ".") in
  let dirs = Sys.readdir (Filename.concat package_root name) |> Array.to_list in
  List.map (remove_head pkgname_part_len) dirs |> List.sort (fun a b -> String.compare b a)

let get_package_type name =
  let open Str in
  let regexp_type_pair = [
    (regexp ".*-doc$",           Document);
    (regexp "^satysfi-class-.*", Class);
    (regexp "^satysfi-fonts-.*", Font);
    (regexp "^satysfi$",         Satysfi);
    (regexp "^satyrographos.*",  Satyrographos);
    (regexp "^satysfi-.*",       Library)
  ] in
  let rec iter lst =
    match lst with
    | [] -> Other
    | (r, t) :: rest ->
        if string_match r name 0 then
          t
        else
          iter rest
  in
  iter regexp_type_pair

let find_variable_in_opamfile ofile name =
  let open OpamParserTypes in
  let rec iter ilst =
    match ilst with
    | [] -> None
    | Variable(_, nm, value) :: rest ->
        if String.compare nm name == 0 then
          Some(value)
        else
          iter rest
    | _ :: rest -> iter rest
  in
  iter ofile.file_contents

let find_string_variable_in_opamfile ofile name =
  match find_variable_in_opamfile ofile name with
  | Some(String(_, strval)) -> Some(strval)
  | _                       -> None

let get_depends_info_in_opamfile ofile =
  match find_variable_in_opamfile ofile "depends" with
  | Some(List(_, vallst)) -> Some(String.concat ", " (List.map OpamPrinter.value vallst))
  | _                     -> None

let json_of_package_info info =
  `Assoc [
    ("name",           `String info.name);
    ("type",           `String (string_of_package_type info.pkg_type));
    ("synopsis",       `String info.synopsis);
    ("description",    `String info.description);
    ("maintainer",     `String info.maintainer);
    ("license",        `String info.license);
    ("homepage",       `String info.homepage);
    ("latest_version", `String info.latest_version);
    ("dependencies",   `String info.dependencies);
    ("document",       `List (List.map (fun s -> `String s) info.documents));
    ("has_docpackage", `Bool info.has_docpackage);
  ]

let json_of_package_info_list ilst =
  `Assoc [("data", `List (List.map json_of_package_info ilst))]

let dir_is_empty dir =
  Array.length (Sys.readdir dir) = 0

let dir_contents dir =
  let rec loop result = function
    | f::fs when Sys.is_directory f ->
          Sys.readdir f
          |> Array.to_list
          |> List.map (Filename.concat f)
          |> List.append fs
          |> loop result
    | f::fs -> loop (f::result) fs
    | []    -> result
  in
    loop [] [dir]

let get_docfile_list name =
  let open Str in
  if string_match (regexp "^satysfi-\\(.*-doc$\\)") name 0 then
    let doc_dir_name = matched_group 1 name in
    let doc_path = doc_root ^ "/" ^ doc_dir_name in
    if Sys.file_exists doc_path && Sys.is_directory doc_path then
      dir_contents doc_path |> List.sort String.compare
    else
      []
  else
    []

let has_docpackage pkglst name =
  let docpkg_name = name ^ "-doc" in
  try
    ignore (List.find (fun s -> (String.compare s docpkg_name) == 0) pkglst);
    true
  with
    Not_found -> false

let () =
  let out_file = Sys.argv.(1) in
  let package_list = get_package_list () in
  let package_info_list = package_list |> List.map (fun name ->
    let version_list = get_version_list name in
    let latest_version = List.hd version_list in
    let opamfile_path = List.fold_left Filename.concat package_root [name; name ^ "." ^ latest_version; "opam"] in
    let ofile = OpamParser.file opamfile_path in
    let get_str_variable nm = Option.value (find_string_variable_in_opamfile ofile nm) ~default:"" in
    {
      name = name;
      pkg_type       = get_package_type name;
      synopsis       = get_str_variable "synopsis";
      description    = get_str_variable "description";
      maintainer     = get_str_variable "maintainer";
      license        = get_str_variable "license";
      homepage       = get_str_variable "homepage";
      latest_version = latest_version;
      dependencies   = Option.value (get_depends_info_in_opamfile ofile) ~default:"(no dependencies)";
      documents      = get_docfile_list name;
      has_docpackage = has_docpackage package_list name;
    }) |> List.sort (fun a b -> String.compare a.name b.name)
  in
  let json_root = json_of_package_info_list package_info_list in
  let ochan = open_out out_file in
  Yojson.Basic.pretty_to_channel ochan json_root;
  close_out ochan
