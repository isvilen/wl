Nonterminals keymap sections section section_type section_content
             section_value subsection item value subsection_id
             identifiers list list_elements list_element
             combination combination_element
             action arguments rest_arguments argument next_argument expression
             description.

Terminals xkb_keymap
          xkb_keycodes xkb_types xkb_compatibility xkb_symbols xkb_geometry
          identifier keyname string integer float
          '[' ']' '(' ')' '{' '}' '=' '!' '+' '-' ';' '.' ','.

Rootsymbol keymap.

Expect 1.

keymap -> xkb_keymap '{' sections '}' ';' : '$3'.


sections -> section sections : ['$1' | '$2'].
sections -> '$empty'         : [].


section -> section_type description '{' '}' ';'
         : {'$1', '$2', []}.

section -> section_type description '{' section_content '}' ';'
         : {'$1', '$2', '$4'}.


section_type -> xkb_keycodes      : '$1'.
section_type -> xkb_types         : '$1'.
section_type -> xkb_compatibility : '$1'.
section_type -> xkb_symbols       : '$1'.
section_type -> xkb_geometry      : '$1'.


section_content -> section_value ';' section_content : ['$1' | '$3'].
section_content -> section_value ',' section_content : ['$1' | '$3'].
section_content -> section_value ';'                 : ['$1'].
section_content -> section_value                     : ['$1'].


section_value -> item '=' value          : {'$1', '$3'}.
section_value -> item                    : '$1'.
section_value -> '!' item                : {'!', '$1'}.
section_value -> identifier identifiers  : {'$1', '$2'}.
section_value -> list                    : '$1'.
section_value -> subsection              : '$1'.


subsection -> identifier subsection_id '{' section_content '}'
            : {{'$1', '$2'}, '$4'}.

subsection -> identifier '{' section_content '}'
            : {'$1', '$3'}.


item -> identifier                     : '$1'.
item -> identifier integer             : {'$1', '$2'}.
item -> identifier identifier integer  : {'$1', '$2', '$3'}.
item -> keyname                        : '$1'.
item -> identifier keyname             : {'$1', '$2'}.
item -> identifier '.' identifier      : {'$1', '$2'}.
item -> identifier '[' identifier ']'  : {'$1', '$3'}.
item -> identifier '[' combination ']' : {'$1', '$3'}.


value -> integer               : '$1'.
value -> float                 : '$1'.
value -> string                : '$1'.
value -> keyname               : '$1'.
value -> identifier            : '$1'.
value -> list                  : '$1'.
value -> combination           : '$1'.
value -> action                : '$1'.


subsection_id -> string      : '$1'.
subsection_id -> keyname     : '$1'.
subsection_id -> identifier  : '$1'.
subsection_id -> combination : '$1'.


identifiers -> identifier ',' identifier  : ['$1' , '$3'].
identifiers -> identifier ',' identifiers : ['$1' | '$3'].


combination -> combination_element '+' combination_element : ['$1', '$3'].
combination -> combination_element '+' combination         : ['$1' | '$2'].

combination_element -> identifier                     : '$1'.
combination_element -> identifier '(' identifier ')'  : {'$1', '$3'}.
combination_element -> identifier '(' combination ')' : {'$1', '$3'}.


list -> '[' ']' : [].
list -> '{' '}' : [].
list -> '[' list_elements ']' : '$2'.
list -> '{' list_elements '}' : '$2'.

list_elements -> list_element                   : ['$1'].
list_elements -> list_element ',' list_elements : ['$1' | '$3'].

list_element -> value                : '$1'.
list_element -> identifier '=' value : {'$1', '$3'}.


action -> identifier '(' ')' : {'$1', []}.
action -> identifier '(' arguments ')' : {'$1', '$3'}.

arguments -> argument                    : ['$1'].
arguments -> argument ',' rest_arguments : ['$1' | '$2'].

rest_arguments -> next_argument ',' rest_arguments : ['$1' | '$2'].
rest_arguments -> next_argument                    :  ['$1'].


argument -> '!' identifier                         : {'!', '$1'}.
argument -> identifier '=' expression              : {'$1', '$3'}.
argument -> identifier '[' integer ']' '=' integer : {{'$1', '$3'}, '$6'}.

next_argument -> argument    : '$1'.
next_argument -> identifier  : '$1'.


expression -> identifier     : '$1'.
expression -> '!' identifier : {'!', '$2'}.
expression -> integer        : '$1'.
expression -> '+' integer    : {'+', '$1'}.
expression -> '-' integer    : {'-', '$1'}.


description -> string   : value_of('$1').
description -> '$empty' : "".


Erlang code.

value_of(Token) -> element(3,Token).
