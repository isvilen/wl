Nonterminals
    XkbFile
    XkbCompositeMap
    XkbCompositeType
    XkbMapConfigList
    XkbMapConfig
    FileType
    OptFlags
    Flags
    Flag
    DeclList
    Decl
    VarDecl
    KeyNameDecl
    KeyAliasDecl
    VModDecl
    VModDefList
    VModDef
    InterpretDecl
    InterpretMatch
    VarDeclList
    KeyTypeDecl
    SymbolsDecl
    SymbolsBody
    SymbolsVarDecl
    ArrayInit
    GroupCompatDecl
    ModMapDecl
    LedMapDecl
    LedNameDecl
    ShapeDecl
    SectionDecl
    SectionBody
    SectionBodyItem
    RowBody
    RowBodyItem
    Keys
    Key
    OverlayDecl
    OverlayKeyList
    OverlayKey
    OutlineList
    OutlineInList
    CoordList
    Coord
    DoodadDecl
    DoodadType
    FieldSpec
    Element
    OptMergeMode
    MergeMode
    OptExprList
    ExprList
    Expr
    Term
    ActionList
    Action
    Lhs
    Terminal
    OptKeySymList
    KeySymList
    KeySyms
    KeySym
    SignedNumber
    Number
    Float
    Integer
    KeyCode
    Ident
    String
    OptMapName
    MapName.


Terminals
    action
    alias
    alphanumeric_keys
    alternate_group
    alternate
    augment
    default
    function_keys
    group
    hidden
    include
    indicator
    interpret
    keypad_keys
    key
    keys
    logo
    modifier_keys
    modifier_map
    outline
    overlay
    override
    partial
    replace
    row
    section
    shape
    solid
    text
    type
    virtual_modifiers
    virtual
    xkb_compat
    xkb_geometry
    xkb_keycodes
    xkb_keymap
    xkb_layout
    xkb_semantics
    xkb_symbols
    xkb_types
    identifier keyname string integer float
    ';' '{' '}' '=' '[' ']' '(' ')' '.' ',' '+' '-' '*' '/' '!' '~'.


Rootsymbol XkbFile.

Right 100 '='.
Left  200 '+' '-'.
Left  300 '*' '/'.
Left  400 '!' '~'.
Left  500 '('.


XkbFile -> XkbCompositeMap : '$1'.
XkbFile -> XkbMapConfig    : '$1'.


XkbCompositeMap -> OptFlags XkbCompositeType OptMapName '{' XkbMapConfigList '}' ';'
                 : xkb_file_create('$2', '$3', '$5', '$1').


XkbCompositeType -> xkb_keymap    : keymap.
XkbCompositeType -> xkb_semantics : keymap.
XkbCompositeType -> xkb_layout    : keymap.


XkbMapConfigList -> XkbMapConfig XkbMapConfigList : ['$1' | '$2'].
XkbMapConfigList -> XkbMapConfig                  : ['$1'].


XkbMapConfig -> OptFlags FileType OptMapName '{' DeclList '}' ';'
              : xkb_file_create('$2', '$3', '$5', '$1').


FileType -> xkb_keycodes : keycodes.
FileType -> xkb_types    : types.
FileType -> xkb_compat   : compat.
FileType -> xkb_symbols  : symbols.
FileType -> xkb_geometry : geometry.


OptFlags -> Flags    : '$1'.
OptFlags -> '$empty' : [].


Flags -> Flag Flags : ['$1' | '$2'].
Flags -> Flag       : ['$1'].


Flag -> partial           : is_partial.
Flag -> default           : is_default.
Flag -> hidden            : is_hidden.
Flag -> alphanumeric_keys : has_alphanumeric.
Flag -> modifier_keys     : has_modifier.
Flag -> keypad_keys       : has_keypad.
Flag -> function_keys     : has_fn.
Flag -> alternate_group   : is_altgr.


DeclList -> Decl DeclList : ['$1' | '$2'].
DeclList -> '$empty'      : [].


Decl -> OptMergeMode VarDecl         : set_merge_mode('$2', '$1').
Decl -> OptMergeMode VModDecl        : set_merge_mode('$2', '$1').
Decl -> OptMergeMode InterpretDecl   : set_merge_mode('$2', '$1').
Decl -> OptMergeMode KeyNameDecl     : set_merge_mode('$2', '$1').
Decl -> OptMergeMode KeyAliasDecl    : set_merge_mode('$2', '$1').
Decl -> OptMergeMode KeyTypeDecl     : set_merge_mode('$2', '$1').
Decl -> OptMergeMode SymbolsDecl     : set_merge_mode('$2', '$1').
Decl -> OptMergeMode ModMapDecl      : set_merge_mode('$2', '$1').
Decl -> OptMergeMode GroupCompatDecl : set_merge_mode('$2', '$1').
Decl -> OptMergeMode LedMapDecl      : set_merge_mode('$2', '$1').
Decl -> OptMergeMode LedNameDecl     : set_merge_mode('$2', '$1').
Decl -> OptMergeMode ShapeDecl       : set_merge_mode('$2', '$1').
Decl -> OptMergeMode SectionDecl     : set_merge_mode('$2', '$1').
Decl -> OptMergeMode DoodadDecl      : set_merge_mode('$2', '$1').
Decl -> MergeMode string             : {include, value_of('$2'), value_of('$1')}.


VarDecl -> Lhs '=' Expr ';' : {'$1', '$3'}.
VarDecl -> Ident ';'        : {'$1', true}.
VarDecl -> '!' Ident ';'    : {'$1', false}.


KeyNameDecl -> keyname '=' KeyCode ';' : {keyname, value_of('$1'), '$3'}.

KeyAliasDecl -> alias keyname '=' keyname ';' : {alias, '$2', '$4'}.


VModDecl -> virtual_modifiers VModDefList ';' : {virtual_modifiers, '$2'}.


VModDefList -> VModDef ',' VModDefList : ['$1' | '$3'].
VModDefList -> VModDef                 : ['$1'].

VModDef -> Ident          : '$1'.
VModDef -> Ident '=' Expr : {'$1', '$3'}.


InterpretDecl -> interpret InterpretMatch '{' VarDeclList '}' ';'
               : {interpret, '$2', '$4'}.

InterpretMatch -> KeySym '+' Expr : {'$1', '$3'}.
InterpretMatch -> KeySym          : '$1'.


VarDeclList -> VarDecl VarDeclList : ['$1' | '$2'].
VarDeclList -> VarDecl             : ['$1'].


KeyTypeDecl -> type String '{' VarDeclList '}' ';'
             : {type, '$2', '$4'}.


SymbolsDecl -> key keyname '{' SymbolsBody '}' ';'
             : {key, value_of('$2'), '$4'}.


SymbolsBody -> SymbolsVarDecl  ',' SymbolsBody : ['$1' | '$3'].
SymbolsBody -> SymbolsVarDecl                  : ['$1'].
SymbolsBody -> '$empty'                        : [].


SymbolsVarDecl -> Lhs '=' Expr      : {'$1', '$3'}.
SymbolsVarDecl -> Lhs '=' ArrayInit : {'$1', '$3'}.
SymbolsVarDecl -> Ident             : {'$1', true}.
SymbolsVarDecl -> '!' Ident         : {'$1', false}.
SymbolsVarDecl -> ArrayInit         : '$1'.


ArrayInit -> '[' OptKeySymList ']' : '$2'.
ArrayInit -> '[' ActionList ']'    : '$2'.


GroupCompatDecl -> group Integer '=' Expr ';'
                 : {group, '$2', '$4'}.

ModMapDecl -> modifier_map Ident '{' ExprList '}' ';'
            : {modifier_map, '$2', '$4'}.

LedMapDecl -> indicator String '{' VarDeclList '}' ';'
            : {indicator, '$2', '$4'}.

LedNameDecl -> indicator Integer '=' Expr ';'
            : {indicator, '$2', '$4', false}.

LedNameDecl -> virtual indicator Integer '=' Expr ';'
            : {indicator, '$3', '$5', true}.

ShapeDecl -> shape String '{' OutlineList '}' ';'
            : {shape, '$2', '$4'}.
ShapeDecl -> shape String '{' CoordList '}' ';'
            : {shape, '$2', '$4'}.


SectionDecl -> section String '{' SectionBody '}' ';'
            : {section, '$2', '$4'}.

SectionBody -> SectionBodyItem SectionBody : ['$1' | '$2'].
SectionBody -> SectionBodyItem             : ['$1'].

SectionBodyItem -> row '{' RowBody '}' ';' : {row, '$3'}.
SectionBodyItem -> VarDecl                 : '$1'.
SectionBodyItem -> DoodadDecl              : '$1'.
SectionBodyItem -> LedMapDecl              : '$1'.
SectionBodyItem -> OverlayDecl             : '$1'.


RowBody -> RowBodyItem RowBody : ['$1' | '$2'].
RowBody -> RowBodyItem         : ['$1'].

RowBodyItem -> keys '{' Keys '}' ';' : {keys, '$3'}.
RowBodyItem -> VarDecl               : '$1'.


Keys -> Key ',' Keys : ['$1' | '$3'].
Keys -> Key          : ['$1'].

Key -> keyname          : value_of('$1').
Key -> '{' ExprList '}' : '$2'.


OverlayDecl -> overlay String '{' OverlayKeyList '}' ';'
             : {overlay, '$2', '$4'}.


OverlayKeyList -> OverlayKey ',' OverlayKeyList : ['$1' | '$3'].
OverlayKeyList -> OverlayKey                    : ['$1'].

OverlayKey ->  keyname '=' keyname : {value_of('$1'), value_of('$3')}.


OutlineList -> OutlineInList  ',' OutlineList : ['$1' | '$3'].
OutlineList -> OutlineInList                  : ['$1'].

OutlineInList ->  '{' CoordList '}'          : '$2'.
OutlineInList -> Ident '=' '{' CoordList '}' : {'$1', '$4'}.
OutlineInList -> Ident '=' Expr              : {'$1', '$3'}.

CoordList -> Coord ',' CoordList : ['$1' | '$3'].
CoordList -> Coord               : ['$1'].

Coord -> '[' SignedNumber ',' SignedNumber ']' : {'$2', '$4'}.


DoodadDecl -> DoodadType String '{' VarDeclList '}' ';'
            : {dooda, '$1', '$2', '$4'}.

DoodadType ->  text    : text.
DoodadType ->  outline : outline.
DoodadType ->  solid   : solid.
DoodadType ->  logo    : logo.


FieldSpec -> Ident   : '$1'.
FieldSpec -> Element : '$1'.

Element -> action       : "action".
Element -> interpret    : "interpret".
Element -> type         : "type".
Element -> key          : "key".
Element -> group        : "group".
Element -> modifier_map : "modifier_map".
Element -> indicator    : "indicator".
Element -> shape        : "shape".
Element -> row          : "row".
Element -> section      : "section".
Element -> text         : "text".


OptMergeMode -> MergeMode : '$1'.
OptMergeMode -> '$empty'  : default.

MergeMode -> include   : default.
MergeMode -> augment   : augment.
MergeMode -> override  : override.
MergeMode -> replace   : replace.
MergeMode -> alternate : default.


OptExprList -> ExprList : '$1'.
OptExprList -> '$empty' : [].

ExprList ->  Expr ',' ExprList : ['$1' | '$3'].
ExprList ->  Expr              : ['$1'].


Expr -> Expr '/' Expr : expr_create('/', '$1', '$3').
Expr -> Expr '+' Expr : expr_create('+', '$1', '$3').
Expr -> Expr '-' Expr : expr_create('-', '$1', '$3').
Expr -> Expr '*' Expr : expr_create('*', '$1', '$3').
Expr -> Lhs  '=' Expr : expr_create('=', '$1', '$3').
Expr -> Term          : '$1'.


Term -> '-' Term                      : expr_create('-', '$2').
Term -> '+' Term                      : expr_create('+', '$2').
Term -> '!' Term                      : expr_create('!', '$2').
Term -> '~' Term                      : expr_create('~', '$2').
Term -> Lhs                           : '$1'.
Term -> FieldSpec '(' OptExprList ')' : expr_create(apply, '$1', '$3').
Term -> Terminal                      : '$1'.
Term -> '(' Expr ')'                  : '$2'.


ActionList -> Action ',' ActionList : ['$1' | '$3'].
ActionList -> Action                : ['$1'].


Action -> FieldSpec '(' OptExprList ')' : expr_create(apply, '$1', '$3').


Lhs -> FieldSpec
     : '$1'.

Lhs -> FieldSpec '.' FieldSpec
     : {'$1', '$3'}.

Lhs -> FieldSpec '[' Expr ']'
     : {'$1', '$3'}.

Lhs -> FieldSpec '.' FieldSpec '[' Expr ']'
     : {'$1', '$3', '$5'}.


Terminal -> String  : '$1'.
Terminal -> Integer : '$1'.
Terminal -> Float   : '$1'.
Terminal -> keyname : {keyname, value_of('$1')}.


OptKeySymList -> KeySymList : '$1'.
OptKeySymList -> '$empty'   : [].


KeySymList -> KeySym  ',' KeySymList : ['$1' | '$3'].
KeySymList -> KeySyms ',' KeySymList : ['$1' | '$3'].
KeySymList -> KeySym                 : ['$1'].
KeySymList -> KeySyms                : ['$1'].


KeySyms -> '{' KeySymList '}' : '$2'.

KeySym -> identifier : resolve_keysym(value_of('$1')).
KeySym -> section    : resolve_keysym("section").
KeySym -> Integer    : resolve_keysym(integer_to_list('$1')).


SignedNumber ->  '-' Number :  -'$2'.
SignedNumber ->  Number     : '$1'.


Number -> float   : value_of('$1').
Number -> integer : value_of('$1').


Float -> float : value_of('$1').

Integer -> integer : value_of('$1').

KeyCode -> integer : value_of('$1').

Ident -> identifier : value_of('$1').

Ident -> default : "default".


String -> string : value_of('$1').


OptMapName -> MapName  : '$1'.
OptMapName -> '$empty' : "".

MapName -> string : value_of('$1').


Erlang code.

-include("wl_xkb_keysymdef.hrl").


xkb_file_create(Type, Name, Decls, Opts) ->
    {Type, Name, Decls, Opts}.


set_merge_mode(Item, MergeMode) ->
    erlang:append_element(Item, MergeMode).


value_of(Token) -> element(3,Token).


expr_create(Op, Arg1, Arg2) ->
    {Op, Arg1, Arg2}.


expr_create(Op, Arg) ->
    {Op, Arg}.


resolve_keysym("Any") ->
    any;
resolve_keysym("NoSymbol") ->
    no_symbol;
resolve_keysym([$U,D1,D2,D3,D4]=KeySym) ->
    case io_lib:fread("~16u", [D1,D2,D3,D4]) of
        {ok,[V],[]} ->
            {char, V};
        _  -> maps:get(KeySym,?XKB_KEYDEFS,undefined)
    end;
resolve_keysym(KeySym) ->
    maps:get(KeySym,?XKB_KEYDEFS,undefined).
