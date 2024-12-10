open Core_kernel
open Mina_base

module T = struct
  include Blake2.Make ()
end

include T

module Base58_check = Codable.Make_base58_check (struct
  type t = Stable.Latest.t [@@deriving bin_io_unversioned]

  let version_byte = Base58_check.Version_bytes.transaction_hash

  let description = "Transaction hash"
end)

[%%define_locally Base58_check.(to_base58_check)]

let hash_signed_command, hash_zkapp_command =
  let mk_hasher (type a) (module M : Bin_prot.Binable.S with type t = a)
      (cmd : a) =
    cmd |> Binable.to_string (module M) |> digest_string
  in
  let signed_cmd_hasher =
    mk_hasher
      ( module struct
        include Signed_command.Stable.V2
      end )
  in
  let zkapp_cmd_hasher =
    mk_hasher
      ( module struct
        include Zkapp_command.Stable.V1
      end )
  in
  let hash_signed_command (cmd : Signed_command.t) =
    let cmd_dummy_signature = { cmd with signature = Signature.dummy } in
    signed_cmd_hasher cmd_dummy_signature
  in
  let hash_zkapp_command (cmd : Zkapp_command.t) =
    let cmd_dummy_signatures_and_proofs =
      { cmd with
        fee_payer = { cmd.fee_payer with authorization = Signature.dummy }
      ; account_updates =
          Zkapp_command.Call_forest.map cmd.account_updates
            ~f:(fun (acct_update : Account_update.t) ->
              let dummy_auth =
                match acct_update.authorization with
                | Control.Proof _ ->
                    Control.Proof (Lazy.force Proof.transaction_dummy)
                | Control.Signature _ ->
                    Control.Signature Signature.dummy
                | Control.None_given ->
                    Control.None_given
              in
              { acct_update with authorization = dummy_auth } )
      }
    in
    zkapp_cmd_hasher cmd_dummy_signatures_and_proofs
  in
  (hash_signed_command, hash_zkapp_command)

let hash_command cmd_str =
  let json = Yojson.Safe.from_string cmd_str in

  ( if Yojson.Safe.(equal (Util.member "payload" json) `Null) then
    Zkapp_command.of_yojson json |> Result.ok_or_failwith |> hash_zkapp_command
  else
    Signed_command.of_yojson json
    |> Result.ok_or_failwith |> hash_signed_command )
  |> to_base58_check

(* main app functionality *)
(* - takes user signed/zkapp command JSON string *)
(* - outputs base58 encoded txn hash *)

let () = Sys.argv.(1) |> String.strip |> hash_command |> print_endline
