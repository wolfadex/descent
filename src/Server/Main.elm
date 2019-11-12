port module Server.Main exposing (main)

import Browser
import Html exposing (Html)
import Html.Attributes as Attributes
import Html.Events as Events
import Set exposing (Set)


--import Json.Decode exposing (Decoder, Value)


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
    = Waiting { name : String, existingServers : Set String }
    | Starting { name : String, existingServers : Set String }
    | Running { name : Name, address : Address }
    | ShuttingDown


type alias Name =
    String


type alias Address =
    String


init : Flags -> ( Model, Cmd Msg )
init existingServers =
    ( Waiting { name = "", existingServers = Set.fromList existingServers }
    , Cmd.none
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ serverStarted ServerStarted
        , serverShutDown ShutDown
        ]


port serverStarted : (( String, String ) -> msg) -> Sub msg
port serverShutDown : ((List String) -> msg) -> Sub msg


type Msg
    = ServerStarted ( Name, Address )
    | StartServer Name
    | DeleteServer Name
    | SetServerName Name
    | AttempShutDown
    | ShutDown (List Name)


port startServer : String -> Cmd msg
port shutDownServer : () -> Cmd msg
port deleteServer : String -> Cmd msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ServerStarted ( name, address ) ->
            case model of
                Starting _ ->
                    ( Running { name = name, address = address }, Cmd.none )

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


view : Model -> Html Msg
view model =
    case model of
        Waiting { name, existingServers } ->
            Html.div
                []
                [ Html.div
                    []
                    [ Html.label
                        []
                        [ Html.text "Server Name:"
                        , Html.input
                            [ Attributes.value name
                            , Events.onInput SetServerName
                            ]
                            []
                        ]
                    ]
                , Html.button
                    [ Events.onClick (StartServer name) ]
                    [ Html.text ("Start " ++ name) ]
                , Html.br [] []
                , Html.br [] []
                , Html.text "Existing Servers:"
                , Html.ul
                    []
                    (existingServers
                        |> Set.toList
                        |> List.map viewExistingServer
                        )
                ]

        Starting _ ->
            Html.text "Starting server..."

        Running { name, address } ->
            Html.div
                []
                [ Html.text ("Server \"" ++ name ++ "\" running")
                , Html.br [] []
                , Html.text ("Server address: " ++ address)
                , Html.br [] []
                , Html.button
                    [ Events.onClick AttempShutDown ]
                    [ Html.text "Shutdown" ]
                ]

        ShuttingDown ->
            Html.text "Shutting down"


viewExistingServer : String -> Html Msg
viewExistingServer name =
    Html.li
        []
        [ Html.text name
        , Html.button
            [ Events.onClick (StartServer name)]
            [ Html.text "Start" ]
        , Html.button
            [ Events.onClick (DeleteServer name)]
            [ Html.text "Delete" ]
        ]