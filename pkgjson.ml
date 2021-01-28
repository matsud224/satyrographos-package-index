(*
 * before running this program...
 *   1. Clone 'satyrographos-repo' in current directory.
 *   2. Install 'satyrographos-snapshot-stable' via opam.
 *   3. Run 'satyrographos install'.
 *   4. Copy '.satysfi/dist/docs' in current directory.
 *)

let package_root = "./satyrographos-repo/packages"
let doc_root = "./docs"
let font_root = "./fonts"

type package_type =
  Library | Class | Font | Document | Satysfi | Satyrographos | Snapshot | Other

type package_info = {
  name            : string;
  pkg_type        : package_type;
  synopsis        : string;
  description     : string;
  maintainer      : string;
  authors         : string;
  license         : string;
  homepage        : string;
  bug_reports     : string;
  latest_version  : string;
  dependencies    : string;
  last_update     : string;
  first_published : string;
  has_docpkg      : bool;
  documents       : string list;
  fonts           : string list;
  tags            : string list;
  snapshots       : string list;
}

let string_of_package_type t =
  match t with
  | Library       -> "Library"
  | Class         -> "Class"
  | Font          -> "Font"
  | Document      -> "Document"
  | Satysfi       -> "Satysfi"
  | Satyrographos -> "Satyrographos"
  | Snapshot      -> "Snapshot"
  | Other         -> "Other"

let remove_head n str = String.sub str n ((String.length str) - n)

let get_package_list () =
  Sys.readdir package_root |> Array.to_list

let get_version_list name =
  let pkgname_part_len = String.length (name ^ ".") in
  let dirs = Sys.readdir (Filename.concat package_root name) |> Array.to_list in
  List.map (remove_head pkgname_part_len) dirs |> List.sort (fun a b -> OpamVersionCompare.compare b a)

let get_package_type name =
  let open Str in
  let regexp_type_pair = [
    (regexp ".*-doc$",           Document);
    (regexp "^satysfi-class-.*", Class);
    (regexp "^satysfi-fonts-.*", Font);
    (regexp "^satysfi$",         Satysfi);
    (regexp "^satyrographos-snapshot-.*",  Snapshot);
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
  let open OpamParserTypes.FullPos in
  let rec iter (ilst : opamfile_item list) =
    match ilst with
    | [] -> None
    | { pelem = Variable(nm_withpos, value); _ } :: rest ->
        if String.compare nm_withpos.pelem name == 0 then
          Some(value.pelem)
        else
          iter rest
    | _ :: rest -> iter rest
  in
  iter ofile.file_contents

let find_string_variable_in_opamfile ofile name =
  let open OpamParserTypes.FullPos in
  match find_variable_in_opamfile ofile name with
  | Some(String(strval)) -> Some(strval)
  | _                       -> None

let find_string_list_variable_in_opamfile ?(use_opamprinter=false) ofile name =
  let open OpamParserTypes.FullPos in
  match find_variable_in_opamfile ofile name with
  | Some(String(strval)) -> Some([strval])
  | Some(List(vallst))   -> Some(List.map (function { pelem = String(s); _ } as v ->
      if use_opamprinter then OpamPrinter.FullPos.value v else s | v -> OpamPrinter.FullPos.value v) vallst.pelem)
  | _                       -> None

let json_of_package_info info =
  let strlist_to_json lst = `List (List.map (fun s -> `String s) lst) in
  `Assoc [
    ("name",           `String info.name);
    ("type",           `String (string_of_package_type info.pkg_type));
    ("synopsis",       `String info.synopsis);
    ("description",    `String info.description);
    ("maintainer",     `String info.maintainer);
    ("authors",        `String info.authors);
    ("license",        `String info.license);
    ("homepage",       `String info.homepage);
    ("bug_reports",    `String info.bug_reports);
    ("latest_version", `String info.latest_version);
    ("dependencies",   `String info.dependencies);
    ("last_update",    `String info.last_update);
    ("first_published",`String info.first_published);
    ("has_docpkg",     `Bool   info.has_docpkg);
    ("documents",      strlist_to_json info.documents);
    ("fonts",          strlist_to_json info.fonts);
    ("tags",           strlist_to_json info.tags);
    ("snapshots",      strlist_to_json info.snapshots);
  ]

let json_of_package_info_list ilst =
  `Assoc [("data", `List (List.map json_of_package_info ilst))]

let dir_is_empty dir =
  Array.length (Sys.readdir dir) = 0

let dir_contents dir =
  let rec loop result = function
    | f::fs when Core.Sys.is_directory f ~follow_symlinks:false == `Yes ->
          Sys.readdir f
          |> Array.to_list
          |> List.map (Filename.concat f)
          |> List.append fs
          |> loop result
    | f::fs -> loop (f::result) fs
    | []    -> result
  in
    loop [] [dir]

let get_document_package_name name = name ^ "-doc"

let get_docfile_list name =
  let open Str in
  let name = get_document_package_name name in
  if string_match (regexp "^satysfi-\\(.*-doc$\\)") name 0 then
    let doc_dir_name = matched_group 1 name in
    let doc_path = doc_root ^ "/" ^ doc_dir_name in
    if Sys.file_exists doc_path && Sys.is_directory doc_path then
      dir_contents doc_path |> List.sort String.compare
    else
      []
  else
    []

let get_fontfile_list name =
  let open Str in
  if string_match (regexp "^satysfi-\\(.*\\)") name 0 then
    let font_dir_name = matched_group 1 name in
    let font_path = font_root ^ "/" ^ font_dir_name in
    if Sys.file_exists font_path && Sys.is_directory font_path then
      dir_contents font_path |> List.map Filename.basename |> List.sort String.compare
    else
      []
  else
    []

let is_package_exists pkglst name =
  try
    ignore (List.find (fun s -> (String.compare s name) == 0) pkglst);
    true
  with
    Not_found -> false

let get_package_updated_date name =
  let cmd = "git --no-pager -C " ^ package_root ^ " log --pretty=%ad -n1 --date=unix " ^ name in
  let chan = Unix.open_process_in cmd in
  let result = input_line chan in
    ignore (Unix.close_process_in chan);
    result

let get_package_first_published_date name =
  let cmd = "git --no-pager -C " ^ package_root ^ " log --pretty=%cd --date=unix " ^ name ^ " | tail -n1" in
  let chan = Unix.open_process_in cmd in
  let result = input_line chan in
    ignore (Unix.close_process_in chan);
    result

let get_snapshot_versions name =
  let open Str in
  get_version_list name |> List.map (fun ver ->
    name ^ "." ^ (List.hd (split (regexp "\\+") ver))
  ) |> List.sort String.compare |> Core.List.remove_consecutive_duplicates ~equal:(fun a b -> a = b)

let get_snapshot_info_list pkglst =
  let snapshot_list = pkglst |> List.filter (fun name -> (get_package_type name) == Snapshot) in
  let snapshot_info_list = snapshot_list |> List.concat_map (fun name ->
    get_version_list name |> List.map (fun version ->
      let full_name = name ^ "." ^ version in
      let opamfile_path = List.fold_left Filename.concat package_root [name; full_name; "opam"] in
      let ofile = OpamParser.FullPos.file opamfile_path in
      let depends = Option.get (find_string_list_variable_in_opamfile ofile "depends" ~use_opamprinter:true) in
        (full_name, String.concat ", " depends)
    )
  ) in
  snapshot_info_list

let get_contained_snapshots ssinfo pkgname =
  let open Str in
  ssinfo |> List.filter (fun (_, deps) ->
    try ((ignore @@ search_forward (regexp ("\"" ^ pkgname ^ "\"")) deps 0); true) with Not_found -> false
  )
  |> List.map (fun (ssname, _) -> ssname)
  |> List.map (fun ssname -> List.hd (split (regexp "\\+") ssname))
  |> List.sort String.compare |> Core.List.remove_consecutive_duplicates ~equal:(fun a b -> a = b)

let () =
  let out_file = Sys.argv.(1) in
  let package_list = get_package_list () in
  let snapshot_info_list = get_snapshot_info_list package_list in
  let package_info_list = package_list |> List.map (fun name ->
    let version_list = get_version_list name in
    let latest_version = List.hd version_list in
    let opamfile_path = List.fold_left Filename.concat package_root [name; name ^ "." ^ latest_version; "opam"] in
    let ofile = OpamParser.FullPos.file opamfile_path in
    let get_str_variable nm default = Option.value (find_string_variable_in_opamfile ofile nm) ~default:default in
    let get_strlist_variable ?(use_opamprinter=false) nm default =
      match find_string_list_variable_in_opamfile ofile nm ~use_opamprinter:use_opamprinter with
      | None -> default
      | Some(xs)  -> String.concat ", " xs
    in
    {
      name = name;
      pkg_type        = get_package_type name;
      synopsis        = get_str_variable "synopsis" "";
      description     = get_str_variable "description" "";
      maintainer      = get_strlist_variable "maintainer" "";
      authors         = get_strlist_variable "authors" "";
      license         = get_strlist_variable "license" "";
      homepage        = get_strlist_variable "homepage" "";
      bug_reports     = get_strlist_variable "bug-reports" "";
      latest_version  = latest_version;
      dependencies    = get_strlist_variable "depends" "(no dependencies)" ~use_opamprinter:true;
      last_update     = get_package_updated_date name;
      first_published = get_package_first_published_date name;
      has_docpkg      = is_package_exists package_list (get_document_package_name name);
      documents       = get_docfile_list name;
      fonts           = get_fontfile_list name;
      tags            = Option.value (find_string_list_variable_in_opamfile ofile "tags") ~default:[];
      snapshots       = get_contained_snapshots snapshot_info_list name;
    })
    |> List.filter (fun p -> match p.pkg_type with
                             | Library | Class | Font -> true
                             | _ -> false)
    |> List.map (fun p -> { p with name = remove_head (String.length "satysfi-") p.name })
    |> List.sort (fun a b -> String.compare a.name b.name)
  in
  let json_root = json_of_package_info_list package_info_list in
  let ochan = open_out out_file in
  Yojson.Basic.pretty_to_channel ochan json_root;
  close_out ochan
