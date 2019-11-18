module Chat exposing (Name, Address, Client, Server(..), serverTypeFromString, serverToString, decodeServer)

import Json.Decode exposing (Decoder)


type alias Name =
    String


type alias Address =
    String


type alias Client =
    { username : Name
    , avatar : Maybe String
    }


type Server
    = Ephemeral
    | Persistent


serverToString : Server -> String
serverToString server =
    case server of
        Ephemeral ->
            "Ephemeral"

        Persistent ->
            "Persistent"

    
serverTypeFromString : String -> Server
serverTypeFromString str =
    case str of
        "Ephemeral" ->
            Ephemeral

        "Persistent" ->
            Persistent

        _ ->
            Ephemeral


decodeServer : Decoder Server
decodeServer =
    Json.Decode.string
        |> Json.Decode.andThen (serverTypeFromString >> Json.Decode.succeed)