port module Client.Main exposing (main)

import Browser
import Chat exposing (Address, Client, Name)
import Dict exposing (Dict)
import Element exposing (Element)
import Element.Keyed as Keyed
import Element.Input as Input
import Html exposing (Html)
import Http
import Json.Decode exposing (Decoder, Value)
import Json.Encode
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
    = Waiting ConnectionData
    | Connecting ConnectionData
    | Running Server


type alias ConnectionData =
    { name : Name
    , address : Address
    }


type alias Message =
    { client : Address
    , content : String
    , timestamp : Posix
    }

type Request d
    = Loading
    | Failure Http.Error
    | Success d


type alias Server =
    { name : Name
    , address : Address
    , context : Context
    , messages : List Message
    , newMessage : String
    , clients : Dict Address Client
    }


type Context = Context Value


setContext : Value -> Context
setContext =
    Context


getContext : Context -> Value
getContext (Context val) =
    val


init : () -> ( Model, Cmd Msg )
init _ =
    ( Waiting { name = "", address = "" }
    , Cmd.none
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ messageReceived (messageToMsg <| serverAddressFromModel model)
        ]


port messageReceived : (( Address, Value ) -> msg) -> Sub msg


messageToMsg : Address -> ( Address, Value ) -> Msg
messageToMsg serverAddress ( address, message ) =
    if address == serverAddress then
        case Json.Decode.decodeValue decodeServerMessage message of
            Ok msg ->
                msg

            Err err ->
                UnknownServerMessage (Json.Decode.errorToString err)

    else
        Debug.todo "handle peer client message"


decodeServerMessage : Decoder Msg
decodeServerMessage =
    Json.Decode.field "action" Json.Decode.string
        |> Json.Decode.andThen
            (\action ->
                case action of
                    "forwardMessage" ->
                         decodePayload decodeForwardMessage

                    _ ->
                        Json.Decode.fail ("Unrecognized action: " ++ action)
            )


decodePayload : Decoder a -> Decoder a
decodePayload =
    Json.Decode.field "payload"


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
        Waiting { address } ->
            address

        Connecting { address } ->
            address

        Running { address } ->
            address


type Msg
    = SetServerName Name
    | SetServerAddress Address
    | ConnectToServer
    | ServerConnected (Result Http.Error Server)
    | ForwardedMessage Message
    | SetMessage String
    | SendMessage
    | UnknownServerMessage String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UnknownServerMessage err ->
            ( model, unknownServerMessage err )

        ForwardedMessage message ->
            case model of
                Running data ->
                    ( Running { data | messages = message :: data.messages }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetServerName name ->
            case model of
                Waiting data ->
                    ( Waiting { data | name = name }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetServerAddress address ->
            case model of
                Waiting data ->
                    ( Waiting { data | address = address }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ConnectToServer ->
            case model of
                Waiting data ->
                    ( Connecting data
                    , Http.post
                        { url = "bugout:connect"
                        , body =
                            data.address
                                |> Json.Encode.string
                                |> Http.jsonBody
                        , expect = Http.expectJson ServerConnected (decodeServerConnected data)
                        }
                    )

                _ ->
                    ( model, Cmd.none )

        ServerConnected result ->
            case model of
                Connecting { address } ->
                    case result of
                        Ok server ->
                            if address == server.address then
                                ( Running server
                                , Cmd.none
                                )

                            else
                                ( model, Cmd.none )

                        Err err ->
                            ( model, Cmd.none )

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


decodeServerConnected : ConnectionData -> Decoder Server
decodeServerConnected { address, name } =
    Json.Decode.map
        (\context ->
            { name = name
            , address = address
            , context = setContext context
            , messages = []
            , newMessage = ""
            , clients = Dict.empty
            }
        )
        (Json.Decode.field "client" Json.Decode.value)




port sendMessage : String -> Cmd msg


port unknownServerMessage : String -> Cmd msg


view : Model -> Html Msg
view model =
    Element.layout
        [ Element.width Element.fill
        , Element.height Element.fill
        ]
    <|
        case model of
            Waiting { name, address } ->
                Element.column
                    (Ui.card ++ [ Element.centerX, Element.centerY, Element.spacing 8 ])
                    [ Element.text "Server:"
                    , Input.text
                        []
                        { onChange = SetServerAddress
                        , text = address
                        , placeholder = Nothing
                        , label = Input.labelLeft [] <| Element.text "Address"
                        }
                    , Input.text
                        []
                        { onChange = SetServerName
                        , text = name
                        , placeholder = Nothing
                        , label = Input.labelLeft [] <| Element.text "Nickname"
                        }
                    , Ui.button
                        (Ui.Color.primary ++ [ Element.alignRight ])
                        { onPress = Just ConnectToServer
                        , label = Element.text "Connect"
                        }
                    ]

            Connecting _ ->
                Element.text "Connecting ..."

            Running { name, messages, newMessage, clients } ->
                Element.row
                    [ Element.width Element.fill
                    , Element.height Element.fill
                    ]
                    [ Element.column
                        Ui.card
                        [ Element.text ("Server: " ++ name)
                        ]
                    , Element.column
                        [ Element.height Element.fill
                        , Element.width Element.fill
                        ]
                        [ Keyed.column
                            [ Element.height Element.fill, Element.alignBottom ]
                            (List.map (viewMessage clients) (List.reverse messages))
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


viewMessage : Dict Address Client -> Message -> ( String, Element Msg )
viewMessage clients { client, content, timestamp } =
    let
        clientData = Dict.get client clients

        displayName =
            case clientData of
                Just { username } -> username
                Nothing -> client
    in
    ( client ++ "__" ++ (timestamp |> Time.posixToMillis |> String.fromInt)
    , Element.el
        [ Element.alignBottom ]
    <|
        Element.text (displayName ++ " says: " ++ content)
    )
