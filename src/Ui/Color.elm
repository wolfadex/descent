module Ui.Color exposing (gray, lightGray, primary, danger, disabled, darkGray, turquoise, cyan, info, green, success, warning, red, lighterGray, darkerGray, light, dark)

import Element exposing (Attribute, Color)
import Html.Attributes as Attributes
import Element.Border as Border
import Element.Background as Background
import Element.Font as Font

lightGray : Color
lightGray =
    Element.rgb255 219 219 219


{-| -}
disabled : List (Attribute msg)
disabled =
    [ Background.color <| lightGray
    , Border.color <| lightGray
    , Font.color <| gray
    , Element.mouseOver []
    , Element.focused []
    , Element.htmlAttribute <| Attributes.style "cursor" "not-allowed"
    ]


{-| -}
gray : Color
gray =
    Element.rgb255 122 122 122


{-| -}
darkGray : Color
darkGray =
    Element.rgb255 54 54 54


{-| -}
turquoise : Color
turquoise =
    Element.rgb255 0 209 178


{-| -}
primary : List (Attribute msg)
primary =
    [ Background.color <| turquoise
    , Border.color <| turquoise
    ]


{-| -}
cyan : Color
cyan =
    Element.rgb255 32 156 238


{-| -}
info : List (Attribute msg)
info =
    [ Background.color <| cyan
    , Border.color <| cyan
    ]


{-| -}
green : Color
green =
    Element.rgb255 35 209 96


{-| -}
success : List (Attribute msg)
success =
    [ Background.color <| green
    , Border.color <| green
    ]


{-| -}
yellow : Color
yellow =
    Element.rgb255 255 221 87


{-| -}
warning : List (Attribute msg)
warning =
    [ Background.color <| yellow
    , Border.color <| yellow
    ]


{-| -}
red : Color
red =
    Element.rgb255 255 56 96


{-| -}
danger : List (Attribute msg)
danger =
    [ Background.color <| red
    , Border.color <| red
    , Font.color <| lighterGray
    ]


{-| -}
lighterGray : Color
lighterGray =
    Element.rgb255 245 245 245


{-| -}
light : List (Attribute msg)
light =
    [ Background.color <| lighterGray
    , Border.color <| lighterGray
    ]


{-| -}
darkerGray : Color
darkerGray =
    Element.rgb255 18 18 18


{-| -}
dark : List (Attribute msg)
dark =
    [ Background.color <| darkerGray
    , Border.color <| darkerGray
    , Font.color <| lighterGray
    ]