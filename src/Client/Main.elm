port module Client.Main exposing (main)

import Browser
import Element exposing (Element)
import Element.Input as Input
import Html exposing (Html)
import Json.Decode exposing (Decoder, Value)
import Time exposing (Posix)
import Ui
import Ui.Color


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = init
        , subscriptions = subscriptions
        , update = update
        }


type Model
    = Waiting { username : Name, serverName : Name, serverAddress : Address }
    | Connecting { username : Name, serverName : Name, serverAddress : Address }
    | Running { username : Name, serverName : Name, serverAddress : Address, messages : List Message, newMessage : String }


type alias Name =
    String


type alias Address =
    String


type alias Message =
    { client : Address
    , content : String
    , timestamp : Posix
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Waiting { username = "", serverName = "", serverAddress = "" }
    , Cmd.none
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ serverConnected ServerConnected
        , messageReceived (messageToMsg <| serverAddressFromModel model)
        ]


port serverConnected : (String -> msg) -> Sub msg


port messageReceived : (( Address, Value ) -> msg) -> Sub msg


messageToMsg : Address -> ( Address, Value ) -> Msg
messageToMsg serverAddress ( address, message ) =
    if address == serverAddress then
        case Json.Decode.decodeValue decodeServerMessage message of
            Ok msg ->
                msg

            Err err ->
                Debug.todo ("handle decode server message error: " ++ Json.Decode.errorToString err)

    else
        Debug.todo "handle peer client message"


decodeServerMessage : Decoder Msg
decodeServerMessage =
    Json.Decode.field "action" Json.Decode.string
        |> Json.Decode.andThen
            (\action ->
                case action of
                    "forwardMessage" ->
                        Json.Decode.field "payload" decodeForwardMessage

                    _ ->
                        Json.Decode.fail ("Unrecognized action: " ++ action)
            )


decodeForwardMessage : Decoder Msg
decodeForwardMessage =
    Json.Decode.map3
        (\client content time ->
            ForwardedMessage
                { client = client
                , content = content
                , timestamp = Time.millisToPosix time
                }
        )
        (Json.Decode.field "sender" Json.Decode.string)
        (Json.Decode.field "content" Json.Decode.string)
        (Json.Decode.field "time" Json.Decode.int)


serverAddressFromModel : Model -> Address
serverAddressFromModel model =
    case model of
        Waiting { serverAddress } ->
            serverAddress

        Connecting { serverAddress } ->
            serverAddress

        Running { serverAddress } ->
            serverAddress


type Msg
    = SetUsername Name
    | SetServerName Name
    | SetServerAddress Address
    | ConnectToServer
    | ServerConnected Address
    | ForwardedMessage Message
    | SetMessage String
    | SendMessage


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ForwardedMessage message ->
            case model of
                Running data ->
                    ( Running { data | messages = message :: data.messages }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetUsername name ->
            case model of
                Waiting data ->
                    ( Waiting { data | username = name }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetServerName name ->
            case model of
                Waiting data ->
                    ( Waiting { data | serverName = name }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetServerAddress address ->
            case model of
                Waiting data ->
                    ( Waiting { data | serverAddress = address }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ConnectToServer ->
            case model of
                Waiting data ->
                    ( Connecting data, connectToServer data.serverAddress )

                _ ->
                    ( model, Cmd.none )

        ServerConnected _ ->
            case model of
                Connecting data ->
                    ( Running
                            { username = data.username
                            , serverName = data.serverName
                            , serverAddress = data.serverAddress
                            , messages = []
                            , newMessage = ""
                            }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        SetMessage message ->
            case model of
                Running data ->
                    ( Running { data | newMessage = message }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SendMessage ->
            case model of
                Running data ->
                    ( Running { data | newMessage = "" }, sendMessage data.newMessage )

                _ ->
                    ( model, Cmd.none )


port connectToServer : String -> Cmd msg


port sendMessage : String -> Cmd msg


view : Model -> Html Msg
view model =
    Element.layout
        [ Element.width Element.fill
        , Element.height Element.fill
        ]
    <|
        case model of
            Waiting { username, serverName, serverAddress } ->
                Element.column
                    (Ui.card ++ [ Element.centerX, Element.centerY ])
                    [ Input.text
                        []
                        { onChange = SetUsername
                        , text = username
                        , placeholder = Nothing
                        , label = Input.labelLeft [] <| Element.text "Username"
                        }
                    , Input.text
                        []
                        { onChange = SetServerName
                        , text = serverName
                        , placeholder = Nothing
                        , label = Input.labelLeft [] <| Element.text "Server Name"
                        }
                    , Input.text
                        []
                        { onChange = SetServerAddress
                        , text = serverAddress
                        , placeholder = Nothing
                        , label = Input.labelLeft [] <| Element.text "Server Address"
                        }
                    , Ui.button
                        Ui.Color.primary
                        { onPress = Just ConnectToServer
                        , label = Element.text "Connect"
                        }
                    ]

            Connecting _ ->
                Element.text "Connecting ..."

            Running { username, serverName, messages, newMessage } ->
                Element.row
                    [ Element.width Element.fill
                    , Element.height Element.fill
                    ]
                    [ Element.column
                        Ui.card
                        [ Element.text ("Username: " ++ username)
                        , Element.text ("Server: " ++ serverName)
                        ]
                    , Element.column
                        [ Element.height Element.fill
                        , Element.width Element.fill
                        ]
                        [ Element.column
                            [ Element.height Element.fill, Element.alignBottom ]
                            (List.map viewMessage (List.reverse messages))
                        , Element.row
                            []
                            [ Input.text
                                []
                                { onChange = SetMessage
                                , text = newMessage
                                , placeholder = Nothing
                                , label = Input.labelHidden "Message"
                                }
                            , Ui.button
                                []
                                { onPress = Just SendMessage
                                , label = Element.text "Send"
                                }
                            ]
                        ]
                    ]


viewMessage : Message -> Element Msg
viewMessage { client, content, timestamp } =
    Element.el
        [ Element.alignBottom ]
    <| Element.text (client ++ " says: " ++ content)
