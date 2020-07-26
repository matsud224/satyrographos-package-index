let package_dir_name = "satyrographos-repo/packages"
let doc_root_dir_name = "./docs"

type package_type = Library | Class | Font | Document | Satysfi | Satyrographos | Other

type package = {
  name : string;
  package_type : package_type;
}


let remove_head str n = String.sub str n ((String.length str) - n)

let get_package_list () =
  Sys.readdir package_dir_name |> Array.to_list

let get_version_list name =
  let prefix_len = (String.length name) + 1 in
  let dirs = Sys.readdir (package_dir_name ^ "/" ^ name) |> Array.to_list in
  List.map (fun str -> remove_head str prefix_len) dirs |> List.sort (fun a b -> -(String.compare a b))

let get_package_type name =
  let open Str in
  let regexp_type_pair = [
    (regexp ".*-doc$", Document);
    (regexp "^satysfi-class-.*", Class);
    (regexp "^satysfi-fonts-.*", Font);
    (regexp "^satysfi$", Satysfi);
    (regexp "^satyrographos.*", Satyrographos);
    (regexp "^satysfi-.*", Library)
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

let string_of_package_type t =
  match t with
  | Library       -> "Library"
  | Class         -> "Class"
  | Font          -> "Font"
  | Document      -> "Document"
  | Satysfi       -> "Satysfi"
  | Satyrographos -> "Satyrographos"
  | Other         -> "Other"

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

let find_string_variable_in_opamfile ofile name default =
  match find_variable_in_opamfile ofile name with
  | Some(String(_, strval)) -> strval
  | _ -> default

let find_deps_variable_in_opamfile ofile name default =
  match find_variable_in_opamfile ofile name with
  | Some(List(_, vallst)) -> String.concat ", " (List.map OpamPrinter.value vallst)
  | _ -> default

type package_info = {
  name : string;
  pkg_type : package_type;
  synopsis : string;
  description : string;
  maintainer : string;
  license : string;
  homepage : string;
  latest_version : string;
  dependencies : string;
  document : string list;
}

let json_of_package_info info =
  `Assoc [
    ("name", `String info.name);
    ("type", `String (string_of_package_type info.pkg_type));
    ("synopsis", `String info.synopsis);
    ("description", `String info.description);
    ("maintainer", `String info.maintainer);
    ("license", `String info.license);
    ("homepage", `String info.homepage);
    ("latest_version", `String info.latest_version);
    ("dependencies", `String info.dependencies);
    ("document", `List (List.map (fun s -> `String s) info.document));
  ]

let json_of_package_info_list lst =
  `Assoc [("data", `List lst)]

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
    let doc_path = doc_root_dir_name ^ "/" ^ doc_dir_name in
    if Sys.file_exists doc_path && Sys.is_directory doc_path then
      dir_contents doc_path
    else
      []
  else
    []

let run_command cmd =
  if Sys.command cmd != 0 then
    failwith "command \"%s\" failed!\n"
  else
    ()

let () =
  run_command "rm -rf ./docs";
  run_command "cp -rL ~/.satysfi/dist/docs .";
  let package_list = get_package_list () in
  let package_info_list = List.map (fun name ->
    let version_list = get_version_list name in
    let latest_version = List.hd version_list in
    let ofile_path = package_dir_name ^ "/" ^ name ^ "/" ^ name ^ "." ^ latest_version ^ "/opam" in
    let ofile = OpamParser.file ofile_path in
    let str_variable = find_string_variable_in_opamfile ofile in
    {
      name = name;
      pkg_type = get_package_type name;
      synopsis = str_variable "synopsis" "";
      description = str_variable "description" "";
      maintainer = str_variable "maintainer" "";
      license = str_variable "license" "";
      homepage = str_variable "homepage" "";
      latest_version = latest_version;
      dependencies = find_deps_variable_in_opamfile ofile "depends" "(no dependencies)";
      document = get_docfile_list name;
    }) package_list
  in
  let json_all = json_of_package_info_list (List.map json_of_package_info package_info_list) in
  let outfile = "data.json" in
  let ochan = open_out outfile in
  Yojson.Basic.pretty_to_channel ochan json_all;
  close_out ochan
