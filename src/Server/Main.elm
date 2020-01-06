port module Server.Main exposing (main)

import Browser
import Chat exposing (Address, Name)
import Element exposing (Element)
import Element.Keyed as Keyed
import Element.Input as Input
import Element.Font as Font
import Html exposing (Html)
import Json.Encode exposing (Value)
import Json.Decode exposing (Decoder)
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
    List Name


type Model
    = Waiting WaitingData
    | Starting WaitingData
    | Running { name : Name, address : Address, clients : Set Address, messages : List Message }
    | ShuttingDown


type alias WaitingData =
    { name : Name
    , existingServers : Set Name
    }


type alias Message =
    { client : Address
    , content : String
    , timestamp : Posix
    }


init : Flags -> ( Model, Cmd Msg )
init existingServers =
    ( Waiting
        { name = ""
        , existingServers = Set.fromList existingServers
        }
    , Cmd.none
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ serverStarted ServerStarted
        , serverShutDown ShutDown
        , newClient NewClient
        , messageReceived MessageReceived
        ]


port serverStarted : (Value -> msg) -> Sub msg


decodeServerStarted : Decoder ( Name, Address )
decodeServerStarted =
    Json.Decode.map2 Tuple.pair
        (Json.Decode.field "name" Json.Decode.string)
        (Json.Decode.field "address" Json.Decode.string)


port serverShutDown : (List Name -> msg) -> Sub msg


port newClient : (Address -> msg) -> Sub msg


port messageReceived : (( Address, String, Int ) -> msg) -> Sub msg


type Msg
    = ServerStarted Value
    | StartServer Name
    | DeleteServer Name
    | SetServerName Name
    | AttempShutDown
    | ShutDown (List Name)
    | NewClient Address
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

        ServerStarted value ->
            case model of
                Starting _ ->
                    case Json.Decode.decodeValue decodeServerStarted value of
                        Ok ( name, address ) ->
                            ( Running { name = name, address = address, clients = Set.empty, messages = [] }, Cmd.none )


                        Err _ ->
                            ( model, Cmd.none )

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
                Running _ ->
                    ( ShuttingDown, shutDownServer () )

                _ ->
                    ( model, Cmd.none )

        ShutDown existingServers ->
            case model of
                ShuttingDown ->
                    ( Waiting { name = "", existingServers = Set.fromList existingServers }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        NewClient address ->
            case model of
                Running data ->
                    ( Running { data | clients = Set.insert address data.clients }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )



encodeMessage : { a | clients : Set Address } -> Message -> Value
encodeMessage { clients } { client, content, timestamp } =
    Json.Encode.object
        [ ( "sender", Json.Encode.string client )
        , ( "recipients"
          , clients
                |> Set.toList
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
        , Element.padding 16
        ]
    <|
        case model of
            Waiting data ->
                viewNewServer data

            Starting _ ->
                Element.text "Starting server..."

            Running { name, address, messages } ->
                Element.column
                    [ Element.centerX
                    , Element.centerY
                    , Element.spacing 8
                    ]
                    [ Element.text ("Name: " ++ name)
                    , Element.text "Status: Running"
                    , Element.text ("Address: " ++ address)
                    , Element.el [ Font.size 16 ] (Element.text "Give a friend the address so they can connect!")
                    , Ui.button
                        Ui.Color.danger
                        { onPress = Just AttempShutDown
                        , label = Element.text "Shutdown"
                        }
                    , Keyed.column
                        Ui.card
                        (List.map viewMessage messages)
                    ]

            ShuttingDown ->
                Element.text "Shutting down"


viewExistingServer : Name -> Element Msg
viewExistingServer name =
    Element.el
        (Ui.card ++ [ Element.width Element.fill ])
    <|
        Element.column
            [ Element.width Element.fill
            , Element.spacing 16
            ]
            [ Element.el [ Font.bold ] (Element.text name)
            , Element.row
                [ Element.width Element.fill ]
                [ Ui.button
                    []
                    { onPress = Just (StartServer name)
                    , label = Element.text "Start"
                    }
                , Ui.button
                    (Ui.Color.danger ++ [ Element.alignRight ])
                    { onPress = Just (DeleteServer name)
                    , label = Element.text "Delete"
                    }
                ]
            ]


viewMessage : Message -> ( String, Element Msg )
viewMessage { client, content, timestamp } =
    ( client ++ "__" ++ (timestamp |> Time.posixToMillis |> String.fromInt)
    , Element.row
        []
        [ Element.text client
        , Element.text "says:"
        , Element.text content
        ]
    )


viewNewServer : WaitingData -> Element Msg
viewNewServer { name, existingServers } =
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
