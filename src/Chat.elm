module Chat exposing (Name, Address, Client)


type alias Name =
    String


type alias Address =
    String


type alias Client =
    { username : Name
    , avatar : Maybe String
    }