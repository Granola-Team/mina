build:
    dune build src/app/cli/src/mina.exe --profile=mainnet

txn_hash txn_json:
    dune exec src/app/mina_txn_hasher/mina_txn_hasher.exe --profile=mainnet -- '{{txn_json}}'

mainnet:
    dune exec src/app/cli/src/mina.exe --profile=mainnet -- daemon --config-file ./genesis_ledgers/mainnet.json --peer-list-url https://storage.googleapis.com/mina-seed-lists/mainnet_seeds.txt

utop_mina_base:
    dune utop src/lib/mina_base
