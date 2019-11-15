port module Server.Main exposing (main)

import Browser
import Dict exposing (Dict)
import Element exposing (Element)
import Element.Input as Input
import Html exposing (Html)
import Json.Encode exposing (Value)
import Random exposing (Seed)
import Set exposing (Set)
import Time exposing (Posix)
import Ui
import Ui.Color


main : Program Flags Model Msg
main =
    Browser.element
        { view = view
        , init = init
        , subscriptions = subscriptions
        , update = update
        }


type alias Flags =
    List String


type Model
    = Waiting { name : String, existingServers : Set String, seed : Seed }
    | Starting { name : String, existingServers : Set String, seed : Seed }
    | Running { name : Name, address : Address, seed : Seed, clients : Dict Address Client, messages : List Message }
    | ShuttingDown Seed


type alias Name =
    String


type alias Address =
    String


type alias Client =
    { username : Name
    , avatar : Maybe String
    }


defaultClient : Client
defaultClient =
    { username = "User123"
    , avatar = Nothing
    }


randomName : Seed -> ( Name, Seed )
randomName seed =
    Random.step
        (Random.uniform
            "Carl"
            [ "Steve"
            , "Jenny"
            , "April"
            , "Jerry"
            , "Ben"
            , "Jenna"
            , "Sarah"
            , "Ken"
            , "Brian"
            , "Sophia"
            ]
        )
        seed
        |> Tuple.mapFirst (\n -> n ++ "Anonymous-")


type alias Message =
    { client : Address
    , content : String
    , timestamp : Posix
    }


init : Flags -> ( Model, Cmd Msg )
init existingServers =
    ( Waiting { name = "", existingServers = Set.fromList existingServers, seed = Random.initialSeed 0 }
    , Random.generate GenerateInitialSeed Random.independentSeed
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ serverStarted ServerStarted
        , serverShutDown ShutDown
        , newClient NewClient
        , messageReceived MessageReceived
        ]


port serverStarted : (( String, String ) -> msg) -> Sub msg


port serverShutDown : (List String -> msg) -> Sub msg


port newClient : (Address -> msg) -> Sub msg


port messageReceived : (( Address, String, Int ) -> msg) -> Sub msg


type Msg
    = ServerStarted ( Name, Address )
    | StartServer Name
    | DeleteServer Name
    | SetServerName Name
    | AttempShutDown
    | ShutDown (List Name)
    | NewClient Address
    | GenerateInitialSeed Seed
    | MessageReceived ( Address, String, Int )


port startServer : String -> Cmd msg


port shutDownServer : () -> Cmd msg


port deleteServer : String -> Cmd msg


port forwardMessage : Value -> Cmd msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MessageReceived ( client, content, time ) ->
            case model of
                Running data ->
                    let
                        message =
                            { client = client, content = content, timestamp = Time.millisToPosix time }
                    in
                    ( Running { data | messages = message :: data.messages }
                    , message |> encodeMessage data |> forwardMessage
                    )

                _ ->
                    ( model, Cmd.none )

        GenerateInitialSeed seed ->
            case model of
                Waiting data ->
                    ( Waiting { data | seed = seed }, Cmd.none )

                Starting data ->
                    ( Starting { data | seed = seed }, Cmd.none )

                Running data ->
                    ( Running { data | seed = seed }, Cmd.none )

                ShuttingDown _ ->
                    ( ShuttingDown seed, Cmd.none )

        ServerStarted ( name, address ) ->
            case model of
                Starting { seed } ->
                    ( Running { name = name, address = address, seed = seed, clients = Dict.empty, messages = [] }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        StartServer name ->
            case model of
                Waiting data ->
                    ( Starting data, startServer name )

                _ ->
                    ( model, Cmd.none )

        DeleteServer name ->
            case model of
                Waiting data ->
                    ( Waiting { data | existingServers = Set.remove name data.existingServers }, deleteServer name )

                Starting data ->
                    ( Starting { data | existingServers = Set.remove name data.existingServers }, deleteServer name )

                _ ->
                    ( model, Cmd.none )

        SetServerName name ->
            case model of
                Waiting data ->
                    ( Waiting { data | name = name }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        AttempShutDown ->
            case model of
                Running { seed } ->
                    ( ShuttingDown seed, shutDownServer () )

                _ ->
                    ( model, Cmd.none )

        ShutDown existingServers ->
            case model of
                ShuttingDown seed ->
                    ( Waiting { name = "", existingServers = Set.fromList existingServers, seed = seed }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        NewClient address ->
            case model of
                Running data ->
                    let
                        ( username, seed ) =
                            randomName data.seed
                    in
                    ( Running
                        { data
                            | clients =
                                Dict.insert
                                    address
                                    { defaultClient | username = username }
                                    data.clients
                            , seed = seed
                        }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )


encodeMessage : { a | clients : Dict Address Client } -> Message -> Value
encodeMessage { clients } { client, content, timestamp } =
    Json.Encode.object
        [ ( "sender", Json.Encode.string client )
        , ( "recipients"
          , clients
                |> Dict.toList
                |> List.map Tuple.first
                |> Json.Encode.list Json.Encode.string
          )
        , ( "content", Json.Encode.string content )
        , ( "time", Json.Encode.int (Time.posixToMillis timestamp) )
        ]


view : Model -> Html Msg
view model =
    Element.layout
        [ Element.width Element.fill
        , Element.height Element.fill
        ]
    <|
        case model of
            Waiting { name, existingServers } ->
                Element.column
                    [ Element.centerX
                    , Element.height Element.fill
                    ]
                    [ Element.column
                        (Ui.card ++ [ Element.width Element.fill ])
                        [ Input.text
                            []
                            { onChange = SetServerName
                            , text = name
                            , placeholder = Nothing
                            , label = Input.labelLeft [] <| Element.text "Server Name"
                            }
                        , Ui.button
                            Ui.Color.primary
                            { onPress = Just (StartServer name)
                            , label = Element.text "Start"
                            }
                        ]
                    , Ui.spacerVertical <| Element.px 32
                    , Element.column
                        (Ui.card
                            ++ [ Element.width Element.fill
                               , Element.scrollbarY
                               ]
                        )
                        [ Element.text "Existing Servers:"
                        , Ui.spacerVertical <| Element.px 16
                        , Element.column
                            [ Element.width Element.fill ]
                            (existingServers
                                |> Set.toList
                                |> List.map viewExistingServer
                                |> List.intersperse (Ui.spacerVertical <| Element.px 16)
                            )
                        ]
                    ]

            Starting _ ->
                Element.text "Starting server..."

            Running { name, address, messages } ->
                Element.column
                    [ Element.centerX
                    , Element.centerY
                    ]
                    [ Element.text ("Server \"" ++ name ++ "\" running")
                    , Element.text ("Server address: " ++ address)
                    , Ui.button
                        Ui.Color.danger
                        { onPress = Just AttempShutDown
                        , label = Element.text "Shutdown"
                        }
                    , Element.column
                        Ui.card
                        (List.map viewMessage messages)
                    ]

            ShuttingDown _ ->
                Element.text "Shutting down"


viewExistingServer : String -> Element Msg
viewExistingServer name =
    Element.el
        (Ui.card ++ [ Element.width Element.fill ])
    <|
        Element.column
            [ Element.width Element.fill ]
            [ Element.text name
            , Ui.spacerVertical <| Element.px 16
            , Element.row
                [ Element.width Element.fill ]
                [ Ui.button
                    []
                    { onPress = Just (StartServer name)
                    , label = Element.text "Start"
                    }
                , Ui.spacerHorizontal Element.fill
                , Ui.button
                    Ui.Color.danger
                    { onPress = Just (DeleteServer name)
                    , label = Element.text "Delete"
                    }
                ]
            ]


viewMessage : Message -> Element Msg
viewMessage { client, content, timestamp } =
    Element.row
        []
        [ Element.text client
        , Element.text "says:"
        , Element.text content
        ]